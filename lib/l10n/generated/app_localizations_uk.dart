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
  String get unsupportedLanguageHint => 'Blab поки не розмовляє цією мовою.';

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
  String get account => 'Обліковий запис';

  @override
  String get settings => 'Налаштування';

  @override
  String get translationPreferences => 'Налаштування перекладу';

  @override
  String get yourGrammaticalForm => 'Твоя граматична форма';

  @override
  String partnerGrammaticalForm(String name) {
    return 'Граматична форма для $name';
  }

  @override
  String get conversationTone => 'Тон розмови';

  @override
  String get grammaticalForm => 'Граматична форма';

  @override
  String get notSet => 'Не вказано';

  @override
  String get formFeminine => 'Жіноча';

  @override
  String get formMasculine => 'Чоловіча';

  @override
  String get toneInformal => 'Неформальний';

  @override
  String get toneRespectful => 'Шанобливий';

  @override
  String get couldNotSavePreference => 'Не вдалося зберегти. Спробуй ще раз.';

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
  String get knownLanguages => 'Мови, які ти знаєш';

  @override
  String get setPrimaryLanguage => 'Зробити основною мовою';

  @override
  String get languageEnglish => 'Англійська';

  @override
  String get languageDutch => 'Нідерландська';

  @override
  String get languageFrench => 'Французька';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get languageGerman => 'Німецька';

  @override
  String get languageHindi => 'Гінді';

  @override
  String get languageItalian => 'Італійська';

  @override
  String get languagePortuguese => 'Португальська';

  @override
  String get languageSpanish => 'Іспанська';

  @override
  String get languageTamil => 'Тамільська';

  @override
  String get languageTurkish => 'Турецька';

  @override
  String get authTagline => 'Вивчай мову, спілкуючись із другом.';

  @override
  String signUpToChat(String name) {
    return 'Зареєструйся, щоб спілкуватися з $name.';
  }

  @override
  String logInToChat(String name) {
    return 'Увійди, щоб спілкуватися з $name.';
  }

  @override
  String get name => 'Ім\'я';

  @override
  String get firstNameHint => 'Твоє ім’я';

  @override
  String get email => 'Електронна пошта';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get password => 'Пароль';

  @override
  String get forgotPassword => 'Не пам’ятаєш пароль?';

  @override
  String get forgotYourPassword => 'Не пам’ятаєш пароль?';

  @override
  String get joinBlab => 'Приєднатися до Blab';

  @override
  String get logIn => 'Увійти';

  @override
  String get signUp => 'Зареєструватися';

  @override
  String get alreadyHaveAccount => 'Уже маєш обліковий запис? Увійди';

  @override
  String get newToBlab => 'Вперше в Blab? Зареєструйся';

  @override
  String get orUseEmail => 'або скористайся поштою';

  @override
  String get continueWithGoogle => 'Продовжити з Google';

  @override
  String get continueWithApple => 'Продовжити з Apple';

  @override
  String get byContinuing => 'Продовжуючи, ти погоджуєшся з нашими ';

  @override
  String get terms => 'Умовами';

  @override
  String get and => ' і ';

  @override
  String get privacyPolicy => 'Політикою конфіденційності';

  @override
  String get ageConfirmation =>
      ' та підтверджуєш, що тобі щонайменше 13 років.';

  @override
  String get enterEmail => 'Введи електронну пошту';

  @override
  String get enterValidEmail => 'Введи дійсну адресу електронної пошти';

  @override
  String get emailResetLink => 'Надіслати посилання';

  @override
  String get checkYourEmail => 'Перевір пошту';

  @override
  String resetLinkSent(String email) {
    return 'Ми надіслали посилання для скидання пароля на адресу $email';
  }

  @override
  String get backToLogin => 'Назад до входу';

  @override
  String get setNewPassword => 'Установи новий пароль';

  @override
  String get newPassword => 'Новий пароль';

  @override
  String get confirmNewPassword => 'Підтверди новий пароль';

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
  String get passwordMinHint => 'Щонайменше 6 символів';

  @override
  String get passwordMinLength => 'Використай щонайменше 6 символів';

  @override
  String get passwordsDoNotMatch => 'Паролі не збігаються';

  @override
  String get enterDisplayName => 'Введи ім’я в профілі';

  @override
  String get displayNameTooLong =>
      'Ім’я в профілі має містити не більше 50 символів';

  @override
  String get displayNameUnsupported =>
      'Ім’я в профілі містить непідтримувані символи';

  @override
  String get editProfile => 'Редагувати профіль';

  @override
  String get displayName => 'Ім’я в профілі';

  @override
  String get yourName => 'Твоє ім’я';

  @override
  String get profileUpdated => 'Профіль оновлено ✓';

  @override
  String get couldNotUpdateProfile =>
      'Не вдалося оновити профіль. Спробуй ще раз.';

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
  String get checkYourInbox => 'Перевір вхідні';

  @override
  String emailConfirmationSent(String email) {
    return 'Ми надіслали посилання для підтвердження на\n$email. Натисни його, щоб завершити зміну.';
  }

  @override
  String get enterNewEmail => 'Введи нову адресу електронної пошти';

  @override
  String get emailAlreadyUsed => 'Це вже твоя електронна пошта';

  @override
  String get changePassword => 'Змінити пароль';

  @override
  String get currentPassword => 'Поточний пароль';

  @override
  String get enterCurrentPassword => 'Введи поточний пароль';

  @override
  String get enterNewPassword => 'Введи новий пароль';

  @override
  String get confirmPassword => 'Підтверди новий пароль';

  @override
  String get chooseDifferentPassword => 'Вибери інший пароль';

  @override
  String get passwordSignInUnavailable =>
      'Вхід за паролем не ввімкнено для цього облікового запису.';

  @override
  String get privacy => 'Конфіденційність';

  @override
  String get typingIndicators => 'Індикатори набору';

  @override
  String get typingIndicatorsHelp =>
      'Якщо вимкнути, ти не бачитимеш, коли інші друкують, а вони не бачитимуть, коли друкуєш ти.';

  @override
  String get readReceipts => 'Сповіщення про прочитання';

  @override
  String get readReceiptsHelp =>
      'Якщо вимкнути, ти не бачитимеш сповіщень інших, а вони не бачитимуть твоїх.';

  @override
  String get couldNotSavePrivacy =>
      'Не вдалося зберегти налаштування конфіденційності.';

  @override
  String get privacyPolicyTitle => 'Політика конфіденційності';

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
  String get yourProfile => 'Твій профіль';

  @override
  String get yourSettings => 'Твої налаштування';

  @override
  String get confirmWithPassword => 'Підтвердити паролем';

  @override
  String typeEmailToConfirm(String email) {
    return 'Введи $email для підтвердження';
  }

  @override
  String get deleteForever => 'Видалити назавжди';

  @override
  String get deleteAccountConfirmationTitle =>
      'Видалити обліковий запис назавжди?';

  @override
  String get deleteAccountConfirmationBody => 'Цю дію неможливо скасувати.';

  @override
  String get enterPasswordToConfirm => 'Введи пароль для підтвердження';

  @override
  String get emailDoesNotMatch => 'Це не збігається з твоєю поштою';

  @override
  String get couldNotDeleteAccount =>
      'Не вдалося видалити обліковий запис. Спробуй ще раз.';

  @override
  String get newChat => 'Новий чат';

  @override
  String get noChatsYet => 'Чатів ще немає';

  @override
  String get inviteFriendStart => 'Запроси друга й почни спілкуватися.';

  @override
  String get inviteFriend => 'Запросити друга';

  @override
  String get couldNotLoadChats => 'Не вдалося завантажити чати';

  @override
  String get couldNotLoadMessages => 'Не вдалося завантажити повідомлення';

  @override
  String get newConnectionSayHi => 'Новий контакт · привітайся';

  @override
  String get typing => 'друкує...';

  @override
  String get offline => 'Немає мережі';

  @override
  String get noConnection => 'Немає з’єднання';

  @override
  String relativeMinutes(int count) {
    return '$count хв';
  }

  @override
  String relativeHours(int count) {
    return '$count год';
  }

  @override
  String relativeDays(int count) {
    return '$count дн';
  }

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
  String get pickLanguage => 'Вибери мову';

  @override
  String get pickLanguageHelp =>
      'Ми перекладатимемо всі повідомлення цією мовою. Ти можеш змінити її будь-коли.';

  @override
  String get continueAction => 'Продовжити';

  @override
  String get sendLinkHelp => 'Надішли посилання, щоб почати спілкування.';

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
      'Не вдалося створити запрошення. Спробуй ще раз.';

  @override
  String get shareInviteLink => 'Поділитися посиланням';

  @override
  String get more => 'Більше';

  @override
  String get linkCopied => 'Посилання скопійовано';

  @override
  String get copyLink => 'Копіювати посилання';

  @override
  String get pasteInChat => 'Тепер встав його в чат';

  @override
  String practicingLanguage(Object language) {
    return 'Ти практикуєш $language.';
  }

  @override
  String get shareYourInvite => 'Поділися посиланням на запрошення.';

  @override
  String validUntil(Object date) {
    return 'Дійсне до $date.';
  }

  @override
  String get inviteAlreadyClaimed => 'Це запрошення вже прийнято';

  @override
  String askForFreshLink(Object name) {
    return 'Попроси $name надіслати нове посилання';
  }

  @override
  String get goToChats => 'До чатів';

  @override
  String get inviteNotFound => 'Не вдалося знайти це запрошення.';

  @override
  String get checkInviteLink => 'Перевір посилання або попроси нове.';

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
  String get inviteCardTitle => 'Спілкуймося в Blab';

  @override
  String get inviteLinkUnavailable => 'Посилання на запрошення недоступне';

  @override
  String get openingShareSheet => 'Відкриваємо варіанти поширення…';

  @override
  String get couldNotOpenSharing =>
      'Не вдалося відкрити меню поширення. Спробуй ще раз.';

  @override
  String get openingInvite => 'Відкриваємо запрошення';

  @override
  String get couldNotOpenInvite => 'Не вдалося відкрити запрошення.';

  @override
  String get tryAgainToContinue => 'Спробуй ще раз, щоб продовжити.';

  @override
  String get askFriendForNewLink =>
      'Попроси того, хто тебе запросив, надіслати нове посилання.';

  @override
  String inviteShareMessage(String link) {
    return 'Спілкуймося в Blab: $link';
  }

  @override
  String get inviteShareBlurb => 'Спілкуймося в Blab.';

  @override
  String get inviteEmailSubject => 'Спілкуймося в Blab';

  @override
  String get inviteSelfClaim => 'Не можна скористатися власним запрошенням.';

  @override
  String get inviteInvalidLanguage =>
      'Вибери підтримувану мову й спробуй ще раз.';

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
      'Не вдалося прийняти запрошення. Спробуй ще раз.';

  @override
  String get appleSignInSoon => 'Вхід через Apple незабаром буде доступний';

  @override
  String get invalidCredentials => 'Неправильна електронна пошта або пароль';

  @override
  String get accountAlreadyExists => 'Обліковий запис із цією поштою вже існує';

  @override
  String get confirmEmailInbox => 'Перевір вхідні, щоб підтвердити пошту';

  @override
  String get somethingWentWrong => 'Сталася помилка. Спробуй ще раз.';

  @override
  String get currentPasswordIncorrect => 'Поточний пароль неправильний';

  @override
  String get signInAgain => 'Увійди знову, перш ніж змінювати пароль';

  @override
  String get tooManyAttempts => 'Забагато спроб. Спробуй пізніше.';

  @override
  String get couldNotUpdatePassword =>
      'Не вдалося оновити пароль. Спробуй ще раз.';

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
      'Відкрий чат, щоб увімкнути сповіщення';

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

  @override
  String usingFeminineForms(String person) {
    return 'Жіночі форми для $person';
  }

  @override
  String usingMasculineForms(String person) {
    return 'Чоловічі форми для $person';
  }

  @override
  String get usingFeminineFormsForYou => 'Жіночі форми для вас';

  @override
  String get usingMasculineFormsForYou => 'Чоловічі форми для вас';

  @override
  String get readingScript => 'Писемність для читання';

  @override
  String get hindiScript => 'Писемність гінді';

  @override
  String get tamilScript => 'Тамільська писемність';

  @override
  String get nativeScripts => 'Рідні писемності';

  @override
  String get englishLetters => 'Латинські літери';
}
