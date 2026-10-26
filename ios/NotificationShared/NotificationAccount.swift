import Foundation

/// No credentials or history in the shared container. Epoch is installation/account scoped.
enum NotificationAccount {
 static var suite: String { "group." + (Bundle.main.object(forInfoDictionaryKey: "BlabParentBundleID") as? String ?? Bundle.main.bundleIdentifier ?? "invalid") + ".notifications" }
 static var defaults: UserDefaults? { UserDefaults(suiteName: suite) }
 static func snapshot() -> [String: Any] {
  let store = defaults
  store?.synchronize()
  return store?.dictionary(forKey: "account") ?? [:]
 }
 static func matches(_ payload: [AnyHashable: Any]) -> Bool {
  let state = snapshot()
  guard let receiver = state["receiverId"] as? String, !receiver.isEmpty,
        let epoch = state["accountEpoch"] as? String, !epoch.isEmpty else { return false }
  return payload["receiverId"] as? String == receiver && payload["accountEpoch"] as? String == epoch && payload["iosPresentation"] as? String == "blab_communication_v1"
 }
 static func sanitized(_ payload: [AnyHashable: Any]) -> [AnyHashable: Any] {
  let state = snapshot()
  let visible = matches(payload) && state["previewsEnabled"] as? Bool == true && (payload["previewsEnabled"] as? Bool == true || payload["previewsEnabled"] as? String == "true")
  var result: [AnyHashable: Any] = ["previewsEnabled": visible, "interfaceLanguage": state["interfaceLanguage"] as? String ?? "en"]
  if matches(payload) {
   for key in ["receiverId", "accountEpoch", "chatId", "messageId", "type", "iosPresentation"] { result[key] = payload[key] }
  }
  if visible {
   for key in ["senderName", "groupTitle", "blabPreviewBody", "recipientCount"] { result[key] = payload[key] }
  }
  return result
 }
}
