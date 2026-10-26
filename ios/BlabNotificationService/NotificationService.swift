import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
 private let lock = NSLock()
 private var handler: ((UNNotificationContent) -> Void)?
 private var fallback: UNNotificationContent?
 private func finish(_ content: UNNotificationContent) {
  lock.lock()
  let callback = handler
  handler = nil
  lock.unlock()
  callback?(content)
 }
 override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
  handler = contentHandler
  let raw = request.content.userInfo
  let generic = UNMutableNotificationContent()
  generic.title = "Blab"
  generic.body = NotificationDisplay(userInfo: NotificationAccount.sanitized(raw.merging(["previewsEnabled": false]) { _, new in new }), body: "").body
  generic.sound = request.content.sound
  // Timeout/failure never returns the original sensitive alert or metadata.
  generic.userInfo = NotificationAccount.sanitized(raw.merging(["previewsEnabled": false]) { _, new in new })
  if let messageId = raw["gcm.message_id"] as? String { generic.userInfo["gcm.message_id"] = messageId }
  generic.categoryIdentifier = "BLAB_MESSAGE_V1"
  fallback = generic
  guard NotificationAccount.matches(raw) else { finish(generic); return }

  BlabCommunication.prepare(["metadata": raw, "remote": true]) { [weak self] content, _ in
   guard let self = self else { return }
   if NotificationAccount.matches(raw), let content = content { self.finish(content) }
   else { self.finish(generic) }
  }
 }
 override func serviceExtensionTimeWillExpire() { if let fallback = fallback { finish(fallback) } }
}
