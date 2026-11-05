// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Chatui';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonDone => 'Done';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopyId => 'Copy id';

  @override
  String get commonClose => 'Close';

  @override
  String get commonName => 'Name';

  @override
  String get commonAddress => 'Address';

  @override
  String get commonAddresses => 'Addresses';

  @override
  String get commonAddressCopied => 'Address copied';

  @override
  String get commonMinerFee => 'Miner fee';

  @override
  String get commonWallet => 'Wallet';

  @override
  String get commonThisWallet => 'This wallet';

  @override
  String get commonToken => 'Token';

  @override
  String get commonTokens => 'Tokens';

  @override
  String get commonContacts => 'Contacts';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonPending => 'Pending';

  @override
  String get commonOffline => 'Offline';

  @override
  String get commonBalanceUnavailable => 'Balance unavailable';

  @override
  String get commonNotAnErgoAddress => 'Not an Ergo address';

  @override
  String get monthShort1 => 'Jan';

  @override
  String get monthShort2 => 'Feb';

  @override
  String get monthShort3 => 'Mar';

  @override
  String get monthShort4 => 'Apr';

  @override
  String get monthShort5 => 'May';

  @override
  String get monthShort6 => 'Jun';

  @override
  String get monthShort7 => 'Jul';

  @override
  String get monthShort8 => 'Aug';

  @override
  String get monthShort9 => 'Sep';

  @override
  String get monthShort10 => 'Oct';

  @override
  String get monthShort11 => 'Nov';

  @override
  String get monthShort12 => 'Dec';

  @override
  String clockTime(
    String hour12,
    String hour24,
    String minute,
    String space,
    String period,
  ) {
    return '$hour12:$minute$space$period';
  }

  @override
  String get clockAm => 'am';

  @override
  String get clockPm => 'pm';

  @override
  String dateMonthDay(String month, String day) {
    return '$month $day';
  }

  @override
  String dateMonthDayYear(String month, String day, String year) {
    return '$month $day, $year';
  }

  @override
  String dateMonthDayTime(String month, String day, String time) {
    return '$month $day, $time';
  }

  @override
  String dateDayMonthYear(String month, String day, String year) {
    return '$day $month $year';
  }

  @override
  String dateNumeric(String month, String day, String year) {
    return '$month/$day/$year';
  }

  @override
  String timeToday(String time) {
    return 'Today, $time';
  }

  @override
  String timeYesterdayAt(String time) {
    return 'Yesterday, $time';
  }

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeSecondsAgo(int count) {
    return '${count}s ago';
  }

  @override
  String timeMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get syncAgeJustNow => 'just now';

  @override
  String syncAgeMinutes(int count) {
    return '${count}m ago';
  }

  @override
  String syncAgeHours(int count) {
    return '${count}h ago';
  }

  @override
  String syncAgeDays(int count) {
    return '${count}d ago';
  }

  @override
  String get dateUnknownDay => 'Unknown day';

  @override
  String get celautNodeRowTitle => 'Celaut node';

  @override
  String get celautNodeRowSubtitle =>
      'Connect to a node and show its advertisement';

  @override
  String get celautScreenTitle => 'Celaut node';

  @override
  String get celautIntro =>
      'Connect to a Celaut node and check who it is. The app checks the identity in its certificate and the signature of its advertisement. Nothing is started and nothing is paid.';

  @override
  String get celautAddressLabel => 'Node address';

  @override
  String get celautAddressHint => 'host:port';

  @override
  String get celautExpectedLabel => 'Expected peer id (optional)';

  @override
  String get celautExpectedHint => '64 hexadecimal characters';

  @override
  String get celautConnect => 'Connect';

  @override
  String get celautConnecting => 'Connecting…';

  @override
  String get celautIdentityTitle => 'Identity';

  @override
  String get celautPeerIdLabel => 'Peer id';

  @override
  String get celautAdvertisedLabel => 'Advertised at';

  @override
  String get celautUrisTitle => 'Addresses';

  @override
  String get celautRatesTitle => 'Rates';

  @override
  String get celautContractsTitle => 'Payment contracts';

  @override
  String get celautResourcesTitle => 'Resources';

  @override
  String get celautProofsLabel => 'Reputation proofs';

  @override
  String get celautNoUris => 'The node advertises no address.';

  @override
  String get celautNoRates => 'The node advertises no rates.';

  @override
  String get celautNoContracts =>
      'The node advertises no payment contract. It cannot be paid yet.';

  @override
  String get celautNoResources => 'The node gives no data about its resources.';

  @override
  String get celautRatesNote => 'Rates are in MU.';

  @override
  String get celautVerifiedNote =>
      'The certificate and the signature were checked. This node is who it says it is.';

  @override
  String get celautAddressEmpty =>
      'Enter the address of the node as host:port.';

  @override
  String get celautAddressInvalid =>
      'This address is not valid. Use host:port, for example 203.0.113.7:8090.';

  @override
  String get celautPortInvalid => 'The port must be a number from 1 to 65535.';

  @override
  String get celautExpectedInvalid =>
      'The peer id must be 64 hexadecimal characters, or empty.';

  @override
  String get celautErrorTitle => 'Cannot show this node';

  @override
  String get celautErrorInvalidInput =>
      'The address is not valid. Check the host and the port.';

  @override
  String get celautErrorUnreachable =>
      'The app cannot connect to this address. Check the address and the network, and check that the node is running.';

  @override
  String get celautErrorTimeout =>
      'The node did not answer in time. Try again, or check the address.';

  @override
  String get celautErrorIdentityMismatch =>
      'The identity of this node is not the one that was expected. The address may now belong to another node. The app did not trust it.';

  @override
  String get celautErrorBadCertificate =>
      'The certificate of this server has no valid Celaut identity. It may not be a Celaut node. The app did not trust it.';

  @override
  String get celautErrorBadSignature =>
      'The signature of the node advertisement is not valid. The app did not trust it.';

  @override
  String get celautErrorStaleTimestamp =>
      'This advertisement is older than one that the app accepted before. Someone may be replaying an old message. The app did not trust it.';

  @override
  String get celautErrorUnsupportedScheme =>
      'The node signs with a scheme that this app does not support.';

  @override
  String get celautErrorProofOfWork =>
      'The node asks for more work than the app does for a new client, or it did not accept the work.';

  @override
  String get celautErrorProtocol =>
      'The node refused the request or sent an answer that the app cannot use.';

  @override
  String get celautErrorStorage =>
      'The app cannot read or write its list of known advertisements.';

  @override
  String get celautErrorLimitReached =>
      'This deposit would pass the limit that you set for this node.';

  @override
  String get celautErrorWallet =>
      'The wallet cannot make this transaction. Check the balance and the network.';

  @override
  String celautDetailLabel(String detail) {
    return 'Detail: $detail';
  }

  @override
  String celautCores(int count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$value cores',
      one: '$value core',
    );
    return '$_temp0';
  }

  @override
  String get celautMemoryLabel => 'Memory';

  @override
  String get celautDiskLabel => 'Disk';

  @override
  String get celautCpuLabel => 'CPU';

  @override
  String get celautBenchmarkLabel => 'Benchmark';

  @override
  String get celautNoExpiry => 'no expiry given';

  @override
  String celautExpires(String when) {
    return 'valid until $when';
  }

  @override
  String celautPerUnit(String mu) {
    return '$mu MU per base unit';
  }

  @override
  String get aboutTitle => 'About';

  @override
  String get securityTitle => 'Security';

  @override
  String get networkTitle => 'Network';

  @override
  String get displayTitle => 'Display';

  @override
  String get chatSettingsTitle => 'Chat';

  @override
  String get chatSettingsRowSubtitle =>
      'Text size, font, pinned messages, widgets';

  @override
  String get chatSettingsTextGroup => 'Text';

  @override
  String get chatSettingsFontSize => 'Text size';

  @override
  String get chatSettingsFontFamily => 'Font';

  @override
  String get chatSettingsPreview =>
      'The assistant answer looks like this. Pick the size you read best.';

  @override
  String get chatFontSystem => 'System';

  @override
  String get chatFontLato => 'Lato';

  @override
  String get chatFontSerif => 'Serif';

  @override
  String get chatFontMono => 'Monospace';

  @override
  String get chatSettingsPinnedGroup => 'Pinned messages';

  @override
  String get chatSettingsPinnedMax => 'Maximum height of a pinned message';

  @override
  String get chatSettingsPinnedNote =>
      'A pinned message stays at the top of the chat. It uses at most this part of the chat height.';

  @override
  String get chatSettingsWidgetsGroup => 'Widgets';

  @override
  String get chatHtmlLoading => 'Making the widget…';

  @override
  String get chatKeyboardLabel => 'Keyboard';

  @override
  String get chatKeyboardClose => 'Close the keyboard';

  @override
  String get chatSettingsHtmlWidgets => 'HTML widgets';

  @override
  String get chatSettingsHtmlWidgetsSubtitle =>
      'Show simple HTML from the assistant as widgets. If off, it shows as code. No scripts and no network.';

  @override
  String get chatSettingsKeyboardGroup => 'Keyboard';

  @override
  String get chatSettingsSystemKeyboard => 'Use the system keyboard';

  @override
  String get chatSettingsSystemKeyboardSubtitle =>
      'If off, the chat types with the keyboard of the app, under the input. If on, the system keyboard shows, except while a form is open.';

  @override
  String get chatSettingsWordSuggestions => 'Word suggestions';

  @override
  String get chatSettingsWordSuggestionsSubtitle =>
      'The keyboard of the app shows words that complete or correct the word you write, from the words of the conversation. It never changes a word by itself. The replies that the service suggests show either way.';

  @override
  String get chatSuggestionsLabel => 'Suggestions';

  @override
  String get chatVkBackspace => 'Delete';

  @override
  String get chatVkShift => 'Capital letter';

  @override
  String get chatVkSymbols => 'Numbers and symbols';

  @override
  String get chatVkLetters => 'Letters';

  @override
  String get chatVkSpace => 'Space';

  @override
  String get chatVkEnter => 'New line';

  @override
  String get chatBgNone => 'None';

  @override
  String get chatBgDawn => 'Dawn';

  @override
  String get chatBgOcean => 'Ocean';

  @override
  String get chatBgForest => 'Forest';

  @override
  String get chatBgDusk => 'Dusk';

  @override
  String get chatBgDots => 'Dots';

  @override
  String get chatBgWaves => 'Waves';

  @override
  String get chatBgDiamonds => 'Diamonds';

  @override
  String get addressBookTitle => 'Address book';

  @override
  String get settingsAboutRowTitle => 'About Chatui';

  @override
  String get settingsAboutRowSubtitle => 'Version, release notes, licenses';

  @override
  String get settingsWalletRowTitle => 'Addresses and backup';

  @override
  String get settingsWalletRowSubtitle =>
      'Primary address, change policy, remove';

  @override
  String get settingsSecurityWalletSubtitle => 'Phone unlock, auto-lock';

  @override
  String get settingsErgoGroup => 'Ergo';

  @override
  String get settingsComputeGroup => 'Compute';

  @override
  String get settingsGeneralGroup => 'General';

  @override
  String get settingsScopeAppWide => 'App-wide';

  @override
  String get settingsSecurityAppSubtitle =>
      'Auto-lock, screenshots, unconfirmed funds';

  @override
  String get settingsRemotePreviewsTitle => 'Remote previews';

  @override
  String get settingsRemotePreviewsSubtitle =>
      'IPFS gateway and Never load remote previews';

  @override
  String settingsContactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
    );
    return '$_temp0';
  }

  @override
  String get settingsUnlocked => 'Unlocked';

  @override
  String get settingsLocked => 'Locked';

  @override
  String get aboutSaveSettingFailed => 'Could not save the setting.';

  @override
  String get aboutAskingGithub => 'Asking GitHub…';

  @override
  String get aboutNotCheckedYet => 'Not checked yet';

  @override
  String aboutUpToDateChecked(String when) {
    return 'Up to date · checked $when';
  }

  @override
  String aboutVersionAvailableChecked(String version, String when) {
    return 'Version $version is available · checked $when';
  }

  @override
  String aboutVersionBuild(String version, String build) {
    return '$version · build $build';
  }

  @override
  String get aboutUpdatesGroup => 'Updates';

  @override
  String get aboutCheckForUpdates => 'Check for updates';

  @override
  String get aboutCheckForUpdatesSubtitle =>
      'Asks GitHub once a day. GitHub sees your IP address, or a Tor exit when Tor is on.';

  @override
  String get aboutCheckNow => 'Check now';

  @override
  String get aboutUpdatesNote =>
      'Off by default. When on, Chatui asks api.github.com for the latest release once a day as it starts. \"Check now\" does the same on request, even with this off. Nothing else is sent: no account, token, app version or device identifier. A download comes from github.com and is checked against this app\'s signing key before Android is asked to install it.';

  @override
  String get aboutThisBuild => 'This build';

  @override
  String get aboutUnauditedTitle => 'Unaudited prototype';

  @override
  String get aboutUnauditedSubtitle =>
      'Transactions on Ergo are irreversible. Use only funds you can afford to lose.';

  @override
  String get aboutReleasesTitle => 'Releases and notes';

  @override
  String get aboutReleasesSubtitle =>
      'What changed in each alpha, and the latest APK.';

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String get aboutLightClientNote =>
      'Chatui is a light client: it talks to public Ergo nodes over HTTPS and never sends your keys anywhere.';

  @override
  String get aboutSigningCertificate => 'Signing certificate';

  @override
  String get aboutSigningCertificateSubtitle =>
      'SHA-256 of the key this build is signed with. An update must be signed with the same one.';

  @override
  String get aboutReading => 'Reading…';

  @override
  String get aboutNotAvailableOnDevice => 'Not available on this device.';

  @override
  String get aboutFingerprintCopied => 'Fingerprint copied';

  @override
  String get addressBookContactsEmpty =>
      'People you send to. Save one from the Send screen.';

  @override
  String addressBookContactsSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved',
    );
    return '$_temp0';
  }

  @override
  String get addressBookLabelsSection => 'Labels for my addresses';

  @override
  String get addressBookNoLabelsTitle => 'No labels yet';

  @override
  String get addressBookNoLabelsBody =>
      'Tap any of your addresses on the home or Receive screen to name it.';

  @override
  String get addressBookRemoveLabel => 'Remove label';

  @override
  String get displayAppearance => 'Appearance';

  @override
  String get displayFollowSystem => 'Follow system';

  @override
  String get displayAlwaysDark => 'Always dark';

  @override
  String get displayAlwaysLight => 'Always light';

  @override
  String displaySystemPalettes(String dark, String light) {
    return 'Dark → $dark, light → $light';
  }

  @override
  String get displayDarkPalette => 'Dark palette';

  @override
  String get displayLightPalette => 'Light palette';

  @override
  String get displayMoney => 'Money';

  @override
  String get displayPricesInUsd => 'Prices in USD';

  @override
  String get displayHideBalances => 'Hide balances';

  @override
  String get displayHideBalancesSubtitle => 'Mask amounts on the home screen';

  @override
  String get displayVehicleMotionCues => 'Vehicle motion cues';

  @override
  String get displayVehicleMotionCuesNote =>
      'Dots at the sides of the screen move with the car, bus or train, so reading on the road makes you less sick.';

  @override
  String get displayMotionCuesOff => 'Off';

  @override
  String get displayMotionCuesAutomatic => 'Automatic';

  @override
  String get displayMotionCuesAutomaticSubtitle =>
      'When the phone feels that you ride a vehicle';

  @override
  String get displayMotionCuesAlways => 'Always';

  @override
  String get displayMotionCuesAlwaysSubtitle => 'All the time';

  @override
  String get displayMotionCuesGps => 'Use the speed of the GPS';

  @override
  String get displayMotionCuesGpsSubtitle =>
      'Tells a vehicle from a walk better. Needs the precise location; the app keeps no position and sends nothing';

  @override
  String get displayMotionCuesGpsDenied =>
      'Without the precise location the app cannot read the speed of the GPS';

  @override
  String get themeTealName => 'Celaut Teal';

  @override
  String get themeTealHint => 'Teal, cream type, coral';

  @override
  String get themeCreamName => 'Celaut Cream';

  @override
  String get themeCreamHint => 'Cream, teal type, coral';

  @override
  String get themeObsidianName => 'Obsidian';

  @override
  String get themeObsidianHint => 'True black, steel accent';

  @override
  String get themeHarborName => 'Harbor';

  @override
  String get themeHarborHint => 'Deep navy, teal accent';

  @override
  String get themeEmberName => 'Ember';

  @override
  String get themeEmberHint => 'Warm charcoal, copper accent';

  @override
  String get themeParchmentName => 'Parchment';

  @override
  String get themeParchmentHint => 'Cream, sage accent';

  @override
  String get themeFrostName => 'Frost';

  @override
  String get themeFrostHint => 'Cool white, slate-blue accent';

  @override
  String get themeCyberpunkName => 'Cyberpunk';

  @override
  String get themeCyberpunkHint => 'Night violet, neon pink';

  @override
  String get themeAppleLightName => 'Apple Light';

  @override
  String get themeAppleLightHint => 'Clean white, system blue';

  @override
  String get themeAppleDarkName => 'Apple Dark';

  @override
  String get themeAppleDarkHint => 'True black, system blue';

  @override
  String get themeMaterialLightName => 'Material Light';

  @override
  String get themeMaterialLightHint => 'Soft lilac, Material purple';

  @override
  String get themeMaterialDarkName => 'Material Dark';

  @override
  String get themeMaterialDarkHint => 'Dark grey, lilac accent';

  @override
  String get themeNordName => 'Nord';

  @override
  String get themeNordHint => 'Arctic slate, ice blue';

  @override
  String get themeSolarizedName => 'Solarized';

  @override
  String get themeSolarizedHint => 'Warm paper, blue accent';

  @override
  String get themeDraculaName => 'Dracula';

  @override
  String get themeDraculaHint => 'Deep indigo, purple accent';

  @override
  String get networkConnectedNode => 'Connected node';

  @override
  String get networkChecking => 'Checking…';

  @override
  String get networkCheckNodes => 'Check nodes';

  @override
  String get networkNodes => 'Nodes';

  @override
  String get networkAddNodeLabel => 'Add node URL';

  @override
  String get networkAddNodeHint => 'https://host  or  1.2.3.4:9053';

  @override
  String get networkAdd => 'Add';

  @override
  String get networkNodesNote =>
      'Tap a node to use it. Automatic picks the reachable node with extraIndex and the smallest index lag. Built-in nodes are HTTPS; you can add http://ip:port for a node you run or trust, unencrypted.';

  @override
  String get networkFindMoreNodes => 'Find more nodes';

  @override
  String get networkDiscovering =>
      'Asking every node for its peers and checking each…';

  @override
  String get networkDiscoverIntro =>
      'Peers of your nodes that publish an HTTPS API.';

  @override
  String get networkSearching => 'Searching…';

  @override
  String get networkSearch => 'Search';

  @override
  String get networkOpenInExplorer => 'Open in explorer';

  @override
  String get networkCustom => 'Custom';

  @override
  String get networkCustomSiteSubtitle =>
      'A website using the Ergo Platform explorer paths';

  @override
  String get networkExplorerWebsite => 'Explorer website';

  @override
  String get networkExplorerSiteNote =>
      'Where transaction and token links open. This changes no data the wallet reads.';

  @override
  String get networkExplorerApi => 'Explorer API';

  @override
  String get networkCustomApiSubtitle =>
      'Any server speaking the Ergo Platform explorer API';

  @override
  String get networkExplorerApiUrl => 'Explorer API URL';

  @override
  String get networkExplorerApiNote =>
      'The data source for token metadata when nodes lack it. ErgExplorer and Kadia use their own APIs, so they cannot be chosen here.';

  @override
  String get networkAutomatic => 'Automatic';

  @override
  String get networkBestReachable => 'Best reachable extraIndex node';

  @override
  String networkUsingHost(String host) {
    return 'Using $host';
  }

  @override
  String networkExtraIndexLag(String lag) {
    return 'extraIndex, lag $lag';
  }

  @override
  String get networkNoExtraIndex => 'no extraIndex';

  @override
  String get networkDisable => 'Disable';

  @override
  String get networkEnable => 'Enable';

  @override
  String get networkNodeOff => 'Off';

  @override
  String get networkNodeInUse => 'In use';

  @override
  String get networkNodeStandby => 'Standby';

  @override
  String get networkNodeChosen => 'chosen';

  @override
  String get networkNodeUnreachable => 'unreachable';

  @override
  String get networkAddNodeInvalid => 'Enter https://host or http://ip:port';

  @override
  String get networkNodeAlreadyAdded => 'Node already added';

  @override
  String get networkSearchNoAnswer =>
      'No node answered the peer request. Check your connection, or try another node.';

  @override
  String networkSearchNoNewApi(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Asked $count nodes: their peers publish no HTTPS API you do not already have.',
      one:
          'Asked $count node: their peers publish no HTTPS API you do not already have.',
    );
    return '$_temp0';
  }

  @override
  String networkSearchNoneReachable(String found) {
    return 'Checked $found found, none reachable right now.';
  }

  @override
  String networkSearchNoneReachablePartial(String checked, String found) {
    return 'Checked $checked of $found found, none reachable right now.';
  }

  @override
  String networkSearchReachable(String reachable, String found) {
    return '$reachable reachable of $found found, best first.';
  }

  @override
  String networkSearchReachablePartial(
    String reachable,
    String checked,
    String found,
  ) {
    return '$reachable reachable of $checked of $found found, best first.';
  }

  @override
  String get pinHelper => '6–32 characters. Number pad first.';

  @override
  String get pinConfirm => 'Confirm PIN';

  @override
  String get pinMismatch => 'PINs do not match';

  @override
  String get pinIncorrect => 'Incorrect PIN';

  @override
  String get securityBiometricDisabled => 'Biometric unlock disabled';

  @override
  String get securityBiometricDisableFailed => 'Could not disable biometrics';

  @override
  String get securityPinLockoutCheckFailed => 'Could not check PIN lockout';

  @override
  String get securityNoPinWalletFound => 'No PIN-protected wallet found.';

  @override
  String get securityBiometricEnabled => 'Biometric unlock enabled';

  @override
  String get securityBiometricEnableFailed => 'Could not enable biometrics';

  @override
  String get securityChangePin => 'Change PIN';

  @override
  String get securityNewPin => 'New PIN';

  @override
  String get securityChange => 'Change';

  @override
  String get securityNoPinWallet => 'No PIN-protected wallet found';

  @override
  String get securityPinChanged => 'PIN changed';

  @override
  String get securityPinChangedLockoutNotReset =>
      'PIN changed but lockout state could not be reset';

  @override
  String get securityChangePinFailed => 'Could not change PIN';

  @override
  String get securityLockImmediately => 'Immediately';

  @override
  String securityLockAfterSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'After $count seconds',
    );
    return '$_temp0';
  }

  @override
  String securityLockAfterMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'After $count minutes',
      one: 'After $count minute',
    );
    return '$_temp0';
  }

  @override
  String get securityLockWhenBackgrounded => 'Lock when backgrounded';

  @override
  String get securityAutoLockUpdateFailed => 'Could not update auto-lock';

  @override
  String get securityAutoLock => 'Auto-lock';

  @override
  String get securityUnlockGroup => 'Unlock';

  @override
  String get securityUnlockFirst => 'Unlock the wallet first';

  @override
  String get securityUnlockFirstSubtitle =>
      'Biometric and PIN settings need an unlocked wallet.';

  @override
  String get securityRetryUnlockSettings => 'Retry unlock settings';

  @override
  String get securityReadSetupFailed => 'Could not read the current setup.';

  @override
  String get securityBiometricUnlock => 'Unlock with your phone';

  @override
  String get securityBiometricOn => 'Fingerprint or screen lock';

  @override
  String get securityOff => 'Off';

  @override
  String get securitySetPinHint =>
      'Set a PIN when you create or restore a wallet.';

  @override
  String get securityDeviceLockNote =>
      'The wallet opens with your fingerprint or the screen lock of your phone. The app has no PIN of its own.';

  @override
  String get securityScreen => 'Screen';

  @override
  String get securityBlockScreenshots => 'Block screenshots';

  @override
  String get securityScreenshotsBlocked =>
      'Screens cannot be captured or recorded';

  @override
  String get securityScreenshotsAllowed =>
      'Off: you can capture screens to report issues';

  @override
  String get securitySeedScreensNote =>
      'Seed phrase screens always block capture, whatever this setting says.';

  @override
  String get securitySpending => 'Spending';

  @override
  String get securitySpendUnconfirmed => 'Spend unconfirmed funds';

  @override
  String get securitySpendUnconfirmedOn =>
      'On: received funds and change can be spent at once';

  @override
  String get securitySpendUnconfirmedOff =>
      'Off: received funds and change wait for 1 confirmation';

  @override
  String get securitySpendingSaveFailed =>
      'Could not save the spending setting';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateCardVersion(String version) {
    return 'Chatui $version';
  }

  @override
  String updateCardVersionDate(String version, String date) {
    return 'Chatui $version · $date';
  }

  @override
  String get updateHideNotes => 'Hide release notes';

  @override
  String get updateReleaseNotes => 'Release notes';

  @override
  String get updateDownloadProgress => 'Download progress';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String updateDownloadingOf(String done, String total) {
    return 'Downloading $done of $total';
  }

  @override
  String get updateCheckingDownload => 'Checking the download';

  @override
  String get updateCheckingAgainstKey =>
      'Checking the download against this app\'s signing key…';

  @override
  String get updateCertMatches => 'The signing certificate matches this app.';

  @override
  String updateCertMatchesWith(String fingerprint) {
    return 'The signing certificate matches this app (SHA-256 $fingerprint…).';
  }

  @override
  String get updateAndroidChecksSignature =>
      'Android checks the signature itself when it installs.';

  @override
  String get updateInstall => 'Install';

  @override
  String get updateTryAgain => 'Try again';

  @override
  String get updateDownloadAndVerify => 'Download and verify';

  @override
  String updateAssetNote(String name, String size) {
    return '$name · $size. Before anything is installed, Chatui checks the file against the checksum GitHub lists and against the key this app is signed with.';
  }

  @override
  String get updateOpenReleasesPage => 'Open the releases page';

  @override
  String get updateNoApkForPhone => 'This release has no APK for your phone.';

  @override
  String updateNoticeAvailable(String version) {
    return 'Chatui $version is available.';
  }

  @override
  String get updateNoticeView => 'View';

  @override
  String get updateNoticeDismiss => 'Dismiss';

  @override
  String get updateErrorTimeout => 'GitHub did not answer in time.';

  @override
  String get updateErrorUnreachable =>
      'Could not reach GitHub. Check your connection.';

  @override
  String get updateErrorRouteBlocked =>
      'Tor is on and not ready, so the app does not connect to GitHub. Try again when Tor is ready (Settings, Developer, Tor).';

  @override
  String updateErrorStatus(String status) {
    return 'GitHub answered with an error ($status).';
  }

  @override
  String get updateErrorBadRedirect =>
      'GitHub sent a redirect that was not understood.';

  @override
  String get updateErrorRedirectedAway =>
      'The request was redirected away from GitHub, so it was stopped.';

  @override
  String get updateErrorTooManyRedirects =>
      'GitHub redirected the request too many times.';

  @override
  String get updateErrorRateLimited =>
      'GitHub is limiting requests from this network. Try again later.';

  @override
  String get updateErrorNoRelease => 'GitHub has no release to offer.';

  @override
  String get updateErrorNotUnderstood => 'GitHub\'s answer was not understood.';

  @override
  String get updateErrorTooLarge =>
      'GitHub\'s answer was larger than expected.';

  @override
  String get updateErrorNotOnGithub => 'The download address is not on GitHub.';

  @override
  String get updateErrorDownloadTooLarge =>
      'The download is larger than Chatui will accept.';

  @override
  String get updateErrorStorage =>
      'Chatui could not save the download. Is the phone out of storage?';

  @override
  String get updateErrorLargerThanListed =>
      'The download is larger than GitHub lists it, so it was stopped.';

  @override
  String get updateErrorEndedEarly => 'The download ended early.';

  @override
  String get updateRejectedWrongSigner =>
      'This download is not signed by the same key as this app, so it must not be installed. It has been deleted.';

  @override
  String get updateRejectedChecksum =>
      'This download does not match the SHA-256 checksum GitHub lists for it, so it may be damaged or tampered with. It has been deleted.';

  @override
  String get updateRejectedUnreadable =>
      'The signing key of this download could not be read, so it was not offered for install. It has been deleted.';

  @override
  String get updateRejectedAppKeyUnknown =>
      'Chatui could not read its own signing key, so it cannot check this download. It has been deleted.';

  @override
  String get updateCheckFailed => 'The update check failed.';

  @override
  String get updateNoApkSeeReleases =>
      'This release has no APK for your phone. The releases page has the files.';

  @override
  String get updateCannotKeepDownload => 'This device cannot keep a download.';

  @override
  String get updateDownloadCancelled => 'Download cancelled.';

  @override
  String get updateDownloadFailed => 'The download failed.';

  @override
  String get updateInstallPermission =>
      'Android needs your permission first. Allow Chatui to install apps on the next screen, then tap Install again.';

  @override
  String get updateInstallerFailed =>
      'Android could not open its installer. The releases page has the file.';

  @override
  String get walletSettingsRemoveTitle => 'Remove the wallet?';

  @override
  String get walletSettingsRemoveBody =>
      'This removes the wallet from this device. Chatui does not keep a copy of the recovery phrase; the paper you wrote when creating this wallet is the only way back in. After that, you can create or restore another wallet.';

  @override
  String get walletSettingsRemoveFailed => 'Could not remove wallet';

  @override
  String get walletSettingsPinIndexTitle => 'Pin address index';

  @override
  String get walletSettingsPinIndexIntro =>
      'Derive the address at this index and use it as the primary address for send and receive. Index 0 resets to the default. The balance still counts every address of the wallet.';

  @override
  String get walletSettingsIndexLabel => 'Index';

  @override
  String get walletSettingsPin => 'Pin';

  @override
  String get walletSettingsInvalidIndex => 'Invalid index';

  @override
  String walletSettingsIndexTooHigh(String max) {
    return 'This wallet can\'t derive past index $max';
  }

  @override
  String walletSettingsCannotDerive(String index) {
    return 'Wallet can\'t derive index $index';
  }

  @override
  String walletSettingsPinnedIndex(String index, String address) {
    return 'Pinned index $index · $address';
  }

  @override
  String walletSettingsPinnedOutOfRange(String index) {
    return 'Pinned index #$index can\'t be derived';
  }

  @override
  String walletSettingsPrimaryPinned(String index) {
    return 'Primary address: index #$index';
  }

  @override
  String get walletSettingsPrimaryDefault => 'Primary address: index 0';

  @override
  String walletSettingsOutOfRangeHint(String max) {
    return 'This wallet derives up to index $max. Unpin or choose a lower index.';
  }

  @override
  String get walletSettingsPrimaryHint =>
      'Receive and change default to this address until it is used.';

  @override
  String get walletSettingsUnpin => 'Unpin';

  @override
  String get walletSettingsFreshAddresses => 'Fresh addresses';

  @override
  String get walletSettingsFreshAddressesSubtitle =>
      'Receive and change on a new address each time, like Nautilus. Off: everything uses your pinned or first address.';

  @override
  String get walletSettingsUnlockToChange =>
      'Unlock the wallet to change this setting';

  @override
  String get walletSettingsPrivacySaveFailed =>
      'Could not update privacy setting';

  @override
  String get walletSettingsBackup => 'Backup';

  @override
  String get walletSettingsBackupNote =>
      'Chatui does not keep a copy of the recovery phrase. The paper you wrote at create or restore is the only way back in.';

  @override
  String get walletSettingsRemoveWallet => 'Remove wallet';

  @override
  String get walletSettingsRemoveWalletSubtitle =>
      'From this device only. Keep the recovery phrase.';

  @override
  String get secureSaveFailed => 'Failed to save';

  @override
  String get secureSaveWrapKeyFailed => 'Failed to save wrap key';

  @override
  String get secureSavePinWrapFailed => 'Failed to save PIN wrap';

  @override
  String get secureLoadWrapKeyFailed => 'Failed to load wrap key';

  @override
  String get secureLoadPinWrapFailed => 'Failed to load PIN wrap';

  @override
  String get secureLoadFailed => 'Failed to load';

  @override
  String secureDeleteWrapKeyFailed(String detail) {
    return 'Failed to delete wrap key: $detail';
  }

  @override
  String secureDeleteSecretsFailed(String detail) {
    return 'Failed to delete wallet secrets: $detail';
  }

  @override
  String secureDeleteWalletFailed(String detail) {
    return 'Failed to delete wallet: $detail';
  }

  @override
  String secureCheckFailed(String detail) {
    return 'Failed to check: $detail';
  }

  @override
  String get secureCheckPinWrapFailed => 'Failed to check PIN wrap';

  @override
  String get secureCheckWrapKeyFailed => 'Failed to check wrap key';

  @override
  String get secureCheckBiometricsFailed => 'Failed to check biometrics';

  @override
  String get secureBiometric => 'Biometric';

  @override
  String get secureLoadPinGateFailed => 'Failed to load PIN gate';

  @override
  String secureTooManyAttempts(String seconds) {
    return 'Too many attempts. Try again in ${seconds}s';
  }

  @override
  String securePersistPinGateFailed(String detail) {
    return 'Failed to persist PIN gate: $detail';
  }

  @override
  String secureListWalletsFailed(String detail) {
    return 'Failed to list wallets: $detail';
  }

  @override
  String get secureBiometricChanged =>
      'Biometric enrollment changed; re-enter mnemonic';

  @override
  String get notifyChannelName => 'Incoming payments';

  @override
  String get notifyChannelDescription =>
      'A payment to one of your addresses was seen on the network.';

  @override
  String get notifyChatDoneChannelName => 'Finished answers';

  @override
  String get notifyChatDoneChannelDescription =>
      'A service finished an answer while you were not looking at the chat.';

  @override
  String notifyIncomingBody(String amount, String wallet) {
    return '$amount to $wallet';
  }

  @override
  String get notifyPaymentOnTheWay => 'Payment on the way';

  @override
  String get notifyPaymentReceived => 'Payment received';

  @override
  String utxoBoxCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boxes',
      one: '$count box',
    );
    return '$_temp0';
  }

  @override
  String utxoNBoxes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boxes',
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
    return 'These $count boxes sit on $addresses different addresses. Spending them together publicly links those addresses to one wallet.';
  }

  @override
  String coinConfirmationNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count of these boxes are still confirming. This transaction can confirm only after the one that created them, and fails if that one is dropped.',
      one:
          'One of these boxes is still confirming. This transaction can confirm only after the one that created it, and fails if that one is dropped.',
    );
    return '$_temp0';
  }

  @override
  String get coinSelectionNone => 'No boxes chosen — Chatui will pick them.';

  @override
  String coinRawUnits(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$amount raw units',
      one: '$amount raw unit',
    );
    return '$_temp0';
  }

  @override
  String get coinRawUnitsLabel => 'raw units';

  @override
  String coinRawUnitsOf(String units, String label) {
    return '$units of $label';
  }

  @override
  String get pendingBalanceHidden => '•••• ERG pending';

  @override
  String pendingBalanceTotalUnknown(String total) {
    return '$total ERG · pending';
  }

  @override
  String pendingBalanceTotalMoved(String total, String moved) {
    return '$total ERG · $moved pending';
  }

  @override
  String pendingBalanceMoved(String moved, String confirmed) {
    return '$moved ERG pending · $confirmed confirmed';
  }

  @override
  String pendingBalanceUnknown(String confirmed) {
    return 'Pending · $confirmed confirmed';
  }

  @override
  String get spendUnconfirmedNote =>
      'Off: money you receive, and the change from your own sends, waits for one confirmation (the next block, usually a few minutes) before Chatui spends it. On: it can be spent at once, but if the transaction that brought it is dropped, the one spending it fails too. Either way, coins a pending transaction is already spending are never used again.';

  @override
  String get rentNoChargeZeroRate =>
      'No storage rent is charged at the current rate.';

  @override
  String rentNoChargeOverflow(String bytes) {
    return 'No storage rent can be charged on a box over $bytes bytes under current rules.';
  }

  @override
  String rentRatePerByte(String fee) {
    return '$fee per byte';
  }

  @override
  String rentRatePerByteDefault(String fee) {
    return '$fee per byte (default rate)';
  }

  @override
  String get rentWhenNow => 'now';

  @override
  String get rentWhenWithinDay => 'within a day';

  @override
  String rentWhenInDays(String days) {
    return 'in ~$days days';
  }

  @override
  String rentWhenMonthYear(String month, String year) {
    return '~$month $year';
  }

  @override
  String get separateNeedsSourceAddress =>
      'Refresh boxes to identify the source address.';

  @override
  String get separateMinPerBox => 'Each token box needs at least 0.001 ERG.';

  @override
  String get separateFundingInvalid =>
      'Funding must be separate ERG-only boxes at the source address.';

  @override
  String get separateInvalidTokenAmount =>
      'The source contains an invalid token amount.';

  @override
  String get separateTokenTypeRange =>
      'Choose a box holding between 2 and 150 token types.';

  @override
  String get separateInvalidErgValue =>
      'The selected boxes contain an invalid ERG value.';

  @override
  String get separateOverLimit =>
      'The selected ERG amount exceeds the transaction limit.';

  @override
  String separateAddFunding(String amount) {
    return 'Add $amount in funding boxes.';
  }

  @override
  String get utxoHealthTidy => 'Tidy';

  @override
  String get utxoHealthTidyHint =>
      'Few boxes: sends select inputs quickly and pay the least.';

  @override
  String get utxoHealthModerate => 'Moderate';

  @override
  String get utxoHealthModerateHint =>
      'Sends may need several inputs; consolidating dust keeps fees down.';

  @override
  String get utxoHealthFragmented => 'Fragmented';

  @override
  String get utxoHealthFragmentedHint =>
      'Many small boxes make every send pick more inputs. Sweep dust or consolidate.';

  @override
  String sendRecipientPrefix(String number) {
    return 'Recipient $number: ';
  }

  @override
  String sendErrorNotErgoAddress(String who) {
    return '${who}not an Ergo address';
  }

  @override
  String sendErrorMinimum(String who, String amount) {
    return '${who}minimum $amount ERG';
  }

  @override
  String sendErrorTokenNotInWallet(String who) {
    return '${who}token is not in this wallet';
  }

  @override
  String sendErrorEnterTokenAmount(String who, String token) {
    return '${who}enter a token amount for $token';
  }

  @override
  String sendErrorTokenOverAllocated(String who, String amount, String token) {
    return '${who}you hold $amount $token in total across all recipients';
  }

  @override
  String get priceHistoryNeedsExtraIndex =>
      'This node cannot serve price history: it needs the extra index.';

  @override
  String get oracleSigmaUsd => 'SigmaUSD oracle';

  @override
  String get oracleDexyUsd => 'Dexy USD oracle';

  @override
  String get oracleDexyGold => 'Dexy gold oracle';

  @override
  String get oracleAvl => 'AVL oracle';

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
    return '$count days';
  }

  @override
  String priceAgeOld(String age) {
    return '$age old';
  }

  @override
  String priceSourceLine(String source, String via) {
    return '$source · ERG via $via';
  }

  @override
  String priceSourceLineStale(String source, String via) {
    return '$source · stale · ERG via $via';
  }

  @override
  String priceHistoryUnreadable(String error) {
    return 'Price history could not be read: $error';
  }

  @override
  String get priceNoNode => 'No node is connected.';

  @override
  String get priceNoHeight => 'The node height is not known yet.';

  @override
  String priceNoHistoryYet(String source) {
    return 'This node has no price history for $source yet.';
  }

  @override
  String get priceOraclePools => 'Oracle pools';

  @override
  String get priceSourceBlurb =>
      'On-chain: ERG from the SigmaUSD oracle pool (the ERG/USD oracle pool), gold from the Dexy gold oracle, wrapped majors from the AVL multi-oracle. An old price is shown with its age, never as current. Reads only your node. Other tokens have no price.';

  @override
  String priceNoneYet(String source) {
    return 'No price yet · $source have not answered';
  }

  @override
  String get priceNoPool => 'No price · no oracle pool prices this token';

  @override
  String priceEach(String price) {
    return '$price each';
  }

  @override
  String priceHeld(String value) {
    return '$value held';
  }

  @override
  String get priceNotCounted => 'not counted in totals (stale)';

  @override
  String get verifiedNetaNote =>
      'The anetaBTC project was abandoned by its team and holders were left without the promised product. Treat NETA as having no backing.';

  @override
  String get tokenErrorNoName => 'Give the token a name';

  @override
  String get tokenErrorNameTooLong =>
      'Name is too long (64 characters at most)';

  @override
  String get tokenErrorDecimalsRange => 'Decimals must be between 0 and 18';

  @override
  String get tokenErrorAmountMissing => 'Enter the amount to issue';

  @override
  String get tokenErrorAmountZero => 'Amount must be above zero';

  @override
  String get tokenErrorAmountTooBig => 'Amount is beyond what a box can hold';

  @override
  String get nftErrorDecimals => 'An NFT has no decimals';

  @override
  String get nftErrorOneUnit => 'An NFT is one unit';

  @override
  String get nftErrorHash => 'Content hash must be 64 hex characters (SHA-256)';

  @override
  String get nftErrorLink => 'Link must start with https:// or ipfs://';

  @override
  String get tokenIssue => 'Issue';

  @override
  String get tokenBurn => 'Burn';

  @override
  String get tokenIssueNftTitle => 'Issue an NFT';

  @override
  String get tokenIssueTokenTitle => 'Issue a token';

  @override
  String get tokenIssueDetail =>
      'The new token lands in this wallet. Its name, description and decimals are written on chain and cannot be changed afterwards.';

  @override
  String get tokenSupply => 'Supply';

  @override
  String tokenSupplyDecimals(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$amount · $count decimals',
      one: '$amount · $count decimals',
    );
    return '$_temp0';
  }

  @override
  String get tokenDescription => 'Description';

  @override
  String get tokenKind => 'Kind';

  @override
  String get tokenLink => 'Link';

  @override
  String get tokenIdRow => 'Token id';

  @override
  String get tokenBoxValue => 'Box value';

  @override
  String get tokenIssuanceSubmitted => 'Token issuance submitted';

  @override
  String get tokenIssuanceNote =>
      'The token ID remains on the issuance screen. The token appears in your assets after confirmation.';

  @override
  String tokenNamedIssuanceSubmitted(String name) {
    return '$name issuance submitted';
  }

  @override
  String get tokenIssuedExplainer =>
      'It appears in your assets once the transaction confirms. The token id is what other wallets and sites know it by.';

  @override
  String get tokenIdLabel => 'Token ID';

  @override
  String get tokenCopyId => 'Copy token id';

  @override
  String get tokenIdCopied => 'Token id copied';

  @override
  String get tokenViewReceipt => 'View transaction receipt';

  @override
  String get tokenTransactionId => 'Transaction ID';

  @override
  String get tokenIssueAnother => 'Issue another';

  @override
  String get tokenIssueIntro =>
      'A token is created by a transaction from this wallet. Its id is fixed by that transaction, and its name, description and decimals are written once, on chain.';

  @override
  String get nftSubtitle => 'A single unit with a content hash and a link';

  @override
  String get tokenDescriptionOptional => 'Description (optional)';

  @override
  String get tokenSupplyHelper => 'Whole units, decimals allowed';

  @override
  String get tokenDecimals => 'Decimals';

  @override
  String get tokenDecimalsHelper => '0 to 18';

  @override
  String get nftKindPicture => 'Picture';

  @override
  String get nftKindAudio => 'Audio';

  @override
  String get nftKindVideo => 'Video';

  @override
  String get nftHashLabel => 'Content SHA-256 (hex, optional)';

  @override
  String get nftHashHelper => '64 hex characters';

  @override
  String get nftLinkLabel => 'Link (optional)';

  @override
  String get nftLinkHelper => 'https:// or ipfs://';

  @override
  String get tokenIssueCost =>
      'Costs 0.001 ERG for the token box plus the miner fee.';

  @override
  String get tokenPreparing => 'Preparing…';

  @override
  String tokenBurnEnterAmount(String token) {
    return 'Enter how much $token to burn';
  }

  @override
  String tokenBurnYouHold(String amount, String token) {
    return 'You hold $amount $token';
  }

  @override
  String get tokenBurnPick => 'Pick a token to burn';

  @override
  String tokenBurnTypeToGoOn(String word) {
    return 'Type $word to go on';
  }

  @override
  String get tokenBurnTitle => 'Burn tokens';

  @override
  String get tokenBurnForGood => 'Burn for good';

  @override
  String get tokenBurnDetail =>
      'These units are left out of every output of the transaction and stop existing. Nobody, including Chatui, can bring them back.';

  @override
  String get tokenBurnBackToYou => 'Back to you';

  @override
  String get tokenBurnSubmitted => 'Token burn submitted';

  @override
  String get tokenBurnWarning =>
      'Burning destroys tokens permanently. It is not a send: the units leave the chain rather than move to anyone. Use it for tokens you are sure you never want back, such as spam or a supply you mean to cut.';

  @override
  String get tokenBurnNoTokens => 'This wallet holds no tokens.';

  @override
  String get tokenBurnInWallet => 'Tokens in this wallet';

  @override
  String tokenBurnHeldRow(String amount, String id) {
    return '$amount held · $id';
  }

  @override
  String tokenBurnOneUnit(String token) {
    return '$token: the one unit';
  }

  @override
  String tokenBurnAmountLabel(String token) {
    return '$token to burn';
  }

  @override
  String tokenBurnOf(String amount) {
    return 'Of $amount';
  }

  @override
  String get tokenBurnAll => 'ALL';

  @override
  String tokenBurnTypeToConfirm(String word) {
    return 'Type $word to confirm';
  }

  @override
  String get assetsTitle => 'Assets';

  @override
  String get assetsShowList => 'Show collectible list';

  @override
  String get assetsShowGrid => 'Show collectible grid';

  @override
  String get assetsClearCache =>
      'Clear collectible cache (saved holdings keep their metadata)';

  @override
  String get assetsAll => 'All';

  @override
  String get assetsCollectibles => 'Collectibles';

  @override
  String get assetsSearchLabel => 'Search name or token ID';

  @override
  String get assetsClearSearch => 'Clear search';

  @override
  String assetsCollectibleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count identified collectibles · previews load only when you choose',
      one: '$count identified collectible · previews load only when you choose',
    );
    return '$_temp0';
  }

  @override
  String assetsTokenIdCount(String count) {
    return '$count token IDs';
  }

  @override
  String assetsTokenIdCountIncomplete(String count, String unknown) {
    return '$count token IDs · $unknown with incomplete metadata';
  }

  @override
  String get assetsPublicOnly => 'Public holdings only';

  @override
  String get assetsNotLoaded => 'Holdings not loaded';

  @override
  String assetsLastSynced(String age) {
    return 'Holdings last synced $age';
  }

  @override
  String get assetsHidden => 'Assets hidden';

  @override
  String get assetsNoMatch => 'No assets match your search';

  @override
  String get assetsNoCollectibles =>
      'No identified collectibles in loaded holdings';

  @override
  String get assetsIncompleteHint =>
      'Some tokens have incomplete metadata. Open them in All to inspect their details.';

  @override
  String get tokenCautionFlagged => 'Caution: this token is flagged';

  @override
  String assetsHeld(String amount) {
    return 'Held: $amount';
  }

  @override
  String tokenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count token IDs (incl. NFTs)',
      one: '$count token ID (incl. NFTs)',
    );
    return '$_temp0';
  }

  @override
  String tokenCountPublic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count public token IDs (incl. NFTs)',
      one: '$count public token ID (incl. NFTs)',
    );
    return '$_temp0';
  }

  @override
  String get artworkClose => 'Close artwork';

  @override
  String get artworkTitle => 'Artwork';

  @override
  String get artworkResetZoom => 'Reset zoom';

  @override
  String get artworkPreviewHidden =>
      'Preview hidden. Reopen asset details to view it.';

  @override
  String get artworkZoomHint => 'Pinch or scroll to zoom. Drag to move.';

  @override
  String get tokenMetaAsciiProvider =>
      'Configure an ASCII/punycode HTTPS metadata provider';

  @override
  String tokenMetaLoadFrom(String host) {
    return 'Load metadata from $host';
  }

  @override
  String tokenMetaLoadFromNode(String host) {
    return 'Load metadata from $host (node)';
  }

  @override
  String get tokenMetaHostNode => 'node';

  @override
  String get tokenMetaHostProvider => 'provider';

  @override
  String get tokenMetaPrivacy =>
      'This provider can see your IP address and the token ID requested. Issuer text may be misleading. No artwork will be downloaded.';

  @override
  String get tokenMetaLoad => 'Load metadata';

  @override
  String get tokenMetaBusy =>
      'Another metadata request is finishing — try again';

  @override
  String tokenMetaUnavailableFrom(String host) {
    return 'Metadata unavailable from $host';
  }

  @override
  String get tokenDetailsHidden => 'Asset details hidden';

  @override
  String get tokenMetaOffline => 'Metadata unavailable offline';

  @override
  String get tokenMetaCancel => 'Cancel metadata request';

  @override
  String get tokenMetaLoading => 'Loading metadata…';

  @override
  String tokenCurated(String project) {
    return 'Curated token · $project';
  }

  @override
  String tokenCaution(String note) {
    return 'Caution: $note';
  }

  @override
  String get tokenCautionDefault => 'this token is flagged.';

  @override
  String tokenImpersonation(String ticker, String project) {
    return 'This token is named like $ticker, but it is not the verified $ticker from $project. Check the id before trusting it.';
  }

  @override
  String get artworkNoMediaLink => 'No media link in issuance metadata.';

  @override
  String get artworkLoadBelow => 'Load metadata below to check for artwork.';

  @override
  String get artworkPreviewUnsupported => 'Preview not supported';

  @override
  String get artworkLinkUnavailable => 'Artwork link unavailable';

  @override
  String get artworkMediaUnavailable => 'Media metadata unavailable';

  @override
  String get artworkConsent => 'Artwork is loaded only with your consent';

  @override
  String get tokenYouHold => 'YOU HOLD';

  @override
  String get tokenIdCaps => 'TOKEN ID';

  @override
  String tokenLeaveFor(String host) {
    return 'Leave Chatui for $host?';
  }

  @override
  String get tokenExplorerPrivacy =>
      'The explorer can see your IP address and this token ID.';

  @override
  String get tokenOpenExplorer => 'Open explorer';

  @override
  String get tokenExplorer => 'Explorer';

  @override
  String get tokenMetaDetails => 'Metadata & media details';

  @override
  String tokenOriginalEmission(String amount) {
    return 'Original emission: $amount (provider reported)';
  }

  @override
  String get tokenOriginalEmissionUnavailable =>
      'Original emission unavailable';

  @override
  String tokenDecimalsLine(String decimals, String evidence) {
    return 'Decimals: $decimals · $evidence';
  }

  @override
  String get tokenDecimalsDeclared => 'declared by the issuer';

  @override
  String get tokenDecimalsNone => 'none declared, so whole units';

  @override
  String get tokenDecimalsListed => 'from a token list';

  @override
  String get tokenDecimalsLastShown => 'as last shown';

  @override
  String get tokenDecimalsUnknown =>
      'Decimals unknown · amounts are shown in raw units';

  @override
  String tokenDeclaredKind(String kind) {
    return 'Declared artwork kind: $kind';
  }

  @override
  String tokenMetaSource(String source) {
    return 'Metadata source: $source';
  }

  @override
  String get tokenMediaHashMissing => 'Issuance media hash missing or invalid';

  @override
  String tokenMediaHash(String hash) {
    return 'Issuance media hash: $hash';
  }

  @override
  String get tokenCopyMediaUri => 'Copy media URI as text';

  @override
  String get tokenIssuanceRegisters => 'Original issuance registers (hex)';

  @override
  String tokenSend(String token) {
    return 'Send $token';
  }

  @override
  String get syncLockedWalletsExplainer =>
      'A locked wallet refreshes from public data every 5 minutes, covering only the addresses this app already knows. Unlock it to pick up new addresses.';

  @override
  String get syncPublicKnownOnly => 'Public data · known addresses only';

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncOutOfSync => 'Out of sync';

  @override
  String get syncHistoryIncomplete => 'History incomplete';

  @override
  String get syncSynced => 'Synced';

  @override
  String get syncNotSynced => 'Not synced';

  @override
  String syncPinIssue(String index, String max) {
    return 'Pinned index $index can\'t be derived (max $max). Reset it in Settings.';
  }

  @override
  String dashboardStartupError(String detail) {
    return 'Error: $detail';
  }

  @override
  String get dashboardUnlockForErgoPay =>
      'Unlock a wallet to continue with the ErgoPay request.';

  @override
  String get dashboardUnlockForNotification =>
      'Unlock a wallet to open what the notification is about.';

  @override
  String get dashboardScanNotErgo => 'Not an Ergo address or ErgoPay link';

  @override
  String dashboardOpenFailed(String detail) {
    return 'Could not open wallet: $detail';
  }

  @override
  String dashboardWalletRemoved(String name) {
    return '\"$name\" removed';
  }

  @override
  String get dashboardNoAddressDerived =>
      'Unlocked, but no address could be derived';

  @override
  String get dashboardPinLockoutCheckFailed => 'Could not check PIN lockout';

  @override
  String get dashboardNoPinWallet => 'No PIN-protected wallet found.';

  @override
  String get dashboardBiometricNotSetUp =>
      'This wallet has no key stored on this device.';

  @override
  String get dashboardBiometricCancelled =>
      'Unlock cancelled. Tap Unlock to try again.';

  @override
  String get dashboardWalletDataMissing =>
      'Wallet data not found on this device.';

  @override
  String get dashboardNoWalletFound => 'No wallet found. Create or restore.';

  @override
  String get dashboardSetPinTitle => 'Set a PIN';

  @override
  String get dashboardLater => 'Later';

  @override
  String get dashboardUnlockFirst => 'Unlock the wallet first';

  @override
  String get dashboardAddressLoading => 'Address is still loading';

  @override
  String get dashboardScanQrTooltip => 'Scan a QR code';

  @override
  String get dashboardWalletSettingsTooltip => 'Wallet settings';

  @override
  String get homeUnlocked => 'Unlocked';

  @override
  String get homeLocked => 'Locked';

  @override
  String get offlineNoNodes => 'No reachable nodes. Tap Retry to check.';

  @override
  String get discoverTokensBlurb =>
      'Issue a token or an NFT, or burn tokens you hold.';

  @override
  String get discoverTokensWhat =>
      'Any Ergo transaction can create a new token: its id is the id of the first input box, its name, decimals and description live in the registers of the box that carries it (EIP-4). An NFT is a token with one unit and a link to its media.';

  @override
  String get discoverTokensCanIssue =>
      'Issue a fungible token with a name, decimals and supply';

  @override
  String get discoverTokensCanNft =>
      'Issue an NFT pointing at an image, audio or video';

  @override
  String get discoverTokensCanBurn =>
      'Burn tokens you hold so they leave circulation';

  @override
  String get discoverTokensRiskName =>
      'A token\'s name is not unique: anyone can issue one with the same name';

  @override
  String get discoverTokensRiskBurn =>
      'Burning is final; the supply cannot be restored';

  @override
  String get discoverTokensRiskCost =>
      'Issuing costs a miner fee and locks the minimum box value with the token';

  @override
  String get discoverTokensGo => 'Open tokens';

  @override
  String get homeUtxoManagement => 'UTXO management';

  @override
  String get discoverUtxosBlurb =>
      'Consolidate, split and restructure the boxes your money sits in.';

  @override
  String get discoverUtxosWhat =>
      'On Ergo your balance is a set of boxes, each a separate coin. Many small boxes make every send bigger and slower to build; one huge box links everything you own in one place. This tool reshapes them.';

  @override
  String get discoverUtxosCanConsolidate =>
      'Consolidate many small boxes into one';

  @override
  String get discoverUtxosCanSplit =>
      'Split a box into several of a chosen size';

  @override
  String get discoverUtxosCanRestructure =>
      'Restructure holdings so tokens sit in boxes of their own';

  @override
  String get discoverUtxosRiskPublic =>
      'Every reshape is a transaction: it costs a miner fee and is public';

  @override
  String get discoverUtxosRiskLinks =>
      'Consolidating links every box it spends to one owner';

  @override
  String get discoverUtxosRiskMinimum =>
      'A box below the minimum value cannot be made';

  @override
  String get discoverUtxosGo => 'Open UTXO management';

  @override
  String get discoverWhatYouCanDo => 'WHAT YOU CAN DO';

  @override
  String get discoverWatchFor => 'WATCH FOR';

  @override
  String get discoverIntro =>
      'What Chatui can do beyond sending and receiving. Each one says what it is, what you can do with it, and what to watch for before it opens.';

  @override
  String get discoverTools => 'Tools';

  @override
  String get discoverRowHint => 'What it is, and the way in';

  @override
  String get navActivity => 'Activity';

  @override
  String get navDiscover => 'Discover';

  @override
  String navActivityPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Activity, $count pending',
    );
    return '$_temp0';
  }

  @override
  String homePricesOld(String age) {
    return 'prices $age old';
  }

  @override
  String get homePricesStale => 'prices stale';

  @override
  String homePricesAsOf(String when) {
    return 'prices as of $when';
  }

  @override
  String get homePriceUnavailable => 'unavailable';

  @override
  String get homePriceUnavailableRetrying => 'unavailable · retrying';

  @override
  String get homeNetworkConnected => 'Connected';

  @override
  String get homeNetworkLooking => 'Looking for a node…';

  @override
  String get homeNoReachableNodes => 'No reachable nodes';

  @override
  String homeAgeOld(String age) {
    return '$age old';
  }

  @override
  String homePriceAsOf(String when) {
    return 'as of $when';
  }

  @override
  String homeHistoryOutOfDate(String source) {
    return '$source history is out of date';
  }

  @override
  String homeLegsMore(String first, String count) {
    return '$first + $count more';
  }

  @override
  String homeWalletsNotLoaded(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n wallets not loaded',
      one: '$n wallet not loaded',
    );
    return '$_temp0';
  }

  @override
  String homeAsOf(String when) {
    return 'as of $when';
  }

  @override
  String homeSpokenLoading(String label) {
    return '$label loading';
  }

  @override
  String homeSpokenUnavailable(String label) {
    return '$label unavailable';
  }

  @override
  String homeSpokenHidden(String label) {
    return '$label hidden';
  }

  @override
  String get homeSpokenSomethingPending => 'something pending';

  @override
  String homeSpokenAbout(String value, String code) {
    return 'about $value $code';
  }

  @override
  String homeSpokenUnpriced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tokens unpriced',
    );
    return '$_temp0';
  }

  @override
  String homeUnpricedTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unpriced tokens',
      one: '$count unpriced token',
    );
    return '$_temp0';
  }

  @override
  String homeSpokenPinnedAddress(String index, String address) {
    return 'Pinned address #$index, $address';
  }

  @override
  String homeSpokenAddress(String address) {
    return 'Address $address';
  }

  @override
  String get homeCopyAddress => 'Copy address';

  @override
  String get homeErgPriceUnavailable => 'ERG price unavailable';

  @override
  String homePriceVia(String window, String source) {
    return '$window via $source';
  }

  @override
  String homeSpokenErgPrice(String value, String code) {
    return 'ERG price $value $code';
  }

  @override
  String homeSpokenUp(String percent, String window) {
    return 'up $percent% over $window';
  }

  @override
  String homeSpokenDown(String percent, String window) {
    return 'down $percent% over $window';
  }

  @override
  String get homeShowBalances => 'Show balances';

  @override
  String get homeHideBalances => 'Hide balances';

  @override
  String get homeNetworkSettings => 'Network settings';

  @override
  String homeBlock(String height) {
    return 'Block $height';
  }

  @override
  String get homeLoading => 'Loading…';

  @override
  String get homeEmpty => 'Empty';

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
    return 'as of $when';
  }

  @override
  String get homeOpensWallet => 'Opens the wallet';

  @override
  String get homeSpokenUnlocked => 'unlocked';

  @override
  String get homeSpokenBalanceHidden => 'balance hidden';

  @override
  String homeSpokenIncl(String other) {
    return 'incl. $other';
  }

  @override
  String homePriceNote(String note) {
    return 'Price $note';
  }

  @override
  String get homeAssetHidden => 'Asset hidden';

  @override
  String get homeSpokenVerified => 'verified';

  @override
  String get homeSpokenCaution => 'caution, named like a verified token';

  @override
  String homeSpokenPrice(String value) {
    return 'price $value';
  }

  @override
  String get homeSpokenPending => 'pending';

  @override
  String get homeSpokenAmountHidden => 'amount hidden';

  @override
  String get overviewOpenToLoad => 'Open to load';

  @override
  String get overviewNotLoadedYet => 'Not loaded yet';

  @override
  String get overviewTagline => 'Decentralized compute';

  @override
  String get overviewTotalBalance => 'Total balance';

  @override
  String get overviewWalletRowTitle => 'Wallet details';

  @override
  String get overviewPrototypeTitle => 'Prototype software';

  @override
  String get overviewPrototypeBody =>
      'Chatui is an unaudited prototype. Transactions on Ergo are irreversible — use only funds you can afford to lose.';

  @override
  String get overviewGotIt => 'Got it';

  @override
  String get overviewPrototypeNote =>
      'Unaudited prototype. Use only funds you can afford to lose.';

  @override
  String get overviewLearnMore => 'Learn more';

  @override
  String get overviewWelcomeTitle => 'Your wallet lives here';

  @override
  String get overviewWelcomeBody =>
      'No wallet yet. Create a new wallet, or restore one from its recovery phrase. The app holds one wallet, and it opens from this screen.';

  @override
  String get overviewCreateWallet => 'Create a wallet';

  @override
  String get overviewRestoreWallet => 'Restore from recovery phrase';

  @override
  String get homeBalanceLabel => 'Balance';

  @override
  String get homeUnlockPrompt => 'Unlock to see activity, send and receive.';

  @override
  String get homeUnlock => 'Unlock';

  @override
  String get homeUsePin => 'Use PIN';

  @override
  String get homeUseBiometrics => 'Use biometrics';

  @override
  String get homeUnlockAndSetPin => 'Unlock and set PIN';

  @override
  String get homeKeysNotHere =>
      'This wallet\'s keys are not stored on this device.';

  @override
  String get homeActionSend => 'Send';

  @override
  String get homeActionReceive => 'Receive';

  @override
  String get homeActionMore => 'More';

  @override
  String get homeToolTokensBlurb => 'Issue tokens and NFTs, or burn tokens.';

  @override
  String get homeToolUtxosBlurb => 'Consolidate, split and tidy up your boxes.';

  @override
  String get homeToolAddressesBlurb =>
      'Each address of this wallet and what it holds.';

  @override
  String get homeToolLock => 'Lock wallet';

  @override
  String get homeToolLockBlurb =>
      'Opening it again asks for your fingerprint or screen lock.';

  @override
  String get homeBreakdownIntro =>
      'The wallet is shown as one address, but its balance covers every address it knows. Any of them can spend from this wallet.';

  @override
  String homeBreakdownEmptyOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other known addresses hold nothing.',
      one: '$count other known address holds nothing.',
    );
    return '$_temp0';
  }

  @override
  String get homeLongPressCopy => 'Long press to copy';

  @override
  String get homeNameAddressHint => 'Names this address. Long press to copy';

  @override
  String get homeSpokenShownAs => 'shown as this wallet';

  @override
  String get homeShownAs => 'Shown as this wallet';

  @override
  String get homeAllWallets => 'Back';

  @override
  String get homeOtherAddressesHint => 'Shows each address and what it holds';

  @override
  String get homeUtxos => 'UTXOs';

  @override
  String homeUtxoCount(String count) {
    return '$count UTXOs';
  }

  @override
  String get homeUtxoTools => 'UTXO tools';

  @override
  String homeSpokenFragmented(String utxos) {
    return '$utxos, fragmented. Tidy up';
  }

  @override
  String get homeTidyUp => 'Tidy up';

  @override
  String get homeFragmented => 'Fragmented';

  @override
  String get homeAllAssets => 'All assets';

  @override
  String homeAllAssetsCount(String count) {
    return 'All $count assets';
  }

  @override
  String get homeRecentActivity => 'Recent Activity';

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeReadingActivity => 'Reading activity';

  @override
  String get homeReadingActivityEllipsis => 'Reading activity…';

  @override
  String get homeFullHistory => 'Full history';

  @override
  String get homeEveryAddress => 'Every address and what it holds';

  @override
  String get homeNoAddresses => 'No addresses read yet';

  @override
  String get homeNoAddressesDot => 'No addresses read yet.';

  @override
  String homeSpokenCountFragmented(String count) {
    return '$count, fragmented';
  }

  @override
  String get homeAssets => 'Assets';

  @override
  String get homeShowMyAddress => 'Show my address';

  @override
  String get homeNoActivity => 'No activity yet';

  @override
  String get activityTitleReceived => 'Received';

  @override
  String get activityTitleSent => 'Sent';

  @override
  String get activityTitleMoved => 'Moved';

  @override
  String get activityTitleConsolidated => 'Consolidated';

  @override
  String activityTitleBurned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Burned tokens',
      one: 'Burned token',
    );
    return '$_temp0';
  }

  @override
  String activityTitleIssued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Issued tokens',
      one: 'Issued token',
    );
    return '$_temp0';
  }

  @override
  String get activityTitleContractInteraction => 'Contract interaction';

  @override
  String get activityTitleContract => 'Contract';

  @override
  String activityFrom(String address) {
    return 'from $address';
  }

  @override
  String activityFromContract(String address) {
    return 'from contract $address';
  }

  @override
  String activityTo(String address) {
    return 'to $address';
  }

  @override
  String activityToContract(String address) {
    return 'to contract $address';
  }

  @override
  String activityContract(String address) {
    return 'contract $address';
  }

  @override
  String activityAndMore(String who, String count) {
    return '$who and $count more';
  }

  @override
  String get activityArgusAppFee => 'Argus app fee';

  @override
  String get activityBetweenYourAddresses => 'between your addresses';

  @override
  String get activityFeeLabel => 'Fee';

  @override
  String activityMoreTokens(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more tokens',
      one: '$count more token',
    );
    return '$_temp0';
  }

  @override
  String activityPlusMore(String count) {
    return '+ $count more';
  }

  @override
  String get activityScreenTitle => 'Activity';

  @override
  String get activityPartial =>
      'Some addresses could not be checked. Activity is incomplete.';

  @override
  String activityLoadFailed(String error) {
    return 'Could not load activity: $error';
  }

  @override
  String activityLoadMoreFailed(String error) {
    return 'Could not load older activity: $error';
  }

  @override
  String get activityNoneToExport => 'No transactions to export';

  @override
  String activityExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String activityCount(String count) {
    return '$count transactions';
  }

  @override
  String get activityExportCsv => 'Export CSV';

  @override
  String get activityEmptyTitle => 'No activity yet';

  @override
  String get activityEmptyBody =>
      'Transactions to and from this wallet will show up here, newest first.';

  @override
  String get activityRefresh => 'Refresh';

  @override
  String ergopayErrorUnreachable(String detail) {
    return 'Could not reach the dApp: $detail';
  }

  @override
  String ergopayErrorHttp(String status) {
    return 'The dApp answered HTTP $status';
  }

  @override
  String get ergopayErrorUnreadable =>
      'The dApp sent an unreadable signing request';

  @override
  String ergopayErrorNotify(String detail) {
    return 'Could not notify the dApp: $detail';
  }

  @override
  String ergopayErrorReplyRejected(String status) {
    return 'The dApp rejected the reply (HTTP $status)';
  }

  @override
  String get ergopayWarningInputsUnknown =>
      'Input values could not be fetched from the node, so the total you spend is unknown. Check the outputs carefully.';

  @override
  String get ergopayWarningForeignInputs =>
      'Some inputs are not from this wallet. The dApp is adding its own boxes to this transaction.';

  @override
  String get ergopayRowRecipients => 'Recipients';

  @override
  String get ergopayRowSent => 'Sent';

  @override
  String get ergopayRowTokensOut => 'Tokens out';

  @override
  String get ergopayRowChange => 'Change to you';

  @override
  String get ergopayRowYouSpend => 'You spend';

  @override
  String get ergopayRowInputs => 'Inputs';

  @override
  String get ergopayStatusContacting => 'Contacting the dApp…';

  @override
  String get ergopayNotALink => 'This is not an ErgoPay link.';

  @override
  String ergopayWrongAddress(String address) {
    return 'This request is for $address, which is not an address of this wallet.';
  }

  @override
  String get ergopayStatusReading => 'Reading the transaction…';

  @override
  String get ergopayPickAddressTitle => 'Which address should the dApp use?';

  @override
  String get ergopayMainAddress => 'Main address';

  @override
  String get ergopaySignTitle => 'Sign for dApp';

  @override
  String get ergopayNodeNotChosen => 'Node not chosen yet';

  @override
  String get ergopayStatusSigning => 'Signing…';

  @override
  String get ergopayStatusBroadcasting => 'Broadcasting…';

  @override
  String get ergopayStatusNotifying => 'Telling the dApp…';

  @override
  String get ergopaySignedAndSent => 'Signed and sent';

  @override
  String get ergopayNoTransaction =>
      'The dApp did not send a transaction to sign.';

  @override
  String get ergopayThisTransaction => 'This transaction';

  @override
  String get ergopayReviewAndSign => 'Review & sign';

  @override
  String get ergopayDecline => 'Decline';

  @override
  String ergopayNotifyFailed(String error) {
    return 'The transaction is on the network, but the dApp could not be notified: $error';
  }

  @override
  String get errorSomethingWentWrong => 'Something went wrong';

  @override
  String get errorCopied => 'Error copied';

  @override
  String get errorContractRejected =>
      'A contract rejected this transaction, so it was not signed. Nothing was sent.';

  @override
  String get errorNothingSent => 'Nothing was sent.';

  @override
  String get errorSigningFailed => 'Signing failed';

  @override
  String get errorBroadcastMayHaveFailed => 'Broadcast may have failed';

  @override
  String get errorCheckActivity =>
      'Check Activity before retrying; the transaction may already be on the network.';

  @override
  String get contactsNoneToExport => 'No contacts to export';

  @override
  String contactsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get contactsSelectTitle => 'Select contact';

  @override
  String get contactsExportTooltip => 'Export contacts';

  @override
  String get contactsEmptySelect => 'No saved contacts yet.';

  @override
  String get contactsEmpty => 'No saved contacts yet.\nTap + to add one.';

  @override
  String get contactsYourWallets => 'Your wallets';

  @override
  String get contactsDeleteTitle => 'Delete contact?';

  @override
  String get contactsDelete => 'Delete';

  @override
  String get contactsInvalidAddress => 'Not a valid Ergo address';

  @override
  String get contactsAddTitle => 'Add contact';

  @override
  String get contactsEditTitle => 'Edit contact';

  @override
  String get contactsAdd => 'Add';

  @override
  String get createPhraseMismatch =>
      'Confirmation does not match the recovery phrase';

  @override
  String get createSkipTitle => 'Skip the check?';

  @override
  String get createSkipBody =>
      'Nothing will prove that your written phrase is complete and in order. If a word is wrong or missing, the funds of this wallet cannot be recovered.';

  @override
  String get createSkip => 'Skip';

  @override
  String get createFailedTitle => 'Could not create the wallet';

  @override
  String get createTitle => 'Create wallet';

  @override
  String get createWriteDownTitle => 'Write these words down';

  @override
  String get createWriteDownBody =>
      'Paper only. They are the only way to recover this wallet. Android blocks screenshots here; iOS hides the app in the switcher and during screen recording.';

  @override
  String get createGenerate => 'Generate recovery phrase';

  @override
  String get createHide => 'Hide';

  @override
  String get createReveal => 'Reveal';

  @override
  String get createWroteDown => 'I wrote these down';

  @override
  String get createConfirmTitle => 'Confirm the phrase';

  @override
  String get createConfirmBody =>
      'Type the words back in order. This proves the backup is readable.';

  @override
  String get createPhraseLabel => 'Recovery phrase';

  @override
  String get createContinue => 'Continue';

  @override
  String get createSkipCheck => 'Skip this check';

  @override
  String get createSetPin => 'Set a PIN';

  @override
  String get createPinBody =>
      'The PIN unwraps the key on this device. It is not a backup.';

  @override
  String get createReplaceTitle => 'Replace existing wallet?';

  @override
  String get createReplaceBody =>
      'A wallet is already stored on this device. Replacing it overwrites the encrypted seed. The recovery phrase is the only way to recover the old wallet.';

  @override
  String get createReplace => 'Replace';

  @override
  String get createScreenshotBlockUnavailable =>
      'Screenshot blocking is unavailable on this device';

  @override
  String get restoreEnterPhrase => 'Enter a recovery phrase';

  @override
  String get restoreWordCount =>
      'Recovery phrase must be 12, 15, 18, 21, or 24 words';

  @override
  String get restoreFailedTitle => 'Could not restore the wallet';

  @override
  String get restoreTitle => 'Restore wallet';

  @override
  String get restoreIntro =>
      '12, 15, 18, 21, or 24 words, in order — 15 is the Ergo standard. Optional BIP-39 passphrase if you used one.';

  @override
  String get restorePhraseHint => '12, 15, 18, 21, or 24 words';

  @override
  String get restorePassphraseLabel => 'BIP-39 passphrase (optional)';

  @override
  String get restoreButton => 'Restore';

  @override
  String receiveCopied(String address) {
    return '$address copied';
  }

  @override
  String get receiveTitle => 'Receive';

  @override
  String get receiveUnusedAddress => 'Unused address';

  @override
  String get receiveAddress => 'Receive address';

  @override
  String get receiveFreshNote =>
      'A new address is shown after this one is used.';

  @override
  String get receiveStaticNote =>
      'This address stays the same. Turn on Fresh addresses in Settings to use a new one after each payment.';

  @override
  String get receiveAmountLabel => 'Optional amount (ERG)';

  @override
  String get receiveAddLabel => 'Add label';

  @override
  String get receiveEditLabel => 'Edit label';

  @override
  String get receiveCopyAddress => 'Copy address';

  @override
  String get receiveShare => 'Share';

  @override
  String get receiveUsedAddresses => 'Used addresses';

  @override
  String get receiveUsedAddressesNote =>
      'Older addresses keep working; tap one to copy it.';

  @override
  String get receiveAmountInvalid =>
      'Amount must be a decimal number, like 0.001';

  @override
  String get receiveAmountNotPositive => 'Amount must be greater than zero';

  @override
  String get scanTitle => 'Scan';

  @override
  String get scanCameraUnavailable =>
      'Camera is unavailable. Allow camera access and try again.';

  @override
  String get scanBack => 'Back';

  @override
  String get txArgusFee => 'Argus fee';

  @override
  String get txLeftWallet => 'Left your wallet';

  @override
  String get txBurned => 'Burned';

  @override
  String get txBurnedNote =>
      'No output holds these any more: they no longer exist.';

  @override
  String get txIssued => 'Issued';

  @override
  String get txArrived => 'Arrived';

  @override
  String get txFees => 'Fees';

  @override
  String get txMovedBetween => 'Moved between your addresses';

  @override
  String get txMovedNote => 'Change and boxes that stayed in this wallet.';

  @override
  String get txTo => 'To';

  @override
  String get txFrom => 'From';

  @override
  String get txContract => 'Contract';

  @override
  String get txIncompleteInputs =>
      'Some inputs of this pending transaction are not readable yet; what the other side put in may be missing.';

  @override
  String txSentAmount(String amount) {
    return 'Sent $amount';
  }

  @override
  String txReceivedAmount(String amount) {
    return 'Received $amount';
  }

  @override
  String get txTitle => 'Transaction';

  @override
  String txConfirmedAt(String height) {
    return 'Confirmed $height';
  }

  @override
  String get txConfirmed => 'Confirmed';

  @override
  String get txNotInBlock => 'Not yet in a block';

  @override
  String get txTokensSent => 'Tokens sent';

  @override
  String get txIdLabel => 'Id';

  @override
  String get txTokensReceived => 'Tokens received';

  @override
  String txFurtherTokenIds(String count) {
    return '$count further token id(s) involved — see explorer.';
  }

  @override
  String get txIdCopied => 'Transaction id copied';

  @override
  String get txExplorerFailed => 'Could not open explorer';

  @override
  String get txOpenExplorer => 'Open in explorer';

  @override
  String txDetailsLoadFailed(String error) {
    return 'Could not load the transaction details: $error';
  }

  @override
  String get txChange => 'Change';

  @override
  String txInputsCount(String count) {
    return 'Inputs ($count)';
  }

  @override
  String get txYours => 'Yours';

  @override
  String get txInput => 'Input';

  @override
  String get txValueUnknown => 'value unknown';

  @override
  String txOutputsCount(String count) {
    return 'Outputs ($count)';
  }

  @override
  String get txMiner => 'Miner';

  @override
  String txDataInputsCount(String count) {
    return 'Data inputs ($count)';
  }

  @override
  String get txBox => 'Box';

  @override
  String get txIdHeading => 'Transaction id';

  @override
  String get txUnsignedCopied => 'Unsigned transaction copied';

  @override
  String get txCopyUnsigned => 'Copy unsigned transaction';

  @override
  String get dialogBiometricTitle => 'Unlock with biometrics?';

  @override
  String get dialogBiometricBody =>
      'Use your fingerprint or face to unlock this wallet instead of typing the PIN each time. You can change this later under Settings › Security.';

  @override
  String get dialogNotNow => 'Not now';

  @override
  String get dialogEnable => 'Enable';

  @override
  String get dialogBiometricEnabled => 'Biometric unlock enabled';

  @override
  String get dialogBiometricFailed =>
      'Could not enable biometrics; try again under Settings › Security';

  @override
  String get entryCurrentPin => 'Current PIN';

  @override
  String get entryContinue => 'Continue';

  @override
  String get labelDialogTitle => 'Address label';

  @override
  String get labelOptional => 'Label (optional)';

  @override
  String get coreTokenMetadataInvalid => 'Metadata invalid';

  @override
  String get coreTokenMetadataConflict => 'Metadata conflict';

  @override
  String get coreTokenCollection => 'Collection token';

  @override
  String get coreTokenDeclaredNftUnsupported =>
      'Declared NFT · unsupported type';

  @override
  String coreTokenSingleUnitArtwork(String kind) {
    return 'Single-unit artwork · $kind';
  }

  @override
  String get coreTokenDeclaredArtworkMultiple =>
      'Declared artwork · multiple units';

  @override
  String get coreTokenDeclaredArtworkUnconfirmed =>
      'Declared artwork · supply unconfirmed';

  @override
  String get coreTokenSingleUnit => 'Single-unit token';

  @override
  String get coreTokenMetadataUnavailable => 'Token · metadata unavailable';

  @override
  String get corePinLength => 'PIN must be 6-32 characters';

  @override
  String coreWalletNumbered(String number) {
    return 'Wallet $number';
  }

  @override
  String get coreCuratedTokenSource => 'Argus curated token list';

  @override
  String coreBroadcastActivityWarning(String error) {
    return 'Transaction submitted, but Activity could not be updated: $error. Keep this transaction ID.';
  }

  @override
  String get coreActivityLoadFailed => 'Could not load activity';

  @override
  String get coreWalletLocked => 'Wallet is locked';

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
      other: 'incl. $parts on $count other addresses',
      one: 'incl. $parts on 1 other address',
    );
    return '$_temp0';
  }

  @override
  String holdingsFundsElsewhereHidden(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'incl. funds on $count other addresses',
      one: 'incl. funds on 1 other address',
    );
    return '$_temp0';
  }

  @override
  String get previewGatewayOriginRule =>
      'Use an HTTPS gateway origin on port 443, without credentials, path or query.';

  @override
  String get previewGatewayNotPublic => 'Gateway address is not public.';

  @override
  String get previewGatewayPublicHostname => 'Use a public gateway hostname.';

  @override
  String get previewCidMalformed => 'Malformed IPFS CID.';

  @override
  String get previewOnlyIpfs =>
      'Only IPFS artwork can be displayed. Issuer hosts are refused because the issuer would choose who learns you looked.';

  @override
  String get previewCidNoncanonical => 'Noncanonical IPFS CID.';

  @override
  String get previewCidUnsupported => 'Unsupported IPFS CID.';

  @override
  String get previewCidFormat =>
      'Use a CIDv0 or lowercase base32 CIDv1 IPFS URI.';

  @override
  String get previewPathUnsupported => 'Unsupported IPFS path.';

  @override
  String get previewImageDimensions =>
      'Image dimensions exceed 4096 per axis or 8 megapixels.';

  @override
  String get previewArtworkTooLarge => 'Artwork exceeds 5 MiB.';

  @override
  String get previewPngMalformed => 'Malformed PNG.';

  @override
  String get previewPngAnimated => 'Animated PNG is unsupported.';

  @override
  String get previewJpegMalformed => 'Malformed JPEG.';

  @override
  String get previewJpegFrame => 'Unsupported JPEG frame.';

  @override
  String get previewFormatMismatch =>
      'Only static PNG and JPEG with matching bytes and MIME are supported.';

  @override
  String get previewHashMismatch => 'Content differs from issuance hash.';

  @override
  String get previewSaveSettingFailed => 'Could not save preview setting.';

  @override
  String get previewSaveGatewayFailed => 'Could not save gateway.';

  @override
  String get previewRequestTimedOut => 'Preview request timed out.';

  @override
  String get previewConnectionTimedOut => 'Preview connection timed out.';

  @override
  String get previewCancelled => 'Preview cancelled.';

  @override
  String get previewConnectionRefused => 'Preview connection refused.';

  @override
  String get previewHostBindingFailed => 'Gateway hostname binding failed.';

  @override
  String get previewRedirectBlocked => 'Redirect blocked.';

  @override
  String get previewNoArtwork => 'Gateway did not return artwork.';

  @override
  String get previewCompressionRefused => 'Transport compression refused.';

  @override
  String get previewStaticOnly => 'Only static PNG and JPEG are supported.';

  @override
  String get previewBusy => 'Another preview is still finishing.';

  @override
  String get previewIntegrityConsentRequired =>
      'View without integrity check requires explicit consent.';

  @override
  String get previewAnimatedUnsupported => 'Animated artwork is unsupported.';

  @override
  String get previewDecodedTooLarge => 'Decoded preview exceeds target size.';

  @override
  String previewLoadThroughTitle(String host) {
    return 'Load preview through $host?';
  }

  @override
  String get previewLoadConsentBody =>
      'This gateway can see your IP address and which artwork was requested. Up to 5 MiB will be downloaded. Artwork may contain unsolicited or misleading content.';

  @override
  String get previewLoad => 'Load preview';

  @override
  String get previewHashMissingTitle => 'Issuance hash missing or invalid';

  @override
  String get previewHashMissingBody =>
      'The format and dimensions passed the preview checks, but these bytes cannot be compared with an issuance hash.';

  @override
  String get previewViewWithoutIntegrity => 'View without integrity check';

  @override
  String get previewMatchesHash => 'Matches issuance hash';

  @override
  String get previewViewedWithoutIntegrity => 'Viewed without integrity check';

  @override
  String get previewLoadFailed => 'Preview could not be loaded.';

  @override
  String get previewMetadataUnsupported =>
      'Preview not supported for this metadata.';

  @override
  String get previewDisabled => 'Remote previews disabled.';

  @override
  String get previewNoGateway =>
      'No gateway configured. Previews are unavailable.';

  @override
  String get previewUnavailableNow =>
      'Previews unavailable while locked, hidden, offline or outside this session.';

  @override
  String get previewViewArtwork => 'View artwork';

  @override
  String get previewHide => 'Hide preview';

  @override
  String get previewLoading => 'Loading preview…';

  @override
  String get previewCancel => 'Cancel preview';

  @override
  String get previewSettingsLink => 'Remote preview settings';

  @override
  String get previewGatewaySaved =>
      'Gateway saved. Each artwork still requires consent.';

  @override
  String get previewSettingsTitle => 'Remote previews';

  @override
  String get previewNeverTitle => 'Never load remote previews';

  @override
  String get previewNeverSubtitle =>
      'Disables loading and clears open previews. Image decoding has no enforceable total allocation ceiling and an active native decode cannot be interrupted. Use this switch to avoid decoder memory or security risks.';

  @override
  String get previewSettingsIpfsOnly =>
      'Only IPFS artwork can be displayed. Issuer-selected hosts are refused because the issuer would choose who learns you looked. There is no default gateway or fallback.';

  @override
  String get previewGatewayFieldLabel => 'Your HTTPS IPFS gateway';

  @override
  String get previewGatewayFieldHelper =>
      'Origin only, port 443. Leave empty to remove.';

  @override
  String get previewGatewayCheckInfo =>
      'Saving resolves the gateway hostname to check that its addresses are public. Loading checks again and connects only to that address. The gateway can see your IP and which artwork you request.';

  @override
  String get previewCheckingGateway => 'Checking gateway…';

  @override
  String get previewSaveGateway => 'Save gateway';

  @override
  String get sendNoSpendableAddresses => 'No spendable addresses';

  @override
  String get sendCouldNotListBoxes => 'Could not list your boxes';

  @override
  String sendContactName(String name) {
    return 'Contact: $name';
  }

  @override
  String get sendSpendableUnknown => 'Spendable balance is unknown';

  @override
  String get sendNotEnoughForFee => 'Not enough ERG for fee and change';

  @override
  String get sendNoTokenSelected => 'No token selected';

  @override
  String get sendSaveToContacts => 'Save to contacts';

  @override
  String get sendContactSaved => 'Contact saved';

  @override
  String sendExceedsBalance(String balance) {
    return 'Amount plus fee exceeds your $balance';
  }

  @override
  String get sendCouldNotPrepare => 'Could not prepare the send';

  @override
  String get sendClipboardTitle => 'Clipboard holds another address';

  @override
  String get sendClipboardDiffersOne =>
      'Something you copied earlier is an Ergo address that differs from the recipient. Malware can swap addresses on the clipboard. Verify every character.';

  @override
  String get sendClipboardDiffersMany =>
      'Something you copied earlier is an Ergo address that differs from every recipient. Malware can swap addresses on the clipboard. Verify every character.';

  @override
  String get sendRecipientLabel => 'Recipient:';

  @override
  String get sendRecipientsLabel => 'Recipients:';

  @override
  String get sendClipboardLabel => 'Clipboard:';

  @override
  String get sendGoBack => 'Go back';

  @override
  String get sendRecipientCorrect => 'Recipient is correct';

  @override
  String get sendRecipientsCorrect => 'Recipients are correct';

  @override
  String get sendTotalSent => 'Total sent';

  @override
  String get sendAmount => 'Amount';

  @override
  String sendFeePaidIn(String token) {
    return 'Miner fee paid in $token';
  }

  @override
  String get sendTokenFallback => 'token';

  @override
  String sendTokensFor(String tokens, String erg) {
    return '$tokens for $erg';
  }

  @override
  String get sendConfirmMulti => 'Confirm multi-recipient send';

  @override
  String get sendConfirm => 'Confirm send';

  @override
  String get sendSent => 'Sent!';

  @override
  String sendAvailable(String amount) {
    return 'Available $amount';
  }

  @override
  String sendAllAddresses(String all) {
    return 'All $all addresses';
  }

  @override
  String sendSomeAddresses(String picked, String all) {
    return '$picked of $all addresses';
  }

  @override
  String sendBoxesChosen(String count) {
    return '$count boxes chosen';
  }

  @override
  String sendFeeErg(String amount) {
    return 'Fee $amount ERG';
  }

  @override
  String sendFeeIn(String token) {
    return 'Fee in $token';
  }

  @override
  String sendTokensPage(String count, String page, String pages) {
    return '$count tokens selected · Page $page of $pages';
  }

  @override
  String get sendPreviousTokens => 'Previous tokens';

  @override
  String get sendNextTokens => 'Next tokens';

  @override
  String sendSendsOne(String token) {
    return 'Sends 1 $token · Available 1';
  }

  @override
  String sendTokenAmount(String token) {
    return '$token amount';
  }

  @override
  String get sendMax => 'MAX';

  @override
  String get sendEnterAmount => 'Enter an amount';

  @override
  String get sendTooMuch => 'Too much';

  @override
  String sendRemoveToken(String token) {
    return 'Remove $token';
  }

  @override
  String sendPlusTokens(String count) {
    return ' + $count tokens';
  }

  @override
  String get sendRawTitle => 'Raw signed transaction';

  @override
  String get sendRawNote =>
      'Transaction is signed but not broadcast. Share or save the raw transaction to submit later via an explorer or another wallet.';

  @override
  String get sendDestination => 'Destination';

  @override
  String get sendRecipientAddress => 'Recipient address';

  @override
  String get sendRecipientHint => 'Or tap contacts to pick a saved one';

  @override
  String get sendRequired => 'Required';

  @override
  String get sendAsset => 'Asset';

  @override
  String get sendChooseTokens => 'Choose tokens';

  @override
  String sendChooseTokensCount(String count) {
    return 'Choose tokens ($count)';
  }

  @override
  String get sendMinimumBox => 'Minimum 0.001 ERG';

  @override
  String get sendErgWithIt => 'ERG to send with it (optional)';

  @override
  String sendBlankFundsTokens(String available) {
    return 'Blank funds the minimum ERG for these tokens. Review shows the exact amount. $available';
  }

  @override
  String get sendAdditionalRecipients => 'Additional recipients';

  @override
  String sendRecipientNAddress(String number) {
    return 'Recipient $number address';
  }

  @override
  String get sendAmountErg => 'Amount (ERG)';

  @override
  String get sendBlankFundsToken =>
      'Blank funds the minimum ERG for this token.';

  @override
  String get sendTokenNone => 'None';

  @override
  String get sendEnterTokenAmount => 'Enter a token amount';

  @override
  String sendYouHold(String amount) {
    return 'You hold $amount';
  }

  @override
  String get sendAddRecipient => 'Add another recipient';

  @override
  String get sendAdvanced => 'Advanced';

  @override
  String get sendErgCarried => 'ERG carried with the token';

  @override
  String sendBlankMinimumBox(String amount) {
    return 'Leave blank for the minimum box value of $amount.';
  }

  @override
  String get sendChoose => 'Choose';

  @override
  String get sendSpendFrom => 'Spend from';

  @override
  String get sendDeselectedNote =>
      'Deselected addresses are excluded from coin selection.';

  @override
  String get sendUseAllAddresses => 'Use all addresses';

  @override
  String get sendPayFeeIn => 'Pay the miner fee in';

  @override
  String get sendPayFeeInHelp =>
      'A token fee is bought from a babel box on chain at its posted price; the ERG fee below is what it buys.';

  @override
  String get sendMinerFeeErg => 'Miner fee (ERG)';

  @override
  String sendBlankDefaultFee(String amount) {
    return 'Leave blank for the default $amount.';
  }

  @override
  String sendMinimum(String amount) {
    return 'Minimum $amount';
  }

  @override
  String get sendReview => 'Review';

  @override
  String get sendChooseInputs => 'Choose inputs';

  @override
  String get sendAutoInputsNote =>
      'Chatui will pick boxes for you. Choose some to control exactly what this transaction spends.';

  @override
  String sendShortBy(String amount) {
    return 'Short by $amount for this amount plus fees.';
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
    return 'block $height';
  }

  @override
  String utxoLoadFailed(String error) {
    return 'Failed to load UTXOs: $error';
  }

  @override
  String get utxoSpreadOut =>
      'Your boxes are spread over many addresses, and merging them would link those addresses. Consolidate does it anyway.';

  @override
  String get utxoNothingToClean => 'Nothing to clean up right now';

  @override
  String get utxoConsolidateNeedsTwo => 'Consolidation needs at least 2 boxes';

  @override
  String get utxoConsolidateTitle => 'Consolidate UTXOs';

  @override
  String utxoConsolidateInN(String count) {
    return 'Consolidate in $count transactions';
  }

  @override
  String get utxoBoxesMerged => 'Boxes merged';

  @override
  String get utxoInto => 'Into';

  @override
  String get utxoTotalValueIn => 'Total value in';

  @override
  String get utxoTokenTypesCarried => 'Token types carried';

  @override
  String get utxoValueAfterFees => 'Value after fees';

  @override
  String get utxoConsolidateOneDetail =>
      'Every selected box is spent into one new box holding all its ERG and tokens.';

  @override
  String utxoConsolidateManyDetail(String max, String count) {
    return 'Ergo transactions are kept under $max inputs each, so this runs as $count transactions back to back. You can consolidate the results again afterwards.';
  }

  @override
  String get utxoSignBroadcast => 'Sign & broadcast';

  @override
  String utxoSignBroadcastN(String count) {
    return 'Sign & broadcast $count';
  }

  @override
  String utxoStoppedAfter(String done, String total) {
    return 'Stopped after $done of $total. Refresh boxes and check Activity before retrying.';
  }

  @override
  String get utxoConsolidationSubmitted => 'Consolidation submitted';

  @override
  String get utxoRefreshBeforeRetry =>
      'Refresh boxes and check Activity before retrying.';

  @override
  String get utxoFewDust => 'Fewer than two dust boxes to sweep';

  @override
  String utxoNewRent(String fee, String when) {
    return '$fee, due $when';
  }

  @override
  String utxoNewRentCapped(String fee, String when) {
    return '$fee, due $when; it holds no more than that';
  }

  @override
  String get utxoSuggestedCleanup => 'Suggested cleanup';

  @override
  String utxoMergedAtAddress(String count, String total) {
    return '$count of $total at this address';
  }

  @override
  String get utxoResultingBoxes => 'Resulting boxes';

  @override
  String get utxoOneOrMore => '1 or more';

  @override
  String get utxoRentClocksRestarted => 'Rent clocks restarted';

  @override
  String get utxoNewBoxRent => 'New box rent';

  @override
  String utxoCleanupDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Every listed box is spent into $count new boxes at this address, holding all their ERG and tokens. A moved box starts a new 4-year storage-rent clock. Only boxes from this one address are merged, so no addresses are linked.',
      one:
          'Every listed box is spent into one new box at this address, holding all their ERG and tokens. A moved box starts a new 4-year storage-rent clock. Only boxes from this one address are merged, so no addresses are linked.',
    );
    return '$_temp0';
  }

  @override
  String get utxoCleanupSubmitted => 'Cleanup submitted';

  @override
  String utxoAtRisk(String count) {
    return '$count at risk';
  }

  @override
  String get utxoSplitTitle => 'Split UTXO';

  @override
  String get utxoOutputsCreated => 'Outputs Created';

  @override
  String utxoBoxesN(String count) {
    return '$count boxes';
  }

  @override
  String get utxoAmountPerBox => 'Amount per Box';

  @override
  String utxoTokensN(String count) {
    return '$count tokens';
  }

  @override
  String get utxoChangeReturned => 'Change Returned';

  @override
  String get utxoMinerFeeTitle => 'Miner Fee';

  @override
  String get utxoFeeByBuilder => 'Fee is computed by the transaction builder.';

  @override
  String get utxoSignBroadcastSplit => 'Sign & broadcast split';

  @override
  String get utxoSplitSubmitted => 'Split submitted';

  @override
  String utxoSeparateTitle(String count) {
    return 'Separate $count token types';
  }

  @override
  String get utxoSourceBox => 'Source box';

  @override
  String get utxoInputsSpent => 'Inputs spent';

  @override
  String get utxoTokenBoxes => 'Token boxes';

  @override
  String utxoRawUnits(String amount, String raw) {
    return '$amount ($raw raw units)';
  }

  @override
  String get utxoErgInTokenBoxes => 'ERG in token boxes';

  @override
  String get utxoErgChange => 'ERG change';

  @override
  String get utxoSeparateDetail =>
      'Each token type keeps its full balance in a separate box at your source address. All remaining ERG is returned to your wallet.';

  @override
  String get utxoSignBroadcastSeparation => 'Sign & broadcast separation';

  @override
  String get utxoSeparationSubmitted => 'Token separation submitted';

  @override
  String get utxoRestructureTitle => 'Restructure UTXOs';

  @override
  String get utxoInputsConsumed => 'Inputs Consumed';

  @override
  String get utxoOutputsGenerated => 'Outputs Generated';

  @override
  String get utxoTotalValueInTitle => 'Total Value In';

  @override
  String get utxoAllocatedToOutputs => 'Allocated to Outputs';

  @override
  String get utxoChangeOutput => 'Change Output';

  @override
  String get utxoSignBroadcastRestructure => 'Sign & broadcast restructure';

  @override
  String get utxoRestructureSubmitted => 'Restructure submitted';

  @override
  String get utxoScreenTitle => 'Wallet boxes';

  @override
  String get utxoLastConsolidation => 'Last consolidation result';

  @override
  String get utxoRefreshBoxes => 'Refresh boxes';

  @override
  String utxoCount(String count) {
    return '$count UTXOs';
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
      other: '$count dust boxes under $limit.',
      one: '1 dust box under $limit.',
    );
    return '$_temp0';
  }

  @override
  String get utxoOldestFirst =>
      'Oldest boxes first. Automatic sends prefer older eligible boxes to reduce storage-rent risk; privacy rules and your manual selection still apply.';

  @override
  String get utxoConsolidate => 'Consolidate';

  @override
  String get utxoSplit => 'Split';

  @override
  String get utxoRestructure => 'Restructure';

  @override
  String get utxoSeparateTokenTypes => 'Separate token types';

  @override
  String utxoSweepDust(String count) {
    return 'Sweep $count dust boxes into one';
  }

  @override
  String get utxoSearchHint => 'Search box ID or token...';

  @override
  String utxoFilterAll(String count) {
    return 'All ($count)';
  }

  @override
  String utxoFilterErgOnly(String count) {
    return 'ERG Only ($count)';
  }

  @override
  String utxoFilterTokens(String count) {
    return 'Tokens ($count)';
  }

  @override
  String utxoFilterDust(String count) {
    return 'Dust ($count)';
  }

  @override
  String utxoFilterRent(String count) {
    return 'Rent ($count)';
  }

  @override
  String utxoClearSelection(String count) {
    return 'Clear ($count)';
  }

  @override
  String get utxoSelectAll => 'Select All';

  @override
  String get utxoNoMatch => 'No UTXOs match criteria';

  @override
  String get utxoCopyBoxId => 'Copy Box ID';

  @override
  String get utxoBoxIdCopied => 'Box ID copied';

  @override
  String utxoHeight(String height) {
    return 'H: $height';
  }

  @override
  String utxoSplitEqual(String count, String amount) {
    return '$count boxes of $amount';
  }

  @override
  String utxoSplitWithChange(String count, String amount, String change) {
    return '$count boxes of $amount · $change change';
  }

  @override
  String utxoSplitToken(String count, String amount, String token, String erg) {
    return '$count boxes of $amount $token, each with $erg';
  }

  @override
  String utxoSplitNotEnough(String count) {
    return 'Not enough ERG for $count boxes after fees';
  }

  @override
  String get utxoSplitEnterErg =>
      'Enter an amount of at least 0.001 ERG that fits the selection';

  @override
  String get utxoSplitEnterToken =>
      'Enter a token amount that fits the selection';

  @override
  String utxoSplitFrom(int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'From $count boxes holding $total.',
      one: 'From 1 box holding $total.',
    );
    return '$_temp0';
  }

  @override
  String get utxoEqualParts => 'Equal parts';

  @override
  String get utxoAmountEach => 'Amount each';

  @override
  String get utxoHowManyBoxes => 'HOW MANY BOXES';

  @override
  String get utxoCustom => 'Custom';

  @override
  String utxoTokenAvailable(String token, String amount) {
    return '$token · $amount available';
  }

  @override
  String utxoPerBox(String token) {
    return '$token per box';
  }

  @override
  String get utxoErgPerBox => 'ERG per box';

  @override
  String get utxoAdjustCount =>
      'Adjust the count or amount until it fits the selection.';

  @override
  String utxoSplitFeeNote(String fee) {
    return 'Miner fee: $fee. Remaining ERG and every token return to you as change.';
  }

  @override
  String get utxoPreviewSplit => 'Preview split';

  @override
  String get utxoCustomRestructure => 'Custom Restructure';

  @override
  String get utxoAddOutput => 'Add output';

  @override
  String get utxoDefineOutputs =>
      'Define desired output boxes. Remainder returns to change.';

  @override
  String utxoBoxErgAmount(String number) {
    return 'Box #$number ERG Amount';
  }

  @override
  String get utxoInvalidAmount => 'Invalid amount: min 0.001 ERG per box';

  @override
  String get utxoPreviewRestructure => 'Preview Restructure';

  @override
  String utxoSelectedCount(String count) {
    return '$count Selected';
  }

  @override
  String rentDueWithin(int count, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count due within $days days',
      one: '1 due within $days days',
    );
    return '$_temp0';
  }

  @override
  String rentBlock(String height) {
    return 'block $height';
  }

  @override
  String rentAtRiskNow(String fee) {
    return 'At risk: it holds no more than its $fee rent, so it can be collected now, tokens included.';
  }

  @override
  String rentAtRiskFrom(String fee, String block, String when) {
    return 'At risk: it holds no more than its $fee rent. From $block ($when) it can be collected whole, tokens included.';
  }

  @override
  String rentWholeNow(String whole) {
    return 'Rent would take this whole box ($whole); it can be collected now.';
  }

  @override
  String rentWholeFrom(String whole, String block, String when) {
    return 'Rent would take this whole box ($whole), from $block ($when).';
  }

  @override
  String rentChargeableNow(String fee, String block) {
    return 'Storage rent of $fee can be charged now (due $block).';
  }

  @override
  String rentDue(String fee, String when, String block) {
    return 'Storage rent of $fee due $when ($block).';
  }

  @override
  String get rentIntoOne => 'into one';

  @override
  String rentIntoCount(String count) {
    return 'into $count';
  }

  @override
  String get rentIntoOneOrMore => 'into one or more';

  @override
  String get rentFewerBoxes => 'Fewer boxes keep every send small and cheap.';

  @override
  String get rentMovingRestarts =>
      'Moving old boxes also restarts their 4-year storage-rent clock.';

  @override
  String rentMergeBoxes(String count, String address, String into) {
    return 'Merge $count boxes at $address $into.';
  }

  @override
  String rentMergeBoxesOf(
    String count,
    String total,
    String address,
    String into,
  ) {
    return 'Merge $count of $total boxes at $address $into.';
  }

  @override
  String rentCleanupFee(String fee) {
    return 'Fee $fee. Only this address\'s boxes move, so no addresses are linked.';
  }

  @override
  String get rentReviewCleanup => 'Review cleanup';

  @override
  String rentCantCover(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boxes can\'t cover their storage rent',
      one: '1 box can\'t cover its storage rent',
    );
    return '$_temp0';
  }

  @override
  String rentFallsDue(int count, String days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fall due within $days days',
      one: '1 falls due within $days days',
    );
    return '$_temp0';
  }

  @override
  String rentReasonAnd(String first, String second) {
    return '$first and $second';
  }

  @override
  String rentReasonMoving(String reason) {
    return '$reason. Moving them starts a new 4-year rent clock.';
  }

  @override
  String get rentChecking => 'Checking storage rent…';

  @override
  String get rentUnavailable =>
      'Storage rent unavailable: your node could not be read. Refresh to try again.';

  @override
  String get rentNotChecked => 'Storage rent not checked yet.';

  @override
  String rentAtRiskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boxes at risk of collection',
      one: '1 box at risk of collection',
    );
    return '$_temp0';
  }

  @override
  String rentUnmeasured(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boxes could not be measured.',
      one: '1 box could not be measured.',
    );
    return '$_temp0';
  }

  @override
  String rentRateLine(String rate) {
    return 'Rate $rate.';
  }

  @override
  String rentErgOnlyWhole(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count ERG-only boxes are worth no more than their rent, which would take them whole.',
      one:
          '1 ERG-only box is worth no more than its rent, which would take it whole.',
    );
    return '$_temp0';
  }

  @override
  String rentLeadParts(String parts) {
    return 'Storage rent: $parts.';
  }

  @override
  String rentLeadAllCovered(String days) {
    return 'Storage rent: nothing due within $days days, and every box covers its rent.';
  }

  @override
  String rentLeadAllMeasuredCovered(String days) {
    return 'Storage rent: nothing due within $days days, and every measured box covers its rent.';
  }

  @override
  String rentLeadNoTokenRisk(String days) {
    return 'Storage rent: no box with tokens is at risk, and nothing else is due within $days days.';
  }

  @override
  String rentLeadNoMeasuredTokenRisk(String days) {
    return 'Storage rent: no measured box with tokens is at risk, and nothing else is due within $days days.';
  }

  @override
  String get confirmSignBroadcast => 'Sign & broadcast';

  @override
  String get confirmWarnBroadcast =>
      'This will sign and broadcast a transaction to the network. It cannot be undone once confirmed.';

  @override
  String get confirmWarnPage =>
      'This will sign a transaction and hand it to the page, which broadcasts it. Once broadcast it cannot be undone.';

  @override
  String get confirmTo => 'TO';

  @override
  String get confirmDetails => 'Details';

  @override
  String get confirmSignOnly => 'Sign only';

  @override
  String get confirmTxDetails => 'Transaction details';

  @override
  String get rentHintDefaultRate => ' at the default rate';

  @override
  String rentHintCharge(String fee, String rate, String bytes) {
    return 'Ergo charges storage rent on boxes left unmoved for 4 years: about $fee$rate for this $bytes-byte box.';
  }

  @override
  String get rentHintCovers => 'This amount covers it.';

  @override
  String get rentHintLess =>
      'A box holding less can be collected whole, tokens included.';

  @override
  String rentHintExtraBoxes(String count) {
    return 'These tokens need $count boxes; the extra ones carry only their minimum ERG.';
  }

  @override
  String rentHintSuggested(String amount) {
    return 'Suggested $amount';
  }

  @override
  String get rentHintUseSuggested => 'Use suggested';

  @override
  String get txResultId => 'Transaction ID';

  @override
  String get txResultIdCopied => 'Transaction ID copied';

  @override
  String get txViewOnExplorer => 'View on explorer';

  @override
  String txBookkeepingFailed(String error) {
    return 'Transaction submitted, but local tracking could not be updated: $error. Keep this transaction ID and check Activity before retrying.';
  }

  @override
  String get txBatchTitle => 'Consolidation result';

  @override
  String txBatchSubmitted(String done, String total) {
    return '$done of $total transactions submitted';
  }

  @override
  String txBatchStopped(String done, String total) {
    return 'Stopped early after $done of $total. No further batches were attempted.';
  }

  @override
  String txBatchItem(String number) {
    return 'Transaction $number';
  }

  @override
  String get pickerSearchHint => 'Search name or token id';

  @override
  String get pickerNoMatch => 'No tokens match that search.';

  @override
  String pickerSelect(String token) {
    return 'Select $token';
  }

  @override
  String pickerSelectedCount(String count) {
    return '$count selected';
  }

  @override
  String get amountEnterErg => 'Enter ERG';

  @override
  String amountEnterFiat(String currency) {
    return 'Enter $currency';
  }

  @override
  String get separateTitle => 'Separate tokens';

  @override
  String get separateIntro =>
      'Move each token type, with its full balance, into a separate box in your wallet. This uses one transaction.';

  @override
  String get separateNoSource => 'No boxes contain multiple token types.';

  @override
  String separateSourceItem(String box, String count, String value) {
    return '$box · $count tokens · $value';
  }

  @override
  String separateEachHolds(String min, String fee) {
    return 'Each token box holds at least $min. Miner fee $fee.';
  }

  @override
  String separateMinimumNeeded(String amount) {
    return 'Minimum ERG needed: $amount';
  }

  @override
  String get separateTokensToSeparate => 'Tokens to separate';

  @override
  String separateRawUnits(String tokenId, String amount) {
    return '$tokenId\n$amount raw units';
  }

  @override
  String get separateAddFundingTitle => 'Add ERG funding';

  @override
  String get separateFundingNote =>
      'Only ERG-only boxes at the source address are listed, oldest first. Select any you want to spend.';

  @override
  String separateFundingItem(String box, String height) {
    return '$box · Height $height';
  }

  @override
  String get separateHeightUnknown => 'unknown';

  @override
  String separatePlanLine(int inputs, String tokens) {
    String _temp0 = intl.Intl.pluralLogic(
      inputs,
      locale: localeName,
      other: '$inputs input boxes → $tokens token boxes',
      one: '1 input box → $tokens token boxes',
    );
    return '$_temp0';
  }

  @override
  String separatePlanLineChange(int inputs, String tokens) {
    String _temp0 = intl.Intl.pluralLogic(
      inputs,
      locale: localeName,
      other: '$inputs input boxes → $tokens token boxes + ERG change',
      one: '1 input box → $tokens token boxes + ERG change',
    );
    return '$_temp0';
  }

  @override
  String separateChangeReturned(String amount) {
    return 'ERG returned as change: $amount';
  }

  @override
  String get separateStayNote =>
      'Every token and all remaining ERG stay in your wallet. A remainder below 0.001 ERG is kept in the first token box.';

  @override
  String get separateReview => 'Review separation';

  @override
  String get homeOnAnotherAddress => 'on another address';

  @override
  String homeOnOtherAddresses(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'on $n other addresses',
      one: 'on $n other address',
    );
    return '$_temp0';
  }

  @override
  String homeFundsWhere(String where) {
    return 'Funds $where';
  }

  @override
  String homeInclFundsWhere(String where) {
    return 'incl. funds $where';
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
    return '$figure ERG pending';
  }

  @override
  String homePendingConfirmed(String lead, String confirmed) {
    return '$lead · $confirmed confirmed';
  }

  @override
  String get homeLockedCaps => 'LOCKED';

  @override
  String get formatUnconfirmed => 'Unconfirmed';

  @override
  String get celautDepositRowTitle => 'Celaut deposit';

  @override
  String get celautDepositRowSubtitle => 'Pay a node in ERG from the wallet';

  @override
  String get celautDepositScreenTitle => 'Celaut deposit';

  @override
  String get celautDepositIntro =>
      'Pay ERG to a node to get MU, the unit of account of the node. The wallet of the app pays. The node gets a plain payment and can keep it, so deposit small amounts. The balance stays with the client id of the app on that node, which the app keeps in its encrypted Celaut database.';

  @override
  String get celautDepositNodeLabel => 'Node address';

  @override
  String get celautDepositNodeHint => 'host:port';

  @override
  String get celautDepositCheck => 'Check the node';

  @override
  String get celautDepositChecking => 'Checking the node…';

  @override
  String get celautDepositNodeTitle => 'Contract of the node';

  @override
  String celautDepositPayTo(String address) {
    return 'Pay to $address';
  }

  @override
  String celautDepositRate(String mu) {
    return '$mu MU per nanoERG';
  }

  @override
  String celautDepositBalance(String mu) {
    return 'Balance of the client: $mu MU';
  }

  @override
  String celautDepositUsed(String used, String limit) {
    return 'Deposits to this node: $used of $limit';
  }

  @override
  String celautDepositUsedValue(String used, String limit) {
    return '$used of $limit';
  }

  @override
  String get celautDepositLimitLabel => 'Limit for this node in ERG';

  @override
  String get celautDepositLimitHelper => '1 ERG at most';

  @override
  String get celautDepositSetLimit => 'Set the limit';

  @override
  String get celautDepositLimitInvalid => 'Enter a limit in ERG, from 0 to 1.';

  @override
  String get celautDepositAmountLabel => 'Amount in ERG';

  @override
  String get celautDepositAmountHint => '0.001 ERG or more';

  @override
  String get celautDepositAmountInvalid =>
      'Enter an amount of 0.001 ERG or more.';

  @override
  String get celautDepositPrepare => 'Prepare the deposit';

  @override
  String get celautDepositPreparing => 'Preparing…';

  @override
  String get celautDepositConfirmTitle => 'Confirm the deposit';

  @override
  String get celautDepositConfirmLabel => 'Deposit';

  @override
  String get celautDepositRowNode => 'Node';

  @override
  String get celautDepositRowAmount => 'Amount';

  @override
  String get celautDepositRowMu => 'Buys';

  @override
  String get celautDepositRowRate => 'Rate';

  @override
  String get celautDepositRowTotal => 'Total from the wallet';

  @override
  String get celautDepositRowUsed => 'Deposits to this node';

  @override
  String celautDepositConfirmDetail(String minutes) {
    return 'The node can keep a plain payment. The app tells the node once, when the explorer shows the box. The token of this deposit expires in $minutes minutes.';
  }

  @override
  String get celautDepositWaiting =>
      'Sent. The app waits until the explorer shows the box…';

  @override
  String get celautDepositWaitAgain => 'Wait again';

  @override
  String celautDepositTx(String id) {
    return 'Transaction: $id';
  }

  @override
  String celautDepositBox(String id) {
    return 'Deposit box: $id';
  }

  @override
  String celautDepositAccepted(String mu) {
    return 'The node accepted the deposit. Balance of the client: $mu MU.';
  }

  @override
  String celautDepositRefused(String message) {
    return 'The node refused the payment: $message';
  }

  @override
  String get celautDepositCancelled =>
      'The deposit was cancelled. Nothing was sent.';

  @override
  String celautDepositSendFailed(String error) {
    return 'The transaction was not sent: $error';
  }

  @override
  String get celautUnknown => 'unknown';

  @override
  String get celautNoFullWallet =>
      'This needs a wallet with its recovery phrase on this device. Create or restore a wallet first.';

  @override
  String get celautDepositPayerTitle => 'Paying wallet';

  @override
  String celautDepositPayerBalance(String amount) {
    return 'Balance: $amount';
  }

  @override
  String get celautDepositPayerOpen =>
      'This wallet is open. The app asks for your fingerprint or screen lock before the deposit.';

  @override
  String get celautDepositPayerLocked =>
      'This wallet is locked. The app asks for your fingerprint or screen lock before the deposit, and opens it.';

  @override
  String get celautDepositRowPayer => 'Paid by';

  @override
  String get celautDepositRowPayerBalance => 'Balance of the paying wallet';

  @override
  String get celautDepositSentTitle => 'Sent deposits';

  @override
  String celautDepositSentRow(String amount, String mu, String node) {
    return '$amount ($mu MU) to $node';
  }

  @override
  String get celautDepositSentExpired =>
      'The deposit token expired. The node refuses this deposit now.';

  @override
  String get celautComputeHomeRowTitle => 'Chats home';

  @override
  String get celautComputeHomeRowSubtitle =>
      'The app opens on the list of conversations. This is the default. Turn it off to see the wallets list first.';

  @override
  String get celautHomeComputeTitle => 'Offered compute';

  @override
  String get celautHomeOfferedNote =>
      'Sums of what the reachable nodes advertise: offered, not free.';

  @override
  String celautHomeNodes(String counted, String unreachable) {
    return 'Nodes counted: $counted. Not reachable: $unreachable.';
  }

  @override
  String get celautHomeNoNodes =>
      'The node list is empty. Add a node with Nodes.';

  @override
  String get celautHomeMoneyTitle => 'Money for compute';

  @override
  String get celautHomeInstancesTitle => 'Running instances';

  @override
  String get celautHomeNoInstances => 'No instance runs.';

  @override
  String celautHomeCostSoFar(String mu, String amount) {
    return 'Cost so far: $mu ($amount)';
  }

  @override
  String get celautHomeStop => 'Stop';

  @override
  String celautHomeStopped(String mu) {
    return 'Stopped. Refund: $mu.';
  }

  @override
  String get celautHomeWallets => 'Wallet';

  @override
  String get celautHomeRefresh => 'Refresh';

  @override
  String get celautHomeLoading => 'Asking the nodes…';

  @override
  String get celautErrorClientUnknown =>
      'The node does not know the client of this app: it forgot it. Choose a new client or retry later.';

  @override
  String celautAtLeast(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes unknown',
      one: '1 node unknown',
    );
    return 'at least $value ($_temp0)';
  }

  @override
  String celautAtLeastWallets(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wallets unknown',
      one: '1 wallet unknown',
    );
    return 'at least $value ($_temp0)';
  }

  @override
  String get celautHomeTagline => 'Compute';

  @override
  String get celautHomeFullWallets => 'Full wallets · can pay';

  @override
  String get celautHomePaidCredit => 'Paid credit on nodes';

  @override
  String get celautHomeFreeCredit => 'Free credit on nodes';

  @override
  String celautHomeUsd(String amount) {
    return '≈ $amount';
  }

  @override
  String get celautHomeUsdUnknown => 'USD unknown';

  @override
  String get celautHomeUsdSource =>
      'USD from the ERG/USD oracle pool price, read on-chain. The free credit counts as spent first.';

  @override
  String celautHomeNodeCredit(String paid, String free, String rate) {
    return 'Paid $paid · free $free · $rate MU per nanoERG';
  }

  @override
  String get celautHomeNodeUnreachable => 'Not reachable';

  @override
  String get celautHomeNodesButton => 'Nodes';

  @override
  String get celautHomeClientUnknownAction => 'Choose what to do';

  @override
  String get celautOpenFullWalletNeeded =>
      'Start and stop need the wallet open. The app asks for your fingerprint or screen lock first.';

  @override
  String get celautClientUnknownTitle => 'The node forgot the client';

  @override
  String celautClientUnknownBody(String node) {
    return 'The node $node does not know the client id of this app. Make a new client now, or retry later.';
  }

  @override
  String get celautClientUnknownWarning =>
      'A new client starts with only the free credit of the node. The balance of the old client is lost, also the ERG that you deposited to it.';

  @override
  String get celautClientUnknownNew => 'New client';

  @override
  String get celautClientUnknownRetry => 'Retry later';

  @override
  String get celautClientUnknownDone =>
      'The app now uses a new client on this node.';

  @override
  String get celautNodesTitle => 'Nodes';

  @override
  String get celautNodesIntro =>
      'The node list of the app. Add a node by its address or with a QR code. Only these nodes are in the sums of the home screen. A removed node keeps its deposits and its client in the app, so adding it again restores them.';

  @override
  String get celautNodesAdd => 'Add';

  @override
  String get celautNodesEmpty => 'The node list is empty.';

  @override
  String get celautNodesRemove => 'Remove';

  @override
  String get celautNodesRemoved =>
      'The node was removed. Its deposits stay in the app.';

  @override
  String get celautNodesAdded => 'The node was added.';

  @override
  String celautNodesDeposited(String amount) {
    return 'Deposits of the app: $amount';
  }

  @override
  String celautUnlockTitle(String name) {
    return 'PIN of $name';
  }

  @override
  String get celautUnlockFailed => 'The wallet did not open.';

  @override
  String get celautDepositAuthNeeded =>
      'The deposit needs the fingerprint or screen lock for the paying wallet. Nothing was sent.';

  @override
  String get celautNodesRowSubtitle =>
      'Add and remove the nodes in the sums of the home screen';

  @override
  String get celautNodesScan => 'Scan a QR code';

  @override
  String get chatInputHint => 'Write a message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatEmpty => 'Say something to start the conversation.';

  @override
  String get chatStarting =>
      'The service is starting. It can take a minute before it answers.';

  @override
  String get chatStop => 'Stop the instance';

  @override
  String get chatErrorUnreachable =>
      'The service did not answer. Your message may not have arrived. Try again.';

  @override
  String get chatErrorBadAnswer =>
      'The service answered in a way that this app does not understand.';

  @override
  String get chatErrorHistoryFull =>
      'This conversation is full. Start a new instance for a new conversation.';

  @override
  String get chatErrorStorageFull =>
      'The service has no room to keep this file. The message was not sent.';

  @override
  String get chatErrorBusy =>
      'The service is too busy to take this message. Try again in a moment.';

  @override
  String get chatErrorOther => 'The service refused the message.';

  @override
  String get chatAttach => 'Attach a photo or an audio file';

  @override
  String get chatAttachmentRemove => 'Remove the file';

  @override
  String get chatAttachmentShare => 'Open or share the file';

  @override
  String get chatAttachmentFailed => 'The file did not load.';

  @override
  String get chatErrorUnsupportedMedia =>
      'The service does not accept this kind of file.';

  @override
  String get chatErrorFile =>
      'A file is empty or too big. Each file can have 4 MiB at most, and each message 4 files.';

  @override
  String chatSkippedDuplicate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files are already attached',
      one: '1 file is already attached',
    );
    return '$_temp0';
  }

  @override
  String chatSkippedInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count files are empty, too big or not JPEG, PNG, MP3 or WAV files',
      one: '1 file is empty, too big or not a JPEG, PNG, MP3 or WAV file',
    );
    return '$_temp0';
  }

  @override
  String chatSkippedTooMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files were left out: a message has 4 files at most',
      one: '1 file was left out: a message has 4 files at most',
    );
    return '$_temp0';
  }

  @override
  String get chatImage => 'Image';

  @override
  String get chatTyping => 'The service is answering…';

  @override
  String get chatSending => 'Sending…';

  @override
  String get chatReasoning => 'Reasoning';

  @override
  String get chatAnswerFailed => 'The answer stopped before the end.';

  @override
  String get chatAnswerCancelled => 'The answer was cancelled.';

  @override
  String chatWaitingSeconds(int seconds) {
    return 'Still working… $seconds s';
  }

  @override
  String chatStopped(String refund) {
    return 'The instance stopped. Refund: $refund';
  }

  @override
  String get chatsMenuMore => 'More';

  @override
  String get chatsNewTitle => 'New conversation';

  @override
  String get chatsServicesTitle => 'Services';

  @override
  String get chatsOtherTitle => 'Other instances';

  @override
  String get chatsOtherEmpty =>
      'No other instances. A service that has no conversation shows here while it runs.';

  @override
  String get chatsEmptyTitle => 'No conversations yet';

  @override
  String get chatsEmptyBody =>
      'Each conversation is a service that runs on a node. Start one with the pencil button.';

  @override
  String get chatsPaneEmpty =>
      'Choose a conversation from the list, or start a new one.';

  @override
  String get chatsTabChats => 'Chats';

  @override
  String get chatsTabWallet => 'Wallet';

  @override
  String get chatsTabCompute => 'Compute';

  @override
  String get chatsDepositRow => 'Deposit to a node';

  @override
  String get chatsDepositRowSubtitle =>
      'Credit on a node for its services, paid from the wallet';

  @override
  String get chatsNodesRowSubtitle => 'Add a node by its address or a QR code';

  @override
  String get chatsServicesRowSubtitle =>
      'Import a service file, or run a service';

  @override
  String get chatsOtherRowSubtitle => 'Instances without a conversation';

  @override
  String get chatsStateChecking => 'Checking…';

  @override
  String get chatsStateStarting => 'Starting';

  @override
  String get chatsStateRunning => 'Running';

  @override
  String get chatsStateUnreachable => 'Not answering';

  @override
  String get chatsStateStopped => 'Stopped';

  @override
  String get chatsNoPreview => 'No message seen since the app opened';

  @override
  String get chatsNoChatSlot =>
      'No conversation: this service has no chat slot';

  @override
  String get chatsNoInterface =>
      'No interface: this service has no chat or web slot';

  @override
  String get chatsWebPreview => 'Web service · opens in the browser';

  @override
  String get chatsOpenInBrowser => 'Open in browser';

  @override
  String get chatsBrowserFailed => 'Could not open the browser';

  @override
  String chatsPreviewYou(String text) {
    return 'You: $text';
  }

  @override
  String get chatsPreviewPhoto => 'Photo';

  @override
  String get chatsPreviewAudio => 'Audio';

  @override
  String chatsPreviewNamed(String kind, String name) {
    return '$kind: $name';
  }

  @override
  String get chatMute => 'Mute notifications';

  @override
  String get chatUnmute => 'Turn notifications on';

  @override
  String get chatMutedHint => 'Notifications are off for this chat';

  @override
  String get chatMic => 'Record a voice message';

  @override
  String get chatMicCancel => 'Discard the recording';

  @override
  String get chatMicDone => 'Attach the recording';

  @override
  String get chatMicDenied =>
      'The app has no permission to use the microphone.';

  @override
  String get chatMicLimit =>
      'The recording reached the size limit and stopped. It is attached.';

  @override
  String get chatPinnedExpand => 'Show more of the pinned message';

  @override
  String get chatPinnedCollapse => 'Show less of the pinned message';

  @override
  String get chatPin => 'Pin';

  @override
  String get chatUnpin => 'Unpin';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatCopied => 'Message copied.';

  @override
  String get chatPinnedIcon => 'Pinned message';

  @override
  String get chatNotifyDoneBody => 'The answer is ready.';

  @override
  String get chatsBackground => 'Chat background';

  @override
  String get chatsActionInfo => 'Info';

  @override
  String get chatsDelete => 'Delete';

  @override
  String get chatsRename => 'Rename';

  @override
  String get chatsRenameTitle => 'Rename';

  @override
  String get chatsRenameNote =>
      'Only this phone sees this name. The node does not get it. Leave it empty to remove it.';

  @override
  String chatsRenameNoteOriginal(String name) {
    return 'Only this phone sees this name. The node does not get it. Leave it empty to show \"$name\" again.';
  }

  @override
  String chatsShowStopped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count stopped instances',
      one: 'Show 1 stopped instance',
    );
    return '$_temp0';
  }

  @override
  String get chatsHideStopped => 'Hide stopped instances';

  @override
  String chatsStopTitle(String name) {
    return 'Stop $name?';
  }

  @override
  String get chatsStopBody =>
      'The conversation ends, and the node refunds what is left of the instance.';

  @override
  String chatsDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get chatsDeleteBody =>
      'The instance is stopped. Delete takes it out of the app, with its token.';

  @override
  String chatsStartedOther(String node) {
    return 'The service started on $node. It has no conversation: find it in Compute, under Services, in the page of the service.';
  }

  @override
  String get chatsInfoTitle => 'Instance';

  @override
  String get chatsInfoStatus => 'State';

  @override
  String get chatsInfoNode => 'Node';

  @override
  String get chatsInfoPeer => 'Peer id of the node';

  @override
  String get chatsInfoServiceId => 'Service id';

  @override
  String get chatsInfoInstanceId => 'Instance id (token)';

  @override
  String get chatsInfoSlot => 'Interface';

  @override
  String get chatsInfoChatSlot => 'Chat over HTTP';

  @override
  String get chatsInfoNoChatSlot => 'No chat interface';

  @override
  String get chatsInfoStarted => 'Started';

  @override
  String get chatsInfoCost => 'Cost so far';

  @override
  String get chatsInfoRefund => 'Refund at the stop';

  @override
  String get chatsInfoStopNote =>
      'Stop ends the conversation. The node refunds what is left of the instance.';

  @override
  String get chatsInfoDeleteNote =>
      'Only a stopped instance can be deleted. The app keeps every other instance, even if its node does not answer.';

  @override
  String get chatsReceiptsTitle => 'Receipts';

  @override
  String get chatsReceiptsStart => 'Start';

  @override
  String get chatsReceiptsCheckpoints => 'Checkpoints';

  @override
  String get chatsReceiptsClose => 'Close';

  @override
  String get chatsReceiptsNone => 'none';

  @override
  String get chatsReceiptsNoTunnel => 'no tunnel yet';

  @override
  String get chatsReceiptsCancelled => 'none (cancelled)';

  @override
  String get chatsReceiptsOpen => 'open';

  @override
  String get chatsReceiptsFaultSent =>
      'The node signed data that does not match what this phone sent';

  @override
  String get chatsReceiptsFaultReceived =>
      'The node signed data that does not match what this phone received';

  @override
  String get chatsReceiptsFaultEnvs =>
      'The node signed environment variables that this phone did not send';

  @override
  String get chatsReceiptsFaultService =>
      'The node signed a different service from the one that this phone started';

  @override
  String get chatsReceiptsFaultAmount =>
      'The node signed a different start balance from the one that this phone asked for';

  @override
  String get chatsReceiptsFaultInvalid => 'A receipt does not verify';

  @override
  String get chatsReceiptsFaultOmitted =>
      'The node gave no start receipt, but it gave one before';

  @override
  String get chatsReceiptsDropped => 'Tunnels dropped';

  @override
  String get chatsReceiptsExport => 'Export receipts';

  @override
  String get chatsReceiptsExportNone => 'There are no receipts to export.';

  @override
  String chatsReceiptsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get chatsReceiptsNote =>
      'The node signs these receipts. They are evidence against the node. You can give them to other people. A tunnel with no close is not always a fault. For example, this phone or the node can stop the tunnel.';

  @override
  String get celautErrorNodeClosed =>
      'The node is closed now: its operator accepts new work only at certain hours. Try later or choose another node.';

  @override
  String get celautErrorNoRoom =>
      'The node has not enough free resources for this service now. Try later or choose another node.';

  @override
  String get celautErrorServiceMissing =>
      'The node does not have this service. Choose a node that has it.';

  @override
  String get celautErrorPolicyRefused =>
      'The policy of the node does not allow what this service connects to. Choose another node.';

  @override
  String get celautErrorUnsupportedArchitecture =>
      'The node does not run this kind of service (it needs another processor architecture). Choose another node.';

  @override
  String get celautErrorRateLimited =>
      'The node limits the calls of this app for a short time. Wait a moment and try again.';

  @override
  String get celautErrorRecursionLimit =>
      'The node refused the request because it went round or too deep. Try again.';

  @override
  String get celautErrorInsufficientCredit =>
      'Your credit on the node is less than the price of the service. Add a deposit on this node or choose another one.';

  @override
  String get celautErrorLaunchFailed =>
      'The node tried to start the service and could not.';

  @override
  String get celautRunTitle => 'Run a service';

  @override
  String get celautRunSearchHint => 'Search skills and tags';

  @override
  String get celautRunLoading => 'Loading skills…';

  @override
  String get celautRunEmpty => 'No skill matches.';

  @override
  String get celautRunCatalogError => 'The skill catalog is not available now.';

  @override
  String get celautRunRetry => 'Try again';

  @override
  String get celautRunServicesTitle => 'Services with this skill';

  @override
  String get celautRunNoServices => 'No service has this skill yet.';

  @override
  String get celautRunBest => 'Best';

  @override
  String celautRunScore(String score) {
    return 'Score $score';
  }

  @override
  String get celautRunButton => 'Run';

  @override
  String celautRunLaunching(String name) {
    return 'Launching $name…';
  }

  @override
  String get celautRunLaunchingNote =>
      'The app asks the nodes, then starts the service on the best one.';

  @override
  String get celautRunStepNodes => 'Asking the nodes for a price';

  @override
  String get celautRunStepReading => 'Reading the service';

  @override
  String get celautRunStepStarting => 'Starting it on the best node';

  @override
  String celautRunStarted(String node, String cost) {
    return 'Started on $node. Start cost: $cost.';
  }

  @override
  String get celautRunOpenChat => 'Open chat';

  @override
  String get celautRunFailedTitle => 'The service did not start';

  @override
  String get celautRunFailedNoNodes =>
      'There is no node to ask. Add a node in the Nodes list.';

  @override
  String get celautRunFailedNoQuotes => 'No node gave a price. Here is why:';

  @override
  String get celautRunFailedAll =>
      'Some nodes gave a price, but none of them started the service. Here is why:';

  @override
  String celautRunNeedsCredit(String credit, String cost) {
    return 'Your credit on this node is $credit, and the service costs $cost. Add a deposit on this node or choose another one.';
  }

  @override
  String get celautRunLeftOut => 'Left out: it did not answer the last checks.';

  @override
  String get celautRunDetails => 'Details';

  @override
  String get celautRunClose => 'Close';

  @override
  String get celautRunDeposit => 'Add a deposit';

  @override
  String celautNodeAvailable(String ms) {
    return 'Available · $ms ms';
  }

  @override
  String celautNodeSlow(String ms) {
    return 'Slow · $ms ms';
  }

  @override
  String get celautNodeUnreachable => 'Not answering';

  @override
  String get celautNodeUnknownState => 'Not checked yet';

  @override
  String celautNodeLastSeen(String ago) {
    return 'Last answer $ago ago';
  }

  @override
  String get celautNodeNeverSeen => 'It has never answered';

  @override
  String get celautNodeChecking => 'Checking…';

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
  String get celautNodesCheckNow => 'Check now';

  @override
  String celautRunPreview(String node, String cost) {
    return 'Best node now: $node · start cost $cost';
  }

  @override
  String get celautRunPreviewLoading => 'Looking for the best node…';

  @override
  String celautRunConfirmTitle(String name) {
    return 'Run $name?';
  }

  @override
  String get celautRunConfirmBody =>
      'The service runs on a node and uses your credit there until it stops. Stop it from its conversation, its info page or the list of conversations.';

  @override
  String get celautRunConfirmNoQuote =>
      'No node gave a price yet. Run asks every node of the list.';

  @override
  String get celautRunSurvivalLabel => 'Keep it running at least';

  @override
  String get celautRunSurvivalHint => 'Empty: the default start balance';

  @override
  String get celautRunSurvivalWrong => 'From 1 minute to 30 days.';

  @override
  String celautRunDefaultBalance(String balance) {
    return 'Start balance $balance (the default).';
  }

  @override
  String celautRunDefaultBalanceLasts(String balance, String time) {
    return 'Start balance $balance (the default): about $time on this node.';
  }

  @override
  String get celautRunSurvivalNoPrice =>
      'This node gives no price for its time. The app uses the default start balance.';

  @override
  String celautRunSurvivalEstimate(String cost, String balance, String time) {
    return 'Start cost about $cost, with a balance of $balance for at least $time at the price of the node now. A busy node, and the traffic of the conversation, cost more. The node gives back what the instance does not use.';
  }

  @override
  String get celautTopUpTitle => 'Keep running';

  @override
  String get celautTopUpThreshold => 'When an instance would last less than';

  @override
  String get celautTopUpAmount => 'Each time, add this much time';

  @override
  String celautTopUpRange(String min, String max) {
    return 'From $min to $max minutes.';
  }

  @override
  String get celautTopUpNote =>
      'The app checks the instances that you keep running when the list of conversations opens and once a minute while the app runs. A top-up moves credit that you already have on the node of the instance (ModifyDeposit): nothing is paid on the blockchain and nothing is signed. If that credit is too low, the app does not pay: it asks you, and a deposit always needs your confirmation and your fingerprint or screen lock. The app does not run when it is closed: then nothing is added, and the node stops the instance when its balance runs out.';

  @override
  String get celautTopUpNeedLater => 'Later';

  @override
  String get celautTopUpNeedDeposit => 'Deposit';

  @override
  String get celautErrorTransferFailed =>
      'The transfer of the service stopped (the file could not be read, it is cut, or it was cancelled). The node did not keep the cut service. Try again.';

  @override
  String get celautSendMissingTitle => 'The service is not on these nodes';

  @override
  String celautSendFromNode(String from, String to) {
    return 'Send it from $from to $to';
  }

  @override
  String celautSendFromFile(String to) {
    return 'Choose a .celaut.bee file and send it to $to';
  }

  @override
  String get celautSendNoHolder =>
      'No node of your list has this service. You can give it to a node from a .celaut.bee file.';

  @override
  String get celautSendConfirmTitle => 'Send the service?';

  @override
  String get celautSendConfirmBody =>
      'The whole service goes through this phone to the node, and a service can be large. The node keeps it, so later launches on that node do not send it again.';

  @override
  String get celautSendMetered =>
      'You are on mobile data: this can use a lot of it.';

  @override
  String get celautSendConfirm => 'Send';

  @override
  String get celautSendCancel => 'Cancel';

  @override
  String get celautSendFetching => 'Getting the service from the node…';

  @override
  String get celautSendSending => 'Giving the service to the node…';

  @override
  String get celautSendStarting => 'Starting the transfer…';

  @override
  String get celautImportChecking => 'Checking the service file…';

  @override
  String get celautImportNote =>
      'The app hashes every block, so a damaged file is found here and not after it goes to a node.';

  @override
  String celautSendProgress(String done, String total, String percent) {
    return '$done of $total ($percent%)';
  }

  @override
  String celautSendSoFar(String done) {
    return '$done so far';
  }

  @override
  String get celautSendDone => 'The node has the service now. Starting it…';

  @override
  String get celautSendFailedTitle => 'The service was not sent';

  @override
  String get celautSendOtherService => 'This file holds another service.';

  @override
  String get celautSendNoServicePart => 'This file has no service in it.';

  @override
  String get celautSendNoDirectory =>
      'The app has no place to keep the service.';

  @override
  String get celautPkgTitle => 'Your services';

  @override
  String get celautPkgImport => 'Import a service file';

  @override
  String get celautPkgEmpty =>
      'No service file is loaded. Import a .celaut.bee file to run a service that no node has yet.';

  @override
  String get celautPkgRemove => 'Remove';

  @override
  String get celautPkgRemoveTitle => 'Remove this service file?';

  @override
  String celautPkgRemoveBody(String name) {
    return '$name is deleted from this app. The nodes that have the service keep it.';
  }

  @override
  String celautPkgLoaded(String name) {
    return 'Loaded $name.';
  }

  @override
  String celautPkgBadFile(String reason) {
    return 'This file is not a service package: $reason';
  }

  @override
  String get celautPkgMissing => 'The file is gone. Import it again.';

  @override
  String get celautPkgRedownload =>
      'Download the file again and try once more: a browser sometimes saves it damaged.';

  @override
  String celautSendFromLibrary(String to) {
    return 'Send your loaded file to $to';
  }

  @override
  String celautHomeNodesReady(String ready, String total) {
    return '$ready of $total nodes ready';
  }

  @override
  String get celautHomeCreditOnNodes => 'Credit on nodes';

  @override
  String celautNodeCredit(String credit) {
    return 'Credit: $credit';
  }

  @override
  String get celautEnvTitle => 'Environment variables';

  @override
  String get celautEnvRowSubtitle =>
      'Values that a service can get when it starts';

  @override
  String get celautEnvIntro =>
      'Named values that you can give to a service when you run it, for example a key. They stay encrypted on this phone. A service only gets the ones that you choose.';

  @override
  String get celautEnvEmpty => 'No variables yet.';

  @override
  String get celautEnvAdd => 'Add variable';

  @override
  String celautEnvEditTitle(String name) {
    return 'Edit $name';
  }

  @override
  String get celautEnvName => 'Name';

  @override
  String get celautEnvValue => 'Value';

  @override
  String get celautEnvShow => 'Show the value';

  @override
  String get celautEnvHide => 'Hide the value';

  @override
  String get celautEnvEdit => 'Edit';

  @override
  String get celautEnvDelete => 'Delete';

  @override
  String celautEnvDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get celautEnvDeleteBody =>
      'Services that you run later cannot use it. Instances that already run keep what they got.';

  @override
  String get celautEnvNameBad =>
      'The name must start with a letter or _ and have only letters, digits and _.';

  @override
  String get celautEnvNameReserved =>
      'This name is reserved for the name of the instance.';

  @override
  String get celautEnvNameTaken =>
      'A variable with this name exists. Edit it instead.';

  @override
  String get celautEnvValueEmpty => 'Write a value.';

  @override
  String get celautEnvValueLong => 'The value is longer than 8192 bytes.';

  @override
  String get celautEnvValueNul => 'The value cannot have a NUL character.';

  @override
  String get celautEnvTooMany => 'There are 256 variables. Delete one first.';

  @override
  String get celautEnvAskTitle => 'Variables of the service';

  @override
  String celautEnvAskStep(int current, int total) {
    return 'Variable $current of $total';
  }

  @override
  String get celautEnvAskNoText =>
      'The service gives no description of this variable.';

  @override
  String get celautEnvAskPick => 'Choose from my variables';

  @override
  String get celautEnvAskPickTitle => 'Choose a variable';

  @override
  String get celautEnvAskPickEmpty =>
      'You have no variables yet. Add them in Settings, Environment variables.';

  @override
  String get celautEnvAskType => 'Type a value';

  @override
  String get celautEnvAskUse => 'Use this value';

  @override
  String get celautEnvAskSkip => 'Skip';

  @override
  String get celautEnvAskSkipHint => 'The service does not get this variable.';

  @override
  String get celautEnvAskBadName =>
      'The node cannot give this variable, because its name is not valid. You can only skip it.';

  @override
  String celautEnvAskChosen(String what) {
    return 'Chosen: $what';
  }

  @override
  String get celautEnvAskBack => 'Back';

  @override
  String get celautEnvReviewTitle => 'Review';

  @override
  String celautEnvReviewFromContainer(String name) {
    return 'My variable $name';
  }

  @override
  String get celautEnvReviewTyped => 'Typed value';

  @override
  String get celautEnvReviewSkipped => 'Skipped';

  @override
  String get celautEnvReviewNote =>
      'The node that starts the service reads these values. A node that refuses the start has read them too.';

  @override
  String get celautEnvRun => 'Run';

  @override
  String get celautEnvDeclUnreadableTitle => 'The service could not be read';

  @override
  String get celautEnvDeclUnreadableBody =>
      'The app could not read the interface and the variables of this service, so it cannot tell if Chatui supports it or if it needs variables. Run it anyway, or cancel.';

  @override
  String get celautEnvRunWithout => 'Run anyway';

  @override
  String celautInviteConnected(String address) {
    return 'Connected by $address. The node is in your list.';
  }

  @override
  String get celautInviteFailedTitle => 'Could not connect to the invited node';

  @override
  String get celautInviteNoAddress =>
      'The invitation has no address that this app can use.';

  @override
  String get celautInviteOnionNeedsProxy =>
      'Not tried. An onion address needs Tor through an external proxy such as Orbot. A direct connection and the Tor client of the app cannot open it.';

  @override
  String get celautInvitePrivateOverTor =>
      'Not tried. An address on a private network cannot be reached through Tor.';

  @override
  String get serviceInfoTitle => 'Service details';

  @override
  String get serviceInfoLoading => 'Reading the service…';

  @override
  String get serviceInfoReadFailed => 'The service could not be read';

  @override
  String get serviceInfoTruncated =>
      'This service is too large to read from a node, so only what comes first is shown. Load its file to see everything.';

  @override
  String get serviceInfoChatSupported =>
      'It follows the chat convention of Chatui, so it opens as a conversation.';

  @override
  String get serviceInfoChatUnsupported =>
      'Chatui does not support its interface: no port speaks the chat convention (tcp, then http2, grpc and chat above it). It can run, but Chatui cannot open a conversation with it.';

  @override
  String get serviceInfoChatUnknown =>
      'The app could not read the interface of this service, so it cannot tell if it works as a conversation.';

  @override
  String get serviceInfoAbout => 'About';

  @override
  String get serviceInfoNoProse => 'The service gives no description.';

  @override
  String get serviceInfoArchitecture => 'Architecture';

  @override
  String get serviceInfoEntry => 'Starts';

  @override
  String get serviceInfoFilesystem => 'Filesystem';

  @override
  String get serviceInfoConfigFile => 'Configuration file';

  @override
  String get serviceInfoResources => 'Resources';

  @override
  String get serviceInfoAtStart => 'Needs at the start';

  @override
  String get serviceInfoAtMost => 'Can use at most';

  @override
  String get serviceInfoNoResources =>
      'The service does not say what it needs.';

  @override
  String get serviceInfoCoreSpeed => 'Speed of one core';

  @override
  String get serviceInfoInterface => 'Interface';

  @override
  String get serviceInfoNoInterface => 'The service declares no port.';

  @override
  String serviceInfoSlot(int n) {
    return 'Interface $n';
  }

  @override
  String get serviceInfoChatReady => 'Chat ready';

  @override
  String get serviceInfoPricePerCall => 'MU per call';

  @override
  String get serviceInfoNetworks => 'Networks';

  @override
  String get serviceInfoNoNetworks =>
      'The service does not connect to any network.';

  @override
  String get serviceInfoAnyAddress => 'Every address';

  @override
  String serviceInfoPeersSpeak(String protocols) {
    return 'Peers speak: $protocols';
  }

  @override
  String get serviceInfoEnvironment => 'Environment variables';

  @override
  String get serviceInfoNoEnvironment => 'The service declares no variables.';

  @override
  String get serviceInfoMore => 'Other';

  @override
  String get serviceInfoNodeProtocols =>
      'Protocols that it expects from the node';

  @override
  String get serviceInfoWorkloads => 'Instances that it can start';

  @override
  String serviceInfoWorkload(int count) {
    return '$count × instance';
  }

  @override
  String get serviceInfoWorkloadService => 'of a service';

  @override
  String serviceInfoWorkloadsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scenarios are too large to show.',
      one: '1 scenario is too large to show.',
    );
    return '$_temp0';
  }

  @override
  String get celautChatUnsupportedTitle =>
      'Chatui does not support this interface';

  @override
  String get celautChatUnsupportedBody =>
      'This service does not follow the chat convention that Chatui uses, so Chatui cannot open a conversation with it. If you run it, it shows in Compute, and you cannot talk to it from here.';

  @override
  String get celautChatRunAnyway => 'Run anyway';

  @override
  String get celautChatDetails => 'Details';

  @override
  String get celautRunConfirmDetails => 'Service details';

  @override
  String get chatsInfoServiceDetails => 'Service details';

  @override
  String serviceInfoPartsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parts of the service are too large to show.',
      one: '1 part of the service is too large to show.',
    );
    return '$_temp0';
  }

  @override
  String get walletSummaryDetails => 'Wallet details';

  @override
  String get walletSummaryLatest => 'Latest transactions';

  @override
  String get walletSummaryNoTransactions => 'No transactions yet';

  @override
  String get chatSelectText => 'Select text';

  @override
  String celautRunMoreOptions(String count) {
    return 'Show $count more options';
  }

  @override
  String get celautRunFewerOptions => 'Show fewer options';

  @override
  String get celautRunCategoryAll => 'All';

  @override
  String get celautRunOnPhone => 'On this phone';

  @override
  String get celautEnvSensitive => 'Sensitive';

  @override
  String get celautEnvNotSensitive => 'Not sensitive';

  @override
  String get celautEnvSensitiveHint =>
      'A password, a key or a token. Before a sensitive value goes where others can read it, the app warns you.';

  @override
  String get celautEnvMarkSensitive => 'Mark as sensitive';

  @override
  String get celautEnvMarkNotSensitive => 'Mark as not sensitive';

  @override
  String get celautEnvEgressSteers =>
      'This variable sets where the service connects.';

  @override
  String get celautEnvEgressTitle => 'Your sensitive values can leave the node';

  @override
  String celautEnvEgressBody(String exits) {
    return 'This service can connect outside the node, to: $exits. It can send your sensitive values there.';
  }

  @override
  String get celautEnvEgressAnyAddress => 'any address';

  @override
  String get celautEnvNetworksTitle =>
      'The service shares networks on the node';

  @override
  String celautEnvNetworksBody(String networks) {
    return 'This service can connect to other services on the node, in the networks: $networks. It can give them your sensitive values.';
  }

  @override
  String get celautEnvNodesTitle => 'Nodes that you do not fully trust';

  @override
  String celautEnvNodesBody(String nodes) {
    return 'These nodes can start the service, and you did not mark them as fully trusted: $nodes. The node that gets the start reads your sensitive values. To mark a node, go to Compute, Nodes.';
  }

  @override
  String get celautEnvDeny => 'Deny';

  @override
  String get celautEnvRunAnyway => 'Send the values and run';

  @override
  String get celautNodesTrusted => 'Fully trusted';

  @override
  String get celautNodesTrustedHint =>
      'Your node, or a node of family, friends or your company. The app does not warn before it gives this node your sensitive values.';

  @override
  String celautNodesPriority(int value) {
    return 'Priority: $value of 100';
  }

  @override
  String get celautNodesPriorityFullTrust =>
      'Priority: 100 of 100 (full trust)';

  @override
  String get celautNodesPriorityHint =>
      'Your reputation for this node, from 0 to 100 (50 is neutral). When the app compares prices, a higher number favors this node. Full trust is always 100.';

  @override
  String get balancerTitle => 'Balancer weights';

  @override
  String get balancerRowSubtitle =>
      'How the app chooses the node that runs a service';

  @override
  String get balancerIntro =>
      'To choose a node, the app asks each one for a price and gives it a score: the price term plus the terms below, each multiplied by its weight. The node with the highest score goes first. A higher weight makes that term count more; 0 switches it off. A free offer always comes first.';

  @override
  String get balancerPriceName => 'Price';

  @override
  String get balancerPriceDesc =>
      'How much a cheaper quote counts. Each time the price is divided by e (about 2.7), the score rises by this weight.';

  @override
  String get balancerReputationName => 'Local reputation';

  @override
  String get balancerReputationDesc =>
      'What this app learned from its own history with each node. There are no recorded events yet, so this term is 0 for now.';

  @override
  String get balancerOnchainName => 'On-chain reputation';

  @override
  String get balancerOnchainDesc =>
      'The opinion that other publishers record on the blockchain. Not read by the app yet, so this term is 0 for now.';

  @override
  String get balancerDonationName => 'Donations';

  @override
  String get balancerDonationDesc =>
      'A bonus for nodes that donate. Not used by the app yet, so this term is 0 for now.';

  @override
  String get balancerPriorityName => 'Your priority for each node';

  @override
  String get balancerPriorityDesc =>
      'The 0 to 100 priority that you give each node in the node list (50 is neutral, full trust is 100).';

  @override
  String get balancerDefaultLabel => 'Default';

  @override
  String get balancerOffLabel => 'Off';

  @override
  String get balancerReset => 'Restore defaults';

  @override
  String get balancerPresetsLabel => 'Quick setups';

  @override
  String get balancerPresetBalanced => 'Balanced';

  @override
  String get balancerPresetCheapest => 'Cheapest first';

  @override
  String get balancerPresetTrusted => 'My nodes first';

  @override
  String get balancerCustom => 'Custom mix';

  @override
  String get balancerMainTitle => 'What matters to you';

  @override
  String get balancerExampleTitle => 'Try it';

  @override
  String get balancerExampleIntro =>
      'Three example nodes. Move the sliders and watch the order change. Your real nodes follow the same rule.';

  @override
  String get balancerExampleCheap => 'Cheap node';

  @override
  String get balancerExampleTrusted => 'Your trusted node';

  @override
  String get balancerExampleRisky => 'Cheapest, little trust';

  @override
  String get balancerAdvancedTitle => 'Terms without data yet';

  @override
  String get balancerAdvancedNote =>
      'These terms add nothing today because the app does not have their data yet. You can set their weight now for when it does.';

  @override
  String get balancerRestoreTerm => 'Restore';

  @override
  String get balancerScaleLow => 'Ignore';

  @override
  String get balancerScaleHigh => 'Maximum';

  @override
  String get balancerReadingNothing =>
      'With both at 0, nothing separates the nodes.';

  @override
  String get balancerReadingPriceIgnored =>
      'The price is ignored: only your priority decides.';

  @override
  String get balancerReadingPriorityIgnored =>
      'Your priority is ignored: the cheapest node always goes first.';

  @override
  String balancerReadingTradeoff(String factor) {
    return 'A node you fully trust can win against one up to $factor× cheaper.';
  }

  @override
  String balancerExampleDetail(String cost, String priority) {
    return 'Costs $cost× · priority $priority';
  }

  @override
  String balancerExampleFirst(String name) {
    return '$name goes first.';
  }

  @override
  String get celautRunModeTime => 'For a time';

  @override
  String get celautRunModeKeep => 'Until I stop it';

  @override
  String get celautRunButtonKeep => 'Run until stopped';

  @override
  String get celautKeepWarning =>
      'Risk: the app will keep adding time to this instance from your credit on this node until you stop it. If you forget it, it can use all of that credit. It works while the app runs and while there is credit; if the credit runs out, the instance stops.';

  @override
  String get celautKeepLimitLabel => 'Spending limit (optional)';

  @override
  String get celautKeepLimitHint => 'Empty: no limit';

  @override
  String get celautKeepLimitWrong => 'A number of MU above zero.';

  @override
  String celautKeepRate(String rate, String credit, String time) {
    return 'This node charges about $rate per hour. Your credit there is $credit: about $time.';
  }

  @override
  String celautKeepRateOnly(String rate) {
    return 'This node charges about $rate per hour.';
  }

  @override
  String celautKeepCredit(String credit) {
    return 'Your credit on this node is $credit.';
  }

  @override
  String get celautKeepLowCredit =>
      'Your credit there covers only a few hours. Make a deposit first if you want it to run longer.';

  @override
  String get celautKeepBadge => 'Runs until you stop it';

  @override
  String get celautTimeTitle => 'Time and credit';

  @override
  String get celautTimeBalance => 'Balance of the instance';

  @override
  String get celautTimeCredit => 'Your credit on this node';

  @override
  String celautTimeAbout(String time) {
    return 'about $time';
  }

  @override
  String get celautKeepSwitch => 'Keep it running until I stop it';

  @override
  String celautKeepOnNoLimit(String spent) {
    return 'The app adds time by itself while you have credit. Added so far: $spent. No limit.';
  }

  @override
  String celautKeepOnLimit(String spent, String limit) {
    return 'The app adds time by itself while you have credit. Added so far: $spent of $limit.';
  }

  @override
  String get celautKeepOff => 'It stops when its balance runs out.';

  @override
  String get celautKeepEnableTitle => 'Keep it running?';

  @override
  String get celautKeepEnableConfirm => 'Keep running';

  @override
  String get celautAddTime => 'Add time';

  @override
  String get celautAddTimeMinutes => 'Add';

  @override
  String celautAddTimeCost(String cost, String left, String time) {
    return 'It costs $cost. You keep $left on this node: about $time more for this instance.';
  }

  @override
  String celautAddTimeCostOnly(String cost) {
    return 'It costs $cost.';
  }

  @override
  String celautAddTimeNoCredit(String cost, String credit) {
    return 'It costs $cost, and your credit on this node is $credit. Make a deposit to add this time.';
  }

  @override
  String get celautAddTimeConfirm => 'Add';

  @override
  String get celautAddTimeDone => 'Time added.';

  @override
  String celautKeepNeed(String node) {
    return 'Keep running: your credit on $node is too low to add time to an instance. Make a deposit to keep it running.';
  }

  @override
  String celautKeepNeedBudget(String node) {
    return 'An instance on $node reached the spending limit that you set. It stops when its balance runs out. Turn \"keep it running\" off and on again on its info page to set a new limit.';
  }

  @override
  String get celautTopUpRow =>
      'When to add time to the instances that you keep running';

  @override
  String get celautTopUpIntro =>
      'For the instances that you keep running until you stop them (set it when you run one, or on its info page). The app adds time from your credit on their node; it never makes a deposit by itself.';

  @override
  String get celautTopUpSaved => 'Saved.';

  @override
  String get chatsGroupsMenu => 'Groups';

  @override
  String get chatsGroupsViewGrouped => 'Show in groups';

  @override
  String get chatsGroupsViewFlat => 'Show as one list';

  @override
  String get chatsGroupsNew => 'New group';

  @override
  String get chatsGroupsNameLabel => 'Group name';

  @override
  String get chatsGroupsRename => 'Rename group';

  @override
  String get chatsGroupsDelete => 'Delete group';

  @override
  String chatsGroupsDeleteTitle(String name) {
    return 'Delete group $name?';
  }

  @override
  String get chatsGroupsDeleteBody =>
      'The conversations in it are not deleted: they go back to the list with no group.';

  @override
  String get chatsGroupsMove => 'Move to a group';

  @override
  String get chatsGroupsNone => 'Remove from its group';

  @override
  String get chatsGroupsUngrouped => 'No group';

  @override
  String get chatSettingsListGroup => 'Chat list';

  @override
  String get chatSettingsGroupedView => 'Organize in groups';

  @override
  String get chatSettingsGroupedViewSubtitle =>
      'Off: one flat list. On: collapsible groups. Long-press a conversation to move it to a group.';

  @override
  String get celautEnvAskSave => 'Save in my variables';

  @override
  String celautEnvAskSaveHint(String name) {
    return 'Saved as $name, with the mark above.';
  }

  @override
  String celautEnvAskSaveReplaces(String name) {
    return 'Replaces the value that you saved as $name.';
  }

  @override
  String get celautEnvSaveFailed =>
      'The value was not saved in your variables.';

  @override
  String get celautSecretAskTitle => 'Secret for the service';

  @override
  String get celautSecretReviewNote =>
      'The service and the node of this instance read the value. The value is not kept in the conversation.';

  @override
  String get celautSecretSend => 'Send';

  @override
  String get celautSecretSendAnyway => 'Send the value';

  @override
  String chatSecretCardTitle(String name) {
    return 'The service asks for $name';
  }

  @override
  String get chatSecretAnswer => 'Choose a value';

  @override
  String get chatSecretSent => 'Sent';

  @override
  String get chatSecretSkipped => 'Skipped';

  @override
  String get chatSecretFailed =>
      'The answer did not reach the service. Try again.';

  @override
  String chatSecretMissing(String name) {
    return '$name is not in your variables any more.';
  }

  @override
  String get btcTitle => 'Bitcoin';

  @override
  String get btcRefresh => 'Read again';

  @override
  String get btcLocked => 'Unlock the wallet to open the Bitcoin wallet.';

  @override
  String get btcUnlock => 'Unlock';

  @override
  String btcTestNetwork(String network) {
    return '$network: a test network. These coins have no value.';
  }

  @override
  String get btcMainnetNote =>
      'Mainnet: real bitcoin. A send cannot be undone.';

  @override
  String get btcConfirmed => 'Confirmed';

  @override
  String btcPending(String amount) {
    return '$amount BTC not confirmed yet';
  }

  @override
  String btcImmature(String amount) {
    return '$amount BTC mined, not mature yet';
  }

  @override
  String get btcReceive => 'Receive';

  @override
  String get btcSend => 'Send';

  @override
  String get btcDepositAction => 'Deposit to a node';

  @override
  String get btcHistory => 'History';

  @override
  String get btcNoHistory => 'No transactions yet.';

  @override
  String get btcUnconfirmed => 'Not confirmed';

  @override
  String btcConfirmations(String count) {
    return 'Confirmations: $count';
  }

  @override
  String get btcTxCopied => 'Transaction ID copied';

  @override
  String get btcReceiveTitle => 'Receive bitcoin';

  @override
  String btcReceiveNote(String network) {
    return 'Send only $network bitcoin to this address. After it receives, the wallet shows a new address.';
  }

  @override
  String get btcCopyAddress => 'Copy address';

  @override
  String get btcAddressCopied => 'Address copied';

  @override
  String get btcSendTitle => 'Send bitcoin';

  @override
  String get btcSendTo => 'Bitcoin address';

  @override
  String btcSendToInvalid(String network) {
    return 'This is not a Bitcoin address of $network';
  }

  @override
  String get btcSendAmount => 'Amount (BTC)';

  @override
  String get btcSendAmountInvalid =>
      'Type an amount in BTC, with 8 decimals or fewer';

  @override
  String get btcSendAll => 'Send everything';

  @override
  String get btcSendAllHint => 'The fee comes out of the amount';

  @override
  String get btcFeeTitle => 'Fee rate';

  @override
  String btcFeeFast(String rate) {
    return 'Fast · $rate sat/vB';
  }

  @override
  String btcFeeNormal(String rate) {
    return 'About 1 hour · $rate sat/vB';
  }

  @override
  String btcFeeSlow(String rate) {
    return 'About 1 day · $rate sat/vB';
  }

  @override
  String get btcFeeNoEstimate =>
      'The server gives no estimate. The app uses the lowest rate.';

  @override
  String get btcReview => 'Review';

  @override
  String get btcConfirmTitle => 'Send bitcoin?';

  @override
  String get btcRowNetwork => 'Network';

  @override
  String get btcRowAmount => 'Amount';

  @override
  String get btcRowFee => 'Fee';

  @override
  String get btcRowFeeRate => 'Fee rate';

  @override
  String get btcRowChange => 'Change';

  @override
  String get btcRowTotal => 'Total';

  @override
  String get btcSendLabel => 'Sign and send';

  @override
  String btcSent(String txid) {
    return 'Sent: $txid';
  }

  @override
  String get btcConsentNeeded =>
      'The send needs the fingerprint or the screen lock. Nothing was sent.';

  @override
  String get btcErrLocked => 'The wallet is locked. Unlock it first.';

  @override
  String get btcErrFunds => 'There is not enough confirmed bitcoin.';

  @override
  String get btcErrUnreachable =>
      'The Bitcoin server does not answer. Check the network or the server in the Bitcoin settings.';

  @override
  String btcErrOther(String reason) {
    return 'Bitcoin: $reason';
  }

  @override
  String get btcSettingsTitle => 'Bitcoin settings';

  @override
  String get btcNetworkTitle => 'Network';

  @override
  String get btcNetMainnet => 'Mainnet (real bitcoin)';

  @override
  String get btcNetTestnet => 'Testnet (test)';

  @override
  String get btcNetSignet => 'Signet (test)';

  @override
  String get btcNetRegtest => 'Regtest (local test)';

  @override
  String get btcMainnetWarnTitle => 'Use real bitcoin?';

  @override
  String get btcMainnetWarnBody =>
      'On mainnet the coins have value, and a send cannot be undone. The Bitcoin wallet of Chatui is new: use small amounts.';

  @override
  String get btcMainnetWarnOk => 'Use mainnet';

  @override
  String get btcServerTitle => 'Esplora server';

  @override
  String btcServerHint(String url) {
    return 'Empty: $url';
  }

  @override
  String get btcServerNoDefault => 'Regtest has no public server. Type one.';

  @override
  String get btcServerInvalid =>
      'The address must start with https:// or http://';

  @override
  String get btcSave => 'Save';

  @override
  String get btcSeedNote =>
      'The Bitcoin wallet uses the words of your wallet, on the BIP-84 path (native SegWit). Any standard Bitcoin wallet opens the same funds with the same words.';

  @override
  String get btcDepTitle => 'Deposit in BTC';

  @override
  String get btcDepNode => 'Node address (host:port)';

  @override
  String get btcDepNodeInvalid => 'Type the address as host:port';

  @override
  String get btcDepCheck => 'Check';

  @override
  String btcDepNoBtc(String network) {
    return 'This node does not take BTC on $network.';
  }

  @override
  String btcDepNodeNetworks(String networks) {
    return 'It takes BTC on: $networks';
  }

  @override
  String get btcDepPayTo => 'Pays to';

  @override
  String btcDepRate(String mu) {
    return '$mu MU per sat';
  }

  @override
  String btcDepCredit(String mu) {
    return 'Your credit on the node: $mu MU';
  }

  @override
  String btcDepWaitsFor(String count) {
    return 'The node checks the deposit after $count confirmations.';
  }

  @override
  String btcDepWaitsDefault(String count) {
    return 'The node does not say how many confirmations it wants. The app waits for $count before it tells the node.';
  }

  @override
  String get btcDepAmount => 'Amount (sat)';

  @override
  String btcDepAmountInvalid(String min) {
    return 'Type $min sat or more';
  }

  @override
  String get btcDepPrepare => 'Prepare the deposit';

  @override
  String get btcDepConfirmTitle => 'Deposit BTC to the node?';

  @override
  String btcDepConfirmDetail(String count) {
    return 'The deposit token of the node goes in an OP_RETURN output. The app tells the node after $count confirmations. The token expires 6 hours after it was made.';
  }

  @override
  String get btcDepRowNode => 'Node';

  @override
  String get btcDepRowMu => 'Credit';

  @override
  String btcDepWaiting(String have, String need) {
    return 'Confirmations: $have of $need';
  }

  @override
  String get btcDepUnknownTx => 'The server does not know the transaction yet.';

  @override
  String get btcDepTelling => 'Asking the server…';

  @override
  String btcDepAccepted(String mu) {
    return 'The node accepted the deposit. Credit now: $mu MU';
  }

  @override
  String btcDepRefused(String reason) {
    return 'The node refused the deposit: $reason';
  }

  @override
  String get btcDepPendingTitle => 'Deposits that wait';

  @override
  String get btcDepWait => 'Wait';

  @override
  String get btcDepForget => 'Forget';

  @override
  String get btcDepPayInBtc => 'Pay in BTC';

  @override
  String btcDepPayInBtcSubtitle(String network) {
    return 'This node takes BTC on $network';
  }

  @override
  String get btcWalletButton => 'Bitcoin wallet';

  @override
  String get celautEnvShare => 'Share by QR';

  @override
  String celautEnvShareTitle(String name) {
    return 'Share $name';
  }

  @override
  String get celautEnvShareWarn =>
      'Whoever scans this code gets the value in plain text. Show it only to people you trust.';

  @override
  String get celautEnvShareWarnSensitive =>
      'This variable is sensitive. Whoever scans this code gets the value in plain text. Show it only to people you trust, and make sure nobody else sees or records your screen.';

  @override
  String get celautEnvShareTooBig => 'This value is too large for a QR code.';

  @override
  String get celautEnvScan => 'Receive by QR';

  @override
  String get celautEnvAskScan => 'Scan a QR code';

  @override
  String get celautEnvScanNotVariable =>
      'That QR code is not a shared variable.';
}
