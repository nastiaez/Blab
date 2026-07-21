const String kPrivacyTypingIndicatorsKey = 'privacy_typing_indicators';
const String kPrivacyReadReceiptsKey = 'privacy_read_receipts';
const String kPendingSendsKeyPrefix = 'pending_sends:';
const String kGuestInterfaceLanguageKey = 'interface_language:guest';
const String kAccountInterfaceLanguageKeyPrefix = 'interface_language:account:';
const String kNotificationPermissionRequestedKey =
    'notifications_permission_requested';
const String kNotificationReminderDismissedKey =
    'notifications_reminder_dismissed';
const String kNotificationPreviewsKey = 'notifications_previews_enabled';

String interfaceLanguageStorageKey(String? userId) => userId == null
    ? kGuestInterfaceLanguageKey
    : '$kAccountInterfaceLanguageKeyPrefix$userId';

String pendingSendsStorageKey({
  required String userId,
  required String chatId,
}) => '$kPendingSendsKeyPrefix$userId:$chatId';
