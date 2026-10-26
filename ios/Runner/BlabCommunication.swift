import UIKit
import Intents
import UserNotifications

/// Explicit local review adapter, not the production remote/account lifecycle path.
final class BlabCommunication {
 static func show(_ args: [String: Any], completion: @escaping (Error?) -> Void) {
  let c = UNMutableNotificationContent()
  c.title = args["title"] as? String ?? "Blab"
  c.body = args["body"] as? String ?? ""
  c.categoryIdentifier = "BLAB_MESSAGE_REVIEW_V1"
  c.sound = .default
  let payload = args["payload"] as? String ?? "{}"
  c.userInfo = ["NotificationId":args["id"] ?? 0,"presentBadge":false,"payload":payload,"presentAlert":true,"presentBanner":true,"presentList":true,"presentSound":true]
  let metadata = (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) as? [String:Any] ?? [:]
  let visible = metadata["previewsEnabled"] as? Bool == true
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
   donation.recipientCount = 2 // Explicit three-person local review fixture: sender + two recipients.
   intent.donationMetadata = donation
  }
  // Generic previews-off state donates no person/group/body identity.
  let interaction = INInteraction(intent:intent,response:nil)
  interaction.direction = .incoming
  interaction.donate { error in
   guard error == nil else { completion(error); return }
   do {
    let updated = try c.updating(from:intent)
    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:String(describing:args["id"] ?? "blab"),content:updated,trigger:nil),withCompletionHandler:completion)
   } catch { completion(error) }
  }
 }
}
