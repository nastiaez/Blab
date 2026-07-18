const String kPrivacyTypingIndicatorsKey = 'privacy_typing_indicators';
const String kPrivacyReadReceiptsKey = 'privacy_read_receipts';
const String kPendingSendsKeyPrefix = 'pending_sends:';

String pendingSendsStorageKey({
  required String userId,
  required String chatId,
}) => '$kPendingSendsKeyPrefix$userId:$chatId';
