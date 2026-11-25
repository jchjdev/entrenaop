import Flutter
import UIKit
import firebase_messaging
import device_health

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var workoutVibration: WorkoutVibration?
  private var phoneRunLocation: PhoneRunLocation?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    DeviceHealthBackgroundDelivery.prepareAtLaunch()
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PhoneRunLocation") {
      phoneRunLocation = PhoneRunLocation(messenger: registrar.messenger())
    }
    if #available(iOS 16.2, *),
      let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WorkoutLockScreen") {
      let activity = StrengthWorkoutLiveActivity()
      let channel = FlutterMethodChannel(
        name: "es.entrenaop/workout_lock_screen", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "show":
          if let data = call.arguments as? [String: Any] { activity.show(data) }
          result(true)
        case "clear":
          if let executionId = call.arguments as? String { activity.clear(executionId) }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WorkoutVibration") {
      workoutVibration = WorkoutVibration(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ClockScreen") {
      let channel = FlutterMethodChannel(
        name: "es.entrenaop/clock_screen", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "setEnabled", let enabled = call.arguments as? Bool else {
          result(FlutterMethodNotImplemented)
          return
        }
        UIApplication.shared.isIdleTimerDisabled = enabled
        result(nil)
      }
    }
  }
}
