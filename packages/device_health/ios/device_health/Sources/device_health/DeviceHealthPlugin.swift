import Flutter
import HealthKit
import UIKit

public final class DeviceHealthPlugin: NSObject, FlutterPlugin {
  private var applePlanner: AnyObject?
  private var appleResults: AnyObject?
  private let store = HKHealthStore()
  private let channel: FlutterMethodChannel
  private var activeQuery: HKSampleQuery?
  private var activeToken: UUID?
  private var pendingResult: FlutterResult?
  private var consentToken: UUID?
  private var pendingConsent: FlutterResult?
  private var backgroundObserver: NSObjectProtocol?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = DeviceHealthPlugin(messenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: instance.channel)
    registrar.publish(instance)
  }

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "es.entrenaop.device_health/reader", binaryMessenger: messenger)
    super.init()
    backgroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.cancelRead() }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method.hasPrefix("apple.results.") {
      if #available(iOS 18.0, *) {
        if appleResults == nil { appleResults = AppleActivityReader(store: store) }
        (appleResults as! AppleActivityReader).handle(call, result)
      } else { result(FlutterError(code: "unsupported", message: nil, details: nil)) }
      return
    }
    if call.method.hasPrefix("apple.") {
      if #available(iOS 18.0, *) {
        if applePlanner == nil { applePlanner = AppleWorkoutBridge() }
        (applePlanner as! AppleWorkoutBridge).handle(call, result)
      } else { result(["state": "unsupported"]) }
      return
    }
    if call.method == "status" {
      result(HKHealthStore.isHealthDataAvailable() ? "available" : "unavailable")
      return
    }
    guard HKHealthStore.isHealthDataAvailable() else {
      result(FlutterError(code: "unavailable", message: nil, details: nil))
      return
    }
    switch call.method {
    case "requestReadAccess":
      guard consentToken == nil, activeToken == nil else {
        result(FlutterError(code: "readFailed", message: nil, details: nil))
        return
      }
      let token = UUID()
      consentToken = token
      pendingConsent = result
      // Completar el diálogo no acredita que el titular haya concedido lectura.
      store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()]) { [weak self] success, _ in
        DispatchQueue.main.async {
          guard let self = self, self.consentToken == token else { return }
          self.consentToken = nil
          self.pendingConsent = nil
          if success {
            result("queryAllowedUnknown")
          } else {
            result(FlutterError(code: "readFailed", message: nil, details: nil))
          }
        }
      }
    case "readRuns": read(call.arguments, result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func read(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard activeToken == nil, consentToken == nil,
      let arguments = arguments as? [String: Any],
      let startNumber = arguments["startMicros"] as? NSNumber,
      let endNumber = arguments["endMicros"] as? NSNumber
    else {
      result(FlutterError(code: "readFailed", message: nil, details: nil))
      return
    }
    let startMicros = startNumber.int64Value
    let endMicros = endNumber.int64Value
    guard startMicros >= 0, endMicros > startMicros,
      endMicros - startMicros <= 7 * 86400 * 1_000_000
    else {
      result(FlutterError(code: "readFailed", message: nil, details: nil))
      return
    }
    let start = Date(timeIntervalSince1970: Double(startMicros) / 1_000_000)
    let end = Date(timeIntervalSince1970: Double(endMicros) / 1_000_000)
    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      HKQuery.predicateForWorkouts(with: .running),
      HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate]),
    ])
    let token = UUID()
    activeToken = token
    pendingResult = result
    let query = HKSampleQuery(
      sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 201,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
    ) { [weak self] _, samples, error in
      DispatchQueue.main.async {
        guard let self = self, self.activeToken == token else { return }
        self.activeToken = nil
        self.activeQuery = nil
        self.pendingResult = nil
        guard error == nil, let workouts = samples as? [HKWorkout] else {
          result(FlutterError(code: "readFailed", message: nil, details: nil))
          return
        }
        result([
          "runs": workouts.prefix(200).map(self.encode),
          "truncated": workouts.count > 200,
        ])
      }
    }
    activeQuery = query
    store.execute(query)
  }

  private func encode(_ workout: HKWorkout) -> [String: Any] {
    var row: [String: Any] = [
      "id": workout.uuid.uuidString,
      "kind": "running",
      "startMicros": Int64((workout.startDate.timeIntervalSince1970 * 1_000_000).rounded()),
      "endMicros": Int64((workout.endDate.timeIntervalSince1970 * 1_000_000).rounded()),
      "timerMicros": Int64((workout.duration * 1_000_000).rounded()),
      "writerApplication": workout.sourceRevision.source.bundleIdentifier,
    ]
    if let distance = workout.totalDistance?.doubleValue(for: HKUnit.meter()) {
      row["distanceMeters"] = distance
    }
    if let identifier = workout.metadata?[HKMetadataKeyTimeZone] as? String,
      let zone = TimeZone(identifier: identifier) {
      row["timeZoneId"] = identifier
      row["startOffsetSeconds"] = zone.secondsFromGMT(for: workout.startDate)
      row["endOffsetSeconds"] = zone.secondsFromGMT(for: workout.endDate)
    }
    if let brand = workout.device?.manufacturer, !brand.isEmpty { row["deviceBrand"] = brand }
    // HealthKit no aporta aquí una fecha de modificación: no usamos la recepción.
    return row
  }

  private func cancelRead() {
    activeToken = nil
    if let query = activeQuery { store.stop(query) }
    activeQuery = nil
    let result = pendingResult
    pendingResult = nil
    result?(FlutterError(code: "readFailed", message: nil, details: nil))
  }

  deinit {
    if let observer = backgroundObserver { NotificationCenter.default.removeObserver(observer) }
    if let query = activeQuery { store.stop(query) }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    cancelRead()
    consentToken = nil
    let consent = pendingConsent
    pendingConsent = nil
    consent?(FlutterError(code: "readFailed", message: nil, details: nil))
    channel.setMethodCallHandler(nil)
    if let observer = backgroundObserver { NotificationCenter.default.removeObserver(observer) }
    backgroundObserver = nil
  }
}
