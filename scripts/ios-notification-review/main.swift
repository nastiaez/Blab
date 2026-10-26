import Foundation
var checks = 0
func check(_ yes: Bool) { precondition(yes); checks += 1 }
for flag: Any in [false, "false", "TRUE", "", NSNull()] {
 for language in ["en", "de", "es", "uk", "unknown"] {
  let p = NotificationDisplay(userInfo: ["previewsEnabled": flag, "senderName": "SECRET", "groupTitle": "PRIVATE", "interfaceLanguage": language], body: "HIDDEN")
  check(p.title == "Blab"); check(p.initials == nil); check(!p.isGroup); check(!p.body.contains("HIDDEN")); check(!p.body.contains("SECRET"))
 }
}
let missing = NotificationDisplay(userInfo: ["senderName": "SECRET"], body: "HIDDEN")
check(missing.initials == nil); check(missing.title == "Blab")
for flag: Any in [true, "true"] {
 let direct = NotificationDisplay(userInfo: ["previewsEnabled": flag, "senderName": " Alice "], body: "See you at six!")
 check(direct.avatarHex == 0xAF787D); check(direct.title == "Alice"); check(direct.initials == "AL"); check(direct.body == "See you at six!"); check(!direct.isGroup)
 let group = NotificationDisplay(userInfo: ["previewsEnabled": flag, "senderName": "Alice", "groupTitle": "Weekend plans"], body: "Café?")
 check(group.avatarHex == 0x788C73); check(group.title == "Weekend plans"); check(group.initials == "WE"); check(group.body == "Alice: Café?"); check(group.isGroup)
}
let empty = NotificationDisplay(userInfo: ["previewsEnabled": true, "senderName": " "], body: "HIDDEN")
check(empty.initials == nil); check(empty.body == "You have a new message")
print("PASS \(checks) native presentation/privacy assertions")
