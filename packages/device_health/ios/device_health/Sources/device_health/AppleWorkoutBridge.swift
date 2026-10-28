import Flutter
import HealthKit
import WorkoutKit

// Adaptador Apple: la autorización comercial y las recetas pertenecen al servidor.
@available(iOS 18.0, *)
final class AppleWorkoutBridge {
  private var busy = false
  private var owners: [String: String] {
    get { UserDefaults.standard.dictionary(forKey: "entrenaop.apple.workout.owners") as? [String: String] ?? [:] }
    set { UserDefaults.standard.set(newValue, forKey: "entrenaop.apple.workout.owners") }
  }
  func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    Task { @MainActor in
      guard WorkoutScheduler.isSupported else { result(["state": "unsupported"]); return }
      let scheduler = WorkoutScheduler.shared
      if call.method == "apple.status" { result(["state": self.state(await scheduler.authorizationState)]); return }
      guard !self.busy else { result(FlutterError(code: "connection_busy", message: nil, details: nil)); return }
      self.busy = true
      defer { self.busy = false }
      if call.method == "apple.authorize" { result(["state": self.state(await scheduler.requestAuthorization())]); return }
      guard await scheduler.authorizationState == .authorized else {
        result(FlutterError(code: "permission_required", message: nil, details: nil)); return
      }
      guard let args = call.arguments as? [String: Any], let owner = args["owner"] as? String, owner.count == 64 else {
        result(FlutterError(code: "invalid_prescription", message: nil, details: nil)); return
      }
      do {
        guard let rawId = args["plan_id"] as? String, let id = UUID(uuidString: rawId) else { throw BridgeError.invalid }
        let key = id.uuidString
        if let savedOwner = self.owners[key], savedOwner != owner { throw BridgeError.account }
        let existing = await scheduler.scheduledWorkouts.filter { $0.plan.id == id }
        if call.method == "apple.remove" {
          // Solo la referencia de nuestra app devuelta por el servidor autenticado.
          for item in existing { await scheduler.remove(item.plan, at: item.date) }
          guard await scheduler.scheduledWorkouts.allSatisfy({ $0.plan.id != id }) else { throw BridgeError.unconfirmed }
          self.owners.removeValue(forKey: key)
          result(["removed": true]); return
        }
        guard call.method == "apple.schedule", let recipe = args["prescription"] as? [String: Any],
          let rawDate = recipe["date"] as? String else { throw BridgeError.invalid }
        guard !existing.contains(where: { $0.complete }) else { throw BridgeError.completed }
        let date = try self.date(rawDate)
        let plan = try self.plan(recipe, id: id)
        let all = await scheduler.scheduledWorkouts
        guard !existing.isEmpty || all.count < WorkoutScheduler.maxAllowedScheduledWorkoutCount else { throw BridgeError.capacity }
        // Validar el plan entero antes de retirar su revisión anterior.
        var owners = self.owners; owners[key] = owner; self.owners = owners
        for item in existing { await scheduler.remove(item.plan, at: item.date) }
        await scheduler.schedule(plan, at: date)
        let confirmed = await scheduler.scheduledWorkouts.filter { $0.plan.id == id }
        // Un UUID y una fecha no acreditan que Apple haya aplicado los cambios.
        guard confirmed.count == 1, let saved = confirmed.first,
          saved.plan.workout == plan.workout, saved.date.year == date.year,
          saved.date.month == date.month, saved.date.day == date.day else { throw BridgeError.unconfirmed }
        result(["submitted": true])
      } catch let error as BridgeError { result(FlutterError(code: error.rawValue, message: nil, details: nil)) }
      catch { result(FlutterError(code: "apple_unavailable", message: nil, details: nil)) }
    }
  }
  private enum BridgeError: String, Error {
    case invalid = "unsupported_prescription", account = "account_changed"
    case capacity = "capacity_reached", unconfirmed = "delivery_uncertain"
    case completed = "already_completed"
  }
  private func state(_ state: WorkoutScheduler.AuthorizationState) -> String {
    switch state {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unsupported"
    }
  }
  private func date(_ raw: String) throws -> DateComponents {
    let parts = raw.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3, raw.count == 10 else { throw BridgeError.invalid }
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
    let result = DateComponents(calendar: calendar, timeZone: .current, year: parts[0], month: parts[1], day: parts[2])
    guard let value = calendar.date(from: result), calendar.component(.month, from: value) == parts[1], calendar.component(.day, from: value) == parts[2] else { throw BridgeError.invalid }
    return result
  }
  private func plan(_ recipe: [String: Any], id: UUID) throws -> WorkoutPlan {
    guard let name = recipe["name"] as? String, !name.isEmpty, name.count <= 255,
      let rows = recipe["steps"] as? [[String: Any]], !rows.isEmpty, rows.count <= 100 else { throw BridgeError.invalid }
    var warmup: WorkoutStep?, cooldown: WorkoutStep?
    var intervals: [IntervalStep] = []
    for (index, row) in rows.enumerated() {
      guard let kind = row["kind"] as? String, let measure = row["measure"] as? String,
        let description = row["description"] as? String, description.count <= 512 else { throw BridgeError.invalid }
      let goal: WorkoutGoal
      if measure == "manual" { goal = .open }
      else {
        guard let n = row["value"] as? Double, n.isFinite, n > 0 else { throw BridgeError.invalid }
        switch measure {
        case "seconds": goal = .time(n, .seconds)
        case "meters": goal = .distance(n, .meters)
        default: throw BridgeError.invalid
        }
      }
      var alert: (any WorkoutAlert)?
      if let pace = row["pace"] as? [String: Any] {
        guard let fast = pace["fast"] as? Double, let slow = pace["slow"] as? Double,
          fast.isFinite, slow.isFinite, fast > 0, slow >= fast else { throw BridgeError.invalid }
        // s/km pasa a m/s: el extremo lento se convierte en el límite inferior.
        alert = SpeedRangeAlert(target: Measurement(value: 1000 / slow, unit: UnitSpeed.metersPerSecond)...Measurement(value: 1000 / fast, unit: UnitSpeed.metersPerSecond), metric: .current)
      }
      guard CustomWorkout.supportsGoal(goal, activity: .running, location: .outdoor) else { throw BridgeError.invalid }
      if let alert = alert, !CustomWorkout.supportsAlert(alert, activity: .running, location: .outdoor) { throw BridgeError.invalid }
      let step = WorkoutStep(goal: goal, alert: alert, displayName: description)
      switch kind {
      case "warmup": guard index == 0 else { throw BridgeError.invalid }; warmup = step
      case "cooldown": guard index == rows.count - 1 else { throw BridgeError.invalid }; cooldown = step
      case "run": intervals.append(IntervalStep(.work, step: step))
      case "rest", "recovery", "walk", "jog": intervals.append(IntervalStep(.recovery, step: step))
      default: throw BridgeError.invalid
      }
    }
    guard !intervals.isEmpty else { throw BridgeError.invalid }
    let workout = CustomWorkout(activity: .running, location: .outdoor, displayName: name, warmup: warmup,
      blocks: [IntervalBlock(steps: intervals, iterations: 1)], cooldown: cooldown)
    return WorkoutPlan(.custom(workout), id: id)
  }
}
