// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Blab';

  @override
  String get back => 'Back';

  @override
  String get apply => 'Apply';

  @override
  String get undo => 'Undo';

  @override
  String get retry => 'Retry';

  @override
  String get viewOriginal => 'View original';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get send => 'Send';

  @override
  String get done => 'Done';

  @override
  String get delete => 'Delete';

  @override
  String get copy => 'Copy';

  @override
  String get edit => 'Edit';

  @override
  String get report => 'Report';

  @override
  String get reply => 'Reply';

  @override
  String get chats => 'Chats';

  @override
  String get profile => 'Profile';

  @override
  String get interfaceLanguage => 'Interface language';

  @override
  String get interfaceLanguageHelp =>
      'Pick the language for menus, buttons, and other system text across the app.';

  @override
  String switchedToLanguage(String language) {
    return 'Switched to $language';
  }

  @override
  String get couldNotSaveLanguage =>
      'Could not save the interface language. Try again.';

  @override
  String get knownLanguages => 'Known languages';

  @override
  String get setPrimaryLanguage => 'Set as primary language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUkrainian => 'Ukrainian';

  @override
  String get languageGerman => 'German';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get authTagline => 'Learn a language by chatting with a friend.';

  @override
  String signUpToChat(String name) {
    return 'Sign up to chat with $name.';
  }

  @override
  String logInToChat(String name) {
    return 'Log in to chat with $name.';
  }

  @override
  String get name => 'Name';

  @override
  String get firstNameHint => 'Your first name';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotYourPassword => 'Forgot your password?';

  @override
  String get joinBlab => 'Join Blab';

  @override
  String get logIn => 'Log in';

  @override
  String get signUp => 'Sign up';

  @override
  String get alreadyHaveAccount => 'Already have an account? Log in';

  @override
  String get newToBlab => 'New to Blab? Sign up';

  @override
  String get orUseEmail => 'or use email';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get byContinuing => 'By continuing, you agree to our ';

  @override
  String get terms => 'Terms';

  @override
  String get and => ' and ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get ageConfirmation => ', and confirm you are at least 13.';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get enterValidEmail => 'Enter a valid email address';

  @override
  String get emailResetLink => 'Email me a reset link';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String resetLinkSent(String email) {
    return 'We sent a reset link to\n$email';
  }

  @override
  String get backToLogin => 'Back to log in';

  @override
  String get setNewPassword => 'Set a new password';

  @override
  String get newPasswordHelp =>
      'Pick something you\'ll remember. Use at least 6 characters.';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get saveNewPassword => 'Save new password';

  @override
  String get passwordUpdated => 'Password updated ✓';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get passwordWeak => 'Weak';

  @override
  String get passwordFair => 'Fair';

  @override
  String get passwordStrong => 'Strong';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get chooseStrongerPassword => 'Choose a stronger password';

  @override
  String get passwordsDoNotMatch => 'Passwords don\'t match';

  @override
  String get enterDisplayName => 'Enter your display name';

  @override
  String get displayNameTooLong =>
      'Display name must be 50 characters or fewer';

  @override
  String get displayNameUnsupported =>
      'Display name contains unsupported characters';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get displayName => 'Display name';

  @override
  String get yourName => 'Your name';

  @override
  String get profileUpdated => 'Profile updated ✓';

  @override
  String get couldNotUpdateProfile =>
      'Could not update your profile. Try again.';

  @override
  String get couldNotLoadProfile => 'Couldn\'t load your profile.';

  @override
  String get changeEmail => 'Change email';

  @override
  String get currentEmail => 'CURRENT EMAIL';

  @override
  String get newEmail => 'New email';

  @override
  String get emailChangeHelp =>
      'We\'ll send a confirmation link. Your old email stays active until you confirm.';

  @override
  String get checkYourInbox => 'Check your inbox';

  @override
  String emailConfirmationSent(String email) {
    return 'We sent a confirmation link to\n$email. Tap it to finish the change.';
  }

  @override
  String get enterNewEmail => 'Enter your new email';

  @override
  String get emailAlreadyUsed => 'That\'s already your email';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get enterCurrentPassword => 'Enter your current password';

  @override
  String get enterNewPassword => 'Enter a new password';

  @override
  String get confirmPassword => 'Confirm your new password';

  @override
  String get chooseDifferentPassword => 'Choose a different password';

  @override
  String get passwordSignInUnavailable =>
      'Password sign-in is not enabled for this account.';

  @override
  String get privacy => 'Privacy';

  @override
  String get typingIndicators => 'Typing indicators';

  @override
  String get typingIndicatorsHelp =>
      'If turned off, you won\'t see when others are typing, and they won\'t see when you are.';

  @override
  String get readReceipts => 'Read receipts';

  @override
  String get readReceiptsHelp =>
      'If turned off, you won\'t see read receipts from others, and they won\'t see yours.';

  @override
  String get couldNotSavePrivacy => 'Couldn\'t save privacy setting.';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get logOut => 'Log out';

  @override
  String get logOutQuestion => 'Log out?';

  @override
  String get logOutHelp =>
      'You\'ll need your email and password (or Google) to sign back in.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountPermanent =>
      'This is permanent. The following will be deleted:';

  @override
  String get allChatsMessages => 'All chats and messages';

  @override
  String get yourProfile => 'Your profile';

  @override
  String get yourSettings => 'Your settings and preferences';

  @override
  String get confirmWithPassword => 'Confirm with password';

  @override
  String typeEmailToConfirm(String email) {
    return 'Type $email to confirm';
  }

  @override
  String get deleteForever => 'Delete forever';

  @override
  String get enterPasswordToConfirm => 'Enter your password to confirm';

  @override
  String get emailDoesNotMatch => 'That doesn\'t match your email';

  @override
  String get couldNotDeleteAccount =>
      'Couldn\'t delete your account. Try again.';

  @override
  String get newChat => 'New chat';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get inviteFriendStart => 'Invite a friend and start chatting.';

  @override
  String get inviteFriend => 'Invite a friend';

  @override
  String get couldNotLoadChats => 'Couldn\'t load chats';

  @override
  String get newConnectionSayHi => 'New connection · say hi';

  @override
  String get typing => 'typing...';

  @override
  String get offline => 'Offline';

  @override
  String get noConnection =>
      'No connection — messages will send when you\'re back online';

  @override
  String get learningLanguage => 'Learning language';

  @override
  String get learningLanguageHelp =>
      'Pick the language you want to learn in this chat. You can change it anytime.';

  @override
  String get chatMenu => 'Chat menu';

  @override
  String get normalMode => 'Normal';

  @override
  String get practiceMode => 'Practice';

  @override
  String get translationLimitReached => 'Translation limit reached';

  @override
  String get translationUnavailable => 'Translation unavailable';

  @override
  String get correction => 'Correction';

  @override
  String get possibleCorrection => 'Possible correction';

  @override
  String get edited => 'edited';

  @override
  String get sending => 'Sending';

  @override
  String get delivered => 'Delivered';

  @override
  String get read => 'Read';

  @override
  String get failedToSend => 'Failed to send. Tap to retry.';

  @override
  String get attach => 'Attach';

  @override
  String get message => 'Message';

  @override
  String get sayHi => 'Say hi';

  @override
  String replyingTo(Object name) {
    return 'Replying to $name';
  }

  @override
  String get editingMessage => 'Editing message';

  @override
  String get messageFailed => 'Message failed to send';

  @override
  String get copied => 'Copied';

  @override
  String get messageDeleted => 'Message deleted';

  @override
  String get thanksReport => 'Thanks — we\'ll review this.';

  @override
  String get couldNotReport => 'Couldn\'t send the report. Try again.';

  @override
  String get couldNotSaveLearningLanguage =>
      'Couldn\'t save language. Try again.';

  @override
  String get reportMessage => 'Report message';

  @override
  String get sendInvite => 'Send the invite';

  @override
  String get pickLanguage => 'Pick a language';

  @override
  String get pickLanguageHelp =>
      'We\'ll translate all messages into this language. Switch it whenever you like.';

  @override
  String get continueAction => 'Continue';

  @override
  String get sendLinkHelp => 'Send the link to start chatting.';

  @override
  String get onePersonInvite => 'Only one person can use this link.';

  @override
  String get validFor48Hours => 'Valid for 48 hours.';

  @override
  String get creatingLink => 'Creating link…';

  @override
  String get shareInvite => 'Share invite';

  @override
  String get change => 'Change';

  @override
  String get inviteSent => 'Invite sent ✓';

  @override
  String get couldNotCreateInvite => 'Couldn\'t create invite. Try again.';

  @override
  String get shareInviteLink => 'Share invite link';

  @override
  String get more => 'More';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get copyLink => 'Copy link';

  @override
  String get pasteInChat => 'Now paste it in a chat';

  @override
  String practicingLanguage(Object language) {
    return 'You\'re practicing $language.';
  }

  @override
  String get shareYourInvite => 'Share your invite link.';

  @override
  String validUntil(Object date) {
    return 'Valid until $date.';
  }

  @override
  String get inviteAlreadyClaimed => 'This invite was already claimed';

  @override
  String askForFreshLink(Object name) {
    return 'Ask $name for a fresh link';
  }

  @override
  String get goToChats => 'Go to chats';

  @override
  String get inviteNotFound => 'We couldn\'t find that invite.';

  @override
  String get checkInviteLink =>
      'Check the link is correct, or ask for a new one.';

  @override
  String get sayHello => 'Say hello';

  @override
  String sayWord(Object word) {
    return 'Say $word';
  }

  @override
  String get aFriend => 'A friend';

  @override
  String get you => 'You';

  @override
  String get partner => 'Partner';

  @override
  String get yourself => 'yourself';

  @override
  String get couldNotEditMessage => 'Couldn\'t edit message. Try again.';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get now => 'Now';

  @override
  String get newLabel => 'New';

  @override
  String get invitedYouToChat => 'invited you to chat';

  @override
  String joinPerson(Object name) {
    return 'Join $name';
  }

  @override
  String get inviteExpired => 'This invite expired';

  @override
  String get alreadyConnected =>
      'You\'re already connected. Open the chat to start.';

  @override
  String get openChat => 'Open chat';

  @override
  String get yourInviteExpired => 'Your invite expired.';

  @override
  String get inviteExpiredHelp =>
      'Nobody joined in 48 hours. Send a fresh link to a friend.';

  @override
  String get sendNewInvite => 'Send new invite';

  @override
  String youLearnLanguage(Object language) {
    return 'You learn $language';
  }

  @override
  String personLearnsLanguage(Object language, Object name) {
    return '$name learns $language';
  }

  @override
  String youAreLearningLanguageWithPerson(Object language, Object name) {
    return 'You\'re learning $language with $name';
  }

  @override
  String get sendAnyMessage => 'Send any message to start.';

  @override
  String get languages => 'Languages';

  @override
  String speaksNatively(Object language) {
    return 'Speaks $language natively';
  }

  @override
  String learningWithYou(Object language) {
    return 'Learning $language with you';
  }

  @override
  String get chat => 'Chat';

  @override
  String get startedJustNow => 'Started chatting just now';

  @override
  String startedMinutesAgo(Object count) {
    return 'Started chatting ${count}m ago';
  }

  @override
  String startedHoursAgo(Object count) {
    return 'Started chatting ${count}h ago';
  }

  @override
  String startedDaysAgo(Object count) {
    return 'Started chatting ${count}d ago';
  }

  @override
  String startedMonthsAgo(Object count) {
    return 'Started chatting ${count}mo ago';
  }

  @override
  String get safety => 'Safety';

  @override
  String reportPerson(Object name) {
    return 'Report $name';
  }

  @override
  String blockPerson(Object name) {
    return 'Block $name';
  }

  @override
  String unblockPerson(Object name) {
    return 'Unblock $name';
  }

  @override
  String personBlocked(Object name) {
    return '$name blocked';
  }

  @override
  String personUnblocked(Object name) {
    return '$name unblocked';
  }

  @override
  String get couldNotBlock => 'Couldn\'t block. Try again.';

  @override
  String get couldNotUnblock => 'Couldn\'t unblock. Try again.';

  @override
  String get reportSpam => 'Spam or scam';

  @override
  String get reportHarassment => 'Harassment or bullying';

  @override
  String get reportHate => 'Hate speech';

  @override
  String get reportSexual => 'Sexual or inappropriate content';

  @override
  String get reportChildSafety => 'Child safety';

  @override
  String get reportOther => 'Something else';

  @override
  String get inviteClaimExpired => 'This invite has expired.';

  @override
  String get inviteClaimUsed => 'This invite has already been used.';

  @override
  String get inviteClaimInvalid => 'This invite is invalid.';

  @override
  String get inviteClaimFailed => 'Couldn\'t accept the invite. Try again.';

  @override
  String get appleSignInSoon => 'Apple sign-in coming soon';

  @override
  String get invalidCredentials => 'Email or password is incorrect';

  @override
  String get accountAlreadyExists =>
      'An account with this email already exists';

  @override
  String get confirmEmailInbox => 'Check your inbox to confirm your email';

  @override
  String get somethingWentWrong => 'Something went wrong. Try again.';

  @override
  String get currentPasswordIncorrect => 'Current password is incorrect';

  @override
  String get signInAgain =>
      'Please sign in again before changing your password';

  @override
  String get tooManyAttempts => 'Too many attempts. Try again later.';

  @override
  String get couldNotUpdatePassword =>
      'Could not update your password. Try again.';

  @override
  String get emailChanged => 'Email changed';

  @override
  String get someoneJoined => 'Someone joined.';

  @override
  String personJoined(Object name) {
    return '$name joined.';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get showMessagePreviews => 'Show message previews';

  @override
  String get showMessagePreviewsHelp =>
      'Show the sender and original message in notifications.';

  @override
  String get androidNotificationSettings => 'Android notification settings';

  @override
  String get notificationsEnabled => 'Notifications are enabled';

  @override
  String get notificationsDisabled => 'Notifications are turned off';

  @override
  String get notificationsNotRequested => 'Open a chat to enable notifications';

  @override
  String get notificationsUnavailable =>
      'Notifications aren\'t available in this build';

  @override
  String get couldNotSaveNotifications =>
      'Couldn\'t save notification setting.';

  @override
  String get enableNotificationsReminder =>
      'Enable notifications to hear from your partner';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get photos => 'Photos';

  @override
  String get photoAccessNeeded => 'Photo access needed';

  @override
  String get photoAccessNeededBody =>
      'Allow access to your photos to share one in chat.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get noPhotosFound => 'No photos yet';

  @override
  String get photoMessagePreview => 'Photo';

  @override
  String get searchEmoji => 'Search emoji';
}
