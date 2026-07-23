import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

String localizedInterfaceLanguageName(
  AppLocalizations localizations,
  String code,
) {
  return switch (code) {
    'uk' => localizations.languageUkrainian,
    'de' => localizations.languageGerman,
    'es' => localizations.languageSpanish,
    _ => localizations.languageEnglish,
  };
}

String localizedAuthMessage(
  AppLocalizations localizations,
  String englishMessage,
) {
  return switch (englishMessage) {
    'Email or password is incorrect' => localizations.invalidCredentials,
    'An account with this email already exists' =>
      localizations.accountAlreadyExists,
    'Password must be at least 6 characters' => localizations.passwordMinLength,
    'Enter a valid email address' => localizations.enterValidEmail,
    'Check your inbox to confirm your email' => localizations.confirmEmailInbox,
    'Current password is incorrect' => localizations.currentPasswordIncorrect,
    'Choose a different password' => localizations.chooseDifferentPassword,
    'Please sign in again before changing your password' =>
      localizations.signInAgain,
    'Too many attempts. Try again later.' => localizations.tooManyAttempts,
    'Could not update your password. Try again.' =>
      localizations.couldNotUpdatePassword,
    _ => localizations.somethingWentWrong,
  };
}
