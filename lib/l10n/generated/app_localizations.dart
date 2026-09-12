import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
    Locale('de'),
    Locale('es'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Blab'**
  String get appName;

  /// No description provided for @unsupportedIncomingLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Blab can’t translate this language yet. Showing the original.'**
  String get unsupportedIncomingLanguageHint;

  /// No description provided for @unsupportedLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Blab doesn’t speak this one yet — try {learningLanguage}.'**
  String unsupportedLanguageHint(String learningLanguage);

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @viewOriginal.
  ///
  /// In en, this message translates to:
  /// **'View original'**
  String get viewOriginal;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @interfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get interfaceLanguage;

  /// No description provided for @interfaceLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'Pick the language for menus, buttons, and other system text across the app.'**
  String get interfaceLanguageHelp;

  /// No description provided for @switchedToLanguage.
  ///
  /// In en, this message translates to:
  /// **'Switched to {language}'**
  String switchedToLanguage(String language);

  /// No description provided for @couldNotSaveLanguage.
  ///
  /// In en, this message translates to:
  /// **'Could not save the interface language. Try again.'**
  String get couldNotSaveLanguage;

  /// No description provided for @knownLanguages.
  ///
  /// In en, this message translates to:
  /// **'Known languages'**
  String get knownLanguages;

  /// No description provided for @setPrimaryLanguage.
  ///
  /// In en, this message translates to:
  /// **'Set as primary language'**
  String get setPrimaryLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get languageUkrainian;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'Learn a language by chatting with a friend.'**
  String get authTagline;

  /// No description provided for @signUpToChat.
  ///
  /// In en, this message translates to:
  /// **'Sign up to chat with {name}.'**
  String signUpToChat(String name);

  /// No description provided for @logInToChat.
  ///
  /// In en, this message translates to:
  /// **'Log in to chat with {name}.'**
  String logInToChat(String name);

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @firstNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your first name'**
  String get firstNameHint;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @forgotYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotYourPassword;

  /// No description provided for @joinBlab.
  ///
  /// In en, this message translates to:
  /// **'Join Blab'**
  String get joinBlab;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get alreadyHaveAccount;

  /// No description provided for @newToBlab.
  ///
  /// In en, this message translates to:
  /// **'New to Blab? Sign up'**
  String get newToBlab;

  /// No description provided for @orUseEmail.
  ///
  /// In en, this message translates to:
  /// **'or use email'**
  String get orUseEmail;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @byContinuing.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get byContinuing;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @ageConfirmation.
  ///
  /// In en, this message translates to:
  /// **', and confirm you are at least 13.'**
  String get ageConfirmation;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterEmail;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get enterValidEmail;

  /// No description provided for @emailResetLink.
  ///
  /// In en, this message translates to:
  /// **'Email me a reset link'**
  String get emailResetLink;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @resetLinkSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a reset link to\n{email}'**
  String resetLinkSent(String email);

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to log in'**
  String get backToLogin;

  /// No description provided for @setNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get setNewPassword;

  /// No description provided for @newPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Pick something you\'ll remember. Use at least 6 characters.'**
  String get newPasswordHelp;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @saveNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Save new password'**
  String get saveNewPassword;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated ✓'**
  String get passwordUpdated;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @passwordWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordWeak;

  /// No description provided for @passwordFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordFair;

  /// No description provided for @passwordStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrong;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @chooseStrongerPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a stronger password'**
  String get chooseStrongerPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDoNotMatch;

  /// No description provided for @enterDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Enter your display name'**
  String get enterDisplayName;

  /// No description provided for @displayNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Display name must be 50 characters or fewer'**
  String get displayNameTooLong;

  /// No description provided for @displayNameUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Display name contains unsupported characters'**
  String get displayNameUnsupported;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated ✓'**
  String get profileUpdated;

  /// No description provided for @couldNotUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not update your profile. Try again.'**
  String get couldNotUpdateProfile;

  /// No description provided for @couldNotLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile.'**
  String get couldNotLoadProfile;

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmail;

  /// No description provided for @currentEmail.
  ///
  /// In en, this message translates to:
  /// **'CURRENT EMAIL'**
  String get currentEmail;

  /// No description provided for @newEmail.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get newEmail;

  /// No description provided for @emailChangeHelp.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a confirmation link. Your old email stays active until you confirm.'**
  String get emailChangeHelp;

  /// No description provided for @checkYourInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get checkYourInbox;

  /// No description provided for @emailConfirmationSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to\n{email}. Tap it to finish the change.'**
  String emailConfirmationSent(String email);

  /// No description provided for @enterNewEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your new email'**
  String get enterNewEmail;

  /// No description provided for @emailAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'That\'s already your email'**
  String get emailAlreadyUsed;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @enterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get enterCurrentPassword;

  /// No description provided for @enterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password'**
  String get enterNewPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm your new password'**
  String get confirmPassword;

  /// No description provided for @chooseDifferentPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a different password'**
  String get chooseDifferentPassword;

  /// No description provided for @passwordSignInUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Password sign-in is not enabled for this account.'**
  String get passwordSignInUnavailable;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @typingIndicators.
  ///
  /// In en, this message translates to:
  /// **'Typing indicators'**
  String get typingIndicators;

  /// No description provided for @typingIndicatorsHelp.
  ///
  /// In en, this message translates to:
  /// **'If turned off, you won\'t see when others are typing, and they won\'t see when you are.'**
  String get typingIndicatorsHelp;

  /// No description provided for @readReceipts.
  ///
  /// In en, this message translates to:
  /// **'Read receipts'**
  String get readReceipts;

  /// No description provided for @readReceiptsHelp.
  ///
  /// In en, this message translates to:
  /// **'If turned off, you won\'t see read receipts from others, and they won\'t see yours.'**
  String get readReceiptsHelp;

  /// No description provided for @couldNotSavePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save privacy setting.'**
  String get couldNotSavePrivacy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @logOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutQuestion;

  /// No description provided for @logOutHelp.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need your email and password (or Google) to sign back in.'**
  String get logOutHelp;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountPermanent.
  ///
  /// In en, this message translates to:
  /// **'This is permanent. The following will be deleted:'**
  String get deleteAccountPermanent;

  /// No description provided for @allChatsMessages.
  ///
  /// In en, this message translates to:
  /// **'All chats and messages'**
  String get allChatsMessages;

  /// No description provided for @yourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get yourProfile;

  /// No description provided for @yourSettings.
  ///
  /// In en, this message translates to:
  /// **'Your settings and preferences'**
  String get yourSettings;

  /// No description provided for @confirmWithPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm with password'**
  String get confirmWithPassword;

  /// No description provided for @typeEmailToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {email} to confirm'**
  String typeEmailToConfirm(String email);

  /// No description provided for @deleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// No description provided for @enterPasswordToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm'**
  String get enterPasswordToConfirm;

  /// No description provided for @emailDoesNotMatch.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t match your email'**
  String get emailDoesNotMatch;

  /// No description provided for @couldNotDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Try again.'**
  String get couldNotDeleteAccount;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// No description provided for @inviteFriendStart.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend and start chatting.'**
  String get inviteFriendStart;

  /// No description provided for @inviteFriend.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get inviteFriend;

  /// No description provided for @couldNotLoadChats.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load chats'**
  String get couldNotLoadChats;

  /// No description provided for @newConnectionSayHi.
  ///
  /// In en, this message translates to:
  /// **'New connection · say hi'**
  String get newConnectionSayHi;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'typing...'**
  String get typing;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get noConnection;

  /// No description provided for @learningLanguage.
  ///
  /// In en, this message translates to:
  /// **'Learning language'**
  String get learningLanguage;

  /// No description provided for @learningLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'Pick the language you want to learn in this chat. You can change it anytime.'**
  String get learningLanguageHelp;

  /// No description provided for @chatMenu.
  ///
  /// In en, this message translates to:
  /// **'Chat menu'**
  String get chatMenu;

  /// No description provided for @normalMode.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normalMode;

  /// No description provided for @practiceMode.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get practiceMode;

  /// No description provided for @practiceComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Type in {learningLanguage} or {knownLanguage}'**
  String practiceComposerHint(String learningLanguage, String knownLanguage);

  /// No description provided for @translationLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Translation limit reached'**
  String get translationLimitReached;

  /// No description provided for @translationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Translation unavailable'**
  String get translationUnavailable;

  /// No description provided for @translating.
  ///
  /// In en, this message translates to:
  /// **'Translating…'**
  String get translating;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @couldntTranslateRetry.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t translate · Retry'**
  String get couldntTranslateRetry;

  /// No description provided for @couldntCheckRetry.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t check · Retry'**
  String get couldntCheckRetry;

  /// No description provided for @correction.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get correction;

  /// No description provided for @possibleCorrection.
  ///
  /// In en, this message translates to:
  /// **'Possible correction'**
  String get possibleCorrection;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get edited;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sending;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @read.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get read;

  /// No description provided for @failedToSend.
  ///
  /// In en, this message translates to:
  /// **'Not sent · Tap to try again'**
  String get failedToSend;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @sayHi.
  ///
  /// In en, this message translates to:
  /// **'Say hi'**
  String get sayHi;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyingTo(Object name);

  /// No description provided for @editingMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editingMessage;

  /// No description provided for @messageFailed.
  ///
  /// In en, this message translates to:
  /// **'Message failed to send'**
  String get messageFailed;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @messageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get messageDeleted;

  /// No description provided for @deleteMessageQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get deleteMessageQuestion;

  /// No description provided for @deleteMessageBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this message? It will also be deleted for {name}.'**
  String deleteMessageBody(String name);

  /// No description provided for @thanksReport.
  ///
  /// In en, this message translates to:
  /// **'Thanks — we\'ll review this.'**
  String get thanksReport;

  /// No description provided for @couldNotReport.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the report. Try again.'**
  String get couldNotReport;

  /// No description provided for @couldNotSaveLearningLanguage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save language. Try again.'**
  String get couldNotSaveLearningLanguage;

  /// No description provided for @reportMessage.
  ///
  /// In en, this message translates to:
  /// **'Report message'**
  String get reportMessage;

  /// No description provided for @sendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send the invite'**
  String get sendInvite;

  /// No description provided for @pickLanguage.
  ///
  /// In en, this message translates to:
  /// **'Pick a language'**
  String get pickLanguage;

  /// No description provided for @pickLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'We\'ll translate all messages into this language. Switch it whenever you like.'**
  String get pickLanguageHelp;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @sendLinkHelp.
  ///
  /// In en, this message translates to:
  /// **'Send the link to start chatting.'**
  String get sendLinkHelp;

  /// No description provided for @onePersonInvite.
  ///
  /// In en, this message translates to:
  /// **'Only one person can use this link.'**
  String get onePersonInvite;

  /// No description provided for @validFor48Hours.
  ///
  /// In en, this message translates to:
  /// **'Valid for 48 hours.'**
  String get validFor48Hours;

  /// No description provided for @creatingLink.
  ///
  /// In en, this message translates to:
  /// **'Creating link…'**
  String get creatingLink;

  /// No description provided for @shareInvite.
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get shareInvite;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @inviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invite sent ✓'**
  String get inviteSent;

  /// No description provided for @couldNotCreateInvite.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create invite. Try again.'**
  String get couldNotCreateInvite;

  /// No description provided for @shareInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Share invite link'**
  String get shareInviteLink;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @pasteInChat.
  ///
  /// In en, this message translates to:
  /// **'Now paste it in a chat'**
  String get pasteInChat;

  /// No description provided for @practicingLanguage.
  ///
  /// In en, this message translates to:
  /// **'You\'re practicing {language}.'**
  String practicingLanguage(Object language);

  /// No description provided for @shareYourInvite.
  ///
  /// In en, this message translates to:
  /// **'Share your invite link.'**
  String get shareYourInvite;

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}.'**
  String validUntil(Object date);

  /// No description provided for @inviteAlreadyClaimed.
  ///
  /// In en, this message translates to:
  /// **'This invite was already claimed'**
  String get inviteAlreadyClaimed;

  /// No description provided for @askForFreshLink.
  ///
  /// In en, this message translates to:
  /// **'Ask {name} for a fresh link'**
  String askForFreshLink(Object name);

  /// No description provided for @goToChats.
  ///
  /// In en, this message translates to:
  /// **'Go to chats'**
  String get goToChats;

  /// No description provided for @inviteNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that invite.'**
  String get inviteNotFound;

  /// No description provided for @checkInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Check the link is correct, or ask for a new one.'**
  String get checkInviteLink;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello'**
  String get sayHello;

  /// No description provided for @sayWord.
  ///
  /// In en, this message translates to:
  /// **'Say {word}'**
  String sayWord(Object word);

  /// No description provided for @aFriend.
  ///
  /// In en, this message translates to:
  /// **'A friend'**
  String get aFriend;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @partner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get partner;

  /// No description provided for @yourself.
  ///
  /// In en, this message translates to:
  /// **'yourself'**
  String get yourself;

  /// No description provided for @couldNotEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t edit message. Try again.'**
  String get couldNotEditMessage;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @invitedYouToChat.
  ///
  /// In en, this message translates to:
  /// **'invited you to chat'**
  String get invitedYouToChat;

  /// No description provided for @joinPerson.
  ///
  /// In en, this message translates to:
  /// **'Join {name}'**
  String joinPerson(Object name);

  /// No description provided for @inviteExpired.
  ///
  /// In en, this message translates to:
  /// **'This invite expired'**
  String get inviteExpired;

  /// No description provided for @alreadyConnected.
  ///
  /// In en, this message translates to:
  /// **'You\'re already connected. Open the chat to start.'**
  String get alreadyConnected;

  /// No description provided for @openChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get openChat;

  /// No description provided for @yourInviteExpired.
  ///
  /// In en, this message translates to:
  /// **'Your invite expired.'**
  String get yourInviteExpired;

  /// No description provided for @inviteExpiredHelp.
  ///
  /// In en, this message translates to:
  /// **'Nobody joined in 48 hours. Send a fresh link to a friend.'**
  String get inviteExpiredHelp;

  /// No description provided for @sendNewInvite.
  ///
  /// In en, this message translates to:
  /// **'Send new invite'**
  String get sendNewInvite;

  /// No description provided for @youLearnLanguage.
  ///
  /// In en, this message translates to:
  /// **'You learn {language}'**
  String youLearnLanguage(Object language);

  /// No description provided for @personLearnsLanguage.
  ///
  /// In en, this message translates to:
  /// **'{name} learns {language}'**
  String personLearnsLanguage(Object language, Object name);

  /// No description provided for @youAreLearningLanguageWithPerson.
  ///
  /// In en, this message translates to:
  /// **'You\'re learning {language} with {name}'**
  String youAreLearningLanguageWithPerson(Object language, Object name);

  /// No description provided for @sendAnyMessage.
  ///
  /// In en, this message translates to:
  /// **'Send any message to start.'**
  String get sendAnyMessage;

  /// No description provided for @languages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get languages;

  /// No description provided for @speaksNatively.
  ///
  /// In en, this message translates to:
  /// **'Speaks {language} natively'**
  String speaksNatively(Object language);

  /// No description provided for @learningWithYou.
  ///
  /// In en, this message translates to:
  /// **'Learning {language} with you'**
  String learningWithYou(Object language);

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @startedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Started chatting just now'**
  String get startedJustNow;

  /// No description provided for @startedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Started chatting {count}m ago'**
  String startedMinutesAgo(Object count);

  /// No description provided for @startedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'Started chatting {count}h ago'**
  String startedHoursAgo(Object count);

  /// No description provided for @startedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Started chatting {count}d ago'**
  String startedDaysAgo(Object count);

  /// No description provided for @startedMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'Started chatting {count}mo ago'**
  String startedMonthsAgo(Object count);

  /// No description provided for @safety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safety;

  /// No description provided for @reportPerson.
  ///
  /// In en, this message translates to:
  /// **'Report {name}'**
  String reportPerson(Object name);

  /// No description provided for @blockPerson.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String blockPerson(Object name);

  /// No description provided for @unblockPerson.
  ///
  /// In en, this message translates to:
  /// **'Unblock {name}'**
  String unblockPerson(Object name);

  /// No description provided for @personBlocked.
  ///
  /// In en, this message translates to:
  /// **'{name} blocked'**
  String personBlocked(Object name);

  /// No description provided for @personUnblocked.
  ///
  /// In en, this message translates to:
  /// **'{name} unblocked'**
  String personUnblocked(Object name);

  /// No description provided for @couldNotBlock.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t block. Try again.'**
  String get couldNotBlock;

  /// No description provided for @couldNotUnblock.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t unblock. Try again.'**
  String get couldNotUnblock;

  /// No description provided for @reportSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or scam'**
  String get reportSpam;

  /// No description provided for @reportHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or bullying'**
  String get reportHarassment;

  /// No description provided for @reportHate.
  ///
  /// In en, this message translates to:
  /// **'Hate speech'**
  String get reportHate;

  /// No description provided for @reportSexual.
  ///
  /// In en, this message translates to:
  /// **'Sexual or inappropriate content'**
  String get reportSexual;

  /// No description provided for @reportChildSafety.
  ///
  /// In en, this message translates to:
  /// **'Child safety'**
  String get reportChildSafety;

  /// No description provided for @reportOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportOther;

  /// No description provided for @inviteClaimExpired.
  ///
  /// In en, this message translates to:
  /// **'This invite has expired.'**
  String get inviteClaimExpired;

  /// No description provided for @inviteClaimUsed.
  ///
  /// In en, this message translates to:
  /// **'This invite has already been used.'**
  String get inviteClaimUsed;

  /// No description provided for @inviteClaimInvalid.
  ///
  /// In en, this message translates to:
  /// **'This invite is invalid.'**
  String get inviteClaimInvalid;

  /// No description provided for @inviteClaimFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t accept the invite. Try again.'**
  String get inviteClaimFailed;

  /// No description provided for @appleSignInSoon.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in coming soon'**
  String get appleSignInSoon;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect'**
  String get invalidCredentials;

  /// No description provided for @accountAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists'**
  String get accountAlreadyExists;

  /// No description provided for @confirmEmailInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox to confirm your email'**
  String get confirmEmailInbox;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get somethingWentWrong;

  /// No description provided for @currentPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get currentPasswordIncorrect;

  /// No description provided for @signInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again before changing your password'**
  String get signInAgain;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get tooManyAttempts;

  /// No description provided for @couldNotUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Could not update your password. Try again.'**
  String get couldNotUpdatePassword;

  /// No description provided for @emailChanged.
  ///
  /// In en, this message translates to:
  /// **'Email changed'**
  String get emailChanged;

  /// No description provided for @someoneJoined.
  ///
  /// In en, this message translates to:
  /// **'Someone joined.'**
  String get someoneJoined;

  /// No description provided for @personJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} joined.'**
  String personJoined(Object name);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @showMessagePreviews.
  ///
  /// In en, this message translates to:
  /// **'Show message previews'**
  String get showMessagePreviews;

  /// No description provided for @showMessagePreviewsHelp.
  ///
  /// In en, this message translates to:
  /// **'Show the sender and original message in notifications.'**
  String get showMessagePreviewsHelp;

  /// No description provided for @androidNotificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Android notification settings'**
  String get androidNotificationSettings;

  /// No description provided for @notificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications are enabled'**
  String get notificationsEnabled;

  /// No description provided for @notificationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off'**
  String get notificationsDisabled;

  /// No description provided for @notificationsNotRequested.
  ///
  /// In en, this message translates to:
  /// **'Open a chat to enable notifications'**
  String get notificationsNotRequested;

  /// No description provided for @notificationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Notifications aren\'t available in this build'**
  String get notificationsUnavailable;

  /// No description provided for @couldNotSaveNotifications.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save notification setting.'**
  String get couldNotSaveNotifications;

  /// No description provided for @enableNotificationsReminder.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications to hear from your partner'**
  String get enableNotificationsReminder;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @photoAccessNeeded.
  ///
  /// In en, this message translates to:
  /// **'Photo access needed'**
  String get photoAccessNeeded;

  /// No description provided for @photoAccessNeededBody.
  ///
  /// In en, this message translates to:
  /// **'Allow access to your photos to share one in chat.'**
  String get photoAccessNeededBody;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @noPhotosFound.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get noPhotosFound;

  /// No description provided for @photoMessagePreview.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoMessagePreview;

  /// No description provided for @searchEmoji.
  ///
  /// In en, this message translates to:
  /// **'Search emoji'**
  String get searchEmoji;

  /// No description provided for @reactionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} reaction} other{{count} reactions}}'**
  String reactionsCount(int count);

  /// No description provided for @tapToRemove.
  ///
  /// In en, this message translates to:
  /// **'Tap to remove'**
  String get tapToRemove;

  /// No description provided for @usingFeminineForms.
  ///
  /// In en, this message translates to:
  /// **'Using feminine forms for {person}'**
  String usingFeminineForms(String person);

  /// No description provided for @usingMasculineForms.
  ///
  /// In en, this message translates to:
  /// **'Using masculine forms for {person}'**
  String usingMasculineForms(String person);

  /// No description provided for @usingFeminineFormsForYou.
  ///
  /// In en, this message translates to:
  /// **'Using feminine forms for you'**
  String get usingFeminineFormsForYou;

  /// No description provided for @usingMasculineFormsForYou.
  ///
  /// In en, this message translates to:
  /// **'Using masculine forms for you'**
  String get usingMasculineFormsForYou;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
