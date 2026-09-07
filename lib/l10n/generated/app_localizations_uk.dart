// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appName => 'Blab';

  @override
  String unsupportedLanguageHint(String learningLanguage) {
    return 'Blab поки не знає цієї мови — спробуйте $learningLanguage.';
  }

  @override
  String get back => 'Назад';

  @override
  String get apply => 'Застосувати';

  @override
  String get undo => 'Скасувати';

  @override
  String get retry => 'Повторити';

  @override
  String get viewOriginal => 'Показати оригінал';

  @override
  String get original => 'Оригінал';

  @override
  String get listen => 'Слухати';

  @override
  String get save => 'Зберегти';

  @override
  String get cancel => 'Скасувати';

  @override
  String get send => 'Надіслати';

  @override
  String get done => 'Готово';

  @override
  String get delete => 'Видалити';

  @override
  String get copy => 'Копіювати';

  @override
  String get edit => 'Редагувати';

  @override
  String get report => 'Поскаржитися';

  @override
  String get reply => 'Відповісти';

  @override
  String get chats => 'Чати';

  @override
  String get profile => 'Профіль';

  @override
  String get interfaceLanguage => 'Мова інтерфейсу';

  @override
  String get interfaceLanguageHelp =>
      'Виберіть мову меню, кнопок та інших системних текстів у застосунку.';

  @override
  String switchedToLanguage(String language) {
    return 'Мову змінено на $language';
  }

  @override
  String get couldNotSaveLanguage =>
      'Не вдалося зберегти мову інтерфейсу. Спробуйте ще раз.';

  @override
  String get knownLanguages => 'Відомі мови';

  @override
  String get setPrimaryLanguage => 'Зробити основною мовою';

  @override
  String get languageEnglish => 'Англійська';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get languageGerman => 'Німецька';

  @override
  String get languageSpanish => 'Іспанська';

  @override
  String get authTagline => 'Вивчайте мову, спілкуючись із другом.';

  @override
  String signUpToChat(String name) {
    return 'Зареєструйтеся, щоб спілкуватися з $name.';
  }

  @override
  String logInToChat(String name) {
    return 'Увійдіть, щоб спілкуватися з $name.';
  }

  @override
  String get name => 'Ім\'я';

  @override
  String get firstNameHint => 'Ваше ім\'я';

  @override
  String get email => 'Електронна пошта';

  @override
  String get emailHint => 'ви@example.com';

  @override
  String get password => 'Пароль';

  @override
  String get forgotPassword => 'Забули пароль?';

  @override
  String get forgotYourPassword => 'Забули пароль?';

  @override
  String get joinBlab => 'Приєднатися до Blab';

  @override
  String get logIn => 'Увійти';

  @override
  String get signUp => 'Зареєструватися';

  @override
  String get alreadyHaveAccount => 'Уже маєте обліковий запис? Увійдіть';

  @override
  String get newToBlab => 'Вперше в Blab? Зареєструйтеся';

  @override
  String get orUseEmail => 'або скористайтеся поштою';

  @override
  String get continueWithGoogle => 'Продовжити з Google';

  @override
  String get continueWithApple => 'Продовжити з Apple';

  @override
  String get byContinuing => 'Продовжуючи, ви погоджуєтеся з нашими ';

  @override
  String get terms => 'Умовами';

  @override
  String get and => ' і ';

  @override
  String get privacyPolicy => 'Політикою конфіденційності';

  @override
  String get ageConfirmation =>
      ' та підтверджуєте, що вам щонайменше 13 років.';

  @override
  String get enterEmail => 'Введіть електронну пошту';

  @override
  String get enterValidEmail => 'Введіть дійсну адресу електронної пошти';

  @override
  String get emailResetLink => 'Надіслати посилання';

  @override
  String get checkYourEmail => 'Перевірте пошту';

  @override
  String resetLinkSent(String email) {
    return 'Ми надіслали посилання для скидання пароля на\n$email';
  }

  @override
  String get backToLogin => 'Назад до входу';

  @override
  String get setNewPassword => 'Установіть новий пароль';

  @override
  String get newPasswordHelp =>
      'Виберіть пароль, який запам\'ятаєте. Використайте щонайменше 6 символів.';

  @override
  String get newPassword => 'Новий пароль';

  @override
  String get confirmNewPassword => 'Підтвердьте новий пароль';

  @override
  String get saveNewPassword => 'Зберегти новий пароль';

  @override
  String get passwordUpdated => 'Пароль оновлено ✓';

  @override
  String get showPassword => 'Показати пароль';

  @override
  String get hidePassword => 'Сховати пароль';

  @override
  String get passwordWeak => 'Слабкий';

  @override
  String get passwordFair => 'Середній';

  @override
  String get passwordStrong => 'Надійний';

  @override
  String get passwordMinLength => 'Пароль має містити щонайменше 6 символів';

  @override
  String get chooseStrongerPassword => 'Виберіть надійніший пароль';

  @override
  String get passwordsDoNotMatch => 'Паролі не збігаються';

  @override
  String get enterDisplayName => 'Введіть відображуване ім\'я';

  @override
  String get displayNameTooLong =>
      'Відображуване ім\'я має містити не більше 50 символів';

  @override
  String get displayNameUnsupported =>
      'Відображуване ім\'я містить непідтримувані символи';

  @override
  String get editProfile => 'Редагувати профіль';

  @override
  String get displayName => 'Відображуване ім\'я';

  @override
  String get yourName => 'Ваше ім\'я';

  @override
  String get profileUpdated => 'Профіль оновлено ✓';

  @override
  String get couldNotUpdateProfile =>
      'Не вдалося оновити профіль. Спробуйте ще раз.';

  @override
  String get couldNotLoadProfile => 'Не вдалося завантажити профіль.';

  @override
  String get changeEmail => 'Змінити пошту';

  @override
  String get currentEmail => 'ПОТОЧНА ПОШТА';

  @override
  String get newEmail => 'Нова пошта';

  @override
  String get emailChangeHelp =>
      'Ми надішлемо посилання для підтвердження. Стара пошта залишатиметься активною до підтвердження.';

  @override
  String get checkYourInbox => 'Перевірте вхідні';

  @override
  String emailConfirmationSent(String email) {
    return 'Ми надіслали посилання для підтвердження на\n$email. Натисніть його, щоб завершити зміну.';
  }

  @override
  String get enterNewEmail => 'Введіть нову адресу електронної пошти';

  @override
  String get emailAlreadyUsed => 'Це вже ваша електронна пошта';

  @override
  String get changePassword => 'Змінити пароль';

  @override
  String get currentPassword => 'Поточний пароль';

  @override
  String get enterCurrentPassword => 'Введіть поточний пароль';

  @override
  String get enterNewPassword => 'Введіть новий пароль';

  @override
  String get confirmPassword => 'Підтвердьте новий пароль';

  @override
  String get chooseDifferentPassword => 'Виберіть інший пароль';

  @override
  String get passwordSignInUnavailable =>
      'Вхід за паролем не ввімкнено для цього облікового запису.';

  @override
  String get privacy => 'Конфіденційність';

  @override
  String get typingIndicators => 'Індикатори набору';

  @override
  String get typingIndicatorsHelp =>
      'Якщо вимкнути, ви не бачитимете, коли інші друкують, а вони не бачитимуть, коли друкуєте ви.';

  @override
  String get readReceipts => 'Сповіщення про прочитання';

  @override
  String get readReceiptsHelp =>
      'Якщо вимкнути, ви не бачитимете сповіщень інших, а вони не бачитимуть ваших.';

  @override
  String get couldNotSavePrivacy =>
      'Не вдалося зберегти налаштування конфіденційності.';

  @override
  String get termsOfUse => 'Умови використання';

  @override
  String get logOut => 'Вийти';

  @override
  String get logOutQuestion => 'Вийти?';

  @override
  String get logOutHelp =>
      'Для повторного входу знадобляться електронна пошта й пароль (або Google).';

  @override
  String get deleteAccount => 'Видалити обліковий запис';

  @override
  String get deleteAccountPermanent => 'Це незворотно. Буде видалено:';

  @override
  String get allChatsMessages => 'Усі чати й повідомлення';

  @override
  String get yourProfile => 'Ваш профіль';

  @override
  String get yourSettings => 'Ваші налаштування';

  @override
  String get confirmWithPassword => 'Підтвердити паролем';

  @override
  String typeEmailToConfirm(String email) {
    return 'Введіть $email для підтвердження';
  }

  @override
  String get deleteForever => 'Видалити назавжди';

  @override
  String get enterPasswordToConfirm => 'Введіть пароль для підтвердження';

  @override
  String get emailDoesNotMatch => 'Це не збігається з вашою поштою';

  @override
  String get couldNotDeleteAccount =>
      'Не вдалося видалити обліковий запис. Спробуйте ще раз.';

  @override
  String get newChat => 'Новий чат';

  @override
  String get noChatsYet => 'Чатів ще немає';

  @override
  String get inviteFriendStart => 'Запросіть друга й почніть спілкуватися.';

  @override
  String get inviteFriend => 'Запросити друга';

  @override
  String get couldNotLoadChats => 'Не вдалося завантажити чати';

  @override
  String get newConnectionSayHi => 'Новий контакт · привітайтеся';

  @override
  String get typing => 'друкує...';

  @override
  String get offline => 'Немає мережі';

  @override
  String get noConnection =>
      'Немає з\'єднання — повідомлення надішлються, коли ви знову будете онлайн';

  @override
  String get learningLanguage => 'Мова вивчення';

  @override
  String get learningLanguageHelp =>
      'Виберіть мову, яку хочете вивчати в цьому чаті. Її можна змінити будь-коли.';

  @override
  String get chatMenu => 'Меню чату';

  @override
  String get normalMode => 'Звичайний';

  @override
  String get practiceMode => 'Практика';

  @override
  String practiceComposerHint(String learningLanguage, String knownLanguage) {
    return 'Пишіть: $learningLanguage або $knownLanguage';
  }

  @override
  String get translationLimitReached => 'Ліміт перекладів вичерпано';

  @override
  String get translationUnavailable => 'Переклад недоступний';

  @override
  String get translating => 'Переклад…';

  @override
  String get checking => 'Перевірка…';

  @override
  String get couldntTranslateRetry => 'Не вдалося перекласти · Повторити';

  @override
  String get couldntCheckRetry => 'Не вдалося перевірити · Повторити';

  @override
  String get correction => 'Виправлення';

  @override
  String get possibleCorrection => 'Можливе виправлення';

  @override
  String get edited => 'відредаговано';

  @override
  String get sending => 'Надсилання';

  @override
  String get delivered => 'Доставлено';

  @override
  String get read => 'Прочитано';

  @override
  String get failedToSend => 'Не надіслано · Натисніть, щоб повторити';

  @override
  String get attach => 'Прикріпити';

  @override
  String get message => 'Повідомлення';

  @override
  String get sayHi => 'Привітайтеся';

  @override
  String replyingTo(Object name) {
    return 'Відповідь для $name';
  }

  @override
  String get editingMessage => 'Редагувати повідомлення';

  @override
  String get messageFailed => 'Не вдалося надіслати повідомлення';

  @override
  String get copied => 'Скопійовано';

  @override
  String get messageDeleted => 'Повідомлення видалено';

  @override
  String get deleteMessageQuestion => 'Видалити повідомлення?';

  @override
  String deleteMessageBody(String name) {
    return 'Ви впевнені, що хочете видалити це повідомлення? Його також буде видалено для $name.';
  }

  @override
  String get thanksReport => 'Дякуємо — ми це перевіримо.';

  @override
  String get couldNotReport => 'Не вдалося надіслати скаргу. Спробуйте ще раз.';

  @override
  String get couldNotSaveLearningLanguage =>
      'Не вдалося зберегти мову. Спробуйте ще раз.';

  @override
  String get reportMessage => 'Поскаржитися на повідомлення';

  @override
  String get sendInvite => 'Надіслати запрошення';

  @override
  String get pickLanguage => 'Виберіть мову';

  @override
  String get pickLanguageHelp =>
      'Ми перекладатимемо всі повідомлення цією мовою. Її можна змінити будь-коли.';

  @override
  String get continueAction => 'Продовжити';

  @override
  String get sendLinkHelp => 'Надішліть посилання, щоб почати спілкування.';

  @override
  String get onePersonInvite =>
      'Це посилання може використати лише одна людина.';

  @override
  String get validFor48Hours => 'Дійсне протягом 48 годин.';

  @override
  String get creatingLink => 'Створення посилання…';

  @override
  String get shareInvite => 'Поділитися запрошенням';

  @override
  String get change => 'Змінити';

  @override
  String get inviteSent => 'Запрошення надіслано ✓';

  @override
  String get couldNotCreateInvite =>
      'Не вдалося створити запрошення. Спробуйте ще раз.';

  @override
  String get shareInviteLink => 'Поділитися посиланням';

  @override
  String get more => 'Більше';

  @override
  String get linkCopied => 'Посилання скопійовано';

  @override
  String get copyLink => 'Копіювати посилання';

  @override
  String get pasteInChat => 'Тепер вставте його в чат';

  @override
  String practicingLanguage(Object language) {
    return 'Ви практикуєте $language.';
  }

  @override
  String get shareYourInvite => 'Поділіться посиланням на запрошення.';

  @override
  String validUntil(Object date) {
    return 'Дійсне до $date.';
  }

  @override
  String get inviteAlreadyClaimed => 'Це запрошення вже прийнято';

  @override
  String askForFreshLink(Object name) {
    return 'Попросіть $name надіслати нове посилання';
  }

  @override
  String get goToChats => 'До чатів';

  @override
  String get inviteNotFound => 'Не вдалося знайти це запрошення.';

  @override
  String get checkInviteLink => 'Перевірте посилання або попросіть нове.';

  @override
  String get sayHello => 'Привітатися';

  @override
  String sayWord(Object word) {
    return 'Сказати «$word»';
  }

  @override
  String get aFriend => 'Друг';

  @override
  String get you => 'Ви';

  @override
  String get partner => 'Співрозмовник';

  @override
  String get yourself => 'себе';

  @override
  String get couldNotEditMessage =>
      'Не вдалося відредагувати повідомлення. Спробуйте ще раз.';

  @override
  String get today => 'Сьогодні';

  @override
  String get yesterday => 'Учора';

  @override
  String get now => 'Зараз';

  @override
  String get newLabel => 'Нове';

  @override
  String get invitedYouToChat => 'запрошує вас до чату';

  @override
  String joinPerson(Object name) {
    return 'Приєднатися до $name';
  }

  @override
  String get inviteExpired => 'Термін дії запрошення минув';

  @override
  String get alreadyConnected =>
      'Ви вже на зв\'язку. Відкрийте чат, щоб почати.';

  @override
  String get openChat => 'Відкрити чат';

  @override
  String get yourInviteExpired => 'Термін дії вашого запрошення минув.';

  @override
  String get inviteExpiredHelp =>
      'Ніхто не приєднався протягом 48 годин. Надішліть нове посилання.';

  @override
  String get sendNewInvite => 'Надіслати нове запрошення';

  @override
  String youLearnLanguage(Object language) {
    return 'Ви вивчаєте $language';
  }

  @override
  String personLearnsLanguage(Object language, Object name) {
    return '$name вивчає $language';
  }

  @override
  String youAreLearningLanguageWithPerson(Object language, Object name) {
    return 'Ви вивчаєте $language з $name';
  }

  @override
  String get sendAnyMessage => 'Надішліть повідомлення, щоб почати.';

  @override
  String get languages => 'Мови';

  @override
  String speaksNatively(Object language) {
    return 'Рідна мова — $language';
  }

  @override
  String learningWithYou(Object language) {
    return 'Вивчає $language разом із вами';
  }

  @override
  String get chat => 'Чат';

  @override
  String get startedJustNow => 'Щойно почали спілкуватися';

  @override
  String startedMinutesAgo(Object count) {
    return 'Почали спілкуватися $count хв тому';
  }

  @override
  String startedHoursAgo(Object count) {
    return 'Почали спілкуватися $count год тому';
  }

  @override
  String startedDaysAgo(Object count) {
    return 'Почали спілкуватися $count дн тому';
  }

  @override
  String startedMonthsAgo(Object count) {
    return 'Почали спілкуватися $count міс тому';
  }

  @override
  String get safety => 'Безпека';

  @override
  String reportPerson(Object name) {
    return 'Поскаржитися на $name';
  }

  @override
  String blockPerson(Object name) {
    return 'Заблокувати $name';
  }

  @override
  String unblockPerson(Object name) {
    return 'Розблокувати $name';
  }

  @override
  String personBlocked(Object name) {
    return '$name заблоковано';
  }

  @override
  String personUnblocked(Object name) {
    return '$name розблоковано';
  }

  @override
  String get couldNotBlock => 'Не вдалося заблокувати. Спробуйте ще раз.';

  @override
  String get couldNotUnblock => 'Не вдалося розблокувати. Спробуйте ще раз.';

  @override
  String get reportSpam => 'Спам або шахрайство';

  @override
  String get reportHarassment => 'Домагання або цькування';

  @override
  String get reportHate => 'Мова ворожнечі';

  @override
  String get reportSexual => 'Сексуальний або неприйнятний вміст';

  @override
  String get reportChildSafety => 'Безпека дітей';

  @override
  String get reportOther => 'Інша причина';

  @override
  String get inviteClaimExpired => 'Термін дії запрошення минув.';

  @override
  String get inviteClaimUsed => 'Це запрошення вже використано.';

  @override
  String get inviteClaimInvalid => 'Це запрошення недійсне.';

  @override
  String get inviteClaimFailed =>
      'Не вдалося прийняти запрошення. Спробуйте ще раз.';

  @override
  String get appleSignInSoon => 'Вхід через Apple незабаром буде доступний';

  @override
  String get invalidCredentials => 'Неправильна електронна пошта або пароль';

  @override
  String get accountAlreadyExists => 'Обліковий запис із цією поштою вже існує';

  @override
  String get confirmEmailInbox => 'Перевірте вхідні, щоб підтвердити пошту';

  @override
  String get somethingWentWrong => 'Сталася помилка. Спробуйте ще раз.';

  @override
  String get currentPasswordIncorrect => 'Поточний пароль неправильний';

  @override
  String get signInAgain => 'Увійдіть знову, перш ніж змінювати пароль';

  @override
  String get tooManyAttempts => 'Забагато спроб. Спробуйте пізніше.';

  @override
  String get couldNotUpdatePassword =>
      'Не вдалося оновити пароль. Спробуйте ще раз.';

  @override
  String get emailChanged => 'Пошту змінено';

  @override
  String get someoneJoined => 'Хтось приєднався.';

  @override
  String personJoined(Object name) {
    return '$name приєднався(-лася).';
  }

  @override
  String get notifications => 'Сповіщення';

  @override
  String get showMessagePreviews => 'Показувати текст повідомлень';

  @override
  String get showMessagePreviewsHelp =>
      'Показувати відправника й оригінал повідомлення у сповіщеннях.';

  @override
  String get androidNotificationSettings => 'Налаштування сповіщень Android';

  @override
  String get notificationsEnabled => 'Сповіщення ввімкнено';

  @override
  String get notificationsDisabled => 'Сповіщення вимкнено';

  @override
  String get notificationsNotRequested =>
      'Відкрийте чат, щоб увімкнути сповіщення';

  @override
  String get notificationsUnavailable => 'Сповіщення недоступні в цій збірці';

  @override
  String get couldNotSaveNotifications =>
      'Не вдалося зберегти налаштування сповіщень.';

  @override
  String get enableNotificationsReminder =>
      'Увімкніть сповіщення, щоб не пропускати повідомлення партнера';

  @override
  String get dismiss => 'Закрити';

  @override
  String get photos => 'Фото';

  @override
  String get photoAccessNeeded => 'Потрібен доступ до фото';

  @override
  String get photoAccessNeededBody =>
      'Дозвольте доступ до фото, щоб надіслати одне в чаті.';

  @override
  String get openSettings => 'Відкрити налаштування';

  @override
  String get noPhotosFound => 'Поки що немає фото';

  @override
  String get photoMessagePreview => 'Фото';

  @override
  String get searchEmoji => 'Пошук емодзі';

  @override
  String reactionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count реакції',
      many: '$count реакцій',
      few: '$count реакції',
      one: '$count реакція',
    );
    return '$_temp0';
  }

  @override
  String get tapToRemove => 'Натисніть, щоб прибрати';
}
