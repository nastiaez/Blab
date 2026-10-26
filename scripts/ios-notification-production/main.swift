import Foundation
let defaults = NotificationAccount.defaults!
let old = defaults.dictionary(forKey: "account")
defer { if let old = old { defaults.set(old,forKey:"account") } else { defaults.removeObject(forKey:"account") } }
let payload: [AnyHashable:Any] = ["receiverId":"a", "accountEpoch":"one", "iosPresentation":"blab_communication_v1", "previewsEnabled":true, "senderName":"Secret", "groupTitle":"Private club", "blabPreviewBody":"Message", "chatId":"chat"]
var count = 0
for receiver in ["a","b", ""] {
 for epoch in ["one", "two", ""] {
  for previews in [true,false] {
   defaults.set(["receiverId":receiver,"accountEpoch":epoch,"previewsEnabled":previews], forKey:"account")
   let safe = NotificationAccount.sanitized(payload)
   let visible = receiver == "a" && epoch == "one" && previews
   assert((safe["senderName"] != nil) == visible)
   assert((safe["blabPreviewBody"] != nil) == visible)
   if !visible { assert(safe["groupTitle"] == nil) }
   count += 3
  }
 }
}
defaults.removeObject(forKey:"account")
assert(!NotificationAccount.matches(payload))
assert(NotificationAccount.sanitized(payload)["senderName"] == nil)
print("Native privacy assertions:", count + 2, "passed")
