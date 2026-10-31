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
  func plan(_ recipe: [String: Any], id: UUID) throws -> WorkoutPlan {
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

// Conserva el archivo ya registrado en CocoaPods: actualizar desde Xcode no
// necesita regenerar su lista local de fuentes para incorporar el lector.

/// Solo devuelve actividades que contienen la referencia de una pauta propia.
/// No transforma vueltas, segmentos o totales en resultados de series supuestas.
@available(iOS 18.0, *)
final class AppleActivityReader {
  private let store: HKHealthStore
  private var busy = false
  private var planCache: [UUID: WorkoutPlan] = [:]
  private var pending: Set<UUID> = []
  init(store: HKHealthStore) { self.store = store }

  func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    Task { @MainActor in
      guard HKHealthStore.isHealthDataAvailable() else {
        result(FlutterError(code: "unsupported", message: nil, details: nil)); return
      }
      guard !self.busy else {
        result(FlutterError(code: "connection_busy", message: nil, details: nil)); return
      }
      self.busy = true
      defer { self.busy = false }
      if call.method == "apple.results.authorize" {
        do {
          var types: Set<HKObjectType> = [HKObjectType.workoutType()]
          if let heart = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(heart) }
          try await self.store.requestAuthorization(toShare: [], read: types)
          // HealthKit no permite distinguir lectura denegada de una consulta vacía.
          result(["requested": true])
        } catch { result(FlutterError(code: "health_unavailable", message: nil, details: nil)) }
        return
      }
      guard call.method == "apple.results.read", let args = call.arguments as? [String: Any],
        let rawPlans = args["plans"] as? [[String: Any]], rawPlans.count <= 200 else {
        result(FlutterError(code: "invalid_prescription", message: nil, details: nil)); return
      }
      var plans: [UUID: (WorkoutPlan, String)] = [:]
      do {
        let compiler = AppleWorkoutBridge()
        for raw in rawPlans {
          guard let key = raw["plan_id"] as? String, let id = UUID(uuidString: key),
            let revision = raw["revision"] as? String, revision.count == 64,
            let recipe = raw["prescription"] as? [String: Any] else { throw ReadError.invalid }
          plans[id] = (try compiler.plan(recipe, id: id), revision)
        }
        let workouts = try await self.workouts()
        var observations: [[String: Any]] = []
        // El SDK puede no resolver workoutPlan en una primera instalación. Un
        // getter atascado no debe bloquear Salud ni provocar un enlace por fecha.
        for offset in stride(from: 0, to: workouts.count, by: 8) {
          let batch = Array(workouts[offset..<min(offset + 8, workouts.count)])
          let found = await withTaskGroup(of: (HKWorkout, WorkoutPlan?).self) { group in
            for workout in batch { group.addTask { (workout, await self.boundedPlan(workout)) } }
            var values: [(HKWorkout, WorkoutPlan?)] = []
            for await value in group { values.append(value) }
            return values
          }
          for (workout, storedPlan) in found {
            guard let plan = storedPlan, let expected = plans[plan.id] else { continue }
            var row: [String: Any] = [
              "workout_id": workout.uuid.uuidString.lowercased(), "plan_id": plan.id.uuidString.lowercased(),
              "revision": expected.1, "matches_prescription": plan.workout == expected.0.workout,
              "started_at": ISO8601DateFormatter().string(from: workout.startDate),
              "ended_at": ISO8601DateFormatter().string(from: workout.endDate), "timer_seconds": workout.duration,
            ]
            if let distance = workout.totalDistance?.doubleValue(for: .meter()) { row["distance_meters"] = distance }
            if let type = HKObjectType.quantityType(forIdentifier: .heartRate), let stats = workout.statistics(for: type) {
              let unit = HKUnit.count().unitDivided(by: .minute())
              if let average = stats.averageQuantity()?.doubleValue(for: unit) { row["average_heart_rate"] = average }
              if let maximum = stats.maximumQuantity()?.doubleValue(for: unit) { row["max_heart_rate"] = maximum }
            }
            observations.append(row)
          }
        }
        result(["observations": observations])
      } catch { result(FlutterError(code: "health_unavailable", message: nil, details: nil)) }
    }
  }

  private enum ReadError: Error { case invalid }
  @MainActor private func workouts() async throws -> [HKWorkout] {
    try await withCheckedThrowingContinuation { continuation in
      var finished = false
      let now = Date()
      let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        HKQuery.predicateForWorkouts(with: .running),
        HKQuery.predicateForSamples(withStart: now.addingTimeInterval(-14 * 86400), end: now, options: [.strictStartDate, .strictEndDate]),
      ])
      let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 201,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
        Task { @MainActor in
          guard !finished else { return }
          finished = true
          if let error = error { continuation.resume(throwing: error) }
          else if let workouts = samples as? [HKWorkout], workouts.count <= 200 { continuation.resume(returning: workouts) }
          else { continuation.resume(throwing: ReadError.invalid) }
        }
      }
      self.store.execute(query)
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 10_000_000_000)
        if !finished {
          finished = true; self.store.stop(query); continuation.resume(throwing: ReadError.invalid)
        }
      }
    }
  }

  @MainActor private func boundedPlan(_ workout: HKWorkout) async -> WorkoutPlan? {
    if let cached = planCache[workout.uuid] { return cached }
    guard !pending.contains(workout.uuid), pending.count < 200 else { return nil }
    pending.insert(workout.uuid)
    return await withCheckedContinuation { continuation in
      var finished = false
      // Esta tarea no pertenece al grupo: cancelar un getter no cooperativo no
      // puede prolongar indefinidamente la espera de la interfaz.
      Task { @MainActor in
        let plan = try? await workout.workoutPlan
        self.pending.remove(workout.uuid)
        if let plan = plan { self.planCache[workout.uuid] = plan }
        if !finished { finished = true; continuation.resume(returning: plan) }
      }
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if !finished { finished = true; continuation.resume(returning: nil) }
      }
    }
  }
}
