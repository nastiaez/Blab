import UIKit
import UserNotifications
import UserNotificationsUI

/// Display-only extension: no network, credentials, history, or navigation authority.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let avatar = UIView()
    private let initials = UILabel()
    private let mark = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        preferredContentSize = CGSize(width: 360, height: 100)
        avatar.layer.cornerRadius = 24
        initials.font = .systemFont(ofSize: 18, weight: .semibold)
        initials.textColor = .white
        initials.textAlignment = .center
        mark.image = UIImage(named: "notification_badge_exact", in: Bundle(for: Self.self), compatibleWith: nil)?.withRenderingMode(.alwaysOriginal)
        mark.contentMode = .scaleAspectFit
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.numberOfLines = 0
        [titleLabel, bodyLabel].forEach { $0.adjustsFontForContentSizeCategory = true }
        [avatar, initials, mark, titleLabel, bodyLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            avatar.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            avatar.widthAnchor.constraint(equalToConstant: 48), avatar.heightAnchor.constraint(equalToConstant: 48),
            initials.leadingAnchor.constraint(equalTo: avatar.leadingAnchor), initials.trailingAnchor.constraint(equalTo: avatar.trailingAnchor),
            initials.topAnchor.constraint(equalTo: avatar.topAnchor), initials.bottomAnchor.constraint(equalTo: avatar.bottomAnchor),
            mark.widthAnchor.constraint(equalToConstant: 22), mark.heightAnchor.constraint(equalToConstant: 22),
            mark.trailingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 3), mark.bottomAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 3),
            titleLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        var metadata = content.userInfo
        if let payload = metadata["payload"] as? String,
           let bytes = payload.data(using: .utf8),
           let local = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
            metadata = local
        }
        let safe = NotificationAccount.sanitized(metadata)
        let display = NotificationDisplay(userInfo: safe, body: safe["blabPreviewBody"] as? String ?? "")
        let showIdentity = display.initials != nil
        titleLabel.text = display.title
        bodyLabel.text = display.body
        initials.text = display.initials
        avatar.backgroundColor = UIColor(red: CGFloat((display.avatarHex >> 16) & 255) / 255, green: CGFloat((display.avatarHex >> 8) & 255) / 255, blue: CGFloat(display.avatarHex & 255) / 255, alpha: 1)
        avatar.isHidden = !showIdentity
        initials.isHidden = !showIdentity
        // Private state uses the full mark, not an identity/avatar or tinted substitute.
        if !showIdentity {
            mark.transform = CGAffineTransform(translationX: -13, y: -13).scaledBy(x: 48.0/22.0, y: 48.0/22.0)
        } else { mark.transform = .identity }
        view.layoutIfNeeded()
        let height = bodyLabel.sizeThatFits(CGSize(width: max(160, view.bounds.width - 96), height: 1000)).height
        preferredContentSize = CGSize(width: view.bounds.width, height: max(96, height + 58))
    }
}
