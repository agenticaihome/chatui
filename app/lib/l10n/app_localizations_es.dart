// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Chatui';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonRemove => 'Quitar';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonCopy => 'Copiar';

  @override
  String get commonCopyId => 'Copiar ID';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonName => 'Nombre';

  @override
  String get commonAddress => 'Dirección';

  @override
  String get commonAddresses => 'Direcciones';

  @override
  String get commonAddressCopied => 'Dirección copiada';

  @override
  String get commonMinerFee => 'Comisión de minería';

  @override
  String get commonWallet => 'Billetera';

  @override
  String get commonThisWallet => 'Esta billetera';

  @override
  String get commonToken => 'Token';

  @override
  String get commonTokens => 'Tokens';

  @override
  String get commonContacts => 'Contactos';

  @override
  String get commonSettings => 'Ajustes';

  @override
  String get commonPending => 'Pendiente';

  @override
  String get commonOffline => 'Sin conexión';

  @override
  String get commonBalanceUnavailable => 'Saldo no disponible';

  @override
  String get commonNotAnErgoAddress => 'No es una dirección de Ergo';

  @override
  String get monthShort1 => 'ene';

  @override
  String get monthShort2 => 'feb';

  @override
  String get monthShort3 => 'mar';

  @override
  String get monthShort4 => 'abr';

  @override
  String get monthShort5 => 'may';

  @override
  String get monthShort6 => 'jun';

  @override
  String get monthShort7 => 'jul';

  @override
  String get monthShort8 => 'ago';

  @override
  String get monthShort9 => 'sept';

  @override
  String get monthShort10 => 'oct';

  @override
  String get monthShort11 => 'nov';

  @override
  String get monthShort12 => 'dic';

  @override
  String clockTime(
    String hour12,
    String hour24,
    String minute,
    String space,
    String period,
  ) {
    return '$hour24:$minute';
  }

  @override
  String get clockAm => 'a. m.';

  @override
  String get clockPm => 'p. m.';

  @override
  String dateMonthDay(String month, String day) {
    return '$day $month';
  }

  @override
  String dateMonthDayYear(String month, String day, String year) {
    return '$day $month $year';
  }

  @override
  String dateMonthDayTime(String month, String day, String time) {
    return '$day $month, $time';
  }

  @override
  String dateDayMonthYear(String month, String day, String year) {
    return '$day $month $year';
  }

  @override
  String dateNumeric(String month, String day, String year) {
    return '$day/$month/$year';
  }

  @override
  String timeToday(String time) {
    return 'Hoy, $time';
  }

  @override
  String timeYesterdayAt(String time) {
    return 'Ayer, $time';
  }

  @override
  String get timeYesterday => 'Ayer';

  @override
  String get timeJustNow => 'Ahora mismo';

  @override
  String timeSecondsAgo(int count) {
    return 'hace $count s';
  }

  @override
  String timeMinutesAgo(int count) {
    return 'hace $count min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'hace $count h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'hace $count días';
  }

  @override
  String get syncAgeJustNow => 'ahora mismo';

  @override
  String syncAgeMinutes(int count) {
    return 'hace $count min';
  }

  @override
  String syncAgeHours(int count) {
    return 'hace $count h';
  }

  @override
  String syncAgeDays(int count) {
    return 'hace $count d';
  }

  @override
  String get dateUnknownDay => 'Día desconocido';

  @override
  String get celautNodeRowTitle => 'Nodo Celaut';

  @override
  String get celautNodeRowSubtitle =>
      'Conéctate a un nodo y muestra su anuncio';

  @override
  String get celautScreenTitle => 'Nodo Celaut';

  @override
  String get celautIntro =>
      'Conéctate a un nodo Celaut y comprueba quién es. La app comprueba la identidad de su certificado y la firma de su anuncio. No se inicia nada y no se paga nada.';

  @override
  String get celautAddressLabel => 'Dirección del nodo';

  @override
  String get celautAddressHint => 'host:puerto';

  @override
  String get celautExpectedLabel => 'ID de par esperado (opcional)';

  @override
  String get celautExpectedHint => '64 caracteres hexadecimales';

  @override
  String get celautConnect => 'Conectar';

  @override
  String get celautConnecting => 'Conectando…';

  @override
  String get celautIdentityTitle => 'Identidad';

  @override
  String get celautPeerIdLabel => 'ID de par';

  @override
  String get celautAdvertisedLabel => 'Anunciado el';

  @override
  String get celautUrisTitle => 'Direcciones';

  @override
  String get celautRatesTitle => 'Tarifas';

  @override
  String get celautContractsTitle => 'Contratos de pago';

  @override
  String get celautResourcesTitle => 'Recursos';

  @override
  String get celautProofsLabel => 'Pruebas de reputación';

  @override
  String get celautNoUris => 'El nodo no anuncia ninguna dirección.';

  @override
  String get celautNoRates => 'El nodo no anuncia tarifas.';

  @override
  String get celautNoContracts =>
      'El nodo no anuncia ningún contrato de pago. Todavía no se le puede pagar.';

  @override
  String get celautNoResources => 'El nodo no da datos sobre sus recursos.';

  @override
  String get celautRatesNote => 'Las tarifas están en MU.';

  @override
  String get celautVerifiedNote =>
      'Se comprobaron el certificado y la firma. Este nodo es quien dice ser.';

  @override
  String get celautAddressEmpty =>
      'Escribe la dirección del nodo como host:puerto.';

  @override
  String get celautAddressInvalid =>
      'Esta dirección no es válida. Usa host:puerto, por ejemplo 203.0.113.7:8090.';

  @override
  String get celautPortInvalid =>
      'El puerto debe ser un número del 1 al 65535.';

  @override
  String get celautExpectedInvalid =>
      'El ID de par debe tener 64 caracteres hexadecimales o estar vacío.';

  @override
  String get celautErrorTitle => 'No se puede mostrar este nodo';

  @override
  String get celautErrorInvalidInput =>
      'La dirección no es válida. Comprueba el host y el puerto.';

  @override
  String get celautErrorUnreachable =>
      'La app no puede conectarse a esta dirección. Comprueba la dirección y la red, y que el nodo esté en marcha.';

  @override
  String get celautErrorTimeout =>
      'El nodo no respondió a tiempo. Vuelve a intentarlo o comprueba la dirección.';

  @override
  String get celautErrorIdentityMismatch =>
      'La identidad de este nodo no es la esperada. Puede que la dirección pertenezca ahora a otro nodo. La app no confió en él.';

  @override
  String get celautErrorBadCertificate =>
      'El certificado de este servidor no tiene una identidad Celaut válida. Puede que no sea un nodo Celaut. La app no confió en él.';

  @override
  String get celautErrorBadSignature =>
      'La firma del anuncio del nodo no es válida. La app no confió en él.';

  @override
  String get celautErrorStaleTimestamp =>
      'Este anuncio es más antiguo que otro que la app ya aceptó. Puede que alguien esté reenviando un mensaje antiguo. La app no confió en él.';

  @override
  String get celautErrorUnsupportedScheme =>
      'El nodo firma con un esquema que esta app no admite.';

  @override
  String get celautErrorProofOfWork =>
      'El nodo pide más trabajo del que la app hace para un cliente nuevo, o no aceptó el trabajo.';

  @override
  String get celautErrorProtocol =>
      'El nodo rechazó la solicitud o envió una respuesta que la app no puede usar.';

  @override
  String get celautErrorStorage =>
      'La app no puede leer ni escribir su lista de anuncios conocidos.';

  @override
  String get celautErrorLimitReached =>
      'Este depósito supera el límite que pusiste para este nodo.';

  @override
  String get celautErrorWallet =>
      'La billetera no puede crear esta transacción. Comprueba el saldo y la red.';

  @override
  String celautDetailLabel(String detail) {
    return 'Detalle: $detail';
  }

  @override
  String celautCores(int count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$value núcleos',
      one: '$value núcleo',
    );
    return '$_temp0';
  }

  @override
  String get celautMemoryLabel => 'Memoria';

  @override
  String get celautDiskLabel => 'Disco';

  @override
  String get celautCpuLabel => 'CPU';

  @override
  String get celautBenchmarkLabel => 'Prueba de rendimiento';

  @override
  String get celautNoExpiry => 'sin fecha de caducidad';

  @override
  String celautExpires(String when) {
    return 'válido hasta $when';
  }

  @override
  String celautPerUnit(String mu) {
    return '$mu MU por unidad base';
  }

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String get securityTitle => 'Seguridad';

  @override
  String get networkTitle => 'Red';

  @override
  String get displayTitle => 'Pantalla';

  @override
  String get chatSettingsTitle => 'Chat';

  @override
  String get chatSettingsRowSubtitle =>
      'Tamaño de letra, fuente, mensajes fijados, widgets';

  @override
  String get chatSettingsTextGroup => 'Texto';

  @override
  String get chatSettingsFontSize => 'Tamaño de letra';

  @override
  String get chatSettingsFontFamily => 'Fuente';

  @override
  String get chatSettingsPreview =>
      'Así se ve la respuesta del asistente. Elige el tamaño con el que lees mejor.';

  @override
  String get chatFontSystem => 'Sistema';

  @override
  String get chatFontLato => 'Lato';

  @override
  String get chatFontSerif => 'Serif';

  @override
  String get chatFontMono => 'Monoespaciada';

  @override
  String get chatSettingsPinnedGroup => 'Mensajes fijados';

  @override
  String get chatSettingsPinnedMax => 'Altura máxima de un mensaje fijado';

  @override
  String get chatSettingsPinnedNote =>
      'Un mensaje fijado se queda arriba del chat. Ocupa como máximo esta parte de la altura del chat.';

  @override
  String get chatSettingsWidgetsGroup => 'Widgets';

  @override
  String get chatHtmlLoading => 'Creando el widget…';

  @override
  String get chatKeyboardLabel => 'Teclado';

  @override
  String get chatKeyboardClose => 'Cerrar el teclado';

  @override
  String get chatSettingsHtmlWidgets => 'Widgets HTML';

  @override
  String get chatSettingsHtmlWidgetsSubtitle =>
      'Muestra el HTML simple del asistente como widgets. Si está apagado, se ve como código. Sin scripts ni red.';

  @override
  String get chatSettingsKeyboardGroup => 'Teclado';

  @override
  String get chatSettingsSystemKeyboard => 'Usar el teclado del sistema';

  @override
  String get chatSettingsSystemKeyboardSubtitle =>
      'Si está apagado, el chat escribe con el teclado de la app, debajo del input. Si está encendido, se muestra el del sistema, salvo mientras hay un formulario.';

  @override
  String get chatSettingsWordSuggestions => 'Sugerencias de palabras';

  @override
  String get chatSettingsWordSuggestionsSubtitle =>
      'El teclado de la app muestra palabras que completan o corrigen la palabra que escribes, con las palabras de la conversación. Nunca cambia una palabra por sí solo. Las respuestas que sugiere el servicio se muestran igual.';

  @override
  String get chatSuggestionsLabel => 'Sugerencias';

  @override
  String get chatVkBackspace => 'Borrar';

  @override
  String get chatVkShift => 'Mayúscula';

  @override
  String get chatVkSymbols => 'Números y símbolos';

  @override
  String get chatVkLetters => 'Letras';

  @override
  String get chatVkSpace => 'Espacio';

  @override
  String get chatVkEnter => 'Nueva línea';

  @override
  String get chatBgNone => 'Ninguno';

  @override
  String get chatBgDawn => 'Amanecer';

  @override
  String get chatBgOcean => 'Océano';

  @override
  String get chatBgForest => 'Bosque';

  @override
  String get chatBgDusk => 'Atardecer';

  @override
  String get chatBgDots => 'Puntos';

  @override
  String get chatBgWaves => 'Ondas';

  @override
  String get chatBgDiamonds => 'Rombos';

  @override
  String get addressBookTitle => 'Libreta de direcciones';

  @override
  String get settingsAboutRowTitle => 'Acerca de Chatui';

  @override
  String get settingsAboutRowSubtitle =>
      'Versión, notas de la versión, licencias';

  @override
  String get settingsWalletRowTitle => 'Direcciones y copia de seguridad';

  @override
  String get settingsWalletRowSubtitle =>
      'Dirección principal, política de cambio, quitar';

  @override
  String get settingsSecurityWalletSubtitle =>
      'Desbloqueo del móvil, bloqueo automático';

  @override
  String get settingsErgoGroup => 'Ergo';

  @override
  String get settingsComputeGroup => 'Cómputo';

  @override
  String get settingsGeneralGroup => 'General';

  @override
  String get settingsScopeAppWide => 'Toda la app';

  @override
  String get settingsSecurityAppSubtitle =>
      'Bloqueo automático, capturas de pantalla, fondos sin confirmar';

  @override
  String get settingsRemotePreviewsTitle => 'Vistas previas remotas';

  @override
  String get settingsRemotePreviewsSubtitle =>
      'Pasarela IPFS y No cargar nunca vistas previas remotas';

  @override
  String settingsContactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contactos',
      one: '$count contacto',
    );
    return '$_temp0';
  }

  @override
  String get settingsUnlocked => 'Desbloqueada';

  @override
  String get settingsLocked => 'Bloqueada';

  @override
  String get aboutSaveSettingFailed => 'No se pudo guardar el ajuste.';

  @override
  String get aboutAskingGithub => 'Consultando a GitHub…';

  @override
  String get aboutNotCheckedYet => 'Aún no se ha comprobado';

  @override
  String aboutUpToDateChecked(String when) {
    return 'Al día · comprobado $when';
  }

  @override
  String aboutVersionAvailableChecked(String version, String when) {
    return 'La versión $version está disponible · comprobado $when';
  }

  @override
  String aboutVersionBuild(String version, String build) {
    return '$version · compilación $build';
  }

  @override
  String get aboutUpdatesGroup => 'Actualizaciones';

  @override
  String get aboutCheckForUpdates => 'Buscar actualizaciones';

  @override
  String get aboutCheckForUpdatesSubtitle =>
      'Consulta a GitHub una vez al día. GitHub ve tu dirección IP, o una salida de Tor si Tor está activado.';

  @override
  String get aboutCheckNow => 'Comprobar ahora';

  @override
  String get aboutUpdatesNote =>
      'Desactivado por defecto. Si está activado, Chatui pide a api.github.com la última versión una vez al día al iniciarse. \"Comprobar ahora\" hace lo mismo cuando lo pides, aunque esto esté desactivado. No se envía nada más: ni cuenta, ni token, ni versión de la app, ni identificador del dispositivo. Una descarga viene de github.com y se comprueba con la clave de firma de esta app antes de pedir a Android que la instale.';

  @override
  String get aboutThisBuild => 'Esta compilación';

  @override
  String get aboutUnauditedTitle => 'Prototipo sin auditar';

  @override
  String get aboutUnauditedSubtitle =>
      'Las transacciones en Ergo son irreversibles. Usa solo fondos que puedas permitirte perder.';

  @override
  String get aboutReleasesTitle => 'Versiones y notas';

  @override
  String get aboutReleasesSubtitle =>
      'Qué cambió en cada alfa, y el APK más reciente.';

  @override
  String get aboutLicenses => 'Licencias de código abierto';

  @override
  String get aboutLightClientNote =>
      'Chatui es un cliente ligero: habla con nodos públicos de Ergo por HTTPS y nunca envía tus claves a ningún sitio.';

  @override
  String get aboutSigningCertificate => 'Certificado de firma';

  @override
  String get aboutSigningCertificateSubtitle =>
      'SHA-256 de la clave con la que está firmada esta compilación. Una actualización debe estar firmada con la misma.';

  @override
  String get aboutReading => 'Leyendo…';

  @override
  String get aboutNotAvailableOnDevice => 'No disponible en este dispositivo.';

  @override
  String get aboutFingerprintCopied => 'Huella copiada';

  @override
  String get addressBookContactsEmpty =>
      'Personas a las que envías. Guarda una desde la pantalla Enviar.';

  @override
  String addressBookContactsSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guardados',
      one: '$count guardado',
    );
    return '$_temp0';
  }

  @override
  String get addressBookLabelsSection => 'Etiquetas de mis direcciones';

  @override
  String get addressBookNoLabelsTitle => 'Aún no hay etiquetas';

  @override
  String get addressBookNoLabelsBody =>
      'Toca cualquiera de tus direcciones en la pantalla de inicio o en Recibir para ponerle nombre.';

  @override
  String get addressBookRemoveLabel => 'Quitar etiqueta';

  @override
  String get displayAppearance => 'Apariencia';

  @override
  String get displayFollowSystem => 'Seguir el sistema';

  @override
  String get displayAlwaysDark => 'Siempre oscuro';

  @override
  String get displayAlwaysLight => 'Siempre claro';

  @override
  String displaySystemPalettes(String dark, String light) {
    return 'Oscuro → $dark, claro → $light';
  }

  @override
  String get displayDarkPalette => 'Paleta oscura';

  @override
  String get displayLightPalette => 'Paleta clara';

  @override
  String get displayMoney => 'Dinero';

  @override
  String get displayPricesInUsd => 'Precios en USD';

  @override
  String get displayHideBalances => 'Ocultar saldos';

  @override
  String get displayHideBalancesSubtitle =>
      'Oculta las cantidades en la pantalla de inicio';

  @override
  String get displayVehicleMotionCues => 'Señales de movimiento del vehículo';

  @override
  String get displayVehicleMotionCuesNote =>
      'Unos puntos a los lados de la pantalla se mueven con el vehículo, para que leer en un viaje te maree menos.';

  @override
  String get displayMotionCuesOff => 'Apagadas';

  @override
  String get displayMotionCuesAutomatic => 'Automáticas';

  @override
  String get displayMotionCuesAutomaticSubtitle =>
      'Cuando el teléfono nota que vas en un vehículo';

  @override
  String get displayMotionCuesAlways => 'Siempre';

  @override
  String get displayMotionCuesAlwaysSubtitle => 'Todo el tiempo';

  @override
  String get displayMotionCuesGps => 'Usar la velocidad del GPS';

  @override
  String get displayMotionCuesGpsSubtitle =>
      'Distingue mejor un vehículo de un paseo. Necesita la ubicación precisa; la app no guarda ninguna posición ni la envía';

  @override
  String get displayMotionCuesGpsDenied =>
      'Sin la ubicación precisa la app no puede leer la velocidad del GPS';

  @override
  String get themeTealName => 'Celaut Turquesa';

  @override
  String get themeTealHint => 'Turquesa, texto crema, coral';

  @override
  String get themeCreamName => 'Celaut Crema';

  @override
  String get themeCreamHint => 'Crema, texto turquesa, coral';

  @override
  String get themeObsidianName => 'Obsidiana';

  @override
  String get themeObsidianHint => 'Negro puro, acento acero';

  @override
  String get themeHarborName => 'Puerto';

  @override
  String get themeHarborHint => 'Azul marino oscuro, acento turquesa';

  @override
  String get themeEmberName => 'Brasa';

  @override
  String get themeEmberHint => 'Carbón cálido, acento cobre';

  @override
  String get themeParchmentName => 'Pergamino';

  @override
  String get themeParchmentHint => 'Crema, acento salvia';

  @override
  String get themeFrostName => 'Escarcha';

  @override
  String get themeFrostHint => 'Blanco frío, acento azul pizarra';

  @override
  String get themeCyberpunkName => 'Cyberpunk';

  @override
  String get themeCyberpunkHint => 'Violeta nocturno, rosa neón';

  @override
  String get themeAppleLightName => 'Apple claro';

  @override
  String get themeAppleLightHint => 'Blanco limpio, azul del sistema';

  @override
  String get themeAppleDarkName => 'Apple oscuro';

  @override
  String get themeAppleDarkHint => 'Negro puro, azul del sistema';

  @override
  String get themeMaterialLightName => 'Material claro';

  @override
  String get themeMaterialLightHint => 'Lila suave, morado Material';

  @override
  String get themeMaterialDarkName => 'Material oscuro';

  @override
  String get themeMaterialDarkHint => 'Gris oscuro, acento lila';

  @override
  String get themeNordName => 'Nord';

  @override
  String get themeNordHint => 'Pizarra ártica, azul hielo';

  @override
  String get themeSolarizedName => 'Solarized';

  @override
  String get themeSolarizedHint => 'Papel cálido, acento azul';

  @override
  String get themeDraculaName => 'Drácula';

  @override
  String get themeDraculaHint => 'Índigo profundo, acento morado';

  @override
  String get networkConnectedNode => 'Nodo conectado';

  @override
  String get networkChecking => 'Comprobando…';

  @override
  String get networkCheckNodes => 'Comprobar nodos';

  @override
  String get networkNodes => 'Nodos';

  @override
  String get networkAddNodeLabel => 'Añadir URL de nodo';

  @override
  String get networkAddNodeHint => 'https://host  o  1.2.3.4:9053';

  @override
  String get networkAdd => 'Añadir';

  @override
  String get networkNodesNote =>
      'Toca un nodo para usarlo. Automático elige el nodo accesible con extraIndex y el menor retraso de índice. Los nodos integrados usan HTTPS; puedes añadir http://ip:port para un nodo que ejecutas o en el que confías, sin cifrar.';

  @override
  String get networkFindMoreNodes => 'Buscar más nodos';

  @override
  String get networkDiscovering =>
      'Pidiendo sus pares a cada nodo y comprobando cada uno…';

  @override
  String get networkDiscoverIntro =>
      'Pares de tus nodos que publican una API HTTPS.';

  @override
  String get networkSearching => 'Buscando…';

  @override
  String get networkSearch => 'Buscar';

  @override
  String get networkOpenInExplorer => 'Abrir en el explorador';

  @override
  String get networkCustom => 'Personalizado';

  @override
  String get networkCustomSiteSubtitle =>
      'Un sitio web que usa las rutas del explorador de Ergo Platform';

  @override
  String get networkExplorerWebsite => 'Sitio web del explorador';

  @override
  String get networkExplorerSiteNote =>
      'Dónde se abren los enlaces de transacciones y tokens. Esto no cambia ningún dato que lee la billetera.';

  @override
  String get networkExplorerApi => 'API del explorador';

  @override
  String get networkCustomApiSubtitle =>
      'Cualquier servidor que hable la API del explorador de Ergo Platform';

  @override
  String get networkExplorerApiUrl => 'URL de la API del explorador';

  @override
  String get networkExplorerApiNote =>
      'La fuente de los metadatos de tokens cuando los nodos no los tienen. ErgExplorer y Kadia usan sus propias API, así que no se pueden elegir aquí.';

  @override
  String get networkAutomatic => 'Automático';

  @override
  String get networkBestReachable => 'El mejor nodo accesible con extraIndex';

  @override
  String networkUsingHost(String host) {
    return 'Usando $host';
  }

  @override
  String networkExtraIndexLag(String lag) {
    return 'extraIndex, retraso $lag';
  }

  @override
  String get networkNoExtraIndex => 'sin extraIndex';

  @override
  String get networkDisable => 'Desactivar';

  @override
  String get networkEnable => 'Activar';

  @override
  String get networkNodeOff => 'Desactivado';

  @override
  String get networkNodeInUse => 'En uso';

  @override
  String get networkNodeStandby => 'En espera';

  @override
  String get networkNodeChosen => 'elegido';

  @override
  String get networkNodeUnreachable => 'inaccesible';

  @override
  String get networkAddNodeInvalid => 'Escribe https://host o http://ip:port';

  @override
  String get networkNodeAlreadyAdded => 'Este nodo ya está añadido';

  @override
  String get networkSearchNoAnswer =>
      'Ningún nodo respondió a la petición de pares. Comprueba tu conexión o prueba con otro nodo.';

  @override
  String networkSearchNoNewApi(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se preguntó a $count nodos: sus pares no publican ninguna API HTTPS que no tengas ya.',
      one:
          'Se preguntó a $count nodo: sus pares no publican ninguna API HTTPS que no tengas ya.',
    );
    return '$_temp0';
  }

  @override
  String networkSearchNoneReachable(String found) {
    return 'Encontrados y comprobados: $found. Ninguno es accesible ahora.';
  }

  @override
  String networkSearchNoneReachablePartial(String checked, String found) {
    return 'Encontrados: $found; comprobados: $checked. Ninguno es accesible ahora.';
  }

  @override
  String networkSearchReachable(String reachable, String found) {
    return 'Encontrados: $found; accesibles: $reachable, primero los mejores.';
  }

  @override
  String networkSearchReachablePartial(
    String reachable,
    String checked,
    String found,
  ) {
    return 'Encontrados: $found; comprobados: $checked; accesibles: $reachable, primero los mejores.';
  }

  @override
  String get pinHelper => '6–32 caracteres. Primero el teclado numérico.';

  @override
  String get pinConfirm => 'Confirmar PIN';

  @override
  String get pinMismatch => 'Los PIN no coinciden';

  @override
  String get pinIncorrect => 'PIN incorrecto';

  @override
  String get securityBiometricDisabled => 'Desbloqueo biométrico desactivado';

  @override
  String get securityBiometricDisableFailed =>
      'No se pudo desactivar la biometría';

  @override
  String get securityPinLockoutCheckFailed =>
      'No se pudo comprobar el bloqueo del PIN';

  @override
  String get securityNoPinWalletFound =>
      'No se encontró ninguna billetera protegida con PIN.';

  @override
  String get securityBiometricEnabled => 'Desbloqueo biométrico activado';

  @override
  String get securityBiometricEnableFailed => 'No se pudo activar la biometría';

  @override
  String get securityChangePin => 'Cambiar PIN';

  @override
  String get securityNewPin => 'PIN nuevo';

  @override
  String get securityChange => 'Cambiar';

  @override
  String get securityNoPinWallet =>
      'No se encontró ninguna billetera protegida con PIN';

  @override
  String get securityPinChanged => 'PIN cambiado';

  @override
  String get securityPinChangedLockoutNotReset =>
      'PIN cambiado, pero no se pudo restablecer el estado de bloqueo';

  @override
  String get securityChangePinFailed => 'No se pudo cambiar el PIN';

  @override
  String get securityLockImmediately => 'Inmediatamente';

  @override
  String securityLockAfterSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tras $count segundos',
      one: 'Tras $count segundo',
    );
    return '$_temp0';
  }

  @override
  String securityLockAfterMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tras $count minutos',
      one: 'Tras $count minuto',
    );
    return '$_temp0';
  }

  @override
  String get securityLockWhenBackgrounded => 'Bloquear en segundo plano';

  @override
  String get securityAutoLockUpdateFailed =>
      'No se pudo actualizar el bloqueo automático';

  @override
  String get securityAutoLock => 'Bloqueo automático';

  @override
  String get securityUnlockGroup => 'Desbloqueo';

  @override
  String get securityUnlockFirst => 'Primero desbloquea la billetera';

  @override
  String get securityUnlockFirstSubtitle =>
      'Los ajustes de biometría y PIN necesitan una billetera desbloqueada.';

  @override
  String get securityRetryUnlockSettings => 'Reintentar ajustes de desbloqueo';

  @override
  String get securityReadSetupFailed =>
      'No se pudo leer la configuración actual.';

  @override
  String get securityBiometricUnlock => 'Desbloqueo con el móvil';

  @override
  String get securityBiometricOn => 'Huella o bloqueo de pantalla';

  @override
  String get securityOff => 'Desactivado';

  @override
  String get securitySetPinHint =>
      'Establece un PIN al crear o restaurar una billetera.';

  @override
  String get securityDeviceLockNote =>
      'La cartera se abre con tu huella o con el bloqueo de pantalla del móvil. La app no tiene un PIN propio.';

  @override
  String get securityScreen => 'Pantalla';

  @override
  String get securityBlockScreenshots => 'Bloquear capturas de pantalla';

  @override
  String get securityScreenshotsBlocked =>
      'No se pueden capturar ni grabar las pantallas';

  @override
  String get securityScreenshotsAllowed =>
      'Desactivado: puedes capturar pantallas para informar de problemas';

  @override
  String get securitySeedScreensNote =>
      'Las pantallas de la frase de recuperación siempre bloquean las capturas, diga lo que diga este ajuste.';

  @override
  String get securitySpending => 'Gastos';

  @override
  String get securitySpendUnconfirmed => 'Gastar fondos sin confirmar';

  @override
  String get securitySpendUnconfirmedOn =>
      'Activado: los fondos recibidos y el cambio se pueden gastar al momento';

  @override
  String get securitySpendUnconfirmedOff =>
      'Desactivado: los fondos recibidos y el cambio esperan 1 confirmación';

  @override
  String get securitySpendingSaveFailed =>
      'No se pudo guardar el ajuste de gastos';

  @override
  String get updateAvailableTitle => 'Actualización disponible';

  @override
  String updateCardVersion(String version) {
    return 'Chatui $version';
  }

  @override
  String updateCardVersionDate(String version, String date) {
    return 'Chatui $version · $date';
  }

  @override
  String get updateHideNotes => 'Ocultar notas de la versión';

  @override
  String get updateReleaseNotes => 'Notas de la versión';

  @override
  String get updateDownloadProgress => 'Progreso de la descarga';

  @override
  String get updateDownloading => 'Descargando…';

  @override
  String updateDownloadingOf(String done, String total) {
    return 'Descargando $done de $total';
  }

  @override
  String get updateCheckingDownload => 'Comprobando la descarga';

  @override
  String get updateCheckingAgainstKey =>
      'Comprobando la descarga con la clave de firma de esta app…';

  @override
  String get updateCertMatches =>
      'El certificado de firma coincide con el de esta app.';

  @override
  String updateCertMatchesWith(String fingerprint) {
    return 'El certificado de firma coincide con el de esta app (SHA-256 $fingerprint…).';
  }

  @override
  String get updateAndroidChecksSignature =>
      'Android comprueba la firma por sí mismo al instalar.';

  @override
  String get updateInstall => 'Instalar';

  @override
  String get updateTryAgain => 'Volver a intentarlo';

  @override
  String get updateDownloadAndVerify => 'Descargar y verificar';

  @override
  String updateAssetNote(String name, String size) {
    return '$name · $size. Antes de instalar nada, Chatui comprueba el archivo con la suma de verificación que indica GitHub y con la clave con la que está firmada esta app.';
  }

  @override
  String get updateOpenReleasesPage => 'Abrir la página de versiones';

  @override
  String get updateNoApkForPhone =>
      'Esta versión no tiene APK para tu teléfono.';

  @override
  String updateNoticeAvailable(String version) {
    return 'Chatui $version está disponible.';
  }

  @override
  String get updateNoticeView => 'Ver';

  @override
  String get updateNoticeDismiss => 'Descartar';

  @override
  String get updateErrorTimeout => 'GitHub no respondió a tiempo.';

  @override
  String get updateErrorUnreachable =>
      'No se pudo conectar con GitHub. Comprueba tu conexión.';

  @override
  String get updateErrorRouteBlocked =>
      'Tor está activado y no está listo, así que la app no se conecta a GitHub. Inténtalo de nuevo cuando Tor esté listo (Ajustes, Desarrollador, Tor).';

  @override
  String updateErrorStatus(String status) {
    return 'GitHub respondió con un error ($status).';
  }

  @override
  String get updateErrorBadRedirect =>
      'GitHub envió una redirección que no se entendió.';

  @override
  String get updateErrorRedirectedAway =>
      'La solicitud se redirigió fuera de GitHub, así que se detuvo.';

  @override
  String get updateErrorTooManyRedirects =>
      'GitHub redirigió la solicitud demasiadas veces.';

  @override
  String get updateErrorRateLimited =>
      'GitHub está limitando las solicitudes desde esta red. Vuelve a intentarlo más tarde.';

  @override
  String get updateErrorNoRelease =>
      'GitHub no tiene ninguna versión que ofrecer.';

  @override
  String get updateErrorNotUnderstood =>
      'No se entendió la respuesta de GitHub.';

  @override
  String get updateErrorTooLarge =>
      'La respuesta de GitHub era más grande de lo esperado.';

  @override
  String get updateErrorNotOnGithub =>
      'La dirección de descarga no está en GitHub.';

  @override
  String get updateErrorDownloadTooLarge =>
      'La descarga es más grande de lo que Chatui acepta.';

  @override
  String get updateErrorStorage =>
      'Chatui no pudo guardar la descarga. ¿El teléfono se quedó sin espacio?';

  @override
  String get updateErrorLargerThanListed =>
      'La descarga es más grande de lo que indica GitHub, así que se detuvo.';

  @override
  String get updateErrorEndedEarly => 'La descarga terminó antes de tiempo.';

  @override
  String get updateRejectedWrongSigner =>
      'Esta descarga no está firmada con la misma clave que esta app, así que no debe instalarse. Se ha eliminado.';

  @override
  String get updateRejectedChecksum =>
      'Esta descarga no coincide con la suma de verificación SHA-256 que indica GitHub, así que puede estar dañada o manipulada. Se ha eliminado.';

  @override
  String get updateRejectedUnreadable =>
      'No se pudo leer la clave de firma de esta descarga, así que no se ofreció para instalar. Se ha eliminado.';

  @override
  String get updateRejectedAppKeyUnknown =>
      'Chatui no pudo leer su propia clave de firma, así que no puede comprobar esta descarga. Se ha eliminado.';

  @override
  String get updateCheckFailed => 'La búsqueda de actualizaciones falló.';

  @override
  String get updateNoApkSeeReleases =>
      'Esta versión no tiene APK para tu teléfono. La página de versiones tiene los archivos.';

  @override
  String get updateCannotKeepDownload =>
      'Este dispositivo no puede guardar una descarga.';

  @override
  String get updateDownloadCancelled => 'Descarga cancelada.';

  @override
  String get updateDownloadFailed => 'La descarga falló.';

  @override
  String get updateInstallPermission =>
      'Android necesita tu permiso primero. Permite que Chatui instale apps en la siguiente pantalla y vuelve a tocar Instalar.';

  @override
  String get updateInstallerFailed =>
      'Android no pudo abrir su instalador. La página de versiones tiene el archivo.';

  @override
  String get walletSettingsRemoveTitle => '¿Quitar la billetera?';

  @override
  String get walletSettingsRemoveBody =>
      'Esto quita la billetera de este dispositivo. Chatui no guarda una copia de la frase de recuperación; el papel en el que la escribiste al crear esta billetera es la única forma de volver a entrar. Después puedes crear o restaurar otra billetera.';

  @override
  String get walletSettingsRemoveFailed => 'No se pudo quitar la billetera';

  @override
  String get walletSettingsPinIndexTitle => 'Fijar índice de dirección';

  @override
  String get walletSettingsPinIndexIntro =>
      'Deriva la dirección en este índice y úsala como dirección principal para enviar y recibir. El índice 0 vuelve al valor predeterminado. El saldo sigue contando todas las direcciones de la billetera.';

  @override
  String get walletSettingsIndexLabel => 'Índice';

  @override
  String get walletSettingsPin => 'Fijar';

  @override
  String get walletSettingsInvalidIndex => 'Índice no válido';

  @override
  String walletSettingsIndexTooHigh(String max) {
    return 'Esta billetera no puede derivar más allá del índice $max';
  }

  @override
  String walletSettingsCannotDerive(String index) {
    return 'La billetera no puede derivar el índice $index';
  }

  @override
  String walletSettingsPinnedIndex(String index, String address) {
    return 'Índice $index fijado · $address';
  }

  @override
  String walletSettingsPinnedOutOfRange(String index) {
    return 'El índice fijado #$index no se puede derivar';
  }

  @override
  String walletSettingsPrimaryPinned(String index) {
    return 'Dirección principal: índice #$index';
  }

  @override
  String get walletSettingsPrimaryDefault => 'Dirección principal: índice 0';

  @override
  String walletSettingsOutOfRangeHint(String max) {
    return 'Esta billetera deriva hasta el índice $max. Quita el índice fijado o elige uno menor.';
  }

  @override
  String get walletSettingsPrimaryHint =>
      'La recepción y el cambio usan esta dirección por defecto hasta que se use.';

  @override
  String get walletSettingsUnpin => 'Quitar fijación';

  @override
  String get walletSettingsFreshAddresses => 'Direcciones nuevas';

  @override
  String get walletSettingsFreshAddressesSubtitle =>
      'La recepción y el cambio van a una dirección nueva cada vez, como en Nautilus. Desactivado: todo usa tu dirección fijada o la primera.';

  @override
  String get walletSettingsUnlockToChange =>
      'Desbloquea la billetera para cambiar este ajuste';

  @override
  String get walletSettingsPrivacySaveFailed =>
      'No se pudo actualizar el ajuste de privacidad';

  @override
  String get walletSettingsBackup => 'Copia de seguridad';

  @override
  String get walletSettingsBackupNote =>
      'Chatui no guarda una copia de la frase de recuperación. El papel en el que la escribiste al crear o restaurar es la única forma de volver a entrar.';

  @override
  String get walletSettingsRemoveWallet => 'Quitar billetera';

  @override
  String get walletSettingsRemoveWalletSubtitle =>
      'Solo de este dispositivo. Conserva la frase de recuperación.';

  @override
  String get secureSaveFailed => 'No se pudo guardar';

  @override
  String get secureSaveWrapKeyFailed =>
      'No se pudo guardar la clave envolvente';

  @override
  String get secureSavePinWrapFailed =>
      'No se pudo guardar la envoltura del PIN';

  @override
  String get secureLoadWrapKeyFailed => 'No se pudo cargar la clave envolvente';

  @override
  String get secureLoadPinWrapFailed =>
      'No se pudo cargar la envoltura del PIN';

  @override
  String get secureLoadFailed => 'No se pudo cargar';

  @override
  String secureDeleteWrapKeyFailed(String detail) {
    return 'No se pudo eliminar la clave envolvente: $detail';
  }

  @override
  String secureDeleteSecretsFailed(String detail) {
    return 'No se pudieron eliminar los secretos de la billetera: $detail';
  }

  @override
  String secureDeleteWalletFailed(String detail) {
    return 'No se pudo eliminar la billetera: $detail';
  }

  @override
  String secureCheckFailed(String detail) {
    return 'No se pudo comprobar: $detail';
  }

  @override
  String get secureCheckPinWrapFailed =>
      'No se pudo comprobar la envoltura del PIN';

  @override
  String get secureCheckWrapKeyFailed =>
      'No se pudo comprobar la clave envolvente';

  @override
  String get secureCheckBiometricsFailed => 'No se pudo comprobar la biometría';

  @override
  String get secureBiometric => 'Biometría';

  @override
  String get secureLoadPinGateFailed => 'No se pudo cargar el bloqueo del PIN';

  @override
  String secureTooManyAttempts(String seconds) {
    return 'Demasiados intentos. Vuelve a intentarlo en $seconds s';
  }

  @override
  String securePersistPinGateFailed(String detail) {
    return 'No se pudo guardar el bloqueo del PIN: $detail';
  }

  @override
  String secureListWalletsFailed(String detail) {
    return 'No se pudieron listar las billeteras: $detail';
  }

  @override
  String get secureBiometricChanged =>
      'La biometría registrada cambió; vuelve a escribir la frase de recuperación';

  @override
  String get notifyChannelName => 'Pagos entrantes';

  @override
  String get notifyChannelDescription =>
      'Se vio en la red un pago a una de tus direcciones.';

  @override
  String get notifyChatDoneChannelName => 'Respuestas terminadas';

  @override
  String get notifyChatDoneChannelDescription =>
      'Un servicio terminó una respuesta mientras no mirabas el chat.';

  @override
  String notifyIncomingBody(String amount, String wallet) {
    return '$amount a $wallet';
  }

  @override
  String get notifyPaymentOnTheWay => 'Pago en camino';

  @override
  String get notifyPaymentReceived => 'Pago recibido';

  @override
  String utxoBoxCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cajas',
      one: '$count caja',
    );
    return '$_temp0';
  }

  @override
  String utxoNBoxes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cajas',
      one: '$count caja',
    );
    return '$_temp0';
  }

  @override
  String utxoTokenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens',
      one: '$count token',
    );
    return '$_temp0';
  }

  @override
  String coinPrivacyNote(String count, String addresses) {
    return 'Estas $count cajas están en $addresses direcciones distintas. Gastarlas juntas vincula públicamente esas direcciones a una misma billetera.';
  }

  @override
  String coinConfirmationNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count de estas cajas aún se están confirmando. Esta transacción solo puede confirmarse después de la que las creó, y falla si esa se descarta.',
      one:
          'Una de estas cajas aún se está confirmando. Esta transacción solo puede confirmarse después de la que la creó, y falla si esa se descarta.',
    );
    return '$_temp0';
  }

  @override
  String get coinSelectionNone => 'Ninguna caja elegida — Chatui las elegirá.';

  @override
  String coinRawUnits(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$amount unidades base',
      one: '$amount unidad base',
    );
    return '$_temp0';
  }

  @override
  String get coinRawUnitsLabel => 'unidades base';

  @override
  String coinRawUnitsOf(String units, String label) {
    return '$units de $label';
  }

  @override
  String get pendingBalanceHidden => '•••• ERG pendientes';

  @override
  String pendingBalanceTotalUnknown(String total) {
    return '$total ERG · pendiente';
  }

  @override
  String pendingBalanceTotalMoved(String total, String moved) {
    return '$total ERG · $moved pendientes';
  }

  @override
  String pendingBalanceMoved(String moved, String confirmed) {
    return '$moved ERG pendientes · $confirmed confirmados';
  }

  @override
  String pendingBalanceUnknown(String confirmed) {
    return 'Pendiente · $confirmed confirmados';
  }

  @override
  String get spendUnconfirmedNote =>
      'Desactivado: el dinero que recibes, y el cambio de tus propios envíos, espera una confirmación (el siguiente bloque, normalmente unos minutos) antes de que Chatui lo gaste. Activado: se puede gastar al momento, pero si la transacción que lo trajo se descarta, la que lo gasta también falla. En ambos casos, las monedas que una transacción pendiente ya está gastando nunca se vuelven a usar.';

  @override
  String get rentNoChargeZeroRate =>
      'No se cobra alquiler de almacenamiento con la tarifa actual.';

  @override
  String rentNoChargeOverflow(String bytes) {
    return 'Con las reglas actuales no se puede cobrar alquiler de almacenamiento a una caja de más de $bytes bytes.';
  }

  @override
  String rentRatePerByte(String fee) {
    return '$fee por byte';
  }

  @override
  String rentRatePerByteDefault(String fee) {
    return '$fee por byte (tarifa predeterminada)';
  }

  @override
  String get rentWhenNow => 'ahora';

  @override
  String get rentWhenWithinDay => 'en menos de un día';

  @override
  String rentWhenInDays(String days) {
    return 'en ~$days días';
  }

  @override
  String rentWhenMonthYear(String month, String year) {
    return '~$month $year';
  }

  @override
  String get separateNeedsSourceAddress =>
      'Actualiza las cajas para identificar la dirección de origen.';

  @override
  String get separateMinPerBox =>
      'Cada caja de token necesita al menos 0.001 ERG.';

  @override
  String get separateFundingInvalid =>
      'Los fondos deben ser otras cajas solo con ERG en la dirección de origen.';

  @override
  String get separateInvalidTokenAmount =>
      'El origen contiene una cantidad de token no válida.';

  @override
  String get separateTokenTypeRange =>
      'Elige una caja que tenga entre 2 y 150 tipos de token.';

  @override
  String get separateInvalidErgValue =>
      'Las cajas seleccionadas contienen un valor de ERG no válido.';

  @override
  String get separateOverLimit =>
      'La cantidad de ERG seleccionada supera el límite de la transacción.';

  @override
  String separateAddFunding(String amount) {
    return 'Añade $amount en cajas de fondos.';
  }

  @override
  String get utxoHealthTidy => 'Ordenada';

  @override
  String get utxoHealthTidyHint =>
      'Pocas cajas: los envíos eligen entradas rápido y pagan lo mínimo.';

  @override
  String get utxoHealthModerate => 'Moderada';

  @override
  String get utxoHealthModerateHint =>
      'Los envíos pueden necesitar varias entradas; consolidar el polvo (dust) mantiene bajas las comisiones.';

  @override
  String get utxoHealthFragmented => 'Fragmentada';

  @override
  String get utxoHealthFragmentedHint =>
      'Muchas cajas pequeñas hacen que cada envío use más entradas. Barre el polvo o consolida.';

  @override
  String sendRecipientPrefix(String number) {
    return 'Destinatario $number: ';
  }

  @override
  String sendErrorNotErgoAddress(String who) {
    return '${who}no es una dirección de Ergo';
  }

  @override
  String sendErrorMinimum(String who, String amount) {
    return '${who}mínimo $amount ERG';
  }

  @override
  String sendErrorTokenNotInWallet(String who) {
    return '${who}el token no está en esta billetera';
  }

  @override
  String sendErrorEnterTokenAmount(String who, String token) {
    return '${who}escribe una cantidad de token para $token';
  }

  @override
  String sendErrorTokenOverAllocated(String who, String amount, String token) {
    return '${who}tienes $amount $token en total entre todos los destinatarios';
  }

  @override
  String get priceHistoryNeedsExtraIndex =>
      'Este nodo no puede dar el historial de precios: necesita el índice extra.';

  @override
  String get oracleSigmaUsd => 'Oráculo SigmaUSD';

  @override
  String get oracleDexyUsd => 'Oráculo Dexy USD';

  @override
  String get oracleDexyGold => 'Oráculo de oro Dexy';

  @override
  String get oracleAvl => 'Oráculo AVL';

  @override
  String priceAgeMinutes(String count) {
    return '$count min';
  }

  @override
  String priceAgeHours(String count) {
    return '$count h';
  }

  @override
  String priceAgeDays(String count) {
    return '$count días';
  }

  @override
  String priceAgeOld(String age) {
    return 'hace $age';
  }

  @override
  String priceSourceLine(String source, String via) {
    return '$source · ERG vía $via';
  }

  @override
  String priceSourceLineStale(String source, String via) {
    return '$source · sin actualizar · ERG vía $via';
  }

  @override
  String priceHistoryUnreadable(String error) {
    return 'No se pudo leer el historial de precios: $error';
  }

  @override
  String get priceNoNode => 'No hay ningún nodo conectado.';

  @override
  String get priceNoHeight => 'Aún no se conoce la altura del nodo.';

  @override
  String priceNoHistoryYet(String source) {
    return 'Este nodo aún no tiene historial de precios de $source.';
  }

  @override
  String get priceOraclePools => 'Pools de oráculos';

  @override
  String get priceSourceBlurb =>
      'En cadena: ERG del pool de oráculos de SigmaUSD (el pool de oráculos ERG/USD), oro del oráculo de oro Dexy y las principales monedas envueltas del multioráculo AVL. Un precio antiguo se muestra con su antigüedad, nunca como actual. Solo lee tu nodo. Los demás tokens no tienen precio.';

  @override
  String priceNoneYet(String source) {
    return 'Aún sin precio · $source no han respondido';
  }

  @override
  String get priceNoPool =>
      'Sin precio · ningún pool de oráculos cotiza este token';

  @override
  String priceEach(String price) {
    return '$price cada uno';
  }

  @override
  String priceHeld(String value) {
    return '$value en tu poder';
  }

  @override
  String get priceNotCounted => 'no cuenta en los totales (sin actualizar)';

  @override
  String get verifiedNetaNote =>
      'Su equipo abandonó el proyecto anetaBTC y los poseedores se quedaron sin el producto prometido. Considera que NETA no tiene respaldo.';

  @override
  String get tokenErrorNoName => 'Ponle un nombre al token';

  @override
  String get tokenErrorNameTooLong =>
      'El nombre es demasiado largo (64 caracteres como máximo)';

  @override
  String get tokenErrorDecimalsRange =>
      'Los decimales deben estar entre 0 y 18';

  @override
  String get tokenErrorAmountMissing => 'Escribe la cantidad que vas a emitir';

  @override
  String get tokenErrorAmountZero => 'La cantidad debe ser mayor que cero';

  @override
  String get tokenErrorAmountTooBig =>
      'La cantidad supera lo que cabe en una caja';

  @override
  String get nftErrorDecimals => 'Un NFT no tiene decimales';

  @override
  String get nftErrorOneUnit => 'Un NFT es una sola unidad';

  @override
  String get nftErrorHash =>
      'El hash del contenido debe tener 64 caracteres hexadecimales (SHA-256)';

  @override
  String get nftErrorLink => 'El enlace debe empezar por https:// o ipfs://';

  @override
  String get tokenIssue => 'Emitir';

  @override
  String get tokenBurn => 'Quemar';

  @override
  String get tokenIssueNftTitle => 'Emitir un NFT';

  @override
  String get tokenIssueTokenTitle => 'Emitir un token';

  @override
  String get tokenIssueDetail =>
      'El nuevo token llega a esta billetera. Su nombre, descripción y decimales se escriben en la cadena y no se pueden cambiar después.';

  @override
  String get tokenSupply => 'Suministro';

  @override
  String tokenSupplyDecimals(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$amount · $count decimales',
      one: '$amount · $count decimal',
    );
    return '$_temp0';
  }

  @override
  String get tokenDescription => 'Descripción';

  @override
  String get tokenKind => 'Tipo';

  @override
  String get tokenLink => 'Enlace';

  @override
  String get tokenIdRow => 'ID del token';

  @override
  String get tokenBoxValue => 'Valor de la caja';

  @override
  String get tokenIssuanceSubmitted => 'Emisión del token enviada';

  @override
  String get tokenIssuanceNote =>
      'El ID del token queda en la pantalla de emisión. El token aparece en tus activos tras la confirmación.';

  @override
  String tokenNamedIssuanceSubmitted(String name) {
    return 'Emisión de $name enviada';
  }

  @override
  String get tokenIssuedExplainer =>
      'Aparece en tus activos cuando se confirme la transacción. El ID del token es como lo conocen otras billeteras y sitios.';

  @override
  String get tokenIdLabel => 'ID del token';

  @override
  String get tokenCopyId => 'Copiar ID del token';

  @override
  String get tokenIdCopied => 'ID del token copiado';

  @override
  String get tokenViewReceipt => 'Ver recibo de la transacción';

  @override
  String get tokenTransactionId => 'ID de transacción';

  @override
  String get tokenIssueAnother => 'Emitir otro';

  @override
  String get tokenIssueIntro =>
      'Un token se crea con una transacción desde esta billetera. Esa transacción fija su ID, y su nombre, descripción y decimales se escriben una sola vez, en la cadena.';

  @override
  String get nftSubtitle =>
      'Una sola unidad con un hash de contenido y un enlace';

  @override
  String get tokenDescriptionOptional => 'Descripción (opcional)';

  @override
  String get tokenSupplyHelper => 'Unidades enteras, se admiten decimales';

  @override
  String get tokenDecimals => 'Decimales';

  @override
  String get tokenDecimalsHelper => '0 a 18';

  @override
  String get nftKindPicture => 'Imagen';

  @override
  String get nftKindAudio => 'Audio';

  @override
  String get nftKindVideo => 'Video';

  @override
  String get nftHashLabel => 'SHA-256 del contenido (hex, opcional)';

  @override
  String get nftHashHelper => '64 caracteres hex';

  @override
  String get nftLinkLabel => 'Enlace (opcional)';

  @override
  String get nftLinkHelper => 'https:// o ipfs://';

  @override
  String get tokenIssueCost =>
      'Cuesta 0.001 ERG por la caja del token más la comisión de minería.';

  @override
  String get tokenPreparing => 'Preparando…';

  @override
  String tokenBurnEnterAmount(String token) {
    return 'Escribe cuánto $token quieres quemar';
  }

  @override
  String tokenBurnYouHold(String amount, String token) {
    return 'Tienes $amount $token';
  }

  @override
  String get tokenBurnPick => 'Elige un token para quemar';

  @override
  String tokenBurnTypeToGoOn(String word) {
    return 'Escribe $word para continuar';
  }

  @override
  String get tokenBurnTitle => 'Quemar tokens';

  @override
  String get tokenBurnForGood => 'Quemar para siempre';

  @override
  String get tokenBurnDetail =>
      'Estas unidades quedan fuera de todas las salidas de la transacción y dejan de existir. Nadie, ni siquiera Chatui, puede recuperarlas.';

  @override
  String get tokenBurnBackToYou => 'Vuelve a ti';

  @override
  String get tokenBurnSubmitted => 'Quema de tokens enviada';

  @override
  String get tokenBurnWarning =>
      'Quemar destruye los tokens para siempre. No es un envío: las unidades salen de la cadena en vez de pasar a alguien. Úsalo con tokens que seguro que no quieres recuperar, como spam o un suministro que quieres reducir.';

  @override
  String get tokenBurnNoTokens => 'Esta billetera no tiene tokens.';

  @override
  String get tokenBurnInWallet => 'Tokens en esta billetera';

  @override
  String tokenBurnHeldRow(String amount, String id) {
    return '$amount en tu poder · $id';
  }

  @override
  String tokenBurnOneUnit(String token) {
    return '$token: la única unidad';
  }

  @override
  String tokenBurnAmountLabel(String token) {
    return '$token para quemar';
  }

  @override
  String tokenBurnOf(String amount) {
    return 'De $amount';
  }

  @override
  String get tokenBurnAll => 'TODO';

  @override
  String tokenBurnTypeToConfirm(String word) {
    return 'Escribe $word para confirmar';
  }

  @override
  String get assetsTitle => 'Activos';

  @override
  String get assetsShowList => 'Mostrar lista de coleccionables';

  @override
  String get assetsShowGrid => 'Mostrar cuadrícula de coleccionables';

  @override
  String get assetsClearCache =>
      'Borrar caché de coleccionables (los activos guardados conservan sus metadatos)';

  @override
  String get assetsAll => 'Todos';

  @override
  String get assetsCollectibles => 'Coleccionables';

  @override
  String get assetsSearchLabel => 'Buscar nombre o ID de token';

  @override
  String get assetsClearSearch => 'Borrar búsqueda';

  @override
  String assetsCollectibleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count coleccionables identificados · las vistas previas solo se cargan cuando tú eliges',
      one:
          '$count coleccionable identificado · las vistas previas solo se cargan cuando tú eliges',
    );
    return '$_temp0';
  }

  @override
  String assetsTokenIdCount(String count) {
    return '$count ID de token';
  }

  @override
  String assetsTokenIdCountIncomplete(String count, String unknown) {
    return '$count ID de token · $unknown con metadatos incompletos';
  }

  @override
  String get assetsPublicOnly => 'Solo activos públicos';

  @override
  String get assetsNotLoaded => 'Activos sin cargar';

  @override
  String assetsLastSynced(String age) {
    return 'Última sincronización de activos: $age';
  }

  @override
  String get assetsHidden => 'Activos ocultos';

  @override
  String get assetsNoMatch => 'Ningún activo coincide con tu búsqueda';

  @override
  String get assetsNoCollectibles =>
      'No hay coleccionables identificados en los activos cargados';

  @override
  String get assetsIncompleteHint =>
      'Algunos tokens tienen metadatos incompletos. Ábrelos en Todos para ver sus detalles.';

  @override
  String get tokenCautionFlagged => 'Precaución: este token está marcado';

  @override
  String assetsHeld(String amount) {
    return 'En tu poder: $amount';
  }

  @override
  String tokenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ID de token (incl. NFT)',
      one: '$count ID de token (incl. NFT)',
    );
    return '$_temp0';
  }

  @override
  String tokenCountPublic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ID públicos de token (incl. NFT)',
      one: '$count ID público de token (incl. NFT)',
    );
    return '$_temp0';
  }

  @override
  String get artworkClose => 'Cerrar imagen';

  @override
  String get artworkTitle => 'Imagen';

  @override
  String get artworkResetZoom => 'Restablecer zoom';

  @override
  String get artworkPreviewHidden =>
      'Vista previa oculta. Vuelve a abrir los detalles del activo para verla.';

  @override
  String get artworkZoomHint =>
      'Pellizca o desplázate para hacer zoom. Arrastra para mover.';

  @override
  String get tokenMetaAsciiProvider =>
      'Configura un proveedor de metadatos HTTPS con ASCII/punycode';

  @override
  String tokenMetaLoadFrom(String host) {
    return 'Cargar metadatos de $host';
  }

  @override
  String tokenMetaLoadFromNode(String host) {
    return 'Cargar metadatos de $host (nodo)';
  }

  @override
  String get tokenMetaHostNode => 'nodo';

  @override
  String get tokenMetaHostProvider => 'proveedor';

  @override
  String get tokenMetaPrivacy =>
      'Este proveedor puede ver tu dirección IP y el ID del token solicitado. El texto del emisor puede ser engañoso. No se descargará ninguna imagen.';

  @override
  String get tokenMetaLoad => 'Cargar metadatos';

  @override
  String get tokenMetaBusy =>
      'Otra solicitud de metadatos está terminando — vuelve a intentarlo';

  @override
  String tokenMetaUnavailableFrom(String host) {
    return 'Metadatos no disponibles en $host';
  }

  @override
  String get tokenDetailsHidden => 'Detalles del activo ocultos';

  @override
  String get tokenMetaOffline => 'Metadatos no disponibles sin conexión';

  @override
  String get tokenMetaCancel => 'Cancelar solicitud de metadatos';

  @override
  String get tokenMetaLoading => 'Cargando metadatos…';

  @override
  String tokenCurated(String project) {
    return 'Token curado · $project';
  }

  @override
  String tokenCaution(String note) {
    return 'Precaución: $note';
  }

  @override
  String get tokenCautionDefault => 'este token está marcado.';

  @override
  String tokenImpersonation(String ticker, String project) {
    return 'Este token se llama como $ticker, pero no es el $ticker verificado de $project. Comprueba el ID antes de confiar en él.';
  }

  @override
  String get artworkNoMediaLink =>
      'No hay enlace multimedia en los metadatos de emisión.';

  @override
  String get artworkLoadBelow =>
      'Carga los metadatos abajo para buscar una imagen.';

  @override
  String get artworkPreviewUnsupported => 'Vista previa no compatible';

  @override
  String get artworkLinkUnavailable => 'Enlace de la imagen no disponible';

  @override
  String get artworkMediaUnavailable => 'Metadatos multimedia no disponibles';

  @override
  String get artworkConsent => 'La imagen solo se carga con tu consentimiento';

  @override
  String get tokenYouHold => 'TIENES';

  @override
  String get tokenIdCaps => 'ID DEL TOKEN';

  @override
  String tokenLeaveFor(String host) {
    return '¿Salir de Chatui hacia $host?';
  }

  @override
  String get tokenExplorerPrivacy =>
      'El explorador puede ver tu dirección IP y el ID de este token.';

  @override
  String get tokenOpenExplorer => 'Abrir explorador';

  @override
  String get tokenExplorer => 'Explorador';

  @override
  String get tokenMetaDetails => 'Detalles de metadatos y multimedia';

  @override
  String tokenOriginalEmission(String amount) {
    return 'Emisión original: $amount (según el proveedor)';
  }

  @override
  String get tokenOriginalEmissionUnavailable =>
      'Emisión original no disponible';

  @override
  String tokenDecimalsLine(String decimals, String evidence) {
    return 'Decimales: $decimals · $evidence';
  }

  @override
  String get tokenDecimalsDeclared => 'declarados por el emisor';

  @override
  String get tokenDecimalsNone => 'ninguno declarado, así que unidades enteras';

  @override
  String get tokenDecimalsListed => 'de una lista de tokens';

  @override
  String get tokenDecimalsLastShown => 'como se mostraron la última vez';

  @override
  String get tokenDecimalsUnknown =>
      'Decimales desconocidos · las cantidades se muestran en unidades sin escalar';

  @override
  String tokenDeclaredKind(String kind) {
    return 'Tipo de contenido declarado: $kind';
  }

  @override
  String tokenMetaSource(String source) {
    return 'Origen de los metadatos: $source';
  }

  @override
  String get tokenMediaHashMissing =>
      'Hash multimedia de emisión ausente o no válido';

  @override
  String tokenMediaHash(String hash) {
    return 'Hash multimedia de emisión: $hash';
  }

  @override
  String get tokenCopyMediaUri => 'Copiar URI multimedia como texto';

  @override
  String get tokenIssuanceRegisters => 'Registros de emisión originales (hex)';

  @override
  String tokenSend(String token) {
    return 'Enviar $token';
  }

  @override
  String get syncLockedWalletsExplainer =>
      'Una billetera bloqueada se actualiza con datos públicos cada 5 minutos, solo en las direcciones que esta app ya conoce. Desbloquéala para incluir direcciones nuevas.';

  @override
  String get syncPublicKnownOnly =>
      'Datos públicos · solo direcciones conocidas';

  @override
  String get syncSyncing => 'Sincronizando…';

  @override
  String get syncOutOfSync => 'Desactualizada';

  @override
  String get syncHistoryIncomplete => 'Historial incompleto';

  @override
  String get syncSynced => 'Sincronizada';

  @override
  String get syncNotSynced => 'Sin sincronizar';

  @override
  String syncPinIssue(String index, String max) {
    return 'No se puede derivar el índice fijado $index (máx. $max). Restablécelo en Ajustes.';
  }

  @override
  String dashboardStartupError(String detail) {
    return 'Error: $detail';
  }

  @override
  String get dashboardUnlockForErgoPay =>
      'Desbloquea una billetera para continuar con la solicitud de ErgoPay.';

  @override
  String get dashboardUnlockForNotification =>
      'Desbloquea una billetera para abrir lo que indica la notificación.';

  @override
  String get dashboardScanNotErgo =>
      'No es una dirección de Ergo ni un enlace de ErgoPay';

  @override
  String dashboardOpenFailed(String detail) {
    return 'No se pudo abrir la billetera: $detail';
  }

  @override
  String dashboardWalletRemoved(String name) {
    return '\"$name\" eliminada';
  }

  @override
  String get dashboardNoAddressDerived =>
      'Desbloqueada, pero no se pudo derivar ninguna dirección';

  @override
  String get dashboardPinLockoutCheckFailed =>
      'No se pudo comprobar el bloqueo del PIN';

  @override
  String get dashboardNoPinWallet =>
      'No se encontró ninguna billetera protegida con PIN.';

  @override
  String get dashboardBiometricNotSetUp =>
      'Esta billetera no tiene su clave guardada en este dispositivo.';

  @override
  String get dashboardBiometricCancelled =>
      'Desbloqueo cancelado. Toca Desbloquear para volver a intentarlo.';

  @override
  String get dashboardWalletDataMissing =>
      'No se encontraron los datos de la billetera en este dispositivo.';

  @override
  String get dashboardNoWalletFound =>
      'No se encontró ninguna billetera. Crea o restaura una.';

  @override
  String get dashboardSetPinTitle => 'Crea un PIN';

  @override
  String get dashboardLater => 'Más tarde';

  @override
  String get dashboardUnlockFirst => 'Primero desbloquea la billetera';

  @override
  String get dashboardAddressLoading => 'La dirección todavía se está cargando';

  @override
  String get dashboardScanQrTooltip => 'Escanear un código QR';

  @override
  String get dashboardWalletSettingsTooltip => 'Ajustes de la billetera';

  @override
  String get homeUnlocked => 'Desbloqueada';

  @override
  String get homeLocked => 'Bloqueada';

  @override
  String get offlineNoNodes =>
      'No hay nodos accesibles. Toca Reintentar para comprobarlo.';

  @override
  String get discoverTokensBlurb =>
      'Emite un token o un NFT, o quema tokens que tengas.';

  @override
  String get discoverTokensWhat =>
      'Cualquier transacción de Ergo puede crear un token nuevo: su ID es el ID de la primera caja de entrada, y su nombre, decimales y descripción están en los registros de la caja que lo lleva (EIP-4). Un NFT es un token con una sola unidad y un enlace a su contenido multimedia.';

  @override
  String get discoverTokensCanIssue =>
      'Emitir un token fungible con nombre, decimales y suministro';

  @override
  String get discoverTokensCanNft =>
      'Emitir un NFT que apunte a una imagen, un audio o un video';

  @override
  String get discoverTokensCanBurn =>
      'Quemar tokens que tengas para sacarlos de circulación';

  @override
  String get discoverTokensRiskName =>
      'El nombre de un token no es único: cualquiera puede emitir uno con el mismo nombre';

  @override
  String get discoverTokensRiskBurn =>
      'Quemar es definitivo; el suministro no se puede recuperar';

  @override
  String get discoverTokensRiskCost =>
      'Emitir cuesta una comisión de minería y bloquea el valor mínimo de caja junto con el token';

  @override
  String get discoverTokensGo => 'Abrir tokens';

  @override
  String get homeUtxoManagement => 'Gestión de UTXO';

  @override
  String get discoverUtxosBlurb =>
      'Consolida, divide y reorganiza las cajas en las que está tu dinero.';

  @override
  String get discoverUtxosWhat =>
      'En Ergo tu saldo es un conjunto de cajas, cada una una moneda aparte. Muchas cajas pequeñas hacen que cada envío sea más grande y más lento de construir; una sola caja enorme vincula todo lo que tienes en un mismo lugar. Esta herramienta las reorganiza.';

  @override
  String get discoverUtxosCanConsolidate =>
      'Consolidar muchas cajas pequeñas en una';

  @override
  String get discoverUtxosCanSplit =>
      'Dividir una caja en varias del tamaño que elijas';

  @override
  String get discoverUtxosCanRestructure =>
      'Reorganizar los fondos para que los tokens estén en cajas propias';

  @override
  String get discoverUtxosRiskPublic =>
      'Cada reorganización es una transacción: cuesta una comisión de minería y es pública';

  @override
  String get discoverUtxosRiskLinks =>
      'Consolidar vincula a un mismo propietario todas las cajas que gasta';

  @override
  String get discoverUtxosRiskMinimum =>
      'No se puede crear una caja por debajo del valor mínimo';

  @override
  String get discoverUtxosGo => 'Abrir gestión de UTXO';

  @override
  String get discoverWhatYouCanDo => 'LO QUE PUEDES HACER';

  @override
  String get discoverWatchFor => 'TEN EN CUENTA';

  @override
  String get discoverIntro =>
      'Lo que Chatui puede hacer además de enviar y recibir. Cada herramienta explica qué es, qué puedes hacer con ella y qué tener en cuenta antes de abrirla.';

  @override
  String get discoverTools => 'Herramientas';

  @override
  String get discoverRowHint => 'Qué es y cómo entrar';

  @override
  String get navActivity => 'Actividad';

  @override
  String get navDiscover => 'Descubrir';

  @override
  String navActivityPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Actividad, $count pendientes',
      one: 'Actividad, $count pendiente',
    );
    return '$_temp0';
  }

  @override
  String homePricesOld(String age) {
    return 'precios de hace $age';
  }

  @override
  String get homePricesStale => 'precios desactualizados';

  @override
  String homePricesAsOf(String when) {
    return 'precios de $when';
  }

  @override
  String get homePriceUnavailable => 'no disponible';

  @override
  String get homePriceUnavailableRetrying => 'no disponible · reintentando';

  @override
  String get homeNetworkConnected => 'Conectado';

  @override
  String get homeNetworkLooking => 'Buscando un nodo…';

  @override
  String get homeNoReachableNodes => 'No hay nodos accesibles';

  @override
  String homeAgeOld(String age) {
    return 'de hace $age';
  }

  @override
  String homePriceAsOf(String when) {
    return 'de $when';
  }

  @override
  String homeHistoryOutOfDate(String source) {
    return 'Historial de $source desactualizado';
  }

  @override
  String homeLegsMore(String first, String count) {
    return '$first + $count más';
  }

  @override
  String homeWalletsNotLoaded(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n billeteras sin cargar',
      one: '$n billetera sin cargar',
    );
    return '$_temp0';
  }

  @override
  String homeAsOf(String when) {
    return 'datos de $when';
  }

  @override
  String homeSpokenLoading(String label) {
    return '$label cargando';
  }

  @override
  String homeSpokenUnavailable(String label) {
    return '$label no disponible';
  }

  @override
  String homeSpokenHidden(String label) {
    return '$label oculto';
  }

  @override
  String get homeSpokenSomethingPending => 'algo pendiente';

  @override
  String homeSpokenAbout(String value, String code) {
    return 'aproximadamente $value $code';
  }

  @override
  String homeSpokenUnpriced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens sin precio',
      one: '$count token sin precio',
    );
    return '$_temp0';
  }

  @override
  String homeUnpricedTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens sin precio',
      one: '$count token sin precio',
    );
    return '$_temp0';
  }

  @override
  String homeSpokenPinnedAddress(String index, String address) {
    return 'Dirección fijada #$index, $address';
  }

  @override
  String homeSpokenAddress(String address) {
    return 'Dirección $address';
  }

  @override
  String get homeCopyAddress => 'Copiar dirección';

  @override
  String get homeErgPriceUnavailable => 'Precio de ERG no disponible';

  @override
  String homePriceVia(String window, String source) {
    return '$window vía $source';
  }

  @override
  String homeSpokenErgPrice(String value, String code) {
    return 'Precio de ERG $value $code';
  }

  @override
  String homeSpokenUp(String percent, String window) {
    return 'sube un $percent% en $window';
  }

  @override
  String homeSpokenDown(String percent, String window) {
    return 'baja un $percent% en $window';
  }

  @override
  String get homeShowBalances => 'Mostrar saldos';

  @override
  String get homeHideBalances => 'Ocultar saldos';

  @override
  String get homeNetworkSettings => 'Ajustes de red';

  @override
  String homeBlock(String height) {
    return 'Bloque $height';
  }

  @override
  String get homeLoading => 'Cargando…';

  @override
  String get homeEmpty => 'Vacía';

  @override
  String homeTokenCount(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n tokens',
      one: '$n token',
    );
    return '$_temp0';
  }

  @override
  String homeAsOfCompact(String when) {
    return 'datos de $when';
  }

  @override
  String get homeOpensWallet => 'Abre la billetera';

  @override
  String get homeSpokenUnlocked => 'desbloqueada';

  @override
  String get homeSpokenBalanceHidden => 'saldo oculto';

  @override
  String homeSpokenIncl(String other) {
    return 'incl. $other';
  }

  @override
  String homePriceNote(String note) {
    return 'Precio $note';
  }

  @override
  String get homeAssetHidden => 'Activo oculto';

  @override
  String get homeSpokenVerified => 'verificado';

  @override
  String get homeSpokenCaution => 'cuidado, se llama como un token verificado';

  @override
  String homeSpokenPrice(String value) {
    return 'precio $value';
  }

  @override
  String get homeSpokenPending => 'pendiente';

  @override
  String get homeSpokenAmountHidden => 'cantidad oculta';

  @override
  String get overviewOpenToLoad => 'Ábrela para cargar';

  @override
  String get overviewNotLoadedYet => 'Aún sin cargar';

  @override
  String get overviewTagline => 'Computación descentralizada';

  @override
  String get overviewTotalBalance => 'Saldo total';

  @override
  String get overviewWalletRowTitle => 'Detalles de la billetera';

  @override
  String get overviewPrototypeTitle => 'Software prototipo';

  @override
  String get overviewPrototypeBody =>
      'Chatui es un prototipo sin auditar. Las transacciones en Ergo son irreversibles — usa solo fondos que puedas permitirte perder.';

  @override
  String get overviewGotIt => 'Entendido';

  @override
  String get overviewPrototypeNote =>
      'Prototipo sin auditar. Usa solo fondos que puedas permitirte perder.';

  @override
  String get overviewLearnMore => 'Más información';

  @override
  String get overviewWelcomeTitle => 'Aquí vive tu billetera';

  @override
  String get overviewWelcomeBody =>
      'Aún no hay billetera. Crea una billetera nueva o restaura una con su frase de recuperación. La app tiene una billetera, y se abre desde esta pantalla.';

  @override
  String get overviewCreateWallet => 'Crear una billetera';

  @override
  String get overviewRestoreWallet => 'Restaurar con la frase de recuperación';

  @override
  String get homeBalanceLabel => 'Saldo';

  @override
  String get homeUnlockPrompt =>
      'Desbloquea para ver la actividad, enviar y recibir.';

  @override
  String get homeUnlock => 'Desbloquear';

  @override
  String get homeUsePin => 'Usar PIN';

  @override
  String get homeUseBiometrics => 'Usar biometría';

  @override
  String get homeUnlockAndSetPin => 'Desbloquear y crear PIN';

  @override
  String get homeKeysNotHere =>
      'Las claves de esta billetera no están guardadas en este dispositivo.';

  @override
  String get homeActionSend => 'Enviar';

  @override
  String get homeActionReceive => 'Recibir';

  @override
  String get homeActionMore => 'Más';

  @override
  String get homeToolTokensBlurb => 'Emite tokens y NFT, o quema tokens.';

  @override
  String get homeToolUtxosBlurb => 'Consolida, divide y ordena tus cajas.';

  @override
  String get homeToolAddressesBlurb =>
      'Cada dirección de esta billetera y lo que contiene.';

  @override
  String get homeToolLock => 'Bloquear billetera';

  @override
  String get homeToolLockBlurb =>
      'Al abrirla de nuevo se pedirá tu huella o el bloqueo de pantalla.';

  @override
  String get homeBreakdownIntro =>
      'La billetera se muestra como una dirección, pero su saldo cubre todas las direcciones que conoce. Cualquiera de ellas puede gastar de esta billetera.';

  @override
  String homeBreakdownEmptyOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count direcciones conocidas más no tienen fondos.',
      one: '$count dirección conocida más no tiene fondos.',
    );
    return '$_temp0';
  }

  @override
  String get homeLongPressCopy => 'Mantén pulsado para copiar';

  @override
  String get homeNameAddressHint =>
      'Pone nombre a esta dirección. Mantén pulsado para copiar';

  @override
  String get homeSpokenShownAs => 'mostrada como esta billetera';

  @override
  String get homeShownAs => 'Mostrada como esta billetera';

  @override
  String get homeAllWallets => 'Atrás';

  @override
  String get homeOtherAddressesHint =>
      'Muestra cada dirección y lo que contiene';

  @override
  String get homeUtxos => 'UTXO';

  @override
  String homeUtxoCount(String count) {
    return '$count UTXO';
  }

  @override
  String get homeUtxoTools => 'Herramientas de UTXO';

  @override
  String homeSpokenFragmented(String utxos) {
    return '$utxos, fragmentados. Ordenar';
  }

  @override
  String get homeTidyUp => 'Ordenar';

  @override
  String get homeFragmented => 'Fragmentados';

  @override
  String get homeAllAssets => 'Todos los activos';

  @override
  String homeAllAssetsCount(String count) {
    return 'Todos los activos ($count)';
  }

  @override
  String get homeRecentActivity => 'Actividad reciente';

  @override
  String get homeViewAll => 'Ver todo';

  @override
  String get homeReadingActivity => 'Leyendo la actividad';

  @override
  String get homeReadingActivityEllipsis => 'Leyendo la actividad…';

  @override
  String get homeFullHistory => 'Historial completo';

  @override
  String get homeEveryAddress => 'Cada dirección y lo que contiene';

  @override
  String get homeNoAddresses => 'Aún no se ha leído ninguna dirección';

  @override
  String get homeNoAddressesDot => 'Aún no se ha leído ninguna dirección.';

  @override
  String homeSpokenCountFragmented(String count) {
    return '$count, fragmentados';
  }

  @override
  String get homeAssets => 'Activos';

  @override
  String get homeShowMyAddress => 'Mostrar mi dirección';

  @override
  String get homeNoActivity => 'Aún no hay actividad';

  @override
  String get activityTitleReceived => 'Recibido';

  @override
  String get activityTitleSent => 'Enviado';

  @override
  String get activityTitleMoved => 'Movido';

  @override
  String get activityTitleConsolidated => 'Consolidado';

  @override
  String activityTitleBurned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tokens quemados',
      one: 'Token quemado',
    );
    return '$_temp0';
  }

  @override
  String activityTitleIssued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tokens emitidos',
      one: 'Token emitido',
    );
    return '$_temp0';
  }

  @override
  String get activityTitleContractInteraction => 'Interacción con un contrato';

  @override
  String get activityTitleContract => 'Contrato';

  @override
  String activityFrom(String address) {
    return 'de $address';
  }

  @override
  String activityFromContract(String address) {
    return 'del contrato $address';
  }

  @override
  String activityTo(String address) {
    return 'a $address';
  }

  @override
  String activityToContract(String address) {
    return 'al contrato $address';
  }

  @override
  String activityContract(String address) {
    return 'contrato $address';
  }

  @override
  String activityAndMore(String who, String count) {
    return '$who y $count más';
  }

  @override
  String get activityArgusAppFee => 'Comisión de la app Argus';

  @override
  String get activityBetweenYourAddresses => 'entre tus direcciones';

  @override
  String get activityFeeLabel => 'Comisión';

  @override
  String activityMoreTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens más',
      one: '$count token más',
    );
    return '$_temp0';
  }

  @override
  String activityPlusMore(String count) {
    return '+ $count más';
  }

  @override
  String get activityScreenTitle => 'Actividad';

  @override
  String get activityPartial =>
      'No se pudieron comprobar algunas direcciones. La actividad está incompleta.';

  @override
  String activityLoadFailed(String error) {
    return 'No se pudo cargar la actividad: $error';
  }

  @override
  String activityLoadMoreFailed(String error) {
    return 'No se pudo cargar la actividad anterior: $error';
  }

  @override
  String get activityNoneToExport => 'No hay transacciones para exportar';

  @override
  String activityExportFailed(String error) {
    return 'No se pudo exportar: $error';
  }

  @override
  String activityCount(String count) {
    return '$count transacciones';
  }

  @override
  String get activityExportCsv => 'Exportar CSV';

  @override
  String get activityEmptyTitle => 'Aún no hay actividad';

  @override
  String get activityEmptyBody =>
      'Las transacciones que entren o salgan de esta billetera aparecerán aquí, las más recientes primero.';

  @override
  String get activityRefresh => 'Actualizar';

  @override
  String ergopayErrorUnreachable(String detail) {
    return 'No se pudo contactar con la dApp: $detail';
  }

  @override
  String ergopayErrorHttp(String status) {
    return 'La dApp respondió HTTP $status';
  }

  @override
  String get ergopayErrorUnreadable =>
      'La dApp envió una solicitud de firma ilegible';

  @override
  String ergopayErrorNotify(String detail) {
    return 'No se pudo avisar a la dApp: $detail';
  }

  @override
  String ergopayErrorReplyRejected(String status) {
    return 'La dApp rechazó la respuesta (HTTP $status)';
  }

  @override
  String get ergopayWarningInputsUnknown =>
      'No se pudieron obtener del nodo los valores de las entradas, así que no se sabe el total que gastas. Revisa las salidas con atención.';

  @override
  String get ergopayWarningForeignInputs =>
      'Algunas entradas no son de esta billetera. La dApp está añadiendo sus propias cajas a esta transacción.';

  @override
  String get ergopayRowRecipients => 'Destinatarios';

  @override
  String get ergopayRowSent => 'Enviado';

  @override
  String get ergopayRowTokensOut => 'Tokens que salen';

  @override
  String get ergopayRowChange => 'Cambio para ti';

  @override
  String get ergopayRowYouSpend => 'Gastas';

  @override
  String get ergopayRowInputs => 'Entradas';

  @override
  String get ergopayStatusContacting => 'Contactando con la dApp…';

  @override
  String get ergopayNotALink => 'Esto no es un enlace de ErgoPay.';

  @override
  String ergopayWrongAddress(String address) {
    return 'Esta solicitud es para $address, que no es una dirección de esta billetera.';
  }

  @override
  String get ergopayStatusReading => 'Leyendo la transacción…';

  @override
  String get ergopayPickAddressTitle => '¿Qué dirección debe usar la dApp?';

  @override
  String get ergopayMainAddress => 'Dirección principal';

  @override
  String get ergopaySignTitle => 'Firmar para la dApp';

  @override
  String get ergopayNodeNotChosen => 'Aún no se ha elegido un nodo';

  @override
  String get ergopayStatusSigning => 'Firmando…';

  @override
  String get ergopayStatusBroadcasting => 'Enviando a la red…';

  @override
  String get ergopayStatusNotifying => 'Avisando a la dApp…';

  @override
  String get ergopaySignedAndSent => 'Firmada y enviada';

  @override
  String get ergopayNoTransaction =>
      'La dApp no envió ninguna transacción para firmar.';

  @override
  String get ergopayThisTransaction => 'Esta transacción';

  @override
  String get ergopayReviewAndSign => 'Revisar y firmar';

  @override
  String get ergopayDecline => 'Rechazar';

  @override
  String ergopayNotifyFailed(String error) {
    return 'La transacción está en la red, pero no se pudo avisar a la dApp: $error';
  }

  @override
  String get errorSomethingWentWrong => 'Algo salió mal';

  @override
  String get errorCopied => 'Error copiado';

  @override
  String get errorContractRejected =>
      'Un contrato rechazó esta transacción, así que no se firmó. No se envió nada.';

  @override
  String get errorNothingSent => 'No se envió nada.';

  @override
  String get errorSigningFailed => 'No se pudo firmar';

  @override
  String get errorBroadcastMayHaveFailed =>
      'Puede que la difusión haya fallado';

  @override
  String get errorCheckActivity =>
      'Comprueba la Actividad antes de reintentar; puede que la transacción ya esté en la red.';

  @override
  String get contactsNoneToExport => 'No hay contactos para exportar';

  @override
  String contactsExportFailed(String error) {
    return 'No se pudo exportar: $error';
  }

  @override
  String get contactsSelectTitle => 'Elegir contacto';

  @override
  String get contactsExportTooltip => 'Exportar contactos';

  @override
  String get contactsEmptySelect => 'Aún no hay contactos guardados.';

  @override
  String get contactsEmpty =>
      'Aún no hay contactos guardados.\nToca + para añadir uno.';

  @override
  String get contactsYourWallets => 'Tus billeteras';

  @override
  String get contactsDeleteTitle => '¿Eliminar el contacto?';

  @override
  String get contactsDelete => 'Eliminar';

  @override
  String get contactsInvalidAddress => 'No es una dirección de Ergo válida';

  @override
  String get contactsAddTitle => 'Añadir contacto';

  @override
  String get contactsEditTitle => 'Editar contacto';

  @override
  String get contactsAdd => 'Añadir';

  @override
  String get createPhraseMismatch =>
      'La confirmación no coincide con la frase de recuperación';

  @override
  String get createSkipTitle => '¿Omitir la comprobación?';

  @override
  String get createSkipBody =>
      'Nada demostrará que la frase que escribiste está completa y en orden. Si una palabra está mal o falta, no se podrán recuperar los fondos de esta billetera.';

  @override
  String get createSkip => 'Omitir';

  @override
  String get createFailedTitle => 'No se pudo crear la billetera';

  @override
  String get createTitle => 'Crear billetera';

  @override
  String get createWriteDownTitle => 'Anota estas palabras';

  @override
  String get createWriteDownBody =>
      'Solo en papel. Son la única forma de recuperar esta billetera. Android bloquea aquí las capturas de pantalla; iOS oculta la app en el selector de apps y durante la grabación de pantalla.';

  @override
  String get createGenerate => 'Generar frase de recuperación';

  @override
  String get createHide => 'Ocultar';

  @override
  String get createReveal => 'Mostrar';

  @override
  String get createWroteDown => 'Ya las anoté';

  @override
  String get createConfirmTitle => 'Confirma la frase';

  @override
  String get createConfirmBody =>
      'Vuelve a escribir las palabras en orden. Así compruebas que la copia de seguridad se puede leer.';

  @override
  String get createPhraseLabel => 'Frase de recuperación';

  @override
  String get createContinue => 'Continuar';

  @override
  String get createSkipCheck => 'Omitir esta comprobación';

  @override
  String get createSetPin => 'Elige un PIN';

  @override
  String get createPinBody =>
      'El PIN descifra la clave en este dispositivo. No es una copia de seguridad.';

  @override
  String get createReplaceTitle => '¿Reemplazar la billetera existente?';

  @override
  String get createReplaceBody =>
      'Ya hay una billetera guardada en este dispositivo. Si la reemplazas, se sobrescribe la semilla cifrada. La frase de recuperación es la única forma de recuperar la billetera anterior.';

  @override
  String get createReplace => 'Reemplazar';

  @override
  String get createScreenshotBlockUnavailable =>
      'El bloqueo de capturas de pantalla no está disponible en este dispositivo';

  @override
  String get restoreEnterPhrase => 'Escribe una frase de recuperación';

  @override
  String get restoreWordCount =>
      'La frase de recuperación debe tener 12, 15, 18, 21 o 24 palabras';

  @override
  String get restoreFailedTitle => 'No se pudo restaurar la billetera';

  @override
  String get restoreTitle => 'Restaurar billetera';

  @override
  String get restoreIntro =>
      '12, 15, 18, 21 o 24 palabras, en orden — 15 es el estándar de Ergo. Frase de contraseña BIP-39 opcional, si usaste una.';

  @override
  String get restorePhraseHint => '12, 15, 18, 21 o 24 palabras';

  @override
  String get restorePassphraseLabel => 'Frase de contraseña BIP-39 (opcional)';

  @override
  String get restoreButton => 'Restaurar';

  @override
  String receiveCopied(String address) {
    return '$address copiada';
  }

  @override
  String get receiveTitle => 'Recibir';

  @override
  String get receiveUnusedAddress => 'Dirección sin usar';

  @override
  String get receiveAddress => 'Dirección para recibir';

  @override
  String get receiveFreshNote =>
      'Cuando se use esta dirección, se mostrará una nueva.';

  @override
  String get receiveStaticNote =>
      'Esta dirección no cambia. Activa Direcciones nuevas en Ajustes para usar una nueva después de cada pago.';

  @override
  String get receiveAmountLabel => 'Cantidad opcional (ERG)';

  @override
  String get receiveAddLabel => 'Añadir etiqueta';

  @override
  String get receiveEditLabel => 'Editar etiqueta';

  @override
  String get receiveCopyAddress => 'Copiar dirección';

  @override
  String get receiveShare => 'Compartir';

  @override
  String get receiveUsedAddresses => 'Direcciones usadas';

  @override
  String get receiveUsedAddressesNote =>
      'Las direcciones anteriores siguen funcionando; toca una para copiarla.';

  @override
  String get receiveAmountInvalid =>
      'La cantidad debe ser un número decimal, como 0.001';

  @override
  String get receiveAmountNotPositive => 'La cantidad debe ser mayor que cero';

  @override
  String get scanTitle => 'Escanear';

  @override
  String get scanCameraUnavailable =>
      'La cámara no está disponible. Permite el acceso a la cámara y vuelve a intentarlo.';

  @override
  String get scanBack => 'Volver';

  @override
  String get txArgusFee => 'Comisión de Argus';

  @override
  String get txLeftWallet => 'Salió de tu billetera';

  @override
  String get txBurned => 'Quemado';

  @override
  String get txBurnedNote => 'Ninguna salida los tiene ya: ya no existen.';

  @override
  String get txIssued => 'Emitido';

  @override
  String get txArrived => 'Llegó';

  @override
  String get txFees => 'Comisiones';

  @override
  String get txMovedBetween => 'Movido entre tus direcciones';

  @override
  String get txMovedNote => 'Cambio y cajas que se quedaron en esta billetera.';

  @override
  String get txTo => 'Para';

  @override
  String get txFrom => 'De';

  @override
  String get txContract => 'Contrato';

  @override
  String get txIncompleteInputs =>
      'Algunas entradas de esta transacción pendiente aún no se pueden leer; puede faltar lo que aportó la otra parte.';

  @override
  String txSentAmount(String amount) {
    return 'Enviado $amount';
  }

  @override
  String txReceivedAmount(String amount) {
    return 'Recibido $amount';
  }

  @override
  String get txTitle => 'Transacción';

  @override
  String txConfirmedAt(String height) {
    return 'Confirmada $height';
  }

  @override
  String get txConfirmed => 'Confirmada';

  @override
  String get txNotInBlock => 'Aún no está en un bloque';

  @override
  String get txTokensSent => 'Tokens enviados';

  @override
  String get txIdLabel => 'Id';

  @override
  String get txTokensReceived => 'Tokens recibidos';

  @override
  String txFurtherTokenIds(String count) {
    return '$count ID(s) de token más implicados — consulta el explorador.';
  }

  @override
  String get txIdCopied => 'ID de transacción copiado';

  @override
  String get txExplorerFailed => 'No se pudo abrir el explorador';

  @override
  String get txOpenExplorer => 'Abrir en el explorador';

  @override
  String txDetailsLoadFailed(String error) {
    return 'No se pudieron cargar los detalles de la transacción: $error';
  }

  @override
  String get txChange => 'Cambio';

  @override
  String txInputsCount(String count) {
    return 'Entradas ($count)';
  }

  @override
  String get txYours => 'Tuya';

  @override
  String get txInput => 'Entrada';

  @override
  String get txValueUnknown => 'valor desconocido';

  @override
  String txOutputsCount(String count) {
    return 'Salidas ($count)';
  }

  @override
  String get txMiner => 'Minería';

  @override
  String txDataInputsCount(String count) {
    return 'Entradas de datos ($count)';
  }

  @override
  String get txBox => 'Caja';

  @override
  String get txIdHeading => 'ID de transacción';

  @override
  String get txUnsignedCopied => 'Transacción sin firmar copiada';

  @override
  String get txCopyUnsigned => 'Copiar transacción sin firmar';

  @override
  String get dialogBiometricTitle => '¿Desbloquear con biometría?';

  @override
  String get dialogBiometricBody =>
      'Usa tu huella o tu cara para desbloquear esta billetera en lugar de escribir el PIN cada vez. Puedes cambiarlo más tarde en Ajustes › Seguridad.';

  @override
  String get dialogNotNow => 'Ahora no';

  @override
  String get dialogEnable => 'Activar';

  @override
  String get dialogBiometricEnabled => 'Desbloqueo biométrico activado';

  @override
  String get dialogBiometricFailed =>
      'No se pudo activar la biometría; vuelve a intentarlo en Ajustes › Seguridad';

  @override
  String get entryCurrentPin => 'PIN actual';

  @override
  String get entryContinue => 'Continuar';

  @override
  String get labelDialogTitle => 'Etiqueta de la dirección';

  @override
  String get labelOptional => 'Etiqueta (opcional)';

  @override
  String get coreTokenMetadataInvalid => 'Metadatos no válidos';

  @override
  String get coreTokenMetadataConflict => 'Conflicto de metadatos';

  @override
  String get coreTokenCollection => 'Token de colección';

  @override
  String get coreTokenDeclaredNftUnsupported =>
      'NFT declarado · tipo no compatible';

  @override
  String coreTokenSingleUnitArtwork(String kind) {
    return 'Obra de una sola unidad · $kind';
  }

  @override
  String get coreTokenDeclaredArtworkMultiple =>
      'Obra declarada · varias unidades';

  @override
  String get coreTokenDeclaredArtworkUnconfirmed =>
      'Obra declarada · suministro sin confirmar';

  @override
  String get coreTokenSingleUnit => 'Token de una sola unidad';

  @override
  String get coreTokenMetadataUnavailable => 'Token · metadatos no disponibles';

  @override
  String get corePinLength => 'El PIN debe tener de 6 a 32 caracteres';

  @override
  String coreWalletNumbered(String number) {
    return 'Billetera $number';
  }

  @override
  String get coreCuratedTokenSource =>
      'Lista de tokens seleccionados por Argus';

  @override
  String coreBroadcastActivityWarning(String error) {
    return 'Transacción enviada, pero no se pudo actualizar Actividad: $error. Guarda este ID de transacción.';
  }

  @override
  String get coreActivityLoadFailed => 'No se pudo cargar la actividad';

  @override
  String get coreWalletLocked => 'La billetera está bloqueada';

  @override
  String holdingsTokenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens',
      one: '1 token',
    );
    return '$_temp0';
  }

  @override
  String holdingsFundsElsewhere(String parts, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'incl. $parts en otras $count direcciones',
      one: 'incl. $parts en otra dirección',
    );
    return '$_temp0';
  }

  @override
  String holdingsFundsElsewhereHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'incl. fondos en otras $count direcciones',
      one: 'incl. fondos en otra dirección',
    );
    return '$_temp0';
  }

  @override
  String get previewGatewayOriginRule =>
      'Usa un origen de pasarela HTTPS en el puerto 443, sin credenciales, ruta ni consulta.';

  @override
  String get previewGatewayNotPublic =>
      'La dirección de la pasarela no es pública.';

  @override
  String get previewGatewayPublicHostname =>
      'Usa un nombre de host público para la pasarela.';

  @override
  String get previewCidMalformed => 'CID de IPFS mal formado.';

  @override
  String get previewOnlyIpfs =>
      'Solo se pueden mostrar obras de IPFS. Se rechazan los hosts del emisor porque el emisor elegiría quién se entera de que la miraste.';

  @override
  String get previewCidNoncanonical => 'CID de IPFS no canónico.';

  @override
  String get previewCidUnsupported => 'CID de IPFS no compatible.';

  @override
  String get previewCidFormat =>
      'Usa una URI de IPFS con CIDv0 o con CIDv1 en base32 en minúsculas.';

  @override
  String get previewPathUnsupported => 'Ruta de IPFS no compatible.';

  @override
  String get previewImageDimensions =>
      'Las dimensiones de la imagen superan 4096 por eje u 8 megapíxeles.';

  @override
  String get previewArtworkTooLarge => 'La obra supera 5 MiB.';

  @override
  String get previewPngMalformed => 'PNG mal formado.';

  @override
  String get previewPngAnimated => 'Los PNG animados no son compatibles.';

  @override
  String get previewJpegMalformed => 'JPEG mal formado.';

  @override
  String get previewJpegFrame => 'Marco JPEG no compatible.';

  @override
  String get previewFormatMismatch =>
      'Solo se admiten PNG y JPEG estáticos cuyos bytes coincidan con el tipo MIME.';

  @override
  String get previewHashMismatch =>
      'El contenido no coincide con el hash de emisión.';

  @override
  String get previewSaveSettingFailed =>
      'No se pudo guardar el ajuste de vista previa.';

  @override
  String get previewSaveGatewayFailed => 'No se pudo guardar la pasarela.';

  @override
  String get previewRequestTimedOut =>
      'Se agotó el tiempo de la solicitud de vista previa.';

  @override
  String get previewConnectionTimedOut =>
      'Se agotó el tiempo de conexión de la vista previa.';

  @override
  String get previewCancelled => 'Vista previa cancelada.';

  @override
  String get previewConnectionRefused => 'Conexión de vista previa rechazada.';

  @override
  String get previewHostBindingFailed =>
      'No se pudo vincular el nombre de host de la pasarela.';

  @override
  String get previewRedirectBlocked => 'Redirección bloqueada.';

  @override
  String get previewNoArtwork => 'La pasarela no devolvió la obra.';

  @override
  String get previewCompressionRefused => 'Compresión de transporte rechazada.';

  @override
  String get previewStaticOnly => 'Solo se admiten PNG y JPEG estáticos.';

  @override
  String get previewBusy => 'Otra vista previa aún está terminando.';

  @override
  String get previewIntegrityConsentRequired =>
      'Ver sin comprobación de integridad requiere tu consentimiento explícito.';

  @override
  String get previewAnimatedUnsupported =>
      'Las obras animadas no son compatibles.';

  @override
  String get previewDecodedTooLarge =>
      'La vista previa decodificada supera el tamaño objetivo.';

  @override
  String previewLoadThroughTitle(String host) {
    return '¿Cargar la vista previa a través de $host?';
  }

  @override
  String get previewLoadConsentBody =>
      'Esta pasarela puede ver tu dirección IP y qué obra se pidió. Se descargarán hasta 5 MiB. La obra puede tener contenido no solicitado o engañoso.';

  @override
  String get previewLoad => 'Cargar vista previa';

  @override
  String get previewHashMissingTitle => 'Hash de emisión ausente o no válido';

  @override
  String get previewHashMissingBody =>
      'El formato y las dimensiones pasaron las comprobaciones de la vista previa, pero estos bytes no se pueden comparar con un hash de emisión.';

  @override
  String get previewViewWithoutIntegrity =>
      'Ver sin comprobación de integridad';

  @override
  String get previewMatchesHash => 'Coincide con el hash de emisión';

  @override
  String get previewViewedWithoutIntegrity =>
      'Mostrada sin comprobación de integridad';

  @override
  String get previewLoadFailed => 'No se pudo cargar la vista previa.';

  @override
  String get previewMetadataUnsupported =>
      'La vista previa no es compatible con estos metadatos.';

  @override
  String get previewDisabled => 'Vistas previas remotas desactivadas.';

  @override
  String get previewNoGateway =>
      'No hay ninguna pasarela configurada. Las vistas previas no están disponibles.';

  @override
  String get previewUnavailableNow =>
      'Vistas previas no disponibles con la billetera bloqueada, oculta, sin conexión o fuera de esta sesión.';

  @override
  String get previewViewArtwork => 'Ver obra';

  @override
  String get previewHide => 'Ocultar vista previa';

  @override
  String get previewLoading => 'Cargando vista previa…';

  @override
  String get previewCancel => 'Cancelar vista previa';

  @override
  String get previewSettingsLink => 'Ajustes de vistas previas remotas';

  @override
  String get previewGatewaySaved =>
      'Pasarela guardada. Cada obra sigue requiriendo tu consentimiento.';

  @override
  String get previewSettingsTitle => 'Vistas previas remotas';

  @override
  String get previewNeverTitle => 'No cargar nunca vistas previas remotas';

  @override
  String get previewNeverSubtitle =>
      'Desactiva la carga y cierra las vistas previas abiertas. La decodificación de imágenes no tiene un límite total de memoria que se pueda imponer y una decodificación nativa en curso no se puede interrumpir. Usa este interruptor para evitar riesgos de memoria o de seguridad del decodificador.';

  @override
  String get previewSettingsIpfsOnly =>
      'Solo se pueden mostrar obras de IPFS. Se rechazan los hosts elegidos por el emisor porque el emisor elegiría quién se entera de que la miraste. No hay pasarela predeterminada ni alternativa.';

  @override
  String get previewGatewayFieldLabel => 'Tu pasarela IPFS HTTPS';

  @override
  String get previewGatewayFieldHelper =>
      'Solo el origen, puerto 443. Déjalo vacío para quitarla.';

  @override
  String get previewGatewayCheckInfo =>
      'Al guardar, se resuelve el nombre de host de la pasarela para comprobar que sus direcciones son públicas. Al cargar, se vuelve a comprobar y solo se conecta a esa dirección. La pasarela puede ver tu IP y qué obra pides.';

  @override
  String get previewCheckingGateway => 'Comprobando pasarela…';

  @override
  String get previewSaveGateway => 'Guardar pasarela';

  @override
  String get sendNoSpendableAddresses => 'No hay direcciones para gastar';

  @override
  String get sendCouldNotListBoxes => 'No se pudieron listar tus cajas';

  @override
  String sendContactName(String name) {
    return 'Contacto: $name';
  }

  @override
  String get sendSpendableUnknown => 'No se conoce el saldo disponible';

  @override
  String get sendNotEnoughForFee =>
      'No hay suficientes ERG para la comisión y el cambio';

  @override
  String get sendNoTokenSelected => 'No hay ningún token elegido';

  @override
  String get sendSaveToContacts => 'Guardar en contactos';

  @override
  String get sendContactSaved => 'Contacto guardado';

  @override
  String sendExceedsBalance(String balance) {
    return 'La cantidad más la comisión supera tus $balance';
  }

  @override
  String get sendCouldNotPrepare => 'No se pudo preparar el envío';

  @override
  String get sendClipboardTitle => 'El portapapeles tiene otra dirección';

  @override
  String get sendClipboardDiffersOne =>
      'Algo que copiaste antes es una dirección de Ergo distinta del destinatario. Un malware puede cambiar las direcciones del portapapeles. Comprueba cada carácter.';

  @override
  String get sendClipboardDiffersMany =>
      'Algo que copiaste antes es una dirección de Ergo distinta de todos los destinatarios. Un malware puede cambiar las direcciones del portapapeles. Comprueba cada carácter.';

  @override
  String get sendRecipientLabel => 'Destinatario:';

  @override
  String get sendRecipientsLabel => 'Destinatarios:';

  @override
  String get sendClipboardLabel => 'Portapapeles:';

  @override
  String get sendGoBack => 'Volver';

  @override
  String get sendRecipientCorrect => 'El destinatario es correcto';

  @override
  String get sendRecipientsCorrect => 'Los destinatarios son correctos';

  @override
  String get sendTotalSent => 'Total enviado';

  @override
  String get sendAmount => 'Cantidad';

  @override
  String sendFeePaidIn(String token) {
    return 'Comisión de minería pagada en $token';
  }

  @override
  String get sendTokenFallback => 'token';

  @override
  String sendTokensFor(String tokens, String erg) {
    return '$tokens por $erg';
  }

  @override
  String get sendConfirmMulti => 'Confirmar envío a varios destinatarios';

  @override
  String get sendConfirm => 'Confirmar envío';

  @override
  String get sendSent => '¡Enviado!';

  @override
  String sendAvailable(String amount) {
    return 'Disponible: $amount';
  }

  @override
  String sendAllAddresses(String all) {
    return 'Las $all direcciones';
  }

  @override
  String sendSomeAddresses(String picked, String all) {
    return '$picked de $all direcciones';
  }

  @override
  String sendBoxesChosen(String count) {
    return '$count cajas elegidas';
  }

  @override
  String sendFeeErg(String amount) {
    return 'Comisión $amount ERG';
  }

  @override
  String sendFeeIn(String token) {
    return 'Comisión en $token';
  }

  @override
  String sendTokensPage(String count, String page, String pages) {
    return '$count tokens elegidos · Página $page de $pages';
  }

  @override
  String get sendPreviousTokens => 'Tokens anteriores';

  @override
  String get sendNextTokens => 'Tokens siguientes';

  @override
  String sendSendsOne(String token) {
    return 'Envía 1 $token · Disponible: 1';
  }

  @override
  String sendTokenAmount(String token) {
    return 'Cantidad de $token';
  }

  @override
  String get sendMax => 'MÁX';

  @override
  String get sendEnterAmount => 'Escribe una cantidad';

  @override
  String get sendTooMuch => 'Demasiado';

  @override
  String sendRemoveToken(String token) {
    return 'Quitar $token';
  }

  @override
  String sendPlusTokens(String count) {
    return ' + $count tokens';
  }

  @override
  String get sendRawTitle => 'Transacción firmada en bruto';

  @override
  String get sendRawNote =>
      'La transacción está firmada pero no se ha difundido. Comparte o guarda la transacción en bruto para enviarla más tarde desde un explorador u otra billetera.';

  @override
  String get sendDestination => 'Destino';

  @override
  String get sendRecipientAddress => 'Dirección del destinatario';

  @override
  String get sendRecipientHint => 'O toca contactos para elegir uno guardado';

  @override
  String get sendRequired => 'Obligatorio';

  @override
  String get sendAsset => 'Activo';

  @override
  String get sendChooseTokens => 'Elegir tokens';

  @override
  String sendChooseTokensCount(String count) {
    return 'Elegir tokens ($count)';
  }

  @override
  String get sendMinimumBox => 'Mínimo 0.001 ERG';

  @override
  String get sendErgWithIt => 'ERG que se envían con él (opcional)';

  @override
  String sendBlankFundsTokens(String available) {
    return 'En blanco, lleva el mínimo de ERG para estos tokens. La revisión muestra la cantidad exacta. $available';
  }

  @override
  String get sendAdditionalRecipients => 'Más destinatarios';

  @override
  String sendRecipientNAddress(String number) {
    return 'Dirección del destinatario $number';
  }

  @override
  String get sendAmountErg => 'Cantidad (ERG)';

  @override
  String get sendBlankFundsToken =>
      'En blanco, lleva el mínimo de ERG para este token.';

  @override
  String get sendTokenNone => 'Ninguno';

  @override
  String get sendEnterTokenAmount => 'Escribe una cantidad de token';

  @override
  String sendYouHold(String amount) {
    return 'Tienes $amount';
  }

  @override
  String get sendAddRecipient => 'Añadir otro destinatario';

  @override
  String get sendAdvanced => 'Avanzado';

  @override
  String get sendErgCarried => 'ERG que lleva el token';

  @override
  String sendBlankMinimumBox(String amount) {
    return 'Déjalo en blanco para el valor mínimo de caja, $amount.';
  }

  @override
  String get sendChoose => 'Elegir';

  @override
  String get sendSpendFrom => 'Gastar desde';

  @override
  String get sendDeselectedNote =>
      'Las direcciones sin marcar quedan fuera de la selección de monedas.';

  @override
  String get sendUseAllAddresses => 'Usar todas las direcciones';

  @override
  String get sendPayFeeIn => 'Pagar la comisión de minería en';

  @override
  String get sendPayFeeInHelp =>
      'Una comisión en token se compra a una caja babel en la cadena a su precio publicado; la comisión en ERG de abajo es lo que compra.';

  @override
  String get sendMinerFeeErg => 'Comisión de minería (ERG)';

  @override
  String sendBlankDefaultFee(String amount) {
    return 'Déjalo en blanco para usar la predeterminada, $amount.';
  }

  @override
  String sendMinimum(String amount) {
    return 'Mínimo $amount';
  }

  @override
  String get sendReview => 'Revisar';

  @override
  String get sendChooseInputs => 'Elegir entradas';

  @override
  String get sendAutoInputsNote =>
      'Chatui elegirá las cajas por ti. Elige algunas para controlar exactamente qué gasta esta transacción.';

  @override
  String sendShortBy(String amount) {
    return 'Faltan $amount para esta cantidad más las comisiones.';
  }

  @override
  String sendBoxTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens',
      one: '1 token',
    );
    return '$_temp0';
  }

  @override
  String sendBoxBlock(String height) {
    return 'bloque $height';
  }

  @override
  String utxoLoadFailed(String error) {
    return 'No se pudieron cargar los UTXO: $error';
  }

  @override
  String get utxoSpreadOut =>
      'Tus cajas están repartidas en muchas direcciones, y unirlas vincularía esas direcciones. Consolidar lo hace de todos modos.';

  @override
  String get utxoNothingToClean => 'Ahora no hay nada que limpiar';

  @override
  String get utxoConsolidateNeedsTwo => 'Consolidar necesita al menos 2 cajas';

  @override
  String get utxoConsolidateTitle => 'Consolidar UTXO';

  @override
  String utxoConsolidateInN(String count) {
    return 'Consolidar en $count transacciones';
  }

  @override
  String get utxoBoxesMerged => 'Cajas unidas';

  @override
  String get utxoInto => 'En';

  @override
  String get utxoTotalValueIn => 'Valor total de entrada';

  @override
  String get utxoTokenTypesCarried => 'Tipos de token incluidos';

  @override
  String get utxoValueAfterFees => 'Valor tras comisiones';

  @override
  String get utxoConsolidateOneDetail =>
      'Cada caja elegida se gasta en una caja nueva con todos sus ERG y tokens.';

  @override
  String utxoConsolidateManyDetail(String max, String count) {
    return 'Las transacciones de Ergo se mantienen por debajo de $max entradas cada una, así que esto se hace en $count transacciones seguidas. Después puedes volver a consolidar los resultados.';
  }

  @override
  String get utxoSignBroadcast => 'Firmar y difundir';

  @override
  String utxoSignBroadcastN(String count) {
    return 'Firmar y difundir $count';
  }

  @override
  String utxoStoppedAfter(String done, String total) {
    return 'Se detuvo tras $done de $total. Actualiza las cajas y revisa la actividad antes de reintentar.';
  }

  @override
  String get utxoConsolidationSubmitted => 'Consolidación enviada';

  @override
  String get utxoRefreshBeforeRetry =>
      'Actualiza las cajas y revisa la actividad antes de reintentar.';

  @override
  String get utxoFewDust => 'Hay menos de dos cajas de polvo para barrer';

  @override
  String utxoNewRent(String fee, String when) {
    return '$fee, vence $when';
  }

  @override
  String utxoNewRentCapped(String fee, String when) {
    return '$fee, vence $when; no guarda más que eso';
  }

  @override
  String get utxoSuggestedCleanup => 'Limpieza sugerida';

  @override
  String utxoMergedAtAddress(String count, String total) {
    return '$count de $total en esta dirección';
  }

  @override
  String get utxoResultingBoxes => 'Cajas resultantes';

  @override
  String get utxoOneOrMore => '1 o más';

  @override
  String get utxoRentClocksRestarted => 'Relojes de alquiler reiniciados';

  @override
  String get utxoNewBoxRent => 'Alquiler de la caja nueva';

  @override
  String utxoCleanupDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cada caja de la lista se gasta en $count cajas nuevas en esta dirección, con todos sus ERG y tokens. Una caja movida empieza un nuevo reloj de alquiler de almacenamiento de 4 años. Solo se unen cajas de esta dirección, así que no se vincula ninguna dirección.',
      one:
          'Cada caja de la lista se gasta en una caja nueva en esta dirección, con todos sus ERG y tokens. Una caja movida empieza un nuevo reloj de alquiler de almacenamiento de 4 años. Solo se unen cajas de esta dirección, así que no se vincula ninguna dirección.',
    );
    return '$_temp0';
  }

  @override
  String get utxoCleanupSubmitted => 'Limpieza enviada';

  @override
  String utxoAtRisk(String count) {
    return '$count en riesgo';
  }

  @override
  String get utxoSplitTitle => 'Dividir UTXO';

  @override
  String get utxoOutputsCreated => 'Salidas creadas';

  @override
  String utxoBoxesN(String count) {
    return '$count cajas';
  }

  @override
  String get utxoAmountPerBox => 'Cantidad por caja';

  @override
  String utxoTokensN(String count) {
    return '$count tokens';
  }

  @override
  String get utxoChangeReturned => 'Cambio devuelto';

  @override
  String get utxoMinerFeeTitle => 'Comisión de minería';

  @override
  String get utxoFeeByBuilder =>
      'La comisión la calcula el constructor de transacciones.';

  @override
  String get utxoSignBroadcastSplit => 'Firmar y difundir la división';

  @override
  String get utxoSplitSubmitted => 'División enviada';

  @override
  String utxoSeparateTitle(String count) {
    return 'Separar $count tipos de token';
  }

  @override
  String get utxoSourceBox => 'Caja de origen';

  @override
  String get utxoInputsSpent => 'Entradas gastadas';

  @override
  String get utxoTokenBoxes => 'Cajas de tokens';

  @override
  String utxoRawUnits(String amount, String raw) {
    return '$amount ($raw unidades base)';
  }

  @override
  String get utxoErgInTokenBoxes => 'ERG en cajas de tokens';

  @override
  String get utxoErgChange => 'Cambio en ERG';

  @override
  String get utxoSeparateDetail =>
      'Cada tipo de token conserva todo su saldo en una caja aparte en tu dirección de origen. Todos los ERG restantes vuelven a tu billetera.';

  @override
  String get utxoSignBroadcastSeparation => 'Firmar y difundir la separación';

  @override
  String get utxoSeparationSubmitted => 'Separación de tokens enviada';

  @override
  String get utxoRestructureTitle => 'Reestructurar UTXO';

  @override
  String get utxoInputsConsumed => 'Entradas consumidas';

  @override
  String get utxoOutputsGenerated => 'Salidas generadas';

  @override
  String get utxoTotalValueInTitle => 'Valor total de entrada';

  @override
  String get utxoAllocatedToOutputs => 'Asignado a salidas';

  @override
  String get utxoChangeOutput => 'Salida de cambio';

  @override
  String get utxoSignBroadcastRestructure =>
      'Firmar y difundir la reestructuración';

  @override
  String get utxoRestructureSubmitted => 'Reestructuración enviada';

  @override
  String get utxoScreenTitle => 'Cajas de la billetera';

  @override
  String get utxoLastConsolidation => 'Resultado de la última consolidación';

  @override
  String get utxoRefreshBoxes => 'Actualizar cajas';

  @override
  String utxoCount(String count) {
    return '$count UTXO';
  }

  @override
  String utxoValueTokens(String value, String count) {
    return '$value · $count tokens';
  }

  @override
  String utxoDustLine(int count, String limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cajas de polvo por debajo de $limit.',
      one: '1 caja de polvo por debajo de $limit.',
    );
    return '$_temp0';
  }

  @override
  String get utxoOldestFirst =>
      'Primero las cajas más antiguas. Los envíos automáticos prefieren las cajas antiguas que se pueden usar, para reducir el riesgo de alquiler de almacenamiento; las reglas de privacidad y tu selección manual se siguen aplicando.';

  @override
  String get utxoConsolidate => 'Consolidar';

  @override
  String get utxoSplit => 'Dividir';

  @override
  String get utxoRestructure => 'Reestructurar';

  @override
  String get utxoSeparateTokenTypes => 'Separar tipos de token';

  @override
  String utxoSweepDust(String count) {
    return 'Barrer $count cajas de polvo en una';
  }

  @override
  String get utxoSearchHint => 'Buscar ID de caja o token...';

  @override
  String utxoFilterAll(String count) {
    return 'Todas ($count)';
  }

  @override
  String utxoFilterErgOnly(String count) {
    return 'Solo ERG ($count)';
  }

  @override
  String utxoFilterTokens(String count) {
    return 'Tokens ($count)';
  }

  @override
  String utxoFilterDust(String count) {
    return 'Polvo ($count)';
  }

  @override
  String utxoFilterRent(String count) {
    return 'Alquiler ($count)';
  }

  @override
  String utxoClearSelection(String count) {
    return 'Borrar ($count)';
  }

  @override
  String get utxoSelectAll => 'Elegir todas';

  @override
  String get utxoNoMatch => 'Ningún UTXO coincide con el filtro';

  @override
  String get utxoCopyBoxId => 'Copiar ID de caja';

  @override
  String get utxoBoxIdCopied => 'ID de caja copiado';

  @override
  String utxoHeight(String height) {
    return 'Alt.: $height';
  }

  @override
  String utxoSplitEqual(String count, String amount) {
    return '$count cajas de $amount';
  }

  @override
  String utxoSplitWithChange(String count, String amount, String change) {
    return '$count cajas de $amount · $change de cambio';
  }

  @override
  String utxoSplitToken(String count, String amount, String token, String erg) {
    return '$count cajas de $amount $token, cada una con $erg';
  }

  @override
  String utxoSplitNotEnough(String count) {
    return 'No hay suficientes ERG para $count cajas después de comisiones';
  }

  @override
  String get utxoSplitEnterErg =>
      'Escribe una cantidad de al menos 0.001 ERG que quepa en la selección';

  @override
  String get utxoSplitEnterToken =>
      'Escribe una cantidad de token que quepa en la selección';

  @override
  String utxoSplitFrom(int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'De $count cajas con $total.',
      one: 'De 1 caja con $total.',
    );
    return '$_temp0';
  }

  @override
  String get utxoEqualParts => 'Partes iguales';

  @override
  String get utxoAmountEach => 'Cantidad por caja';

  @override
  String get utxoHowManyBoxes => 'CUÁNTAS CAJAS';

  @override
  String get utxoCustom => 'Otra';

  @override
  String utxoTokenAvailable(String token, String amount) {
    return '$token · $amount disponibles';
  }

  @override
  String utxoPerBox(String token) {
    return '$token por caja';
  }

  @override
  String get utxoErgPerBox => 'ERG por caja';

  @override
  String get utxoAdjustCount =>
      'Ajusta el número o la cantidad hasta que quepa en la selección.';

  @override
  String utxoSplitFeeNote(String fee) {
    return 'Comisión de minería: $fee. Los ERG restantes y todos los tokens vuelven a ti como cambio.';
  }

  @override
  String get utxoPreviewSplit => 'Vista previa de la división';

  @override
  String get utxoCustomRestructure => 'Reestructuración personalizada';

  @override
  String get utxoAddOutput => 'Añadir salida';

  @override
  String get utxoDefineOutputs =>
      'Define las cajas de salida que quieres. El resto vuelve como cambio.';

  @override
  String utxoBoxErgAmount(String number) {
    return 'Cantidad de ERG de la caja #$number';
  }

  @override
  String get utxoInvalidAmount =>
      'Cantidad no válida: mínimo 0.001 ERG por caja';

  @override
  String get utxoPreviewRestructure => 'Vista previa de la reestructuración';

  @override
  String utxoSelectedCount(String count) {
    return '$count elegidas';
  }

  @override
  String rentDueWithin(int count, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vencen en menos de $days días',
      one: '1 vence en menos de $days días',
    );
    return '$_temp0';
  }

  @override
  String rentBlock(String height) {
    return 'bloque $height';
  }

  @override
  String rentAtRiskNow(String fee) {
    return 'En riesgo: no guarda más que su alquiler de $fee, así que se puede cobrar ya, tokens incluidos.';
  }

  @override
  String rentAtRiskFrom(String fee, String block, String when) {
    return 'En riesgo: no guarda más que su alquiler de $fee. Desde el $block ($when) se puede cobrar entera, tokens incluidos.';
  }

  @override
  String rentWholeNow(String whole) {
    return 'El alquiler se llevaría toda esta caja ($whole); se puede cobrar ya.';
  }

  @override
  String rentWholeFrom(String whole, String block, String when) {
    return 'El alquiler se llevaría toda esta caja ($whole), desde el $block ($when).';
  }

  @override
  String rentChargeableNow(String fee, String block) {
    return 'Ya se puede cobrar un alquiler de almacenamiento de $fee (vence en el $block).';
  }

  @override
  String rentDue(String fee, String when, String block) {
    return 'Alquiler de almacenamiento de $fee, vence $when ($block).';
  }

  @override
  String get rentIntoOne => 'en una';

  @override
  String rentIntoCount(String count) {
    return 'en $count';
  }

  @override
  String get rentIntoOneOrMore => 'en una o más';

  @override
  String get rentFewerBoxes =>
      'Menos cajas hacen que cada envío sea pequeño y barato.';

  @override
  String get rentMovingRestarts =>
      'Mover cajas antiguas también reinicia su reloj de alquiler de almacenamiento de 4 años.';

  @override
  String rentMergeBoxes(String count, String address, String into) {
    return 'Une $count cajas de $address $into.';
  }

  @override
  String rentMergeBoxesOf(
    String count,
    String total,
    String address,
    String into,
  ) {
    return 'Une $count de $total cajas de $address $into.';
  }

  @override
  String rentCleanupFee(String fee) {
    return 'Comisión: $fee. Solo se mueven las cajas de esta dirección, así que no se vincula ninguna dirección.';
  }

  @override
  String get rentReviewCleanup => 'Revisar la limpieza';

  @override
  String rentCantCover(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cajas no cubren su alquiler de almacenamiento',
      one: '1 caja no cubre su alquiler de almacenamiento',
    );
    return '$_temp0';
  }

  @override
  String rentFallsDue(int count, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vencen en menos de $days días',
      one: '1 vence en menos de $days días',
    );
    return '$_temp0';
  }

  @override
  String rentReasonAnd(String first, String second) {
    return '$first y $second';
  }

  @override
  String rentReasonMoving(String reason) {
    return '$reason. Moverlas inicia un nuevo reloj de alquiler de 4 años.';
  }

  @override
  String get rentChecking => 'Comprobando el alquiler de almacenamiento…';

  @override
  String get rentUnavailable =>
      'Alquiler de almacenamiento no disponible: no se pudo leer tu nodo. Actualiza para volver a intentarlo.';

  @override
  String get rentNotChecked =>
      'Aún no se ha comprobado el alquiler de almacenamiento.';

  @override
  String rentAtRiskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cajas en riesgo de cobro',
      one: '1 caja en riesgo de cobro',
    );
    return '$_temp0';
  }

  @override
  String rentUnmeasured(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cajas no se pudieron medir.',
      one: '1 caja no se pudo medir.',
    );
    return '$_temp0';
  }

  @override
  String rentRateLine(String rate) {
    return 'Tarifa: $rate.';
  }

  @override
  String rentErgOnlyWhole(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count cajas solo de ERG no valen más que su alquiler, que se las llevaría enteras.',
      one:
          '1 caja solo de ERG no vale más que su alquiler, que se la llevaría entera.',
    );
    return '$_temp0';
  }

  @override
  String rentLeadParts(String parts) {
    return 'Alquiler de almacenamiento: $parts.';
  }

  @override
  String rentLeadAllCovered(String days) {
    return 'Alquiler de almacenamiento: nada vence en menos de $days días y cada caja cubre su alquiler.';
  }

  @override
  String rentLeadAllMeasuredCovered(String days) {
    return 'Alquiler de almacenamiento: nada vence en menos de $days días y cada caja medida cubre su alquiler.';
  }

  @override
  String rentLeadNoTokenRisk(String days) {
    return 'Alquiler de almacenamiento: ninguna caja con tokens está en riesgo y nada más vence en menos de $days días.';
  }

  @override
  String rentLeadNoMeasuredTokenRisk(String days) {
    return 'Alquiler de almacenamiento: ninguna caja medida con tokens está en riesgo y nada más vence en menos de $days días.';
  }

  @override
  String get confirmSignBroadcast => 'Firmar y difundir';

  @override
  String get confirmWarnBroadcast =>
      'Esto firmará y difundirá una transacción a la red. No se puede deshacer una vez confirmada.';

  @override
  String get confirmWarnPage =>
      'Esto firmará una transacción y se la pasará a la página, que la difunde. Una vez difundida no se puede deshacer.';

  @override
  String get confirmTo => 'PARA';

  @override
  String get confirmDetails => 'Detalles';

  @override
  String get confirmSignOnly => 'Solo firmar';

  @override
  String get confirmTxDetails => 'Detalles de la transacción';

  @override
  String get rentHintDefaultRate => ' a la tarifa por defecto';

  @override
  String rentHintCharge(String fee, String rate, String bytes) {
    return 'Ergo cobra alquiler de almacenamiento a las cajas que no se mueven en 4 años: unos $fee$rate para esta caja de $bytes bytes.';
  }

  @override
  String get rentHintCovers => 'Esta cantidad lo cubre.';

  @override
  String get rentHintLess =>
      'Una caja con menos se puede cobrar entera, tokens incluidos.';

  @override
  String rentHintExtraBoxes(String count) {
    return 'Estos tokens necesitan $count cajas; las de más solo llevan su mínimo de ERG.';
  }

  @override
  String rentHintSuggested(String amount) {
    return 'Sugerido: $amount';
  }

  @override
  String get rentHintUseSuggested => 'Usar el sugerido';

  @override
  String get txResultId => 'ID de la transacción';

  @override
  String get txResultIdCopied => 'ID de la transacción copiado';

  @override
  String get txViewOnExplorer => 'Ver en el explorador';

  @override
  String txBookkeepingFailed(String error) {
    return 'Transacción enviada, pero no se pudo actualizar el seguimiento local: $error. Guarda este ID de transacción y revisa la actividad antes de reintentar.';
  }

  @override
  String get txBatchTitle => 'Resultado de la consolidación';

  @override
  String txBatchSubmitted(String done, String total) {
    return '$done de $total transacciones enviadas';
  }

  @override
  String txBatchStopped(String done, String total) {
    return 'Se detuvo antes, tras $done de $total. No se intentaron más lotes.';
  }

  @override
  String txBatchItem(String number) {
    return 'Transacción $number';
  }

  @override
  String get pickerSearchHint => 'Buscar nombre o ID de token';

  @override
  String get pickerNoMatch => 'Ningún token coincide con esa búsqueda.';

  @override
  String pickerSelect(String token) {
    return 'Elegir $token';
  }

  @override
  String pickerSelectedCount(String count) {
    return '$count elegidos';
  }

  @override
  String get amountEnterErg => 'Escribir ERG';

  @override
  String amountEnterFiat(String currency) {
    return 'Escribir $currency';
  }

  @override
  String get separateTitle => 'Separar tokens';

  @override
  String get separateIntro =>
      'Mueve cada tipo de token, con todo su saldo, a una caja aparte en tu billetera. Esto usa una transacción.';

  @override
  String get separateNoSource => 'Ninguna caja tiene varios tipos de token.';

  @override
  String separateSourceItem(String box, String count, String value) {
    return '$box · $count tokens · $value';
  }

  @override
  String separateEachHolds(String min, String fee) {
    return 'Cada caja de token tiene al menos $min. Comisión de minería: $fee.';
  }

  @override
  String separateMinimumNeeded(String amount) {
    return 'ERG mínimos necesarios: $amount';
  }

  @override
  String get separateTokensToSeparate => 'Tokens que separar';

  @override
  String separateRawUnits(String tokenId, String amount) {
    return '$tokenId\n$amount unidades base';
  }

  @override
  String get separateAddFundingTitle => 'Añadir fondos en ERG';

  @override
  String get separateFundingNote =>
      'Solo se muestran las cajas solo de ERG de la dirección de origen, primero las más antiguas. Elige las que quieras gastar.';

  @override
  String separateFundingItem(String box, String height) {
    return '$box · Altura $height';
  }

  @override
  String get separateHeightUnknown => 'desconocida';

  @override
  String separatePlanLine(int inputs, String tokens) {
    String _temp0 = intl.Intl.pluralLogic(
      inputs,
      locale: localeName,
      other: '$inputs cajas de entrada → $tokens cajas de token',
      one: '1 caja de entrada → $tokens cajas de token',
    );
    return '$_temp0';
  }

  @override
  String separatePlanLineChange(int inputs, String tokens) {
    String _temp0 = intl.Intl.pluralLogic(
      inputs,
      locale: localeName,
      other:
          '$inputs cajas de entrada → $tokens cajas de token + cambio en ERG',
      one: '1 caja de entrada → $tokens cajas de token + cambio en ERG',
    );
    return '$_temp0';
  }

  @override
  String separateChangeReturned(String amount) {
    return 'ERG devueltos como cambio: $amount';
  }

  @override
  String get separateStayNote =>
      'Todos los tokens y los ERG restantes se quedan en tu billetera. Un resto menor de 0.001 ERG se guarda en la primera caja de token.';

  @override
  String get separateReview => 'Revisar la separación';

  @override
  String get homeOnAnotherAddress => 'en otra dirección';

  @override
  String homeOnOtherAddresses(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'en otras $n direcciones',
      one: 'en $n dirección más',
    );
    return '$_temp0';
  }

  @override
  String homeFundsWhere(String where) {
    return 'Fondos $where';
  }

  @override
  String homeInclFundsWhere(String where) {
    return 'incl. fondos $where';
  }

  @override
  String homePartsWhere(String parts, String where) {
    return '$parts $where';
  }

  @override
  String homeInclPartsWhere(String parts, String where) {
    return 'incl. $parts $where';
  }

  @override
  String homeErgPendingFigure(String figure) {
    return '$figure ERG pendientes';
  }

  @override
  String homePendingConfirmed(String lead, String confirmed) {
    return '$lead · $confirmed confirmados';
  }

  @override
  String get homeLockedCaps => 'BLOQUEADA';

  @override
  String get formatUnconfirmed => 'Sin confirmar';

  @override
  String get celautDepositRowTitle => 'Depósito en Celaut';

  @override
  String get celautDepositRowSubtitle =>
      'Paga a un nodo en ERG desde la billetera';

  @override
  String get celautDepositScreenTitle => 'Depósito en Celaut';

  @override
  String get celautDepositIntro =>
      'Paga ERG a un nodo para obtener MU, la unidad de cuenta del nodo. Paga la billetera de la app. El nodo recibe un pago simple y puede quedárselo, así que deposita cantidades pequeñas. El saldo queda con el ID de cliente de la app en ese nodo, que la app guarda en su base de datos cifrada de Celaut.';

  @override
  String get celautDepositNodeLabel => 'Dirección del nodo';

  @override
  String get celautDepositNodeHint => 'host:puerto';

  @override
  String get celautDepositCheck => 'Comprobar el nodo';

  @override
  String get celautDepositChecking => 'Comprobando el nodo…';

  @override
  String get celautDepositNodeTitle => 'Contrato del nodo';

  @override
  String celautDepositPayTo(String address) {
    return 'Pagar a $address';
  }

  @override
  String celautDepositRate(String mu) {
    return '$mu MU por nanoERG';
  }

  @override
  String celautDepositBalance(String mu) {
    return 'Saldo del cliente: $mu MU';
  }

  @override
  String celautDepositUsed(String used, String limit) {
    return 'Depósitos a este nodo: $used de $limit';
  }

  @override
  String celautDepositUsedValue(String used, String limit) {
    return '$used de $limit';
  }

  @override
  String get celautDepositLimitLabel => 'Límite para este nodo en ERG';

  @override
  String get celautDepositLimitHelper => '1 ERG como máximo';

  @override
  String get celautDepositSetLimit => 'Fijar el límite';

  @override
  String get celautDepositLimitInvalid => 'Escribe un límite en ERG, de 0 a 1.';

  @override
  String get celautDepositAmountLabel => 'Cantidad en ERG';

  @override
  String get celautDepositAmountHint => '0.001 ERG o más';

  @override
  String get celautDepositAmountInvalid =>
      'Escribe una cantidad de 0.001 ERG o más.';

  @override
  String get celautDepositPrepare => 'Preparar el depósito';

  @override
  String get celautDepositPreparing => 'Preparando…';

  @override
  String get celautDepositConfirmTitle => 'Confirmar el depósito';

  @override
  String get celautDepositConfirmLabel => 'Depositar';

  @override
  String get celautDepositRowNode => 'Nodo';

  @override
  String get celautDepositRowAmount => 'Cantidad';

  @override
  String get celautDepositRowMu => 'Compra';

  @override
  String get celautDepositRowRate => 'Tasa';

  @override
  String get celautDepositRowTotal => 'Total desde la billetera';

  @override
  String get celautDepositRowUsed => 'Depósitos a este nodo';

  @override
  String celautDepositConfirmDetail(String minutes) {
    return 'El nodo puede quedarse un pago simple. La app avisa al nodo una sola vez, cuando el explorador muestra la caja. El token de este depósito vence en $minutes minutos.';
  }

  @override
  String get celautDepositWaiting =>
      'Enviado. La app espera hasta que el explorador muestre la caja…';

  @override
  String get celautDepositWaitAgain => 'Esperar de nuevo';

  @override
  String celautDepositTx(String id) {
    return 'Transacción: $id';
  }

  @override
  String celautDepositBox(String id) {
    return 'Caja del depósito: $id';
  }

  @override
  String celautDepositAccepted(String mu) {
    return 'El nodo aceptó el depósito. Saldo del cliente: $mu MU.';
  }

  @override
  String celautDepositRefused(String message) {
    return 'El nodo rechazó el pago: $message';
  }

  @override
  String get celautDepositCancelled =>
      'Se canceló el depósito. No se envió nada.';

  @override
  String celautDepositSendFailed(String error) {
    return 'No se envió la transacción: $error';
  }

  @override
  String get celautUnknown => 'desconocido';

  @override
  String get celautNoFullWallet =>
      'Esto necesita una billetera con su frase de recuperación en este dispositivo. Primero crea o restaura una billetera.';

  @override
  String get celautDepositPayerTitle => 'Billetera que paga';

  @override
  String celautDepositPayerBalance(String amount) {
    return 'Saldo: $amount';
  }

  @override
  String get celautDepositPayerOpen =>
      'Esta billetera está abierta. La app pide tu huella o el bloqueo de pantalla antes del depósito.';

  @override
  String get celautDepositPayerLocked =>
      'Esta billetera está bloqueada. La app pide tu huella o el bloqueo de pantalla antes del depósito, y la abre.';

  @override
  String get celautDepositRowPayer => 'Pagado por';

  @override
  String get celautDepositRowPayerBalance => 'Saldo de la billetera que paga';

  @override
  String get celautDepositSentTitle => 'Depósitos enviados';

  @override
  String celautDepositSentRow(String amount, String mu, String node) {
    return '$amount ($mu MU) a $node';
  }

  @override
  String get celautDepositSentExpired =>
      'El token de depósito expiró. El nodo rechaza este depósito ahora.';

  @override
  String get celautComputeHomeRowTitle => 'Inicio de conversaciones';

  @override
  String get celautComputeHomeRowSubtitle =>
      'La app se abre en la lista de conversaciones. Es lo predeterminado. Desactívalo para ver primero la lista de billeteras.';

  @override
  String get celautHomeComputeTitle => 'Cómputo ofrecido';

  @override
  String get celautHomeOfferedNote =>
      'Sumas de lo que anuncian los nodos alcanzables: ofrecido, no libre.';

  @override
  String celautHomeNodes(String counted, String unreachable) {
    return 'Nodos contados: $counted. No alcanzables: $unreachable.';
  }

  @override
  String get celautHomeNoNodes =>
      'La lista de nodos está vacía. Añade un nodo con Nodos.';

  @override
  String get celautHomeMoneyTitle => 'Dinero para cómputo';

  @override
  String get celautHomeInstancesTitle => 'Instancias activas';

  @override
  String get celautHomeNoInstances => 'No hay instancias en ejecución.';

  @override
  String celautHomeCostSoFar(String mu, String amount) {
    return 'Costo hasta ahora: $mu ($amount)';
  }

  @override
  String get celautHomeStop => 'Detener';

  @override
  String celautHomeStopped(String mu) {
    return 'Detenida. Reembolso: $mu.';
  }

  @override
  String get celautHomeWallets => 'Billetera';

  @override
  String get celautHomeRefresh => 'Actualizar';

  @override
  String get celautHomeLoading => 'Consultando a los nodos…';

  @override
  String get celautErrorClientUnknown =>
      'El nodo no conoce el cliente de esta app: lo olvidó. Elige un nuevo cliente o reintenta más tarde.';

  @override
  String celautAtLeast(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodos desconocidos',
      one: '1 nodo desconocido',
    );
    return 'al menos $value ($_temp0)';
  }

  @override
  String celautAtLeastWallets(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count billeteras desconocidas',
      one: '1 billetera desconocida',
    );
    return 'al menos $value ($_temp0)';
  }

  @override
  String get celautHomeTagline => 'Cómputo';

  @override
  String get celautHomeFullWallets => 'Billeteras completas · pueden pagar';

  @override
  String get celautHomePaidCredit => 'Crédito pagado en los nodos';

  @override
  String get celautHomeFreeCredit => 'Crédito gratuito en los nodos';

  @override
  String celautHomeUsd(String amount) {
    return '≈ $amount';
  }

  @override
  String get celautHomeUsdUnknown => 'USD desconocido';

  @override
  String get celautHomeUsdSource =>
      'USD según el precio ERG/USD del oracle pool, leído en la cadena. El crédito gratuito cuenta como gastado primero.';

  @override
  String celautHomeNodeCredit(String paid, String free, String rate) {
    return 'Pagado $paid · gratuito $free · $rate MU por nanoERG';
  }

  @override
  String get celautHomeNodeUnreachable => 'No alcanzable';

  @override
  String get celautHomeNodesButton => 'Nodos';

  @override
  String get celautHomeClientUnknownAction => 'Elegir qué hacer';

  @override
  String get celautOpenFullWalletNeeded =>
      'Iniciar y detener necesitan la billetera abierta. Primero la app pide tu huella o el bloqueo de pantalla.';

  @override
  String get celautClientUnknownTitle => 'El nodo olvidó el cliente';

  @override
  String celautClientUnknownBody(String node) {
    return 'El nodo $node no conoce el ID de cliente de esta app. Crea un nuevo cliente ahora o reintenta más tarde.';
  }

  @override
  String get celautClientUnknownWarning =>
      'Un nuevo cliente empieza solo con el crédito gratuito del nodo. El saldo del cliente anterior se pierde, también el ERG que depositaste en él.';

  @override
  String get celautClientUnknownNew => 'Nuevo cliente';

  @override
  String get celautClientUnknownRetry => 'Reintentar más tarde';

  @override
  String get celautClientUnknownDone =>
      'La app ahora usa un nuevo cliente en este nodo.';

  @override
  String get celautNodesTitle => 'Nodos';

  @override
  String get celautNodesIntro =>
      'La lista de nodos de la app. Añade un nodo por su dirección o con un código QR. Solo estos nodos entran en las sumas de la pantalla de inicio. Un nodo quitado conserva sus depósitos y su cliente en la app, así que añadirlo de nuevo los recupera.';

  @override
  String get celautNodesAdd => 'Añadir';

  @override
  String get celautNodesEmpty => 'La lista de nodos está vacía.';

  @override
  String get celautNodesRemove => 'Quitar';

  @override
  String get celautNodesSupport => 'Chat de soporte';

  @override
  String get celautSupportTitle => 'Chat de soporte';

  @override
  String get celautSupportHint => 'Escribe al operador del nodo';

  @override
  String get celautSupportSend => 'Enviar';

  @override
  String get celautSupportEmpty =>
      'Aún no hay mensajes. Si tienes un problema con este nodo, escribe aquí a su operador. El operador lee los mensajes y puede responder.';

  @override
  String get celautSupportUnsupported => 'Este nodo no tiene chat de soporte.';

  @override
  String celautSupportRefused(String reason) {
    return 'El nodo no aceptó el mensaje: $reason';
  }

  @override
  String get celautNodesRemoved =>
      'Se quitó el nodo. Sus depósitos quedan en la app.';

  @override
  String get celautNodesAdded => 'Se añadió el nodo.';

  @override
  String celautNodesDeposited(String amount) {
    return 'Depósitos de la app: $amount';
  }

  @override
  String celautUnlockTitle(String name) {
    return 'PIN de $name';
  }

  @override
  String get celautUnlockFailed => 'La billetera no se abrió.';

  @override
  String get celautDepositAuthNeeded =>
      'El depósito necesita la huella o el bloqueo de pantalla de la billetera que paga. No se envió nada.';

  @override
  String get celautNodesRowSubtitle =>
      'Añade y quita los nodos de las sumas de la pantalla de inicio';

  @override
  String get celautNodesScan => 'Escanear un código QR';

  @override
  String get chatInputHint => 'Escribe un mensaje';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatEmpty => 'Escribe algo para empezar la conversación.';

  @override
  String get chatStarting =>
      'El servicio se está iniciando. Puede tardar un minuto en responder.';

  @override
  String get chatStop => 'Detener la instancia';

  @override
  String get chatErrorUnreachable =>
      'El servicio no respondió. Puede que tu mensaje no haya llegado. Inténtalo de nuevo.';

  @override
  String get chatErrorBadAnswer =>
      'El servicio respondió de una forma que esta app no entiende.';

  @override
  String get chatErrorHistoryFull =>
      'Esta conversación está llena. Inicia una instancia nueva para una conversación nueva.';

  @override
  String get chatErrorStorageFull =>
      'El servicio no tiene espacio para guardar este archivo. El mensaje no se envió.';

  @override
  String get chatErrorBusy =>
      'El servicio está demasiado ocupado para recibir este mensaje. Inténtalo de nuevo en un momento.';

  @override
  String get chatErrorOther => 'El servicio rechazó el mensaje.';

  @override
  String get chatAttach => 'Adjuntar una foto o un audio';

  @override
  String get chatAttachmentRemove => 'Quitar el archivo';

  @override
  String get chatAttachmentShare => 'Abrir o compartir el archivo';

  @override
  String get chatAttachmentFailed => 'El archivo no se cargó.';

  @override
  String get chatErrorUnsupportedMedia =>
      'El servicio no acepta este tipo de archivo.';

  @override
  String get chatErrorFile =>
      'Un archivo está vacío o es demasiado grande. Cada archivo admite hasta 4 MiB y cada mensaje hasta 4 archivos.';

  @override
  String chatSkippedDuplicate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos ya están adjuntos',
      one: '1 archivo ya está adjunto',
    );
    return '$_temp0';
  }

  @override
  String chatSkippedInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count archivos están vacíos, son demasiado grandes o no son JPEG, PNG, MP3 ni WAV',
      one:
          '1 archivo está vacío, es demasiado grande o no es JPEG, PNG, MP3 ni WAV',
    );
    return '$_temp0';
  }

  @override
  String chatSkippedTooMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count archivos se quedaron fuera: un mensaje admite hasta 4 archivos',
      one: '1 archivo se quedó fuera: un mensaje admite hasta 4 archivos',
    );
    return '$_temp0';
  }

  @override
  String get chatImage => 'Imagen';

  @override
  String get chatTyping => 'El servicio está respondiendo…';

  @override
  String get chatSending => 'Enviando…';

  @override
  String get chatReasoning => 'Razonamiento';

  @override
  String get chatAnswerFailed => 'La respuesta se detuvo antes de terminar.';

  @override
  String get chatAnswerCancelled => 'La respuesta se canceló.';

  @override
  String chatWaitingSeconds(int seconds) {
    return 'Sigue trabajando… $seconds s';
  }

  @override
  String chatStopped(String refund) {
    return 'La instancia se detuvo. Reembolso: $refund';
  }

  @override
  String get chatsMenuMore => 'Más';

  @override
  String get chatsNewTitle => 'Nueva conversación';

  @override
  String get chatsServicesTitle => 'Servicios';

  @override
  String get chatsOtherTitle => 'Otras instancias';

  @override
  String get chatsOtherEmpty =>
      'No hay otras instancias. Aquí aparece, mientras corre, un servicio que no tiene conversación.';

  @override
  String get chatsEmptyTitle => 'Aún no hay conversaciones';

  @override
  String get chatsEmptyBody =>
      'Cada conversación es un servicio que corre en un nodo. Empieza una con el botón del lápiz.';

  @override
  String get chatsPaneEmpty =>
      'Elige una conversación de la lista, o empieza una nueva.';

  @override
  String get chatsTabChats => 'Chats';

  @override
  String get chatsTabWallet => 'Billetera';

  @override
  String get chatsTabCompute => 'Cómputo';

  @override
  String get chatsDepositRow => 'Depositar en un nodo';

  @override
  String get chatsDepositRowSubtitle =>
      'Crédito en un nodo para sus servicios, pagado con la billetera';

  @override
  String get chatsNodesRowSubtitle =>
      'Añade un nodo por su dirección o un código QR';

  @override
  String get chatsServicesRowSubtitle =>
      'Importa un archivo de servicio, o ejecuta un servicio';

  @override
  String get chatsOtherRowSubtitle => 'Instancias sin conversación';

  @override
  String get chatsStateChecking => 'Comprobando…';

  @override
  String get chatsStateStarting => 'Iniciando';

  @override
  String get chatsStateRunning => 'En marcha';

  @override
  String get chatsStateUnreachable => 'No responde';

  @override
  String get chatsStateStopped => 'Detenida';

  @override
  String get chatsNoPreview => 'Ningún mensaje visto desde que se abrió la app';

  @override
  String get chatsNoChatSlot =>
      'Sin conversación: este servicio no tiene ranura de chat';

  @override
  String get chatsNoInterface =>
      'Sin interfaz: este servicio no tiene ranura de chat ni web';

  @override
  String get chatsWebPreview => 'Servicio web · se abre en el navegador';

  @override
  String get chatsOpenInBrowser => 'Abrir en el navegador';

  @override
  String get chatsBrowserFailed => 'No se pudo abrir el navegador';

  @override
  String chatsPreviewYou(String text) {
    return 'Tú: $text';
  }

  @override
  String get chatsPreviewPhoto => 'Foto';

  @override
  String get chatsPreviewAudio => 'Audio';

  @override
  String chatsPreviewNamed(String kind, String name) {
    return '$kind: $name';
  }

  @override
  String get chatMute => 'Silenciar notificaciones';

  @override
  String get chatUnmute => 'Activar notificaciones';

  @override
  String get chatMutedHint =>
      'Las notificaciones de este chat están desactivadas';

  @override
  String get chatMic => 'Grabar un mensaje de voz';

  @override
  String get chatMicCancel => 'Descartar la grabación';

  @override
  String get chatMicDone => 'Adjuntar la grabación';

  @override
  String get chatMicDenied => 'La app no tiene permiso para usar el micrófono.';

  @override
  String get chatMicLimit =>
      'La grabación llegó al límite de tamaño y se detuvo. Está adjunta.';

  @override
  String get chatPinnedExpand => 'Ver más del mensaje fijado';

  @override
  String get chatPinnedCollapse => 'Ver menos del mensaje fijado';

  @override
  String get chatPin => 'Fijar';

  @override
  String get chatUnpin => 'Desfijar';

  @override
  String get chatCopy => 'Copiar';

  @override
  String get chatCopied => 'Mensaje copiado.';

  @override
  String get chatPinnedIcon => 'Mensaje fijado';

  @override
  String get chatNotifyDoneBody => 'La respuesta está lista.';

  @override
  String get chatsBackground => 'Fondo del chat';

  @override
  String get chatsActionInfo => 'Información';

  @override
  String get chatsDelete => 'Eliminar';

  @override
  String get chatsRename => 'Cambiar nombre';

  @override
  String get chatsRenameTitle => 'Cambiar nombre';

  @override
  String get chatsRenameNote =>
      'Solo este teléfono ve este nombre. El nodo no lo recibe. Déjalo vacío para quitarlo.';

  @override
  String chatsRenameNoteOriginal(String name) {
    return 'Solo este teléfono ve este nombre. El nodo no lo recibe. Déjalo vacío para volver a mostrar «$name».';
  }

  @override
  String chatsShowStopped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $count instancias detenidas',
      one: 'Mostrar 1 instancia detenida',
    );
    return '$_temp0';
  }

  @override
  String get chatsHideStopped => 'Ocultar instancias detenidas';

  @override
  String chatsStopTitle(String name) {
    return '¿Detener $name?';
  }

  @override
  String get chatsStopBody =>
      'La conversación termina y el nodo devuelve lo que le queda a la instancia.';

  @override
  String chatsDeleteTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get chatsDeleteBody =>
      'La instancia está detenida. Eliminar la quita de la app, con su token.';

  @override
  String chatsStartedOther(String node) {
    return 'El servicio se inició en $node. No tiene conversación: búscalo en Cómputo, en Servicios, en la página del servicio.';
  }

  @override
  String get chatsInfoTitle => 'Instancia';

  @override
  String get chatsInfoStatus => 'Estado';

  @override
  String get chatsInfoNode => 'Nodo';

  @override
  String get chatsInfoPeer => 'ID de par del nodo';

  @override
  String get chatsInfoServiceId => 'ID del servicio';

  @override
  String get chatsInfoInstanceId => 'ID de la instancia (token)';

  @override
  String get chatsInfoSlot => 'Interfaz';

  @override
  String get chatsInfoChatSlot => 'Chat por HTTP';

  @override
  String get chatsInfoNoChatSlot => 'Sin interfaz de chat';

  @override
  String get chatsInfoStarted => 'Inicio';

  @override
  String get chatsInfoCost => 'Coste hasta ahora';

  @override
  String get chatsInfoRefund => 'Reembolso al detenerla';

  @override
  String get chatsInfoStopNote =>
      'Detener termina la conversación. El nodo devuelve lo que le queda a la instancia.';

  @override
  String get chatsInfoDeleteNote =>
      'Solo se puede eliminar una instancia detenida. La app guarda todas las demás, aunque su nodo no responda.';

  @override
  String get chatsReceiptsTitle => 'Recibos';

  @override
  String get chatsReceiptsStart => 'Inicio';

  @override
  String get chatsReceiptsCheckpoints => 'Puntos de control';

  @override
  String get chatsReceiptsClose => 'Cierre';

  @override
  String get chatsReceiptsNone => 'ninguno';

  @override
  String get chatsReceiptsNoTunnel => 'aún sin túnel';

  @override
  String get chatsReceiptsCancelled => 'ninguno (cancelado)';

  @override
  String get chatsReceiptsOpen => 'abierto';

  @override
  String get chatsReceiptsFaultSent =>
      'El nodo firmó datos que no coinciden con lo que este teléfono envió';

  @override
  String get chatsReceiptsFaultReceived =>
      'El nodo firmó datos que no coinciden con lo que este teléfono recibió';

  @override
  String get chatsReceiptsFaultEnvs =>
      'El nodo firmó variables de entorno que este teléfono no envió';

  @override
  String get chatsReceiptsFaultService =>
      'El nodo firmó un servicio distinto del que inició este teléfono';

  @override
  String get chatsReceiptsFaultAmount =>
      'El nodo firmó un saldo inicial distinto del que pidió este teléfono';

  @override
  String get chatsReceiptsFaultInvalid => 'Un recibo no se verifica';

  @override
  String get chatsReceiptsFaultOmitted =>
      'El nodo no dio recibo de inicio, pero dio uno antes';

  @override
  String get chatsReceiptsDropped => 'Túneles descartados';

  @override
  String get chatsReceiptsExport => 'Exportar recibos';

  @override
  String get chatsReceiptsExportNone => 'No hay recibos para exportar.';

  @override
  String chatsReceiptsExportFailed(String error) {
    return 'La exportación falló: $error';
  }

  @override
  String get chatsReceiptsNote =>
      'El nodo firma estos recibos. Son pruebas contra el nodo, y puede darlas a otras personas. Un túnel sin cierre no es por sí solo una falta: por ejemplo, este teléfono o el nodo lo detuvo.';

  @override
  String get celautErrorNodeClosed =>
      'El nodo está cerrado ahora: su operador solo acepta trabajo nuevo en ciertas horas. Inténtalo más tarde o elige otro nodo.';

  @override
  String get celautErrorNoRoom =>
      'El nodo no tiene recursos libres suficientes para este servicio ahora. Inténtalo más tarde o elige otro nodo.';

  @override
  String get celautErrorServiceMissing =>
      'El nodo no tiene este servicio. Elige un nodo que lo tenga.';

  @override
  String get celautErrorPolicyRefused =>
      'La política del nodo no permite aquello a lo que se conecta este servicio. Elige otro nodo.';

  @override
  String get celautErrorUnsupportedArchitecture =>
      'El nodo no ejecuta este tipo de servicio (necesita otra arquitectura de procesador). Elige otro nodo.';

  @override
  String get celautErrorRateLimited =>
      'El nodo limita las llamadas de esta app durante un rato. Espera un momento y vuelve a intentarlo.';

  @override
  String get celautErrorRecursionLimit =>
      'El nodo rechazó la petición porque dio vueltas o llegó demasiado hondo. Inténtalo de nuevo.';

  @override
  String get celautErrorInsufficientCredit =>
      'Tu crédito en el nodo es menor que el precio del servicio. Añade un depósito en este nodo o elige otro.';

  @override
  String get celautErrorLaunchFailed =>
      'El nodo intentó iniciar el servicio y no pudo.';

  @override
  String get celautRunTitle => 'Ejecutar un servicio';

  @override
  String get celautRunSearchHint => 'Buscar habilidades y etiquetas';

  @override
  String get celautRunLoading => 'Cargando habilidades…';

  @override
  String get celautRunEmpty => 'Ninguna habilidad coincide.';

  @override
  String get celautRunCatalogError =>
      'El catálogo de habilidades no está disponible ahora.';

  @override
  String get celautRunRetry => 'Reintentar';

  @override
  String get celautRunNoServices =>
      'Ningún servicio tiene esta habilidad todavía.';

  @override
  String get celautRunButton => 'Ejecutar';

  @override
  String celautRunLaunching(String name) {
    return 'Lanzando $name…';
  }

  @override
  String get celautRunLaunchingNote =>
      'La app pregunta a los nodos y arranca el servicio en el mejor.';

  @override
  String get celautRunStepNodes => 'Preguntando el precio a los nodos';

  @override
  String get celautRunStepReading => 'Leyendo el servicio';

  @override
  String get celautRunStepStarting => 'Arrancándolo en el mejor nodo';

  @override
  String celautRunStarted(String node, String cost) {
    return 'Iniciado en $node. Coste de inicio: $cost.';
  }

  @override
  String get celautRunOpenChat => 'Abrir chat';

  @override
  String get celautRunFailedTitle => 'El servicio no se inició';

  @override
  String get celautRunFailedNoNodes =>
      'No hay ningún nodo al que preguntar. Añade un nodo en la lista de Nodos.';

  @override
  String get celautRunFailedNoQuotes =>
      'Ningún nodo dio un precio. Este es el motivo:';

  @override
  String get celautRunFailedAll =>
      'Hubo nodos que dieron precio, pero ninguno inició el servicio. Este es el motivo:';

  @override
  String celautRunNeedsCredit(String credit, String cost) {
    return 'Tu crédito en este nodo es $credit, y el servicio cuesta $cost. Añade un depósito en este nodo o elige otro.';
  }

  @override
  String get celautRunLeftOut =>
      'Descartado: no respondió a las últimas comprobaciones.';

  @override
  String get celautRunDetails => 'Detalles';

  @override
  String get celautRunClose => 'Cerrar';

  @override
  String get celautRunDeposit => 'Añadir un depósito';

  @override
  String celautNodeAvailable(String ms) {
    return 'Disponible · $ms ms';
  }

  @override
  String celautNodeSlow(String ms) {
    return 'Lento · $ms ms';
  }

  @override
  String get celautNodeUnreachable => 'No responde';

  @override
  String get celautNodeUnknownState => 'Sin comprobar todavía';

  @override
  String celautNodeLastSeen(String ago) {
    return 'Última respuesta hace $ago';
  }

  @override
  String get celautNodeNeverSeen => 'Nunca ha respondido';

  @override
  String get celautNodeChecking => 'Comprobando…';

  @override
  String celautAgoSeconds(String n) {
    return '$n s';
  }

  @override
  String celautAgoMinutes(String n) {
    return '$n min';
  }

  @override
  String celautAgoHours(String n) {
    return '$n h';
  }

  @override
  String celautAgoDays(String n) {
    return '$n d';
  }

  @override
  String get celautNodesCheckNow => 'Comprobar ahora';

  @override
  String celautRunPreview(String node, String cost) {
    return 'Mejor nodo ahora: $node · coste de inicio $cost';
  }

  @override
  String get celautRunPreviewLoading => 'Buscando el mejor nodo…';

  @override
  String celautRunConfirmTitle(String name) {
    return '¿Ejecutar $name?';
  }

  @override
  String get celautRunConfirmBody =>
      'El servicio se ejecuta en un nodo y usa tu crédito allí hasta que se detiene. Detenlo desde su conversación, su página de información o la lista de conversaciones.';

  @override
  String get celautRunConfirmNoQuote =>
      'Ningún nodo ha dado un precio todavía. Ejecutar pregunta a todos los nodos de la lista.';

  @override
  String get celautRunSurvivalLabel => 'Mantenerla en marcha al menos';

  @override
  String get celautRunSurvivalHint => 'Vacío: lo decide el nodo';

  @override
  String get celautRunSurvivalWrong => 'De 1 minuto a 30 días.';

  @override
  String celautRunNodeBalance(String cost) {
    return 'Construcción $cost. El nodo añade su saldo inicial por defecto, que mantiene la instancia el tiempo que fija el nodo. El nodo devuelve lo que la instancia no usa.';
  }

  @override
  String get celautRunSurvivalNoPrice =>
      'Este nodo no da un precio por su tiempo. El nodo elige el saldo inicial.';

  @override
  String celautRunSurvivalEstimate(String cost, String balance, String time) {
    return 'Coste de inicio de unos $cost, con un saldo de $balance para al menos $time al precio actual del nodo. Un nodo ocupado y el tráfico de la conversación cuestan más. El nodo devuelve lo que la instancia no usa.';
  }

  @override
  String get celautTopUpTitle => 'Mantener en marcha';

  @override
  String get celautTopUpThreshold =>
      'Cuando una instancia vaya a durar menos de';

  @override
  String get celautTopUpAmount => 'Cada vez, añadir este tiempo';

  @override
  String celautTopUpRange(String min, String max) {
    return 'De $min a $max minutos.';
  }

  @override
  String get celautTopUpNote =>
      'La app revisa las instancias que mantienes en marcha cuando se abre la lista de conversaciones y una vez por minuto mientras la app está abierta. Una recarga pasa crédito que ya tienes en el nodo de la instancia (ModifyDeposit): no se paga nada en la cadena de bloques y no se firma nada. Si ese crédito no basta, la app no paga: te lo pregunta, y un depósito siempre necesita tu confirmación y tu huella o el bloqueo de pantalla. Si la app está cerrada no se añade nada, y el nodo detiene la instancia cuando se le acaba el saldo.';

  @override
  String get celautTopUpNeedLater => 'Más tarde';

  @override
  String get celautTopUpNeedDeposit => 'Depositar';

  @override
  String get celautErrorTransferFailed =>
      'La transferencia del servicio se detuvo (no se pudo leer el fichero, está cortado o se canceló). El nodo no guardó el servicio cortado. Inténtalo de nuevo.';

  @override
  String get celautSendMissingTitle => 'El servicio no está en estos nodos';

  @override
  String celautSendFromNode(String from, String to) {
    return 'Enviarlo de $from a $to';
  }

  @override
  String celautSendFromFile(String to) {
    return 'Elegir un fichero .celaut.bee y enviarlo a $to';
  }

  @override
  String get celautSendNoHolder =>
      'Ningún nodo de tu lista tiene este servicio. Puedes dárselo a un nodo desde un fichero .celaut.bee.';

  @override
  String get celautSendConfirmTitle => '¿Enviar el servicio?';

  @override
  String get celautSendConfirmBody =>
      'Todo el servicio pasa por este teléfono hasta el nodo, y un servicio puede ser grande. El nodo lo guarda, así que los siguientes lanzamientos en ese nodo no lo envían otra vez.';

  @override
  String get celautSendMetered =>
      'Estás con datos móviles: esto puede gastar muchos datos.';

  @override
  String get celautSendConfirm => 'Enviar';

  @override
  String get celautSendCancel => 'Cancelar';

  @override
  String get celautSendFetching => 'Obteniendo el servicio del nodo…';

  @override
  String get celautSendSending => 'Entregando el servicio al nodo…';

  @override
  String get celautSendStarting => 'Empezando la transferencia…';

  @override
  String get celautImportReading => 'Leyendo el archivo del servicio…';

  @override
  String get celautImportReadingNote =>
      'Primero la app copia el archivo en su propio almacenamiento. Un archivo grande tarda un poco.';

  @override
  String get celautImportChecking => 'Comprobando el archivo del servicio…';

  @override
  String get celautImportNote =>
      'La app calcula el hash de cada bloque, así un archivo dañado se detecta aquí y no después de enviarlo a un nodo.';

  @override
  String celautSendProgress(String done, String total, String percent) {
    return '$done de $total ($percent %)';
  }

  @override
  String celautSendSoFar(String done) {
    return '$done hasta ahora';
  }

  @override
  String get celautSendDone => 'El nodo ya tiene el servicio. Iniciándolo…';

  @override
  String get celautSendFailedTitle => 'El servicio no se envió';

  @override
  String get celautSendOtherService => 'Este fichero contiene otro servicio.';

  @override
  String get celautSendNoServicePart =>
      'Este fichero no contiene ningún servicio.';

  @override
  String get celautSendNoDirectory =>
      'La app no tiene dónde guardar el servicio.';

  @override
  String get celautPkgTitle => 'Tus servicios';

  @override
  String get celautPkgImport => 'Importar un fichero de servicio';

  @override
  String get celautPkgEmpty =>
      'No hay ningún fichero de servicio cargado. Importa un fichero .celaut.bee para ejecutar un servicio que ningún nodo tiene todavía.';

  @override
  String get celautPkgRemove => 'Quitar';

  @override
  String get celautPkgRemoveTitle => '¿Quitar este fichero de servicio?';

  @override
  String celautPkgRemoveBody(String name) {
    return '$name se borra de esta app. Los nodos que tienen el servicio lo conservan.';
  }

  @override
  String celautPkgLoaded(String name) {
    return 'Cargado $name.';
  }

  @override
  String celautPkgBadFile(String reason) {
    return 'Este fichero no es un paquete de servicio: $reason';
  }

  @override
  String celautPkgUnreadable(String reason) {
    return 'La app no puede leer este archivo: $reason';
  }

  @override
  String get celautPkgAgainTitle => 'Ya está en la app';

  @override
  String celautPkgAgainBody(String name) {
    return '$name ya está en la app, con el mismo tamaño. ¿Importarlo de nuevo?';
  }

  @override
  String get celautPkgAgainImport => 'Importar de nuevo';

  @override
  String celautPkgReplaced(String name) {
    return 'Cargado $name de nuevo. Sustituye al archivo que tenía la app.';
  }

  @override
  String get celautPkgMissing => 'El fichero ya no está. Impórtalo de nuevo.';

  @override
  String get celautPkgRedownload =>
      'Vuelve a descargar el archivo y prueba otra vez: a veces el navegador lo descarga dañado.';

  @override
  String celautSendFromLibrary(String to) {
    return 'Envía tu fichero cargado a $to';
  }

  @override
  String celautHomeNodesReady(String ready, String total) {
    return '$ready de $total nodos listos';
  }

  @override
  String get celautHomeCreditOnNodes => 'Crédito en nodos';

  @override
  String celautNodeCredit(String credit) {
    return 'Crédito: $credit';
  }

  @override
  String get celautEnvTitle => 'Variables de entorno';

  @override
  String get celautEnvRowSubtitle =>
      'Valores que un servicio puede recibir al arrancar';

  @override
  String get celautEnvIntro =>
      'Valores con nombre que puedes dar a un servicio al ejecutarlo, por ejemplo una clave. Se guardan cifrados en este teléfono. Un servicio solo recibe los que tú elijas.';

  @override
  String get celautEnvEmpty => 'Todavía no hay variables.';

  @override
  String get celautEnvAdd => 'Añadir variable';

  @override
  String celautEnvEditTitle(String name) {
    return 'Editar $name';
  }

  @override
  String get celautEnvName => 'Nombre';

  @override
  String get celautEnvValue => 'Valor';

  @override
  String get celautEnvShow => 'Mostrar el valor';

  @override
  String get celautEnvHide => 'Ocultar el valor';

  @override
  String get celautEnvEdit => 'Editar';

  @override
  String get celautEnvDelete => 'Eliminar';

  @override
  String celautEnvDeleteTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get celautEnvDeleteBody =>
      'Los servicios que ejecutes después no podrán usarla. Las instancias que ya se ejecutan conservan lo que recibieron.';

  @override
  String get celautEnvNameBad =>
      'El nombre debe empezar por una letra o _ y tener solo letras, dígitos y _.';

  @override
  String get celautEnvNameReserved =>
      'Este nombre está reservado para el nombre de la instancia.';

  @override
  String get celautEnvNameTaken =>
      'Ya existe una variable con este nombre. Edítala.';

  @override
  String get celautEnvValueEmpty => 'Escribe un valor.';

  @override
  String get celautEnvValueLong => 'El valor tiene más de 8192 bytes.';

  @override
  String get celautEnvValueNul => 'El valor no puede tener un carácter NUL.';

  @override
  String get celautEnvTooMany => 'Hay 256 variables. Elimina una primero.';

  @override
  String get celautEnvAskTitle => 'Variables del servicio';

  @override
  String celautEnvAskStep(int current, int total) {
    return 'Variable $current de $total';
  }

  @override
  String get celautEnvAskNoText => 'El servicio no describe esta variable.';

  @override
  String get celautEnvAskPick => 'Elige de mis variables';

  @override
  String get celautEnvAskPickTitle => 'Elige una variable';

  @override
  String get celautEnvAskPickEmpty =>
      'Todavía no tienes variables. Añádelas en Ajustes, Variables de entorno.';

  @override
  String get celautEnvAskType => 'Escribe un valor';

  @override
  String get celautEnvAskUse => 'Usar este valor';

  @override
  String get celautEnvAskSkip => 'Omitir';

  @override
  String get celautEnvAskSkipHint => 'El servicio no recibe esta variable.';

  @override
  String get celautEnvAskBadName =>
      'El nodo no puede dar esta variable, porque su nombre no es válido. Solo puedes omitirla.';

  @override
  String celautEnvAskChosen(String what) {
    return 'Elegida: $what';
  }

  @override
  String get celautEnvAskBack => 'Atrás';

  @override
  String get celautEnvReviewTitle => 'Revisa';

  @override
  String celautEnvReviewFromContainer(String name) {
    return 'Mi variable $name';
  }

  @override
  String get celautEnvReviewTyped => 'Valor escrito';

  @override
  String get celautEnvReviewSkipped => 'Omitida';

  @override
  String get celautEnvReviewNote =>
      'El nodo que arranca el servicio lee estos valores. Un nodo que rechaza el arranque también los ha leído.';

  @override
  String get celautEnvRun => 'Ejecutar';

  @override
  String get celautEnvDeclUnreadableTitle => 'No se pudo leer el servicio';

  @override
  String get celautEnvDeclUnreadableBody =>
      'La app no ha podido leer la interfaz ni las variables de este servicio, así que no sabe si Chatui lo admite ni si necesita variables. Ejecútalo igualmente o cancela.';

  @override
  String get celautEnvRunWithout => 'Ejecutar igualmente';

  @override
  String celautInviteConnected(String address) {
    return 'Conectado por $address. El nodo está en tu lista.';
  }

  @override
  String get celautInviteFailedTitle =>
      'No se pudo conectar con el nodo de la invitación';

  @override
  String get celautInviteNoAddress =>
      'La invitación no tiene ninguna dirección que esta app pueda usar.';

  @override
  String get celautInviteOnionNeedsProxy =>
      'No se probó. Una dirección onion necesita Tor mediante un proxy externo, como Orbot. Una conexión directa y el cliente Tor de la app no pueden abrirla.';

  @override
  String get celautInvitePrivateOverTor =>
      'No se probó. Una dirección de una red privada no se puede alcanzar a través de Tor.';

  @override
  String get serviceInfoTitle => 'Detalles del servicio';

  @override
  String get serviceInfoLoading => 'Leyendo el servicio…';

  @override
  String get serviceInfoReadFailed => 'No se pudo leer el servicio';

  @override
  String get serviceInfoTruncated =>
      'Este servicio es demasiado grande para leerlo desde un nodo, así que solo se muestra lo que viene primero. Carga su fichero para verlo todo.';

  @override
  String get serviceInfoChatSupported =>
      'Sigue la convención de chat de Chatui, así que se abre como una conversación.';

  @override
  String get serviceInfoChatUnsupported =>
      'Chatui no admite su interfaz: ningún puerto habla la convención de chat (tcp, luego http2, grpc y chat encima). Se puede ejecutar, pero Chatui no puede abrir una conversación con él.';

  @override
  String get serviceInfoChatUnknown =>
      'La app no ha podido leer la interfaz de este servicio, así que no sabe si funciona como una conversación.';

  @override
  String get serviceInfoAbout => 'Acerca de';

  @override
  String get serviceInfoNoProse => 'El servicio no da ninguna descripción.';

  @override
  String get serviceInfoArchitecture => 'Arquitectura';

  @override
  String get serviceInfoEntry => 'Arranca';

  @override
  String get serviceInfoFilesystem => 'Sistema de ficheros';

  @override
  String get serviceInfoConfigFile => 'Fichero de configuración';

  @override
  String get serviceInfoResources => 'Recursos';

  @override
  String get serviceInfoAtStart => 'Necesita al arrancar';

  @override
  String get serviceInfoAtMost => 'Puede usar como máximo';

  @override
  String get serviceInfoNoResources => 'El servicio no dice qué necesita.';

  @override
  String get serviceInfoCoreSpeed => 'Velocidad de un núcleo';

  @override
  String get serviceInfoInterface => 'Interfaz';

  @override
  String get serviceInfoNoInterface => 'El servicio no declara ningún puerto.';

  @override
  String serviceInfoSlot(int n) {
    return 'Interfaz $n';
  }

  @override
  String get serviceInfoChatReady => 'Apto para chat';

  @override
  String get serviceInfoPricePerCall => 'MU por llamada';

  @override
  String get serviceInfoNetworks => 'Redes';

  @override
  String get serviceInfoNoNetworks =>
      'El servicio no se conecta a ninguna red.';

  @override
  String get serviceInfoAnyAddress => 'Cualquier dirección';

  @override
  String serviceInfoPeersSpeak(String protocols) {
    return 'Los pares hablan: $protocols';
  }

  @override
  String get serviceInfoEnvironment => 'Variables de entorno';

  @override
  String get serviceInfoNoEnvironment =>
      'El servicio no declara ninguna variable.';

  @override
  String get serviceInfoMore => 'Otros';

  @override
  String get serviceInfoNodeProtocols => 'Protocolos que espera del nodo';

  @override
  String get serviceInfoWorkloads => 'Instancias que puede arrancar';

  @override
  String serviceInfoWorkload(int count) {
    return '$count × instancia';
  }

  @override
  String get serviceInfoWorkloadService => 'de un servicio';

  @override
  String serviceInfoWorkloadsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count escenarios son demasiado grandes para mostrarlos.',
      one: '1 escenario es demasiado grande para mostrarlo.',
    );
    return '$_temp0';
  }

  @override
  String get celautChatUnsupportedTitle => 'Chatui no admite esta interfaz';

  @override
  String get celautChatUnsupportedBody =>
      'Este servicio no sigue la convención de chat que usa Chatui, así que Chatui no puede abrir una conversación con él. Si lo ejecutas, aparece en Cómputo y no podrás hablar con él desde aquí.';

  @override
  String get celautChatRunAnyway => 'Ejecutar igualmente';

  @override
  String get celautChatDetails => 'Detalles';

  @override
  String get celautRunConfirmDetails => 'Detalles del servicio';

  @override
  String get chatsInfoServiceDetails => 'Detalles del servicio';

  @override
  String serviceInfoPartsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count partes del servicio son demasiado grandes para mostrarlas.',
      one: '1 parte del servicio es demasiado grande para mostrarla.',
    );
    return '$_temp0';
  }

  @override
  String get walletSummaryDetails => 'Detalles de la billetera';

  @override
  String get walletSummaryLatest => 'Últimas transacciones';

  @override
  String get walletSummaryNoTransactions => 'Aún no hay transacciones';

  @override
  String get chatSelectText => 'Seleccionar texto';

  @override
  String get celautRunOnPhone => 'En el móvil';

  @override
  String get celautRunImport => 'Importar';

  @override
  String get celautRunPhoneServices => 'Ejecutar los servicios del móvil';

  @override
  String celautStoreServices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servicios',
      one: '1 servicio',
    );
    return '$_temp0';
  }

  @override
  String get celautEnvSensitive => 'Sensible';

  @override
  String get celautEnvNotSensitive => 'No sensible';

  @override
  String get celautEnvSensitiveHint =>
      'Una contraseña, una clave o un token. Antes de que un valor sensible vaya a donde otros puedan leerlo, la app te avisa.';

  @override
  String get celautEnvMarkSensitive => 'Marcar como sensible';

  @override
  String get celautEnvMarkNotSensitive => 'Marcar como no sensible';

  @override
  String get celautEnvEgressSteers =>
      'Esta variable decide a dónde se conecta el servicio.';

  @override
  String get celautEnvEgressTitle =>
      'Tus valores sensibles pueden salir del nodo';

  @override
  String celautEnvEgressBody(String exits) {
    return 'Este servicio puede conectarse fuera del nodo, a: $exits. Puede enviar allí tus valores sensibles.';
  }

  @override
  String get celautEnvEgressAnyAddress => 'cualquier dirección';

  @override
  String get celautEnvNetworksTitle => 'El servicio comparte redes en el nodo';

  @override
  String celautEnvNetworksBody(String networks) {
    return 'Este servicio puede conectarse a otros servicios del nodo, en las redes: $networks. Puede darles tus valores sensibles.';
  }

  @override
  String get celautEnvNodesTitle => 'Nodos que no son de tu plena confianza';

  @override
  String celautEnvNodesBody(String nodes) {
    return 'Estos nodos pueden arrancar el servicio y no los marcaste como de plena confianza: $nodes. El nodo que recibe el arranque lee tus valores sensibles. Para marcar un nodo, ve a Cómputo, Nodos.';
  }

  @override
  String get celautEnvDeny => 'Denegar';

  @override
  String get celautEnvRunAnyway => 'Enviar los valores y ejecutar';

  @override
  String get celautNodesTrusted => 'De plena confianza';

  @override
  String get celautNodesTrustedHint =>
      'Tu nodo, o un nodo de tu familia, tus amigos o tu empresa. La app no avisa antes de dar a este nodo tus valores sensibles.';

  @override
  String celautNodesPriority(int value) {
    return 'Prioridad: $value de 100';
  }

  @override
  String get celautNodesPriorityFullTrust =>
      'Prioridad: 100 de 100 (plena confianza)';

  @override
  String get celautNodesPriorityHint =>
      'Tu reputación para este nodo, de 0 a 100 (50 es neutral). Al comparar precios, un número más alto favorece a este nodo. La plena confianza siempre es 100.';

  @override
  String get balancerTitle => 'Pesos del balanceador';

  @override
  String get balancerRowSubtitle =>
      'Cómo elige la app el nodo que ejecuta un servicio';

  @override
  String get balancerIntro =>
      'Para elegir un nodo, la app pide un precio a cada uno y le da una puntuación: el término del precio más los términos de abajo, cada uno multiplicado por su peso. Va primero el nodo con la puntuación más alta. Un peso mayor hace que ese término cuente más; 0 lo desactiva. Una oferta gratuita siempre va primero.';

  @override
  String get balancerPriceName => 'Precio';

  @override
  String get balancerPriceDesc =>
      'Cuánto cuenta una cotización más barata. Cada vez que el precio se divide entre e (unos 2,7), la puntuación sube en este peso.';

  @override
  String get balancerReputationName => 'Reputación local';

  @override
  String get balancerReputationDesc =>
      'Lo que esta app aprendió de su propio historial con cada nodo. Aún no se registran eventos, así que este término vale 0 por ahora.';

  @override
  String get balancerOnchainName => 'Reputación en cadena';

  @override
  String get balancerOnchainDesc =>
      'La opinión que otros editores registran en la cadena de bloques. La app aún no la lee, así que este término vale 0 por ahora.';

  @override
  String get balancerDonationName => 'Donaciones';

  @override
  String get balancerDonationDesc =>
      'Una bonificación para los nodos que donan. La app aún no la usa, así que este término vale 0 por ahora.';

  @override
  String get balancerPriorityName => 'Tu prioridad por nodo';

  @override
  String get balancerPriorityDesc =>
      'La prioridad de 0 a 100 que das a cada nodo en la lista de nodos (50 es neutral, la plena confianza es 100).';

  @override
  String get balancerDefaultLabel => 'Por defecto';

  @override
  String get balancerOffLabel => 'Desactivado';

  @override
  String get balancerReset => 'Restaurar valores por defecto';

  @override
  String get balancerPresetsLabel => 'Ajustes rápidos';

  @override
  String get balancerPresetBalanced => 'Equilibrado';

  @override
  String get balancerPresetCheapest => 'Lo más barato primero';

  @override
  String get balancerPresetTrusted => 'Mis nodos primero';

  @override
  String get balancerCustom => 'Mezcla personalizada';

  @override
  String get balancerMainTitle => 'Lo que más te importa';

  @override
  String get balancerExampleTitle => 'Pruébalo';

  @override
  String get balancerExampleIntro =>
      'Tres nodos de ejemplo. Mueve los deslizadores y mira cómo cambia el orden. Tus nodos reales siguen la misma regla.';

  @override
  String get balancerExampleCheap => 'Nodo barato';

  @override
  String get balancerExampleTrusted => 'Tu nodo de confianza';

  @override
  String get balancerExampleRisky => 'El más barato, poca confianza';

  @override
  String get balancerAdvancedTitle => 'Términos aún sin datos';

  @override
  String get balancerAdvancedNote =>
      'Estos términos hoy no suman nada porque la app aún no tiene sus datos. Puedes fijar su peso ya, para cuando los tenga.';

  @override
  String get balancerRestoreTerm => 'Restaurar';

  @override
  String get balancerScaleLow => 'Ignorar';

  @override
  String get balancerScaleHigh => 'Máximo';

  @override
  String get balancerReadingNothing =>
      'Con los dos en 0, nada distingue a unos nodos de otros.';

  @override
  String get balancerReadingPriceIgnored =>
      'Se ignora el precio: solo decide tu prioridad.';

  @override
  String get balancerReadingPriorityIgnored =>
      'Se ignora tu prioridad: siempre va primero el nodo más barato.';

  @override
  String balancerReadingTradeoff(String factor) {
    return 'Un nodo de tu plena confianza puede ganar a otro hasta $factor× más barato.';
  }

  @override
  String balancerExampleDetail(String cost, String priority) {
    return 'Cuesta $cost× · prioridad $priority';
  }

  @override
  String balancerExampleFirst(String name) {
    return '$name va primero.';
  }

  @override
  String get celautRunModeTime => 'Por tiempo';

  @override
  String get celautRunModeKeep => 'Hasta que la detenga';

  @override
  String get celautRunButtonKeep => 'Ejecutar sin límite de tiempo';

  @override
  String get celautKeepWarning =>
      'Riesgo: la app irá añadiendo tiempo a esta instancia con tu crédito en este nodo hasta que la detengas. Si te olvidas, puede gastar todo ese crédito. Funciona mientras la app esté abierta y haya crédito; si el crédito se acaba, la instancia se detiene.';

  @override
  String get celautKeepLimitLabel => 'Tope de gasto (opcional)';

  @override
  String get celautKeepLimitHint => 'Vacío: sin tope';

  @override
  String get celautKeepLimitWrong => 'Un número de MU mayor que cero.';

  @override
  String celautKeepRate(String rate, String credit, String time) {
    return 'Este nodo cobra unos $rate por hora. Tu crédito allí es $credit: unos $time.';
  }

  @override
  String celautKeepRateOnly(String rate) {
    return 'Este nodo cobra unos $rate por hora.';
  }

  @override
  String celautKeepCredit(String credit) {
    return 'Tu crédito en este nodo es $credit.';
  }

  @override
  String get celautKeepLowCredit =>
      'Tu crédito allí solo cubre unas pocas horas. Haz antes un depósito si quieres que dure más.';

  @override
  String get celautKeepBadge => 'Se mantiene hasta que la detengas';

  @override
  String get celautTimeTitle => 'Tiempo y crédito';

  @override
  String get celautTimeBalance => 'Saldo de la instancia';

  @override
  String get celautTimeCredit => 'Tu crédito en este nodo';

  @override
  String celautTimeAbout(String time) {
    return 'unos $time';
  }

  @override
  String get celautKeepSwitch => 'Mantenerla en marcha hasta que la detenga';

  @override
  String celautKeepOnNoLimit(String spent) {
    return 'La app añade tiempo sola mientras tengas crédito. Añadido hasta ahora: $spent. Sin tope.';
  }

  @override
  String celautKeepOnLimit(String spent, String limit) {
    return 'La app añade tiempo sola mientras tengas crédito. Añadido hasta ahora: $spent de $limit.';
  }

  @override
  String get celautKeepOff => 'Se detiene cuando se le acaba el saldo.';

  @override
  String get celautKeepEnableTitle => '¿Mantenerla en marcha?';

  @override
  String get celautKeepEnableConfirm => 'Mantener en marcha';

  @override
  String get celautAddTime => 'Añadir tiempo';

  @override
  String get celautAddTimeMinutes => 'Añadir';

  @override
  String celautAddTimeCost(String cost, String left, String time) {
    return 'Cuesta $cost. Te quedan $left en este nodo: unos $time más para esta instancia.';
  }

  @override
  String celautAddTimeCostOnly(String cost) {
    return 'Cuesta $cost.';
  }

  @override
  String celautAddTimeNoCredit(String cost, String credit) {
    return 'Cuesta $cost y tu crédito en este nodo es $credit. Haz un depósito para añadir este tiempo.';
  }

  @override
  String get celautAddTimeConfirm => 'Añadir';

  @override
  String get celautAddTimeDone => 'Tiempo añadido.';

  @override
  String celautKeepNeed(String node) {
    return 'Mantener en marcha: tu crédito en $node es demasiado bajo para añadir tiempo a una instancia. Haz un depósito para que siga en marcha.';
  }

  @override
  String celautKeepNeedBudget(String node) {
    return 'Una instancia en $node llegó al tope de gasto que pusiste. Se detendrá cuando se le acabe el saldo. Apaga y vuelve a encender «mantenerla en marcha» en su página de información para poner otro tope.';
  }

  @override
  String get celautTopUpRow =>
      'Cuándo añadir tiempo a las instancias que mantienes en marcha';

  @override
  String get celautTopUpIntro =>
      'Para las instancias que mantienes en marcha hasta que las detengas (se elige al ejecutarlas, o en su página de información). La app añade tiempo con tu crédito en su nodo; nunca hace un depósito por sí sola.';

  @override
  String get celautTopUpSaved => 'Guardado.';

  @override
  String get chatsGroupsMenu => 'Grupos';

  @override
  String get chatsGroupsViewGrouped => 'Mostrar en grupos';

  @override
  String get chatsGroupsViewFlat => 'Mostrar como una lista';

  @override
  String get chatsGroupsNew => 'Nuevo grupo';

  @override
  String get chatsGroupsNameLabel => 'Nombre del grupo';

  @override
  String get chatsGroupsRename => 'Cambiar nombre del grupo';

  @override
  String get chatsGroupsDelete => 'Eliminar grupo';

  @override
  String chatsGroupsDeleteTitle(String name) {
    return '¿Eliminar el grupo $name?';
  }

  @override
  String get chatsGroupsDeleteBody =>
      'Las conversaciones del grupo no se eliminan: vuelven a la lista sin grupo.';

  @override
  String get chatsGroupsMove => 'Mover a un grupo';

  @override
  String get chatsGroupsNone => 'Quitar de su grupo';

  @override
  String get chatsGroupsUngrouped => 'Sin grupo';

  @override
  String get chatSettingsListGroup => 'Lista de chats';

  @override
  String get chatSettingsGroupedView => 'Organizar en grupos';

  @override
  String get chatSettingsGroupedViewSubtitle =>
      'Desactivado: una lista plana. Activado: grupos plegables. Mantén pulsada una conversación para moverla a un grupo.';

  @override
  String get celautEnvAskSave => 'Guardar en mis variables';

  @override
  String celautEnvAskSaveHint(String name) {
    return 'Se guarda como $name, con la marca de arriba.';
  }

  @override
  String celautEnvAskSaveReplaces(String name) {
    return 'Sustituye el valor que guardaste como $name.';
  }

  @override
  String get celautEnvSaveFailed => 'El valor no se guardó en tus variables.';

  @override
  String get celautSecretAskTitle => 'Secreto para el servicio';

  @override
  String get celautSecretReviewNote =>
      'El servicio y el nodo de esta instancia leen el valor. El valor no se guarda en la conversación.';

  @override
  String get celautSecretSend => 'Enviar';

  @override
  String get celautSecretSendAnyway => 'Enviar el valor';

  @override
  String chatSecretCardTitle(String name) {
    return 'El servicio pide $name';
  }

  @override
  String get chatSecretAnswer => 'Elegir un valor';

  @override
  String get chatSecretSent => 'Enviado';

  @override
  String get chatSecretSkipped => 'Omitido';

  @override
  String get chatSecretFailed =>
      'La respuesta no llegó al servicio. Inténtalo de nuevo.';

  @override
  String chatSecretMissing(String name) {
    return '$name ya no está en tus variables.';
  }

  @override
  String get btcTitle => 'Bitcoin';

  @override
  String get btcRefresh => 'Leer de nuevo';

  @override
  String get btcLocked =>
      'Desbloquea la billetera para abrir la billetera Bitcoin.';

  @override
  String get btcUnlock => 'Desbloquear';

  @override
  String btcTestNetwork(String network) {
    return '$network: una red de prueba. Estas monedas no tienen valor.';
  }

  @override
  String get btcMainnetNote =>
      'Mainnet: bitcoin real. Un envío no se puede deshacer.';

  @override
  String get btcConfirmed => 'Confirmado';

  @override
  String btcPending(String amount) {
    return '$amount BTC sin confirmar todavía';
  }

  @override
  String btcImmature(String amount) {
    return '$amount BTC minados, todavía no maduros';
  }

  @override
  String get btcReceive => 'Recibir';

  @override
  String get btcSend => 'Enviar';

  @override
  String get btcDepositAction => 'Depositar en un nodo';

  @override
  String get btcHistory => 'Historial';

  @override
  String get btcNoHistory => 'Todavía no hay transacciones.';

  @override
  String get btcUnconfirmed => 'Sin confirmar';

  @override
  String btcConfirmations(String count) {
    return 'Confirmaciones: $count';
  }

  @override
  String get btcTxCopied => 'ID de transacción copiado';

  @override
  String get btcReceiveTitle => 'Recibir bitcoin';

  @override
  String btcReceiveNote(String network) {
    return 'Envía solo bitcoin de $network a esta dirección. Cuando reciba, la billetera muestra una dirección nueva.';
  }

  @override
  String get btcCopyAddress => 'Copiar dirección';

  @override
  String get btcAddressCopied => 'Dirección copiada';

  @override
  String get btcSendTitle => 'Enviar bitcoin';

  @override
  String get btcSendTo => 'Dirección Bitcoin';

  @override
  String btcSendToInvalid(String network) {
    return 'No es una dirección Bitcoin de $network';
  }

  @override
  String get btcSendAmount => 'Cantidad (BTC)';

  @override
  String get btcSendAmountInvalid =>
      'Escribe una cantidad en BTC, con 8 decimales o menos';

  @override
  String get btcSendAll => 'Enviar todo';

  @override
  String get btcSendAllHint => 'La comisión sale de la cantidad';

  @override
  String get btcFeeTitle => 'Tarifa de comisión';

  @override
  String btcFeeFast(String rate) {
    return 'Rápida · $rate sat/vB';
  }

  @override
  String btcFeeNormal(String rate) {
    return 'Cerca de 1 hora · $rate sat/vB';
  }

  @override
  String btcFeeSlow(String rate) {
    return 'Cerca de 1 día · $rate sat/vB';
  }

  @override
  String get btcFeeNoEstimate =>
      'El servidor no da estimación. La app usa la tarifa más baja.';

  @override
  String get btcReview => 'Revisar';

  @override
  String get btcConfirmTitle => '¿Enviar bitcoin?';

  @override
  String get btcRowNetwork => 'Red';

  @override
  String get btcRowAmount => 'Cantidad';

  @override
  String get btcRowFee => 'Comisión';

  @override
  String get btcRowFeeRate => 'Tarifa';

  @override
  String get btcRowChange => 'Cambio';

  @override
  String get btcRowTotal => 'Total';

  @override
  String get btcSendLabel => 'Firmar y enviar';

  @override
  String btcSent(String txid) {
    return 'Enviado: $txid';
  }

  @override
  String get btcConsentNeeded =>
      'El envío necesita la huella o el bloqueo de pantalla. No se envió nada.';

  @override
  String get btcErrLocked =>
      'La billetera está bloqueada. Desbloquéala primero.';

  @override
  String get btcErrFunds => 'No hay suficiente bitcoin confirmado.';

  @override
  String get btcErrUnreachable =>
      'El servidor de Bitcoin no responde. Revisa la red o el servidor en los ajustes de Bitcoin.';

  @override
  String btcErrOther(String reason) {
    return 'Bitcoin: $reason';
  }

  @override
  String get btcSettingsTitle => 'Ajustes de Bitcoin';

  @override
  String get btcNetworkTitle => 'Red';

  @override
  String get btcNetMainnet => 'Mainnet (bitcoin real)';

  @override
  String get btcNetTestnet => 'Testnet (prueba)';

  @override
  String get btcNetSignet => 'Signet (prueba)';

  @override
  String get btcNetRegtest => 'Regtest (prueba local)';

  @override
  String get btcMainnetWarnTitle => '¿Usar bitcoin real?';

  @override
  String get btcMainnetWarnBody =>
      'En mainnet las monedas tienen valor y un envío no se puede deshacer. La billetera Bitcoin de Chatui es nueva: usa cantidades pequeñas.';

  @override
  String get btcMainnetWarnOk => 'Usar mainnet';

  @override
  String get btcServerTitle => 'Servidor Esplora';

  @override
  String btcServerHint(String url) {
    return 'Vacío: $url';
  }

  @override
  String get btcServerNoDefault =>
      'Regtest no tiene servidor público. Escribe uno.';

  @override
  String get btcServerInvalid =>
      'La dirección debe empezar por https:// o http://';

  @override
  String get btcSave => 'Guardar';

  @override
  String get btcSeedNote =>
      'La billetera Bitcoin usa las palabras de tu billetera, en la ruta BIP-84 (SegWit nativo). Cualquier billetera Bitcoin estándar abre los mismos fondos con las mismas palabras.';

  @override
  String get btcDepTitle => 'Depósito en BTC';

  @override
  String get btcDepNode => 'Dirección del nodo (host:puerto)';

  @override
  String get btcDepNodeInvalid => 'Escribe la dirección como host:puerto';

  @override
  String get btcDepCheck => 'Comprobar';

  @override
  String btcDepNoBtc(String network) {
    return 'Este nodo no acepta BTC en $network.';
  }

  @override
  String btcDepNodeNetworks(String networks) {
    return 'Acepta BTC en: $networks';
  }

  @override
  String get btcDepPayTo => 'Paga a';

  @override
  String btcDepRate(String mu) {
    return '$mu MU por sat';
  }

  @override
  String btcDepCredit(String mu) {
    return 'Tu crédito en el nodo: $mu MU';
  }

  @override
  String btcDepWaitsFor(String count) {
    return 'El nodo comprueba el depósito después de $count confirmaciones.';
  }

  @override
  String btcDepWaitsDefault(String count) {
    return 'El nodo no dice cuántas confirmaciones quiere. La app espera $count antes de avisar al nodo.';
  }

  @override
  String get btcDepAmount => 'Cantidad (sat)';

  @override
  String btcDepAmountInvalid(String min) {
    return 'Escribe $min sat o más';
  }

  @override
  String get btcDepPrepare => 'Preparar el depósito';

  @override
  String get btcDepConfirmTitle => '¿Depositar BTC en el nodo?';

  @override
  String btcDepConfirmDetail(String count) {
    return 'El token de depósito del nodo va en una salida OP_RETURN. La app avisa al nodo después de $count confirmaciones. El token caduca 6 horas después de crearse.';
  }

  @override
  String get btcDepRowNode => 'Nodo';

  @override
  String get btcDepRowMu => 'Crédito';

  @override
  String btcDepWaiting(String have, String need) {
    return 'Confirmaciones: $have de $need';
  }

  @override
  String get btcDepUnknownTx => 'El servidor todavía no conoce la transacción.';

  @override
  String get btcDepTelling => 'Preguntando al servidor…';

  @override
  String btcDepAccepted(String mu) {
    return 'El nodo aceptó el depósito. Crédito ahora: $mu MU';
  }

  @override
  String btcDepRefused(String reason) {
    return 'El nodo rechazó el depósito: $reason';
  }

  @override
  String get btcDepPendingTitle => 'Depósitos en espera';

  @override
  String get btcDepWait => 'Esperar';

  @override
  String get btcDepForget => 'Olvidar';

  @override
  String get btcDepPayInBtc => 'Pagar en BTC';

  @override
  String btcDepPayInBtcSubtitle(String network) {
    return 'Este nodo acepta BTC en $network';
  }

  @override
  String get btcWalletButton => 'Billetera Bitcoin';

  @override
  String get celautEnvShare => 'Compartir por QR';

  @override
  String celautEnvShareTitle(String name) {
    return 'Compartir $name';
  }

  @override
  String get celautEnvShareWarn =>
      'Quien escanee este código obtiene el valor en texto plano. Muéstralo solo a personas de confianza.';

  @override
  String get celautEnvShareWarnSensitive =>
      'Esta variable es sensible. Quien escanee este código obtiene el valor en texto plano. Muéstralo solo a personas de confianza y asegúrate de que nadie más ve o graba tu pantalla.';

  @override
  String get celautEnvShareTooBig =>
      'Este valor es demasiado grande para un código QR.';

  @override
  String get celautEnvScan => 'Recibir por QR';

  @override
  String get celautEnvAskScan => 'Escanear un código QR';

  @override
  String get celautEnvScanNotVariable =>
      'Ese código QR no es una variable compartida.';

  @override
  String get chatsStateHibernated => 'Hibernada';

  @override
  String get chatsHibernate => 'Hibernar';

  @override
  String get chatsWake => 'Despertar';

  @override
  String chatsHibernateTitle(String name) {
    return '¿Hibernar $name?';
  }

  @override
  String get chatsHibernateBody =>
      'La instancia deja de usar CPU y RAM, y el nodo cobra solo por su disco. El estado del proceso se pierde: al despertar la instancia, el servicio arranca de nuevo desde su punto de entrada. La dirección y los puertos se mantienen. La app guarda la CPU y la RAM que tiene la instancia ahora, y la despierta con ellas. Hibernar cuesta a la instancia dos tarifas de llamada.';

  @override
  String get chatsHibernated => 'La instancia está hibernada.';

  @override
  String chatsWakeTitle(String name) {
    return '¿Despertar $name?';
  }

  @override
  String chatsWakeBody(String cpu, String ram) {
    return 'La instancia arranca de nuevo con $cpu y $ram. El estado del proceso se perdió: el servicio arranca desde su punto de entrada. Despertar cuesta a la instancia una tarifa de llamada.';
  }

  @override
  String get chatsWakeLastKnown =>
      'La app no sabe si estos valores son los que tenía la instancia al hibernar. Son los últimos que la app obtuvo del nodo.';

  @override
  String get chatsWakeUnknown =>
      'La app no conoce la CPU y la RAM de esta instancia, así que no puede despertarla.';

  @override
  String get chatsWoken => 'La instancia está despierta.';

  @override
  String chatsResourcesCpu(String cores) {
    return '$cores núcleos de CPU';
  }

  @override
  String get chatsRefusalSharedFilesystem =>
      'El nodo no hiberna esta instancia: comparte un sistema de archivos con otras instancias.';

  @override
  String get chatsRefusalNotRevivable =>
      'El nodo no hiberna esta instancia: no puede arrancar de nuevo desde su propio disco.';

  @override
  String get chatsRefusalInstanceBalance =>
      'La instancia no tiene saldo para pagar la tarifa de esta llamada. Añade tiempo a la instancia e inténtalo de nuevo.';

  @override
  String get chatsRefusalDoesNotFit =>
      'El nodo no tiene sitio ahora para la CPU y la RAM de esta instancia. La instancia sigue hibernada. Inténtalo más tarde.';

  @override
  String get chatsRefusalNoLocalInstance =>
      'Esta instancia se ejecuta en un par del nodo, o ya no existe. El nodo no puede hibernarla ni despertarla.';

  @override
  String get chatsRefusalNotTheFather =>
      'El nodo dice que esta app no es la propietaria de la instancia, así que no acepta la llamada.';

  @override
  String get chatsRefusalNoResources =>
      'La app no pudo leer la CPU y la RAM de la instancia, así que no la hibernó. Nada cambió.';

  @override
  String get chatsRefusalUnsupported =>
      'Este nodo no admite la hibernación: es anterior a esa función, así que la app oculta las acciones de hibernar y despertar de sus instancias. No se cobró nada.';

  @override
  String get chatsRefusalNotConfirmed =>
      'El nodo no confirmó la hibernación. Nada cambió en la app.';

  @override
  String chatsRefusalOther(String message) {
    return 'El nodo rechazó la llamada: $message';
  }

  @override
  String get chatsInfoResources => 'CPU y RAM';

  @override
  String get chatsInfoResourcesNone => 'Aún no se conocen';

  @override
  String chatsInfoResourcesLastKnown(String resources) {
    return '$resources (últimos valores conocidos)';
  }

  @override
  String get chatsInfoHibernatedSince => 'Hibernada desde';

  @override
  String get chatsInfoHibernateNote =>
      'Hibernar libera la CPU y la RAM, y el nodo cobra solo por el disco. El estado del proceso se pierde al despertar la instancia.';

  @override
  String get chatsInfoHibernatedNote =>
      'Una instancia hibernada paga solo su disco. Despiértala para usarla de nuevo. Detenla para recibir el reembolso; solo se puede eliminar una instancia detenida.';

  @override
  String get coinErgo => 'Ergo';

  @override
  String get coinBitcoin => 'Bitcoin';

  @override
  String coinTestNetwork(String network) {
    return '$network · red de prueba';
  }

  @override
  String homeCoinPendingFigure(String figure, String unit) {
    return '$figure $unit pendientes';
  }

  @override
  String get btcOverviewUnlockOnce =>
      'Desbloquea la billetera una vez para leer la billetera Bitcoin.';

  @override
  String get btcOverviewUnreachable =>
      'El servidor Bitcoin no respondió. Las cifras pueden ser antiguas.';

  @override
  String get btcWalletRowSubtitle =>
      'Las mismas palabras que la billetera Ergo';

  @override
  String get btcSettingsRowSubtitle => 'Red y servidor';

  @override
  String get btcReceiveAmount => 'Cantidad a pedir (BTC), opcional';

  @override
  String get btcReceiveAmountHelp => 'El código QR pide esta cantidad';

  @override
  String btcScanNotBitcoin(String network) {
    return 'Este código QR no es una dirección Bitcoin de $network';
  }

  @override
  String get btcFeeCustom => 'Otra tarifa';

  @override
  String get btcFeeCustomLabel => 'Tarifa de comisión';

  @override
  String get btcFeeCustomInvalid => 'Escribe una tarifa de 1 a 1000 sat/vB';

  @override
  String get btcTxTime => 'Hora';

  @override
  String get btcTxSize => 'Tamaño';

  @override
  String get btcTxData => 'Datos (OP_RETURN)';

  @override
  String get btcTxUnknownScript => 'No es una dirección';

  @override
  String get btcTxYours => 'tuya';

  @override
  String get btcBump => 'Subir la comisión';

  @override
  String get btcBumpHint =>
      'El pago se envía de nuevo con una comisión más alta y reemplaza al pago que espera (RBF). La comisión sale del cambio.';

  @override
  String btcBumpNow(String rate, String min) {
    return 'La tarifa es $rate sat/vB ahora. La nueva tarifa debe ser $min sat/vB o más.';
  }

  @override
  String btcBumpTooLow(String min) {
    return 'La tarifa debe ser $min sat/vB o más';
  }

  @override
  String get btcBumpConfirmTitle =>
      '¿Enviar de nuevo con una comisión más alta?';

  @override
  String get btcBumpOldFee => 'Comisión anterior';

  @override
  String btcBumped(String txid) {
    return 'Enviado de nuevo con una comisión más alta: $txid';
  }

  @override
  String btcAddressReceive(String index) {
    return 'Recibir n.º $index';
  }

  @override
  String btcAddressChange(String index) {
    return 'Cambio n.º $index';
  }

  @override
  String get btcAddressUsed => 'Usada';

  @override
  String get btcAddressUnused => 'Sin usar';

  @override
  String get btcUtxosTitle => 'Salidas sin gastar';

  @override
  String get btcUtxosNone => 'La billetera no tiene salidas sin gastar.';

  @override
  String get btcOutpointCopied => 'Salida copiada';

  @override
  String get btcBackupTitle => 'Frase de recuperación';

  @override
  String get btcBackupBody =>
      'La billetera Bitcoin no tiene frase de recuperación propia. Sus claves salen de las palabras de la billetera (BIP-84). Guarda esas palabras: restauran la billetera Ergo y la billetera Bitcoin. Cualquier billetera Bitcoin estándar abre los mismos bitcoin con las mismas palabras.';

  @override
  String get btcToolAddressesBlurb =>
      'Cada dirección, lo que tiene y su etiqueta';

  @override
  String get btcToolUtxosBlurb => 'Las monedas de la billetera, una a una';

  @override
  String get btcToolNetworkBlurb => 'La red y el servidor Esplora';

  @override
  String get btcToolBackupBlurb => 'Las mismas palabras que la billetera';

  @override
  String get btcToolLockBlurb => 'Bloquear la billetera: Ergo y Bitcoin';

  @override
  String get celautErrorNoDescendants => 'Este nodo no admite descendientes.';

  @override
  String get descendantsTitle => 'Descendientes';

  @override
  String get descendantsNote =>
      'Instancias que esta instancia arrancó, y las que arrancaron ellas. La app las encuentra cuando compruebas. Una comprobación pregunta al nodo y cuesta MU.';

  @override
  String get descendantsThisInstance => 'Esta instancia';

  @override
  String get descendantsStateAlive => 'Viva';

  @override
  String get descendantsStateStopped => 'Parada';

  @override
  String get descendantsStateNotVerifiable => 'No verificable';

  @override
  String get descendantsStateNotChecked => 'Sin comprobar';

  @override
  String descendantsService(String id) {
    return 'Servicio $id';
  }

  @override
  String get descendantsServiceUnknown => 'Servicio desconocido';

  @override
  String descendantsLastCheck(String time) {
    return 'Última comprobación: $time';
  }

  @override
  String get descendantsNeverChecked => 'Nunca comprobada';

  @override
  String get descendantsCheck => 'Comprobar';

  @override
  String get descendantsCheckTitle => '¿Comprobar con el nodo?';

  @override
  String descendantsCheckBody(String node) {
    return 'La app pide al nodo $node un extracto firmado de la cuenta. Esto cuesta MU y escribe un movimiento en el nodo. Puede costar hasta el máximo de abajo, y no más.';
  }

  @override
  String get descendantsMaxLabel => 'MU máximos';

  @override
  String get descendantsMaxInvalid => 'Escribe un número entero de MU.';

  @override
  String get descendantsCheckConfirm => 'Comprobar y pagar';

  @override
  String get descendantsCancel => 'Cancelar';

  @override
  String descendantsQuoteFailed(String error) {
    return 'La app no puede calcular el coste: $error';
  }

  @override
  String descendantsCheckFailed(String error) {
    return 'La comprobación falló: $error';
  }

  @override
  String descendantsFoundNew(String count) {
    return 'Descendientes nuevos encontrados: $count';
  }

  @override
  String get descendantsFoundNone => 'Ningún descendiente nuevo.';

  @override
  String get descendantsDiedWithMuTitle =>
      'Un nodo terminó una instancia que aún tenía MU';

  @override
  String descendantsDiedWithMu(String mu, String reason) {
    return 'La cuenta terminó con $mu todavía en ella. Motivo: $reason. Los MU se quedaron en el nodo.';
  }

  @override
  String get descendantsFatherGone =>
      'El padre ya no estaba, así que el nodo no dio los MU a nadie.';

  @override
  String get descendantsRefusedTitle => 'El nodo rechazó la comprobación';

  @override
  String get descendantsRefused =>
      'El nodo rechazó mostrar el extracto, así que la app no puede verificar este descendiente. Si murió con MU, la app no puede verlo.';

  @override
  String get descendantsClose => 'Cerrar';

  @override
  String get descendantsOpen => 'Abrir página';

  @override
  String get descendantsNoWeb =>
      'El servicio no declara ninguna página que abrir.';

  @override
  String descendantsOpenFailed(String error) {
    return 'La página no se abrió: $error';
  }

  @override
  String get descendantsChatSlots =>
      'El servicio declara un puerto de chat. La app todavía no lo abre.';

  @override
  String descendantsDepth(String depth) {
    return 'Nivel $depth';
  }

  @override
  String get descendantsRelayed =>
      'Retransmitido. Otro nodo escribió este extracto. El nodo de esta instancia lo firmó de nuevo, y la app no puede comprobar al otro nodo.';

  @override
  String get descendantsUnreadRows =>
      'Comprobado en parte. Faltan movimientos por leer, y uno de ellos puede ser una parada. Comprueba otra vez.';

  @override
  String get descendantsOpenTitle => '¿Abrir con el nodo?';

  @override
  String descendantsOpenBody(String node, String perStream, String hops) {
    return 'La app abre un flujo al descendiente por cada conexión de la página, a través del nodo $node. Abrir un flujo puede costar hasta $perStream MU (como máximo $hops saltos). El tráfico cuesta más. El puerto se detiene tras los flujos que paga el presupuesto de abajo.';
  }

  @override
  String descendantsOpenStreams(String count) {
    return 'El presupuesto paga $count flujos.';
  }

  @override
  String get descendantsOpenBudgetTooSmall =>
      'El presupuesto no paga ni un flujo.';

  @override
  String get descendantsOpenConfirm => 'Abrir y pagar';

  @override
  String get serviceInfoWorkloadsInitial => 'Primeras instancias que arranca';

  @override
  String get serviceInfoWorkloadOr => 'o';

  @override
  String get celautSkillsIntro =>
      'Elige una habilidad para ver los servicios que la hacen.';

  @override
  String get celautStoreOtherField => 'Otros';

  @override
  String celautStoreShowMore(int count) {
    return 'Mostrar más ($count)';
  }

  @override
  String get celautStoreShowFewer => 'Mostrar menos';

  @override
  String get celautSkillAbout => 'Sobre esta habilidad';

  @override
  String celautSkillField(String field) {
    return 'Campo: $field';
  }

  @override
  String get celautSkillTestBanner =>
      'La mayoría de los resultados son pruebas. Compruébalos antes de confiar en ellos.';

  @override
  String get celautSkillRecommended => 'Recomendado';

  @override
  String celautSkillOtherOptions(String count) {
    return 'Otras opciones ($count)';
  }

  @override
  String celautSkillRating(String level) {
    return 'Valoración: $level';
  }

  @override
  String get celautSkillRatingHigh => 'Alta';

  @override
  String get celautSkillRatingMedium => 'Media';

  @override
  String get celautSkillRatingLow => 'Baja';

  @override
  String celautSkillRatingExact(String score) {
    return 'Valoración exacta: $score de 1';
  }

  @override
  String get celautSkillDeclared => 'Declarado por el publicador';

  @override
  String get celautSkillFromResults =>
      'Visto solo en resultados de pruebas, sin declarar por un publicador';

  @override
  String get celautSkillUnverified => 'Sin verificar';

  @override
  String celautSkillServiceId(String id) {
    return 'Id del servicio $id';
  }

  @override
  String get celautSkillIdCopied => 'Id del servicio copiado';

  @override
  String get celautSkillUse => 'Usar este servicio';

  @override
  String get celautRunServicesTitle => 'Servicios con esta habilidad';

  @override
  String get celautRunBest => 'Mejor';

  @override
  String celautRunScore(String score) {
    return 'Puntuación $score';
  }

  @override
  String celautRunDefaultBalance(String balance) {
    return 'Saldo inicial de $balance (por defecto).';
  }

  @override
  String celautRunDefaultBalanceLasts(String balance, String time) {
    return 'Saldo inicial de $balance (por defecto): unos $time en este nodo.';
  }

  @override
  String celautRunMoreOptions(String count) {
    return 'Mostrar $count opciones más';
  }

  @override
  String get celautRunFewerOptions => 'Mostrar menos opciones';

  @override
  String get celautRunCategoryAll => 'Todas';

  @override
  String get celautStoreFeatured => 'Destacadas';

  @override
  String get celautStoreFeaturedHint =>
      'Una habilidad de cada campo, del publicador con más reputación';

  @override
  String get celautStoreSuggested => 'Sugeridas para ti';

  @override
  String get celautStoreSuggestedHint =>
      'En los campos de las habilidades que ejecutaste';

  @override
  String get celautStoreNew => 'Nuevas';

  @override
  String get celautStoreNewHint => 'Las últimas habilidades publicadas en Ergo';

  @override
  String get celautStorePopular => 'Populares';

  @override
  String get celautStorePopularHint => 'Las habilidades con más servicios';

  @override
  String get celautStoreCategories => 'Categorías';

  @override
  String get celautStoreAll => 'Todas las habilidades';

  @override
  String celautStoreSkills(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count habilidades',
      one: '1 habilidad',
    );
    return '$_temp0';
  }

  @override
  String get cardsLoading => 'Cargando las cartas…';

  @override
  String get cardsNoDeck => 'El servicio no tiene cartas ahora.';

  @override
  String get cardsEnd => 'No quedan más cartas.';

  @override
  String get cardsBackToChat => 'Volver al chat';

  @override
  String get cardsUndo => 'Deshacer';

  @override
  String cardsProgress(int position, int total) {
    return '$position de $total';
  }

  @override
  String cardsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimientos esperan para enviarse',
      one: '1 movimiento espera para enviarse',
    );
    return '$_temp0';
  }

  @override
  String get cardsConnecting => 'Conectando…';

  @override
  String get cardsTapForDetail => 'Toca la carta para ver los detalles';

  @override
  String get chatOpenCards => 'Abrir las cartas';

  @override
  String get celautIdCopied => 'Id copiado';

  @override
  String get celautIdShowFull => 'Mostrar el id completo';

  @override
  String get celautIdShowShort => 'Mostrar el id corto';

  @override
  String get celautClientIdLabel => 'Id de cliente';

  @override
  String get celautClientIdNone => 'Todavía no hay cliente';

  @override
  String get celautClientIdCopied => 'Id de cliente copiado';

  @override
  String get celautNodesDetail => 'Detalles del nodo';

  @override
  String get celautResourcesScreenTitle => 'Recursos de los nodos';

  @override
  String get celautResourcesByResource => 'Por recurso';

  @override
  String get celautResourcesByNode => 'Por nodo';

  @override
  String get celautResourcesNote =>
      'Lo que ofrecen los nodos, no lo que está libre ahora.';

  @override
  String celautResourcesUnreachable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodos no respondieron y no están en el total',
      one: '1 nodo no respondió y no está en el total',
    );
    return '$_temp0';
  }

  @override
  String get celautResourcesNoNode => 'Ningún nodo respondió.';

  @override
  String celautResourcesTotal(String resource, String total, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodos',
      one: '1 nodo',
    );
    return '$resource: $total en $_temp0';
  }

  @override
  String celautResourcesShareHint(int count) {
    return 'La parte de este nodo en el total de los $count nodos que respondieron';
  }
}
