import CoreHaptics
import Flutter
import UIKit

final class WorkoutVibration: NSObject {
  private let channel: FlutterMethodChannel
  private var engine: CHHapticEngine?
  private var player: CHHapticPatternPlayer?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "es.entrenaop/workout_vibration", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "haptics_unavailable", message: nil, details: nil))
        return
      }
      self.handle(call, result: result)
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(cancel),
      name: UIApplication.willResignActiveNotification, object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    engine?.stop(completionHandler: nil)
  }

  private func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "diagnostics":
      result([
        "supportsHaptics": CHHapticEngine.capabilitiesForHardware().supportsHaptics,
        "visible": UIApplication.shared.applicationState == .active,
        "engineCreated": engine != nil,
        "engineMuted": engine?.isMutedForHaptics ?? false,
      ])
    case "signal":
      guard let cue = call.arguments as? String else {
        result(FlutterError(code: "invalid_cue", message: "Aviso inválido.", details: nil))
        return
      }
      do {
        result(try signal(cue))
      } catch {
        NSLog("EntrenaOPVibration: aviso=%@ error=%@", cue, error.localizedDescription)
        result(FlutterError(
          code: "haptics_failed", message: error.localizedDescription, details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func signal(_ cue: String) throws -> Bool {
    let pattern = try Self.pattern(for: cue)
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
    guard UIApplication.shared.applicationState == .active else {
      throw NSError(domain: "EntrenaOPVibration", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "La sesión debe estar en primer plano."
      ])
    }
    if engine == nil {
      let created = try CHHapticEngine()
      // Solo eventos hápticos: el audio sigue a cargo del reproductor existente.
      created.playsHapticsOnly = true
      created.isAutoShutdownEnabled = true
      created.resetHandler = { [weak self] in
        DispatchQueue.main.async { self?.player = nil }
      }
      created.stoppedHandler = { [weak self] _ in
        DispatchQueue.main.async { self?.player = nil }
      }
      engine = created
    }
    guard let engine = engine else { return false }
    // Reiniciar tras interrupciones y recrear el player evita reutilizar uno
    // invalidado por iOS. No se repite ningún aviso al volver a la sesión.
    try engine.start()
    try? player?.stop(atTime: CHHapticTimeImmediate)
    let next = try engine.makePlayer(with: pattern)
    player = next
    try next.start(atTime: CHHapticTimeImmediate)
    NSLog("EntrenaOPVibration: iOS aviso=%@ enviada=true duración=%.3f", cue, pattern.duration)
    return true
  }

  @objc private func cancel() {
    try? player?.stop(atTime: CHHapticTimeImmediate)
    player = nil
    engine?.stop(completionHandler: nil)
  }

  static func pattern(for cue: String) throws -> CHHapticPattern {
    let pulses: [(start: TimeInterval, duration: TimeInterval)]
    switch cue {
    case "preparationTick", "workEndingTick": pulses = [(0, 0.060)]
    case "halfway", "tenSecondsRemaining": pulses = [(0, 0.120)]
    case "workStarted": pulses = [(0, 0.200)]
    case "workFinished", "restFinished": pulses = [(0, 0.160), (0.260, 0.160)]
    default:
      throw NSError(domain: "EntrenaOPVibration", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Aviso de vibración desconocido."
      ])
    }
    let events = pulses.map { pulse in
      CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
        ],
        relativeTime: pulse.start, duration: pulse.duration)
    }
    return try CHHapticPattern(events: events, parameters: [])
  }
}
