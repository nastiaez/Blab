enum OnboardingDestination {
  bootstrap,
  retry,
  legacyAuth,
  welcome,
  confirmName,
  language,
  pendingInvite,
  chats,
  resetPassword,
  resetLinkExpired,
  emailChange,
}

enum OnboardingCallback {
  none,
  passwordRecoveryValid,
  passwordRecoveryInvalid,
  emailChange,
}

enum ProfileResolutionState { notRequired, loading, ready, retry }
