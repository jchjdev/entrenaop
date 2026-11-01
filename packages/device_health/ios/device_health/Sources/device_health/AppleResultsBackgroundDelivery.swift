import Flutter
import HealthKit
import UIKit

/// Conserva avisos, nunca mediciones ni credenciales. La sincronización usa el
/// caso de uso Dart y la sesión vigente, incluso al arrancar por HealthKit.
public final class DeviceHealthBackgroundDelivery: NSObject {
  private static let shared = DeviceHealthBackgroundDelivery()
  private let store = HKHealthStore()
  private let wantedKey = "es.entrenaop.apple-results.background-wanted"
  private let dirtyKey = "es.entrenaop.apple-results.background-pending"
  private var queries: [HKObserverQuery] = []
  private var channel: FlutterMethodChannel?
  private var completions: [UUID: () -> Void] = [:]
  private var sending = false
  private var changes = 0
  private var flight: UUID?
  private var backgroundTask = UIBackgroundTaskIdentifier.invalid
  private var generation = 0
  private var notifications: [NSObjectProtocol] = []

  public static func prepareAtLaunch() {
    guard #available(iOS 18.0, *) else { return }
    shared.startIfWanted()
  }

  static func attach(messenger: FlutterBinaryMessenger) {
    let instance = shared
    let channel = FlutterMethodChannel(name: "es.entrenaop.device_health/background", binaryMessenger: messenger)
    instance.channel = channel
    channel.setMethodCallHandler { call, result in
      DispatchQueue.main.async {
        if call.method == "detach" {
          instance.channel = nil
          instance.finish(success: false)
          result(nil)
          return
        }
        guard call.method == "configure", let args = call.arguments as? [String: Any],
          let enabled = args["enabled"] as? Bool else {
          result(FlutterMethodNotImplemented); return
        }
        instance.configure(enabled: enabled, result: result)
      }
    }
  }

  private func configure(enabled: Bool, result: @escaping FlutterResult) {
    generation += 1
    let expected = generation
    guard enabled, #available(iOS 18.0, *) else {
      UserDefaults.standard.set(false, forKey: wantedKey)
      UserDefaults.standard.set(false, forKey: dirtyKey)
      queries.forEach { store.stop($0) }
      queries.removeAll()
      finish(success: false)
      store.disableBackgroundDelivery(for: HKObjectType.workoutType()) { _, _ in }
      if #available(iOS 18.0, *), let effort = HKObjectType.quantityType(forIdentifier: .workoutEffortScore) {
        store.disableBackgroundDelivery(for: effort) { _, _ in }
      }
      result(false)
      return
    }
    store.enableBackgroundDelivery(for: HKObjectType.workoutType(), frequency: .immediate) { success, _ in
      DispatchQueue.main.async {
        guard expected == self.generation else { result(false); return }
        UserDefaults.standard.set(success, forKey: self.wantedKey)
        if success {
          self.startIfWanted()
          if let effort = HKObjectType.quantityType(forIdentifier: .workoutEffortScore) {
            // El esfuerzo puede guardarse después del entrenamiento. Su aviso
            // relee el resultado; no se interpreta como un nuevo entrenamiento.
            self.store.enableBackgroundDelivery(for: effort, frequency: .immediate) { _, _ in }
          }
        }
        result(success)
        // La respuesta de configuración debe llegar antes del aviso: evita que
        // la lectura espere su propia configuración al arrancar el motor.
        DispatchQueue.main.async { self.flush() }
      }
    }
  }

  private func startIfWanted() {
    guard queries.isEmpty, UserDefaults.standard.bool(forKey: wantedKey),
      HKHealthStore.isHealthDataAvailable() else { return }
    var types: [HKSampleType] = [HKObjectType.workoutType()]
    if #available(iOS 18.0, *), let effort = HKObjectType.quantityType(forIdentifier: .workoutEffortScore) { types.append(effort) }
    for type in types {
      let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
        DispatchQueue.main.async {
          guard error == nil else { completion(); return }
          self.changes += 1
          UserDefaults.standard.set(true, forKey: self.dirtyKey)
          let notification = UUID()
          self.completions[notification] = completion
          // Un arranque sin motor/sesión lista tampoco deja a HealthKit esperando.
          DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            self.completions.removeValue(forKey: notification)?()
          }
          self.flush()
        }
      }
      queries.append(query)
      store.execute(query)
    }
    if notifications.isEmpty {
      for name in [UIApplication.protectedDataDidBecomeAvailableNotification, UIApplication.willEnterForegroundNotification] {
        notifications.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in self.flush() })
      }
    }
  }

  private func flush() {
    guard !sending, let channel = channel,
      UserDefaults.standard.bool(forKey: wantedKey),
      UserDefaults.standard.bool(forKey: dirtyKey) else { return }
    guard UIApplication.shared.isProtectedDataAvailable else {
      // Salud puede estar protegida con el teléfono bloqueado; se relee al
      // desbloquear, sin borrar el aviso ni almacenar una copia de los datos.
      finish(success: false)
      return
    }
    sending = true
    let expected = generation
    let version = changes
    let request = UUID()
    flight = request
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AppleResults") {
      self.close(request: request, success: false, version: version)
    }
    channel.invokeMethod("changed", arguments: nil) { answer in
      self.close(request: request, success: (answer as? Bool) == true && expected == self.generation, version: version)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
      self.close(request: request, success: false, version: version)
    }
  }

  private func close(request: UUID, success: Bool, version: Int) {
    guard flight == request else { return }
    let repeatRead = success && changes != version
    finish(success: success && !repeatRead)
    // Un aviso llegado durante la lectura puede representar datos posteriores
    // a la consulta. Nunca se borra ese aviso con la respuesta de la anterior.
    if repeatRead { DispatchQueue.main.async { self.flush() } }
  }

  private func finish(success: Bool) {
    if success { UserDefaults.standard.set(false, forKey: dirtyKey) }
    sending = false
    flight = nil
    if backgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
    let callbacks = Array(completions.values)
    completions.removeAll()
    // Siempre se acusa el aviso al sistema. Si falta red/sesión, el marcador
    // pendiente y la lectura idempotente recuperan los datos en la siguiente
    // entrega o apertura, sin interpretar un fallo como una importación válida.
    callbacks.forEach { $0() }
  }
}
