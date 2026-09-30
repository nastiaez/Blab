String confirmedEmailChangeDestination({required bool signedIn}) {
  return signedIn ? '/profile' : '/onboarding/welcome';
}

bool isSameAccountEmailChange({
  required String? previousUserId,
  required String? previousEmail,
  required String? currentUserId,
  required String? currentEmail,
}) {
  return previousUserId != null &&
      previousUserId == currentUserId &&
      previousEmail != null &&
      currentEmail != null &&
      previousEmail != currentEmail;
}
