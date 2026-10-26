import UIKit
import UserNotifications
import Intents
@main final class App: UIResponder, UIApplicationDelegate {
 var window: UIWindow?
 func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
  let w = UIWindow(frame: UIScreen.main.bounds); let vc = UIViewController(); vc.view.backgroundColor = .systemBackground
  let label = UILabel(frame: CGRect(x: 20, y: 160, width: 350, height: 100)); label.numberOfLines = 0; label.text = "Blab native notification review\nSimulator fixtures only; not live push."; vc.view.addSubview(label); w.rootViewController = vc; w.makeKeyAndVisible(); window = w
  let center = UNUserNotificationCenter.current()
  center.setNotificationCategories([UNNotificationCategory(identifier: "BLAB_MESSAGE_REVIEW_V1", actions: [], intentIdentifiers: [], options: [])])
  center.requestAuthorization(options: [.alert, .sound, .badge]) { allowed, _ in
   guard allowed else { return }
   center.removeAllDeliveredNotifications(); center.removeAllPendingNotificationRequests()
   let scenario = ProcessInfo.processInfo.environment["BLAB_REVIEW_CASE"] ?? "direct"
   let c = UNMutableNotificationContent(); c.categoryIdentifier = "BLAB_MESSAGE_REVIEW_V1"
   c.title = scenario == "private" ? "Blab" : scenario == "group" ? "Weekend plans" : "Alice"
   c.body = scenario == "private" ? "You have a new message" : scenario == "group" ? "Shall we meet at the café?" : "See you at six!"
   c.userInfo = ["previewsEnabled": scenario != "private", "senderName": scenario == "private" ? "" : "Alice", "groupTitle": scenario == "group" ? "Weekend plans" : "", "interfaceLanguage": "en"]
   let renderer = UIGraphicsImageRenderer(size: CGSize(width:160,height:160))
   let image = renderer.image { ctx in
    if scenario == "private", let url = Bundle.main.url(forResource:"notification_badge_exact",withExtension:"png"), let mark = UIImage(contentsOfFile:url.path) { mark.draw(in:CGRect(x:0,y:0,width:160,height:160)); return }
    UIColor(red:70.0/255,green:40.0/255,blue:28.0/255,alpha:1).setFill(); ctx.fill(CGRect(x:0,y:0,width:160,height:160))
    let text = scenario == "group" ? "WE" : "AL"
    (text as NSString).draw(at:CGPoint(x:30,y:40),withAttributes:[.font:UIFont.systemFont(ofSize:64,weight:.semibold),.foregroundColor:UIColor.white])
   }
   let sender = INPerson(personHandle:INPersonHandle(value:"review-" + scenario,type:.unknown),nameComponents:nil,displayName:scenario == "private" ? "Blab" : "Alice",image:INImage(imageData:image.pngData()!),contactIdentifier:nil,customIdentifier:nil)
   let intent = INSendMessageIntent(recipients:nil,outgoingMessageType:.outgoingMessageText,content:c.body,speakableGroupName:scenario == "group" ? INSpeakableString(spokenPhrase:"Weekend plans") : nil,conversationIdentifier:"review-" + scenario,serviceName:nil,sender:sender,attachments:nil)
   if scenario == "group" { intent.setImage(INImage(imageData:image.pngData()!),forParameterNamed: \.speakableGroupName) }
   let interaction = INInteraction(intent:intent,response:nil); interaction.direction = .incoming
   interaction.donate { error in
    print("COMMUNICATION donation: \(String(describing:error))")
    do { let updated = try c.updating(from:intent)
     center.add(UNNotificationRequest(identifier:scenario,content:updated,trigger:UNTimeIntervalNotificationTrigger(timeInterval:8,repeats:false)))
    } catch { print("COMMUNICATION updating: \(error)") }
   }
  }
  return true
 }
}
