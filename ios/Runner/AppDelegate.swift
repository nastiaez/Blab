import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    #if DEBUG
    // Local review surface only; production delivery remains unchanged.
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BlabCommunication")!
    let channel = FlutterMethodChannel(name: "blab/communication-review", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "show", let args = call.arguments as? [String:Any] else { result(FlutterMethodNotImplemented); return }
      BlabCommunication.show(args) { error in
        DispatchQueue.main.async { result(error == nil ? nil : FlutterError(code:"communication",message:error!.localizedDescription,details:nil)) }
      }
    }
    #endif
  }
}
