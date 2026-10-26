import UIKit
import Intents
import UserNotifications

/// Production local communication adapter.
final class BlabCommunication {
 static func show(_ args: [String: Any], completion: @escaping (Error?) -> Void) {
  prepare(args) { content, error in
   guard let content = content else { completion(error); return }
   DispatchQueue.main.async {
    let raw = args["metadata"] as? [String:Any] ?? [:]
    guard NotificationAccount.matches(raw) else { completion(nil); return }
    let id = String(describing:args["id"] ?? "blab")
    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:id,content:content,trigger:nil)) { error in
     if !NotificationAccount.matches(raw) {
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
     }
     completion(error)
    }
   }
  }
 }
 static func prepare(_ args: [String: Any], completion: @escaping (UNNotificationContent?, Error?) -> Void) {
  let raw = args["metadata"] as? [String:Any] ?? [:]
  let metadata = NotificationAccount.sanitized(raw)
  guard NotificationAccount.matches(raw) else { completion(nil, nil); return }
  let display = NotificationDisplay(userInfo: metadata, body: metadata["blabPreviewBody"] as? String ?? "")
  let c = UNMutableNotificationContent()
  c.title = display.title
  c.body = display.body
  c.categoryIdentifier = "BLAB_MESSAGE_V1"
  c.sound = .default
  c.threadIdentifier = "blab:" + (metadata["receiverId"] as? String ?? "") + ":" + (metadata["chatId"] as? String ?? "")
  let payload = String(data: (try? JSONSerialization.data(withJSONObject: metadata)) ?? Data(), encoding: .utf8) ?? "{}"
  c.userInfo = ["NotificationId":args["id"] ?? 0,"presentBadge":false,"payload":payload,"presentAlert":true,"presentBanner":true,"presentList":true,"presentSound":true]
  if args["remote"] as? Bool == true { c.userInfo = metadata }
  for (key, value) in metadata { c.userInfo[key] = value }
  // Firebase's remote-open delegate requires this non-display transport identifier.
  if let messageId = raw["gcm.message_id"] as? String { c.userInfo["gcm.message_id"] = messageId }
  let visible = display.initials != nil
  let group = metadata["groupTitle"] as? String ?? ""
  let senderName = metadata["senderName"] as? String ?? c.title
  let identity = group.isEmpty ? senderName : group
  let renderer = UIGraphicsImageRenderer(size:CGSize(width:160,height:160))
  let image = renderer.image { context in
   if !visible {
    UIImage(named:"notification_badge_exact")?.draw(in:CGRect(x:0,y:0,width:160,height:160))
    return
   }
   let colors: [UInt32] = [0x46281C,0x917869,0xBC6C4E,0x788C73,0xAF787D,0x5F3C4B]
   let hex = colors[identity.utf16.reduce(0){$0+Int($1)} % colors.count]
   UIColor(red:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1).setFill()
   context.fill(CGRect(x:0,y:0,width:160,height:160))
   let text = String(identity.filter{!$0.isWhitespace}.prefix(2)).uppercased() as NSString
   let style: [NSAttributedString.Key:Any] = [.font:UIFont.systemFont(ofSize:60,weight:.semibold),.foregroundColor:UIColor.white]
   let size = text.size(withAttributes:style)
   text.draw(at:CGPoint(x:(160-size.width)/2,y:(160-size.height)/2),withAttributes:style)
  }
  let avatar = INImage(imageData:image.pngData()!)
  let conversation = visible ? "\(metadata["receiverId"] ?? ""):\(metadata["chatId"] ?? "")" : "blab-private"
  let person = INPerson(personHandle:INPersonHandle(value:conversation,type:.unknown),nameComponents:nil,displayName:visible ? senderName : "Blab",image:avatar,contactIdentifier:nil,customIdentifier:nil)
  let intent = INSendMessageIntent(recipients:nil,outgoingMessageType:.outgoingMessageText,content:c.body,speakableGroupName:visible && !group.isEmpty ? INSpeakableString(spokenPhrase:group) : nil,conversationIdentifier:conversation,serviceName:nil,sender:person,attachments:nil)
  if visible && !group.isEmpty {
   intent.setImage(avatar,forParameterNamed: \.speakableGroupName)
   let donation = INSendMessageIntentDonationMetadata()
   let recipients = (metadata["recipientCount"] as? Int) ?? Int(metadata["recipientCount"] as? String ?? "")
   if let recipients = recipients, recipients > 0 && recipients <= 100 {
    donation.recipientCount = recipients
    intent.donationMetadata = donation
   }
  }
  // Generic previews-off state donates no person/group/body identity.
  let interaction = INInteraction(intent:intent,response:nil)
  interaction.direction = .incoming
  interaction.identifier = conversation + ":" + (metadata["accountEpoch"] as? String ?? "")
  interaction.donate { error in
   guard NotificationAccount.matches(raw) else {
    INInteraction.delete(with: [interaction.identifier], completion: nil)
    completion(nil, nil); return
   }
   guard error == nil else { completion(nil, error); return }
   do {
    let updated = try c.updating(from:intent)
    completion(updated, nil)
   } catch { completion(nil, error) }
  }
 }
}
