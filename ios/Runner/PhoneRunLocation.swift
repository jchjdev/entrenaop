import CoreLocation
import AVFAudio
import Flutter
import UIKit

final class PhoneRunLocation: NSObject, CLLocationManagerDelegate, FlutterStreamHandler {
  private let manager = CLLocationManager()
  private var token: String?
  private var pendingStart: FlutterResult?
  private var sink: FlutterEventSink?
  private let speech = AVSpeechSynthesizer()
  private var liveActivity: AnyObject?

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    if #available(iOS 16.2, *) { liveActivity = PhoneRunLiveActivity() }
    manager.delegate = self
    manager.activityType = .fitness
    manager.desiredAccuracy = kCLLocationAccuracyBest
    // La pausa y reanudación las controla el deportista, también al bloquear.
    manager.pausesLocationUpdatesAutomatically = false

    let methods = FlutterMethodChannel(name: "es.entrenaop/phone_run", binaryMessenger: messenger)
    methods.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: nil, details: nil))
        return
      }
      switch call.method {
      case "start":
        guard let requested = call.arguments as? String else {
          result(FlutterError(code: "invalid_session", message: nil, details: nil))
          return
        }
        self.start(requested, result)
      case "stop":
        if self.token == call.arguments as? String { self.stop() }
        result(nil)
      case "publishProgress":
        if #available(iOS 16.2, *), let data = call.arguments as? [String: Any],
          let token = self.token, data["token"] as? String == token {
          (self.liveActivity as? PhoneRunLiveActivity)?.publish(data, token: token)
        }
        result(nil)
      case "endProgress":
        if #available(iOS 16.2, *), let token = call.arguments as? String {
          (self.liveActivity as? PhoneRunLiveActivity)?.end(token)
        }
        result(nil)
      case "speak":
        if let text = call.arguments as? String { self.speak(text) }
        result(nil)
      case "silence":
        self.speech.stopSpeaking(at: .immediate)
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
    let events = FlutterEventChannel(
      name: "es.entrenaop/phone_run/locations", binaryMessenger: messenger)
    events.setStreamHandler(self)
  }

  private func speak(_ text: String) {
    speech.stopSpeaking(at: .immediate)
    try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
    speech.speak(utterance)
  }

  private func start(_ requested: String, _ result: @escaping FlutterResult) {
    guard token == nil else {
      result(FlutterError(code: "busy", message: nil, details: nil))
      return
    }
    token = requested
    pendingStart = result
    if manager.authorizationStatus == .notDetermined {
      manager.requestWhenInUseAuthorization()
    } else {
      resolveAuthorization()
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    resolveAuthorization()
  }

  private func resolveAuthorization() {
    let authorized = manager.authorizationStatus == .authorizedWhenInUse
      || manager.authorizationStatus == .authorizedAlways
    if let result = pendingStart {
      guard manager.authorizationStatus != .notDetermined else { return }
      pendingStart = nil
      guard authorized, manager.accuracyAuthorization == .fullAccuracy else {
        stop()
        result(FlutterError(code: "permission", message: nil, details: nil))
        return
      }
      guard UIApplication.shared.applicationState != .background else {
        stop()
        result(FlutterError(code: "unavailable", message: nil, details: nil))
        return
      }
      manager.allowsBackgroundLocationUpdates = true
      manager.showsBackgroundLocationIndicator = true
      manager.startUpdatingLocation()
      result(nil)
    } else if token != nil
      && (!authorized || manager.accuracyAuthorization != .fullAccuracy) {
      interrupt("permission")
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let token else { return }
    for location in locations {
      sink?([
        "token": token,
        "lat": location.coordinate.latitude,
        "lon": location.coordinate.longitude,
        "accuracy": location.horizontalAccuracy,
        "time": Int64(location.timestamp.timeIntervalSince1970 * 1000),
      ])
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    switch (error as? CLError)?.code {
    case .locationUnknown: break
    case .denied: interrupt("permission")
    default: interrupt("interrupted")
    }
  }

  private func interrupt(_ error: String) {
    guard let token else { return }
    sink?(["token": token, "error": error])
    stop()
  }

  private func stop() {
    if #available(iOS 16.2, *), let token {
      (liveActivity as? PhoneRunLiveActivity)?.end(token)
    }
    speech.stopSpeaking(at: .immediate)
    token = nil
    manager.stopUpdatingLocation()
    manager.allowsBackgroundLocationUpdates = false
    manager.showsBackgroundLocationIndicator = false
    let result = pendingStart
    pendingStart = nil
    result?(FlutterError(code: "cancelled", message: nil, details: nil))
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    stop()
    return nil
  }
}
