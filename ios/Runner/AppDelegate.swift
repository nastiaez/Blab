import Flutter
import UIKit
import UserNotifications
import Intents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BlabCommunication")!
    let channel = FlutterMethodChannel(name: "blab/communication", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "state":
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NotificationAccount.suite) != nil else {
          result(FlutterError(code: "app_group_unavailable", message: "Notification account storage is unavailable", details: nil)); return
        }
        let old = NotificationAccount.snapshot()
        let receiver = args["receiverId"] as? String ?? ""
        let previews = args["previewsEnabled"] as? Bool == true
        let changed = old["receiverId"] as? String != receiver || old["previewsEnabled"] as? Bool != previews
        let epoch = changed ? UUID().uuidString : (old["accountEpoch"] as? String ?? UUID().uuidString)
        let state: [String: Any] = ["receiverId": receiver, "previewsEnabled": previews, "accountEpoch": epoch, "interfaceLanguage": args["interfaceLanguage"] as? String ?? "en"]
        NotificationAccount.defaults?.set(state, forKey: "account")
        NotificationAccount.defaults?.synchronize()
        if changed {
          UNUserNotificationCenter.current().removeAllDeliveredNotifications()
          UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
          INInteraction.deleteAll(completion: nil)
        }
        result(["accountEpoch": epoch, "iosPresentation": "blab_communication_v1"])
      case "show":
        BlabCommunication.show(args) { error in
          DispatchQueue.main.async { result(error == nil ? nil : FlutterError(code: "communication", message: error!.localizedDescription, details: nil)) }
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}
