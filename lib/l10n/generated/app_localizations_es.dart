// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Blab';

  @override
  String get back => 'Atrás';

  @override
  String get apply => 'Aplicar';

  @override
  String get undo => 'Deshacer';

  @override
  String get retry => 'Reintentar';

  @override
  String get viewOriginal => 'Ver original';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get send => 'Enviar';

  @override
  String get done => 'Listo';

  @override
  String get delete => 'Eliminar';

  @override
  String get copy => 'Copiar';

  @override
  String get edit => 'Editar';

  @override
  String get report => 'Denunciar';

  @override
  String get reply => 'Responder';

  @override
  String get chats => 'Chats';

  @override
  String get profile => 'Perfil';

  @override
  String get interfaceLanguage => 'Idioma de la interfaz';

  @override
  String get interfaceLanguageHelp =>
      'Elige el idioma de los menús, botones y otros textos del sistema de la aplicación.';

  @override
  String switchedToLanguage(String language) {
    return 'Idioma cambiado a $language';
  }

  @override
  String get couldNotSaveLanguage =>
      'No se pudo guardar el idioma de la interfaz. Inténtalo de nuevo.';

  @override
  String get knownLanguages => 'Idiomas que conoces';

  @override
  String get setPrimaryLanguage => 'Establecer como idioma principal';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageUkrainian => 'Ucraniano';

  @override
  String get languageGerman => 'Alemán';

  @override
  String get languageSpanish => 'Español';

  @override
  String get authTagline => 'Aprende un idioma chateando con un amigo.';

  @override
  String signUpToChat(String name) {
    return 'Regístrate para chatear con $name.';
  }

  @override
  String logInToChat(String name) {
    return 'Inicia sesión para chatear con $name.';
  }

  @override
  String get name => 'Nombre';

  @override
  String get firstNameHint => 'Tu nombre';

  @override
  String get email => 'Correo electrónico';

  @override
  String get emailHint => 'tu@ejemplo.com';

  @override
  String get password => 'Contraseña';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get forgotYourPassword => '¿Olvidaste tu contraseña?';

  @override
  String get joinBlab => 'Unirse a Blab';

  @override
  String get logIn => 'Iniciar sesión';

  @override
  String get signUp => 'Registrarse';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta? Inicia sesión';

  @override
  String get newToBlab => '¿Eres nuevo en Blab? Regístrate';

  @override
  String get orUseEmail => 'o usa el correo';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get byContinuing => 'Al continuar, aceptas nuestros ';

  @override
  String get terms => 'Términos';

  @override
  String get and => ' y la ';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get ageConfirmation => ', y confirmas que tienes al menos 13 años.';

  @override
  String get enterEmail => 'Introduce tu correo electrónico';

  @override
  String get enterValidEmail => 'Introduce una dirección de correo válida';

  @override
  String get emailResetLink => 'Enviarme un enlace';

  @override
  String get checkYourEmail => 'Revisa tu correo';

  @override
  String resetLinkSent(String email) {
    return 'Enviamos un enlace para restablecer la contraseña a\n$email';
  }

  @override
  String get backToLogin => 'Volver al inicio de sesión';

  @override
  String get setNewPassword => 'Establece una nueva contraseña';

  @override
  String get newPasswordHelp =>
      'Elige algo que recuerdes. Usa al menos 6 caracteres.';

  @override
  String get newPassword => 'Nueva contraseña';

  @override
  String get confirmNewPassword => 'Confirmar nueva contraseña';

  @override
  String get saveNewPassword => 'Guardar nueva contraseña';

  @override
  String get passwordUpdated => 'Contraseña actualizada ✓';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';

  @override
  String get passwordWeak => 'Débil';

  @override
  String get passwordFair => 'Aceptable';

  @override
  String get passwordStrong => 'Fuerte';

  @override
  String get passwordMinLength =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get chooseStrongerPassword => 'Elige una contraseña más segura';

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get enterDisplayName => 'Introduce tu nombre visible';

  @override
  String get displayNameTooLong =>
      'El nombre visible debe tener 50 caracteres o menos';

  @override
  String get displayNameUnsupported =>
      'El nombre visible contiene caracteres no compatibles';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get displayName => 'Nombre visible';

  @override
  String get yourName => 'Tu nombre';

  @override
  String get profileUpdated => 'Perfil actualizado ✓';

  @override
  String get couldNotUpdateProfile =>
      'No se pudo actualizar tu perfil. Inténtalo de nuevo.';

  @override
  String get couldNotLoadProfile => 'No se pudo cargar tu perfil.';

  @override
  String get changeEmail => 'Cambiar correo';

  @override
  String get currentEmail => 'CORREO ACTUAL';

  @override
  String get newEmail => 'Nuevo correo';

  @override
  String get emailChangeHelp =>
      'Enviaremos un enlace de confirmación. Tu correo anterior seguirá activo hasta que confirmes.';

  @override
  String get checkYourInbox => 'Revisa tu bandeja de entrada';

  @override
  String emailConfirmationSent(String email) {
    return 'Enviamos un enlace de confirmación a\n$email. Tócalo para completar el cambio.';
  }

  @override
  String get enterNewEmail => 'Introduce tu nuevo correo';

  @override
  String get emailAlreadyUsed => 'Ese ya es tu correo';

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get currentPassword => 'Contraseña actual';

  @override
  String get enterCurrentPassword => 'Introduce tu contraseña actual';

  @override
  String get enterNewPassword => 'Introduce una contraseña nueva';

  @override
  String get confirmPassword => 'Confirma tu nueva contraseña';

  @override
  String get chooseDifferentPassword => 'Elige una contraseña diferente';

  @override
  String get passwordSignInUnavailable =>
      'El inicio de sesión con contraseña no está activado para esta cuenta.';

  @override
  String get privacy => 'Privacidad';

  @override
  String get typingIndicators => 'Indicadores de escritura';

  @override
  String get typingIndicatorsHelp =>
      'Si los desactivas, no verás cuándo escriben los demás y ellos tampoco verán cuándo escribes.';

  @override
  String get readReceipts => 'Confirmaciones de lectura';

  @override
  String get readReceiptsHelp =>
      'Si las desactivas, no verás las confirmaciones de los demás y ellos tampoco verán las tuyas.';

  @override
  String get couldNotSavePrivacy =>
      'No se pudo guardar la configuración de privacidad.';

  @override
  String get termsOfUse => 'Términos de uso';

  @override
  String get logOut => 'Cerrar sesión';

  @override
  String get logOutQuestion => '¿Cerrar sesión?';

  @override
  String get logOutHelp =>
      'Necesitarás tu correo y contraseña (o Google) para volver a entrar.';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountPermanent =>
      'Esto es permanente. Se eliminará lo siguiente:';

  @override
  String get allChatsMessages => 'Todos los chats y mensajes';

  @override
  String get yourProfile => 'Tu perfil';

  @override
  String get yourSettings => 'Tus ajustes y preferencias';

  @override
  String get confirmWithPassword => 'Confirmar con contraseña';

  @override
  String typeEmailToConfirm(String email) {
    return 'Escribe $email para confirmar';
  }

  @override
  String get deleteForever => 'Eliminar para siempre';

  @override
  String get enterPasswordToConfirm => 'Introduce tu contraseña para confirmar';

  @override
  String get emailDoesNotMatch => 'No coincide con tu correo';

  @override
  String get couldNotDeleteAccount =>
      'No se pudo eliminar tu cuenta. Inténtalo de nuevo.';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get noChatsYet => 'Aún no hay chats';

  @override
  String get inviteFriendStart => 'Invita a un amigo y empieza a chatear.';

  @override
  String get inviteFriend => 'Invitar a un amigo';

  @override
  String get couldNotLoadChats => 'No se pudieron cargar los chats';

  @override
  String get newConnectionSayHi => 'Nueva conexión · saluda';

  @override
  String get typing => 'escribiendo...';

  @override
  String get offline => 'Sin conexión';

  @override
  String get noConnection =>
      'Sin conexión — los mensajes se enviarán cuando vuelvas a conectarte';

  @override
  String get learningLanguage => 'Idioma de aprendizaje';

  @override
  String get learningLanguageHelp =>
      'Elige el idioma que quieres aprender en este chat. Puedes cambiarlo cuando quieras.';

  @override
  String get chatMenu => 'Menú del chat';

  @override
  String get normalMode => 'Normal';

  @override
  String get practiceMode => 'Práctica';

  @override
  String get translationLimitReached => 'Límite de traducción alcanzado';

  @override
  String get translationUnavailable => 'Traducción no disponible';

  @override
  String get correction => 'Corrección';

  @override
  String get possibleCorrection => 'Posible corrección';

  @override
  String get edited => 'editado';

  @override
  String get sending => 'Enviando';

  @override
  String get delivered => 'Entregado';

  @override
  String get read => 'Leído';

  @override
  String get failedToSend => 'No se pudo enviar. Toca para reintentar.';

  @override
  String get attach => 'Adjuntar';

  @override
  String get message => 'Mensaje';

  @override
  String get sayHi => 'Saluda';

  @override
  String replyingTo(Object name) {
    return 'Respondiendo a $name';
  }

  @override
  String get editingMessage => 'Editando mensaje';

  @override
  String get messageFailed => 'No se pudo enviar el mensaje';

  @override
  String get copied => 'Copiado';

  @override
  String get messageDeleted => 'Mensaje eliminado';

  @override
  String get thanksReport => 'Gracias — lo revisaremos.';

  @override
  String get couldNotReport =>
      'No se pudo enviar la denuncia. Inténtalo de nuevo.';

  @override
  String get couldNotSaveLearningLanguage =>
      'No se pudo guardar el idioma. Inténtalo de nuevo.';

  @override
  String get reportMessage => 'Denunciar mensaje';

  @override
  String get sendInvite => 'Enviar invitación';

  @override
  String get pickLanguage => 'Elige un idioma';

  @override
  String get pickLanguageHelp =>
      'Traduciremos todos los mensajes a este idioma. Puedes cambiarlo cuando quieras.';

  @override
  String get continueAction => 'Continuar';

  @override
  String get sendLinkHelp => 'Envía el enlace para empezar a chatear.';

  @override
  String get onePersonInvite => 'Solo una persona puede usar este enlace.';

  @override
  String get validFor48Hours => 'Válido durante 48 horas.';

  @override
  String get creatingLink => 'Creando enlace…';

  @override
  String get shareInvite => 'Compartir invitación';

  @override
  String get change => 'Cambiar';

  @override
  String get inviteSent => 'Invitación enviada ✓';

  @override
  String get couldNotCreateInvite =>
      'No se pudo crear la invitación. Inténtalo de nuevo.';

  @override
  String get shareInviteLink => 'Compartir enlace de invitación';

  @override
  String get more => 'Más';

  @override
  String get linkCopied => 'Enlace copiado';

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get pasteInChat => 'Ahora pégalo en un chat';

  @override
  String practicingLanguage(Object language) {
    return 'Estás practicando $language.';
  }

  @override
  String get shareYourInvite => 'Comparte tu enlace de invitación.';

  @override
  String validUntil(Object date) {
    return 'Válido hasta $date.';
  }

  @override
  String get inviteAlreadyClaimed => 'Esta invitación ya fue aceptada';

  @override
  String askForFreshLink(Object name) {
    return 'Pide a $name un enlace nuevo';
  }

  @override
  String get goToChats => 'Ir a los chats';

  @override
  String get inviteNotFound => 'No encontramos esa invitación.';

  @override
  String get checkInviteLink => 'Comprueba el enlace o pide uno nuevo.';

  @override
  String get sayHello => 'Di hola';

  @override
  String sayWord(Object word) {
    return 'Di $word';
  }

  @override
  String get aFriend => 'Un amigo';

  @override
  String get you => 'Tú';

  @override
  String get partner => 'Compañero';

  @override
  String get yourself => 'ti';

  @override
  String get couldNotEditMessage =>
      'No se pudo editar el mensaje. Inténtalo de nuevo.';

  @override
  String get today => 'Hoy';

  @override
  String get yesterday => 'Ayer';

  @override
  String get now => 'Ahora';

  @override
  String get newLabel => 'Nuevo';

  @override
  String get invitedYouToChat => 'te invitó a chatear';

  @override
  String joinPerson(Object name) {
    return 'Unirse a $name';
  }

  @override
  String get inviteExpired => 'Esta invitación caducó';

  @override
  String get alreadyConnected =>
      'Ya estáis conectados. Abre el chat para empezar.';

  @override
  String get openChat => 'Abrir chat';

  @override
  String get yourInviteExpired => 'Tu invitación caducó.';

  @override
  String get inviteExpiredHelp =>
      'Nadie se unió en 48 horas. Envía un enlace nuevo.';

  @override
  String get sendNewInvite => 'Enviar nueva invitación';

  @override
  String youLearnLanguage(Object language) {
    return 'Aprendes $language';
  }

  @override
  String personLearnsLanguage(Object language, Object name) {
    return '$name aprende $language';
  }

  @override
  String youAreLearningLanguageWithPerson(Object language, Object name) {
    return 'Estás aprendiendo $language con $name';
  }

  @override
  String get sendAnyMessage => 'Envía un mensaje para empezar.';

  @override
  String get languages => 'Idiomas';

  @override
  String speaksNatively(Object language) {
    return 'Habla $language de forma nativa';
  }

  @override
  String learningWithYou(Object language) {
    return 'Aprende $language contigo';
  }

  @override
  String get chat => 'Chat';

  @override
  String get startedJustNow => 'Empezasteis a chatear ahora';

  @override
  String startedMinutesAgo(Object count) {
    return 'Empezasteis a chatear hace $count min';
  }

  @override
  String startedHoursAgo(Object count) {
    return 'Empezasteis a chatear hace $count h';
  }

  @override
  String startedDaysAgo(Object count) {
    return 'Empezasteis a chatear hace $count d';
  }

  @override
  String startedMonthsAgo(Object count) {
    return 'Empezasteis a chatear hace $count meses';
  }

  @override
  String get safety => 'Seguridad';

  @override
  String reportPerson(Object name) {
    return 'Denunciar a $name';
  }

  @override
  String blockPerson(Object name) {
    return 'Bloquear a $name';
  }

  @override
  String unblockPerson(Object name) {
    return 'Desbloquear a $name';
  }

  @override
  String personBlocked(Object name) {
    return '$name bloqueado';
  }

  @override
  String personUnblocked(Object name) {
    return '$name desbloqueado';
  }

  @override
  String get couldNotBlock => 'No se pudo bloquear. Inténtalo de nuevo.';

  @override
  String get couldNotUnblock => 'No se pudo desbloquear. Inténtalo de nuevo.';

  @override
  String get reportSpam => 'Spam o estafa';

  @override
  String get reportHarassment => 'Acoso o intimidación';

  @override
  String get reportHate => 'Discurso de odio';

  @override
  String get reportSexual => 'Contenido sexual o inapropiado';

  @override
  String get reportChildSafety => 'Seguridad infantil';

  @override
  String get reportOther => 'Otro motivo';

  @override
  String get inviteClaimExpired => 'Esta invitación ha caducado.';

  @override
  String get inviteClaimUsed => 'Esta invitación ya se ha usado.';

  @override
  String get inviteClaimInvalid => 'Esta invitación no es válida.';

  @override
  String get inviteClaimFailed =>
      'No se pudo aceptar la invitación. Inténtalo de nuevo.';

  @override
  String get appleSignInSoon =>
      'El inicio de sesión con Apple estará disponible pronto';

  @override
  String get invalidCredentials => 'El correo o la contraseña son incorrectos';

  @override
  String get accountAlreadyExists => 'Ya existe una cuenta con este correo';

  @override
  String get confirmEmailInbox =>
      'Revisa tu correo para confirmar la dirección';

  @override
  String get somethingWentWrong => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get currentPasswordIncorrect => 'La contraseña actual es incorrecta';

  @override
  String get signInAgain =>
      'Vuelve a iniciar sesión antes de cambiar la contraseña';

  @override
  String get tooManyAttempts => 'Demasiados intentos. Inténtalo más tarde.';

  @override
  String get couldNotUpdatePassword =>
      'No se pudo actualizar la contraseña. Inténtalo de nuevo.';

  @override
  String get emailChanged => 'Correo cambiado';

  @override
  String get someoneJoined => 'Alguien se unió.';

  @override
  String personJoined(Object name) {
    return '$name se unió.';
  }

  @override
  String get notifications => 'Notificaciones';

  @override
  String get showMessagePreviews => 'Mostrar vista previa';

  @override
  String get showMessagePreviewsHelp =>
      'Muestra el remitente y el mensaje original en las notificaciones.';

  @override
  String get androidNotificationSettings =>
      'Ajustes de notificaciones de Android';

  @override
  String get notificationsEnabled => 'Las notificaciones están activadas';

  @override
  String get notificationsDisabled => 'Las notificaciones están desactivadas';

  @override
  String get notificationsNotRequested =>
      'Abre un chat para activar las notificaciones';

  @override
  String get notificationsUnavailable =>
      'Las notificaciones no están disponibles en esta versión';

  @override
  String get couldNotSaveNotifications =>
      'No se pudo guardar el ajuste de notificaciones.';

  @override
  String get enableNotificationsReminder =>
      'Activa las notificaciones para recibir mensajes de tu compañero';

  @override
  String get dismiss => 'Cerrar';

  @override
  String get photos => 'Fotos';

  @override
  String get photoAccessNeeded => 'Se necesita acceso a las fotos';

  @override
  String get photoAccessNeededBody =>
      'Permite el acceso a tus fotos para compartir una en el chat.';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get noPhotosFound => 'Todavía no hay fotos';

  @override
  String get photoMessagePreview => 'Foto';

  @override
  String get searchEmoji => 'Buscar emoji';

  @override
  String reactionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reacciones',
      one: '$count reacción',
    );
    return '$_temp0';
  }

  @override
  String get tapToRemove => 'Toca para quitar';
}
