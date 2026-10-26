import Foundation

struct NotificationDisplay {
    let title: String
    let body: String
    let initials: String?
    let isGroup: Bool
    let avatarHex: UInt32

    init(userInfo: [AnyHashable: Any], body: String) {
        let previews = (userInfo["previewsEnabled"] as? String) == "true" || (userInfo["previewsEnabled"] as? Bool) == true
        func label(_ key: String) -> String { (userInfo[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        let sender = label("senderName")
        let group = label("groupTitle")
        let identity = group.isEmpty ? sender : group
        let visible = previews && !identity.isEmpty
        let generic: String
        switch label("interfaceLanguage") {
        case "de": generic = "Du hast eine neue Nachricht"
        case "es": generic = "Tienes un mensaje nuevo"
        case "uk": generic = "У вас нове повідомлення"
        default: generic = "You have a new message"
        }
        self.title = visible ? identity : "Blab"
        self.body = visible ? (group.isEmpty || sender.isEmpty ? body : "\(sender): \(body)") : generic
        self.initials = visible ? String(identity.filter { !$0.isWhitespace }.prefix(2)).uppercased() : nil
        let palette: [UInt32] = [0x46281C, 0x917869, 0xBC6C4E, 0x788C73, 0xAF787D, 0x5F3C4B]
        self.avatarHex = palette[identity.utf16.reduce(0) { $0 + Int($1) } % palette.count]
        self.isGroup = visible && !group.isEmpty
    }
}
