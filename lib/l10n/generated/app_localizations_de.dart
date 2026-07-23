// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Blab';

  @override
  String get back => 'Zurück';

  @override
  String get apply => 'Übernehmen';

  @override
  String get undo => 'Rückgängig';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get viewOriginal => 'Original anzeigen';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get send => 'Senden';

  @override
  String get done => 'Fertig';

  @override
  String get delete => 'Löschen';

  @override
  String get copy => 'Kopieren';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get report => 'Melden';

  @override
  String get reply => 'Antworten';

  @override
  String get chats => 'Chats';

  @override
  String get profile => 'Profil';

  @override
  String get interfaceLanguage => 'App-Sprache';

  @override
  String get interfaceLanguageHelp =>
      'Wähle die Sprache für Menüs, Schaltflächen, Nachrichtenuntertitel und Wortdefinitionen in der App.';

  @override
  String switchedToLanguage(String language) {
    return 'Zu $language gewechselt';
  }

  @override
  String get couldNotSaveLanguage =>
      'Die App-Sprache konnte nicht gespeichert werden. Versuche es erneut.';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageUkrainian => 'Ukrainisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageSpanish => 'Spanisch';

  @override
  String get authTagline =>
      'Lerne eine Sprache, indem du mit einem Freund chattest.';

  @override
  String signUpToChat(String name) {
    return 'Registriere dich, um mit $name zu chatten.';
  }

  @override
  String logInToChat(String name) {
    return 'Melde dich an, um mit $name zu chatten.';
  }

  @override
  String get name => 'Name';

  @override
  String get firstNameHint => 'Dein Vorname';

  @override
  String get email => 'E-Mail';

  @override
  String get emailHint => 'du@beispiel.de';

  @override
  String get password => 'Passwort';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get forgotYourPassword => 'Passwort vergessen?';

  @override
  String get joinBlab => 'Blab beitreten';

  @override
  String get logIn => 'Anmelden';

  @override
  String get signUp => 'Registrieren';

  @override
  String get alreadyHaveAccount => 'Du hast schon ein Konto? Anmelden';

  @override
  String get newToBlab => 'Neu bei Blab? Registrieren';

  @override
  String get orUseEmail => 'oder E-Mail verwenden';

  @override
  String get continueWithGoogle => 'Mit Google fortfahren';

  @override
  String get continueWithApple => 'Mit Apple fortfahren';

  @override
  String get byContinuing => 'Wenn du fortfährst, stimmst du unseren ';

  @override
  String get terms => 'Nutzungsbedingungen';

  @override
  String get and => ' und der ';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get ageConfirmation =>
      ' zu und bestätigst, dass du mindestens 13 Jahre alt bist.';

  @override
  String get enterEmail => 'Gib deine E-Mail-Adresse ein';

  @override
  String get enterValidEmail => 'Gib eine gültige E-Mail-Adresse ein';

  @override
  String get emailResetLink => 'Link zum Zurücksetzen senden';

  @override
  String get checkYourEmail => 'Prüfe deine E-Mails';

  @override
  String resetLinkSent(String email) {
    return 'Wir haben einen Link zum Zurücksetzen an\n$email gesendet';
  }

  @override
  String get backToLogin => 'Zurück zur Anmeldung';

  @override
  String get setNewPassword => 'Neues Passwort festlegen';

  @override
  String get newPasswordHelp =>
      'Wähle ein Passwort, das du dir merkst. Verwende mindestens 6 Zeichen.';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get confirmNewPassword => 'Neues Passwort bestätigen';

  @override
  String get saveNewPassword => 'Neues Passwort speichern';

  @override
  String get passwordUpdated => 'Passwort aktualisiert ✓';

  @override
  String get showPassword => 'Passwort anzeigen';

  @override
  String get hidePassword => 'Passwort ausblenden';

  @override
  String get passwordWeak => 'Schwach';

  @override
  String get passwordFair => 'Mittel';

  @override
  String get passwordStrong => 'Stark';

  @override
  String get passwordMinLength =>
      'Das Passwort muss mindestens 6 Zeichen lang sein';

  @override
  String get chooseStrongerPassword => 'Wähle ein stärkeres Passwort';

  @override
  String get passwordsDoNotMatch => 'Die Passwörter stimmen nicht überein';

  @override
  String get enterDisplayName => 'Gib deinen Anzeigenamen ein';

  @override
  String get displayNameTooLong =>
      'Der Anzeigename darf höchstens 50 Zeichen lang sein';

  @override
  String get displayNameUnsupported =>
      'Der Anzeigename enthält nicht unterstützte Zeichen';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get displayName => 'Anzeigename';

  @override
  String get yourName => 'Dein Name';

  @override
  String get profileUpdated => 'Profil aktualisiert ✓';

  @override
  String get couldNotUpdateProfile =>
      'Dein Profil konnte nicht aktualisiert werden. Versuche es erneut.';

  @override
  String get couldNotLoadProfile => 'Dein Profil konnte nicht geladen werden.';

  @override
  String get changeEmail => 'E-Mail ändern';

  @override
  String get currentEmail => 'AKTUELLE E-MAIL';

  @override
  String get newEmail => 'Neue E-Mail';

  @override
  String get emailChangeHelp =>
      'Wir senden einen Bestätigungslink. Deine alte E-Mail bleibt aktiv, bis du bestätigst.';

  @override
  String get checkYourInbox => 'Prüfe deinen Posteingang';

  @override
  String emailConfirmationSent(String email) {
    return 'Wir haben einen Bestätigungslink an\n$email gesendet. Tippe darauf, um die Änderung abzuschließen.';
  }

  @override
  String get enterNewEmail => 'Gib deine neue E-Mail-Adresse ein';

  @override
  String get emailAlreadyUsed => 'Das ist bereits deine E-Mail-Adresse';

  @override
  String get changePassword => 'Passwort ändern';

  @override
  String get currentPassword => 'Aktuelles Passwort';

  @override
  String get enterCurrentPassword => 'Gib dein aktuelles Passwort ein';

  @override
  String get enterNewPassword => 'Gib ein neues Passwort ein';

  @override
  String get confirmPassword => 'Bestätige dein neues Passwort';

  @override
  String get chooseDifferentPassword => 'Wähle ein anderes Passwort';

  @override
  String get passwordSignInUnavailable =>
      'Die Passwort-Anmeldung ist für dieses Konto nicht aktiviert.';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get typingIndicators => 'Tippanzeigen';

  @override
  String get typingIndicatorsHelp =>
      'Wenn deaktiviert, siehst du nicht, wann andere tippen, und sie sehen nicht, wann du tippst.';

  @override
  String get readReceipts => 'Lesebestätigungen';

  @override
  String get readReceiptsHelp =>
      'Wenn deaktiviert, siehst du keine Lesebestätigungen anderer, und sie sehen deine nicht.';

  @override
  String get couldNotSavePrivacy =>
      'Die Datenschutzeinstellung konnte nicht gespeichert werden.';

  @override
  String get termsOfUse => 'Nutzungsbedingungen';

  @override
  String get logOut => 'Abmelden';

  @override
  String get logOutQuestion => 'Abmelden?';

  @override
  String get logOutHelp =>
      'Zum erneuten Anmelden brauchst du deine E-Mail und dein Passwort (oder Google).';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountPermanent =>
      'Dies ist endgültig. Folgendes wird gelöscht:';

  @override
  String get allChatsMessages => 'Alle Chats und Nachrichten';

  @override
  String get yourProfile => 'Dein Profil';

  @override
  String get yourSettings => 'Deine Einstellungen';

  @override
  String get confirmWithPassword => 'Mit Passwort bestätigen';

  @override
  String typeEmailToConfirm(String email) {
    return 'Gib zur Bestätigung $email ein';
  }

  @override
  String get deleteForever => 'Endgültig löschen';

  @override
  String get enterPasswordToConfirm => 'Gib zur Bestätigung dein Passwort ein';

  @override
  String get emailDoesNotMatch => 'Das stimmt nicht mit deiner E-Mail überein';

  @override
  String get couldNotDeleteAccount =>
      'Dein Konto konnte nicht gelöscht werden. Versuche es erneut.';

  @override
  String get newChat => 'Neuer Chat';

  @override
  String get noChatsYet => 'Noch keine Chats';

  @override
  String get inviteFriendStart =>
      'Lade einen Freund ein und beginne zu chatten.';

  @override
  String get inviteFriend => 'Freund einladen';

  @override
  String get couldNotLoadChats => 'Chats konnten nicht geladen werden';

  @override
  String get newConnectionSayHi => 'Neue Verbindung · sag Hallo';

  @override
  String get typing => 'tippt...';

  @override
  String get offline => 'Offline';

  @override
  String get noConnection =>
      'Keine Verbindung — Nachrichten werden gesendet, sobald du wieder online bist';

  @override
  String get showTranslations => 'Übersetzungen und Korrekturen anzeigen';

  @override
  String get learningLanguage => 'Lernsprache';

  @override
  String get learningLanguageHelp =>
      'Wähle die Sprache, die du in diesem Chat lernen möchtest. Du kannst sie jederzeit ändern.';

  @override
  String get chatMenu => 'Chat-Menü';

  @override
  String get translationLimitReached => 'Übersetzungslimit erreicht';

  @override
  String get translationUnavailable => 'Übersetzung nicht verfügbar';

  @override
  String get correction => 'Korrektur';

  @override
  String get possibleCorrection => 'Mögliche Korrektur';

  @override
  String get edited => 'bearbeitet';

  @override
  String get sending => 'Wird gesendet';

  @override
  String get delivered => 'Zugestellt';

  @override
  String get read => 'Gelesen';

  @override
  String get failedToSend => 'Senden fehlgeschlagen. Zum Wiederholen tippen.';

  @override
  String get attach => 'Anhängen';

  @override
  String get message => 'Nachricht';

  @override
  String replyingTo(Object name) {
    return 'Antwort an $name';
  }

  @override
  String get editingMessage => 'Nachricht bearbeiten';

  @override
  String get messageFailed => 'Nachricht konnte nicht gesendet werden';

  @override
  String get copied => 'Kopiert';

  @override
  String get messageDeleted => 'Nachricht gelöscht';

  @override
  String get thanksReport => 'Danke — wir prüfen das.';

  @override
  String get couldNotReport =>
      'Die Meldung konnte nicht gesendet werden. Versuche es erneut.';

  @override
  String get couldNotSaveLearningLanguage =>
      'Die Sprache konnte nicht gespeichert werden. Versuche es erneut.';

  @override
  String get reportMessage => 'Nachricht melden';

  @override
  String get sendInvite => 'Einladung senden';

  @override
  String get pickLanguage => 'Sprache wählen';

  @override
  String get pickLanguageHelp =>
      'Wir übersetzen alle Nachrichten in diese Sprache. Du kannst sie jederzeit wechseln.';

  @override
  String get continueAction => 'Weiter';

  @override
  String get sendLinkHelp => 'Sende den Link, um den Chat zu beginnen.';

  @override
  String get onePersonInvite => 'Nur eine Person kann diesen Link verwenden.';

  @override
  String get validFor48Hours => '48 Stunden gültig.';

  @override
  String get creatingLink => 'Link wird erstellt…';

  @override
  String get shareInvite => 'Einladung teilen';

  @override
  String get change => 'Ändern';

  @override
  String get inviteSent => 'Einladung gesendet ✓';

  @override
  String get couldNotCreateInvite =>
      'Einladung konnte nicht erstellt werden. Versuche es erneut.';

  @override
  String get shareInviteLink => 'Einladungslink teilen';

  @override
  String get more => 'Mehr';

  @override
  String get linkCopied => 'Link kopiert';

  @override
  String get copyLink => 'Link kopieren';

  @override
  String get pasteInChat => 'Füge ihn jetzt in einen Chat ein';

  @override
  String practicingLanguage(Object language) {
    return 'Du übst $language.';
  }

  @override
  String get shareYourInvite => 'Teile deinen Einladungslink.';

  @override
  String validUntil(Object date) {
    return 'Gültig bis $date.';
  }

  @override
  String get inviteAlreadyClaimed => 'Diese Einladung wurde bereits angenommen';

  @override
  String askForFreshLink(Object name) {
    return 'Bitte $name um einen neuen Link';
  }

  @override
  String get goToChats => 'Zu den Chats';

  @override
  String get inviteNotFound => 'Diese Einladung wurde nicht gefunden.';

  @override
  String get checkInviteLink => 'Prüfe den Link oder bitte um einen neuen.';

  @override
  String get sayHello => 'Sag Hallo';

  @override
  String sayWord(Object word) {
    return 'Sag $word';
  }

  @override
  String get aFriend => 'Ein Freund';

  @override
  String get you => 'Du';

  @override
  String get partner => 'Partner';

  @override
  String get yourself => 'dir selbst';

  @override
  String get couldNotEditMessage =>
      'Die Nachricht konnte nicht bearbeitet werden. Versuche es erneut.';

  @override
  String get today => 'Heute';

  @override
  String get yesterday => 'Gestern';

  @override
  String get now => 'Jetzt';

  @override
  String get newLabel => 'Neu';

  @override
  String get invitedYouToChat => 'hat dich zum Chat eingeladen';

  @override
  String joinPerson(Object name) {
    return '$name beitreten';
  }

  @override
  String get inviteExpired => 'Diese Einladung ist abgelaufen';

  @override
  String get alreadyConnected =>
      'Ihr seid bereits verbunden. Öffne den Chat, um zu beginnen.';

  @override
  String get openChat => 'Chat öffnen';

  @override
  String get yourInviteExpired => 'Deine Einladung ist abgelaufen.';

  @override
  String get inviteExpiredHelp =>
      'Innerhalb von 48 Stunden ist niemand beigetreten. Sende einen neuen Link.';

  @override
  String get sendNewInvite => 'Neue Einladung senden';

  @override
  String youLearnLanguage(Object language) {
    return 'Du lernst $language';
  }

  @override
  String personLearnsLanguage(Object language, Object name) {
    return '$name lernt $language';
  }

  @override
  String get sendAnyMessage => 'Sende eine Nachricht, um zu beginnen.';

  @override
  String get languages => 'Sprachen';

  @override
  String speaksNatively(Object language) {
    return 'Spricht $language als Muttersprache';
  }

  @override
  String learningWithYou(Object language) {
    return 'Lernt $language mit dir';
  }

  @override
  String get chat => 'Chat';

  @override
  String get startedJustNow => 'Chat gerade begonnen';

  @override
  String startedMinutesAgo(Object count) {
    return 'Chat vor $count Min. begonnen';
  }

  @override
  String startedHoursAgo(Object count) {
    return 'Chat vor $count Std. begonnen';
  }

  @override
  String startedDaysAgo(Object count) {
    return 'Chat vor $count Tagen begonnen';
  }

  @override
  String startedMonthsAgo(Object count) {
    return 'Chat vor $count Mon. begonnen';
  }

  @override
  String get safety => 'Sicherheit';

  @override
  String reportPerson(Object name) {
    return '$name melden';
  }

  @override
  String blockPerson(Object name) {
    return '$name blockieren';
  }

  @override
  String unblockPerson(Object name) {
    return 'Blockierung von $name aufheben';
  }

  @override
  String personBlocked(Object name) {
    return '$name blockiert';
  }

  @override
  String personUnblocked(Object name) {
    return 'Blockierung von $name aufgehoben';
  }

  @override
  String get couldNotBlock => 'Blockieren fehlgeschlagen. Versuche es erneut.';

  @override
  String get couldNotUnblock =>
      'Aufheben der Blockierung fehlgeschlagen. Versuche es erneut.';

  @override
  String get reportSpam => 'Spam oder Betrug';

  @override
  String get reportHarassment => 'Belästigung oder Mobbing';

  @override
  String get reportHate => 'Hassrede';

  @override
  String get reportSexual => 'Sexuelle oder unangemessene Inhalte';

  @override
  String get reportChildSafety => 'Kinderschutz';

  @override
  String get reportOther => 'Etwas anderes';

  @override
  String get inviteClaimExpired => 'Diese Einladung ist abgelaufen.';

  @override
  String get inviteClaimUsed => 'Diese Einladung wurde bereits verwendet.';

  @override
  String get inviteClaimInvalid => 'Diese Einladung ist ungültig.';

  @override
  String get inviteClaimFailed =>
      'Die Einladung konnte nicht angenommen werden. Versuche es erneut.';

  @override
  String get appleSignInSoon => 'Anmeldung mit Apple folgt bald';

  @override
  String get invalidCredentials => 'E-Mail oder Passwort ist falsch';

  @override
  String get accountAlreadyExists =>
      'Für diese E-Mail existiert bereits ein Konto';

  @override
  String get confirmEmailInbox =>
      'Prüfe deinen Posteingang, um die E-Mail zu bestätigen';

  @override
  String get somethingWentWrong =>
      'Etwas ist schiefgegangen. Versuche es erneut.';

  @override
  String get currentPasswordIncorrect => 'Das aktuelle Passwort ist falsch';

  @override
  String get signInAgain =>
      'Melde dich erneut an, bevor du dein Passwort änderst';

  @override
  String get tooManyAttempts => 'Zu viele Versuche. Versuche es später erneut.';

  @override
  String get couldNotUpdatePassword =>
      'Das Passwort konnte nicht aktualisiert werden. Versuche es erneut.';

  @override
  String get emailChanged => 'E-Mail geändert';

  @override
  String get someoneJoined => 'Jemand ist beigetreten.';

  @override
  String personJoined(Object name) {
    return '$name ist beigetreten.';
  }

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get showMessagePreviews => 'Nachrichtenvorschau anzeigen';

  @override
  String get showMessagePreviewsHelp =>
      'Absender und Originalnachricht in Benachrichtigungen anzeigen.';

  @override
  String get androidNotificationSettings =>
      'Android-Benachrichtigungseinstellungen';

  @override
  String get notificationsEnabled => 'Benachrichtigungen sind aktiviert';

  @override
  String get notificationsDisabled => 'Benachrichtigungen sind deaktiviert';

  @override
  String get notificationsNotRequested =>
      'Öffne einen Chat, um Benachrichtigungen zu aktivieren';

  @override
  String get notificationsUnavailable =>
      'Benachrichtigungen sind in diesem Build nicht verfügbar';

  @override
  String get couldNotSaveNotifications =>
      'Die Benachrichtigungseinstellung konnte nicht gespeichert werden.';

  @override
  String get enableNotificationsReminder =>
      'Aktiviere Benachrichtigungen, um von deinem Partner zu hören';

  @override
  String get dismiss => 'Schließen';
}
