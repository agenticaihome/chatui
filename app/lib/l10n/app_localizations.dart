import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Chatui'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy id'**
  String get commonCopyId;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get commonAddress;

  /// No description provided for @commonAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get commonAddresses;

  /// No description provided for @commonAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get commonAddressCopied;

  /// No description provided for @commonMinerFee.
  ///
  /// In en, this message translates to:
  /// **'Miner fee'**
  String get commonMinerFee;

  /// No description provided for @commonWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get commonWallet;

  /// No description provided for @commonThisWallet.
  ///
  /// In en, this message translates to:
  /// **'This wallet'**
  String get commonThisWallet;

  /// No description provided for @commonToken.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get commonToken;

  /// No description provided for @commonTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get commonTokens;

  /// No description provided for @commonContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get commonContacts;

  /// No description provided for @commonSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// No description provided for @commonPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get commonPending;

  /// No description provided for @commonOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get commonOffline;

  /// No description provided for @commonBalanceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Balance unavailable'**
  String get commonBalanceUnavailable;

  /// No description provided for @commonNotAnErgoAddress.
  ///
  /// In en, this message translates to:
  /// **'Not an Ergo address'**
  String get commonNotAnErgoAddress;

  /// No description provided for @monthShort1.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthShort1;

  /// No description provided for @monthShort2.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthShort2;

  /// No description provided for @monthShort3.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthShort3;

  /// No description provided for @monthShort4.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthShort4;

  /// No description provided for @monthShort5.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthShort5;

  /// No description provided for @monthShort6.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthShort6;

  /// No description provided for @monthShort7.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthShort7;

  /// No description provided for @monthShort8.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthShort8;

  /// No description provided for @monthShort9.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthShort9;

  /// No description provided for @monthShort10.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthShort10;

  /// No description provided for @monthShort11.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthShort11;

  /// No description provided for @monthShort12.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthShort12;

  /// A time of day. English uses a 12-hour clock with am or pm; Spanish a 24-hour clock.
  ///
  /// In en, this message translates to:
  /// **'{hour12}:{minute}{space}{period}'**
  String clockTime(
    String hour12,
    String hour24,
    String minute,
    String space,
    String period,
  );

  /// No description provided for @clockAm.
  ///
  /// In en, this message translates to:
  /// **'am'**
  String get clockAm;

  /// No description provided for @clockPm.
  ///
  /// In en, this message translates to:
  /// **'pm'**
  String get clockPm;

  /// No description provided for @dateMonthDay.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}'**
  String dateMonthDay(String month, String day);

  /// No description provided for @dateMonthDayYear.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String dateMonthDayYear(String month, String day, String year);

  /// No description provided for @dateMonthDayTime.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {time}'**
  String dateMonthDayTime(String month, String day, String time);

  /// No description provided for @dateDayMonthYear.
  ///
  /// In en, this message translates to:
  /// **'{day} {month} {year}'**
  String dateDayMonthYear(String month, String day, String year);

  /// No description provided for @dateNumeric.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}/{year}'**
  String dateNumeric(String month, String day, String year);

  /// No description provided for @timeToday.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String timeToday(String time);

  /// No description provided for @timeYesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String timeYesterdayAt(String time);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterday;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}s ago'**
  String timeSecondsAgo(int count);

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String timeDaysAgo(int count);

  /// No description provided for @syncAgeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get syncAgeJustNow;

  /// No description provided for @syncAgeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String syncAgeMinutes(int count);

  /// No description provided for @syncAgeHours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String syncAgeHours(int count);

  /// No description provided for @syncAgeDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String syncAgeDays(int count);

  /// No description provided for @dateUnknownDay.
  ///
  /// In en, this message translates to:
  /// **'Unknown day'**
  String get dateUnknownDay;

  /// No description provided for @celautNodeRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Celaut node'**
  String get celautNodeRowTitle;

  /// No description provided for @celautNodeRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to a node and show its advertisement'**
  String get celautNodeRowSubtitle;

  /// No description provided for @celautScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Celaut node'**
  String get celautScreenTitle;

  /// No description provided for @celautIntro.
  ///
  /// In en, this message translates to:
  /// **'Connect to a Celaut node and check who it is. The app checks the identity in its certificate and the signature of its advertisement. Nothing is started and nothing is paid.'**
  String get celautIntro;

  /// No description provided for @celautAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Node address'**
  String get celautAddressLabel;

  /// No description provided for @celautAddressHint.
  ///
  /// In en, this message translates to:
  /// **'host:port'**
  String get celautAddressHint;

  /// No description provided for @celautExpectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected peer id (optional)'**
  String get celautExpectedLabel;

  /// No description provided for @celautExpectedHint.
  ///
  /// In en, this message translates to:
  /// **'64 hexadecimal characters'**
  String get celautExpectedHint;

  /// No description provided for @celautConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get celautConnect;

  /// No description provided for @celautConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get celautConnecting;

  /// No description provided for @celautIdentityTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get celautIdentityTitle;

  /// No description provided for @celautPeerIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Peer id'**
  String get celautPeerIdLabel;

  /// No description provided for @celautAdvertisedLabel.
  ///
  /// In en, this message translates to:
  /// **'Advertised at'**
  String get celautAdvertisedLabel;

  /// No description provided for @celautUrisTitle.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get celautUrisTitle;

  /// No description provided for @celautRatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Rates'**
  String get celautRatesTitle;

  /// No description provided for @celautContractsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment contracts'**
  String get celautContractsTitle;

  /// No description provided for @celautResourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get celautResourcesTitle;

  /// No description provided for @celautProofsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reputation proofs'**
  String get celautProofsLabel;

  /// No description provided for @celautNoUris.
  ///
  /// In en, this message translates to:
  /// **'The node advertises no address.'**
  String get celautNoUris;

  /// No description provided for @celautNoRates.
  ///
  /// In en, this message translates to:
  /// **'The node advertises no rates.'**
  String get celautNoRates;

  /// No description provided for @celautNoContracts.
  ///
  /// In en, this message translates to:
  /// **'The node advertises no payment contract. It cannot be paid yet.'**
  String get celautNoContracts;

  /// No description provided for @celautNoResources.
  ///
  /// In en, this message translates to:
  /// **'The node gives no data about its resources.'**
  String get celautNoResources;

  /// No description provided for @celautRatesNote.
  ///
  /// In en, this message translates to:
  /// **'Rates are in MU.'**
  String get celautRatesNote;

  /// No description provided for @celautVerifiedNote.
  ///
  /// In en, this message translates to:
  /// **'The certificate and the signature were checked. This node is who it says it is.'**
  String get celautVerifiedNote;

  /// No description provided for @celautAddressEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter the address of the node as host:port.'**
  String get celautAddressEmpty;

  /// No description provided for @celautAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'This address is not valid. Use host:port, for example 203.0.113.7:8090.'**
  String get celautAddressInvalid;

  /// No description provided for @celautPortInvalid.
  ///
  /// In en, this message translates to:
  /// **'The port must be a number from 1 to 65535.'**
  String get celautPortInvalid;

  /// No description provided for @celautExpectedInvalid.
  ///
  /// In en, this message translates to:
  /// **'The peer id must be 64 hexadecimal characters, or empty.'**
  String get celautExpectedInvalid;

  /// No description provided for @celautErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot show this node'**
  String get celautErrorTitle;

  /// No description provided for @celautErrorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'The address is not valid. Check the host and the port.'**
  String get celautErrorInvalidInput;

  /// No description provided for @celautErrorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The app cannot connect to this address. Check the address and the network, and check that the node is running.'**
  String get celautErrorUnreachable;

  /// No description provided for @celautErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The node did not answer in time. Try again, or check the address.'**
  String get celautErrorTimeout;

  /// No description provided for @celautErrorIdentityMismatch.
  ///
  /// In en, this message translates to:
  /// **'The identity of this node is not the one that was expected. The address may now belong to another node. The app did not trust it.'**
  String get celautErrorIdentityMismatch;

  /// No description provided for @celautErrorBadCertificate.
  ///
  /// In en, this message translates to:
  /// **'The certificate of this server has no valid Celaut identity. It may not be a Celaut node. The app did not trust it.'**
  String get celautErrorBadCertificate;

  /// No description provided for @celautErrorBadSignature.
  ///
  /// In en, this message translates to:
  /// **'The signature of the node advertisement is not valid. The app did not trust it.'**
  String get celautErrorBadSignature;

  /// No description provided for @celautErrorStaleTimestamp.
  ///
  /// In en, this message translates to:
  /// **'This advertisement is older than one that the app accepted before. Someone may be replaying an old message. The app did not trust it.'**
  String get celautErrorStaleTimestamp;

  /// No description provided for @celautErrorUnsupportedScheme.
  ///
  /// In en, this message translates to:
  /// **'The node signs with a scheme that this app does not support.'**
  String get celautErrorUnsupportedScheme;

  /// No description provided for @celautErrorProofOfWork.
  ///
  /// In en, this message translates to:
  /// **'The node asks for more work than the app does for a new client, or it did not accept the work.'**
  String get celautErrorProofOfWork;

  /// No description provided for @celautErrorProtocol.
  ///
  /// In en, this message translates to:
  /// **'The node refused the request or sent an answer that the app cannot use.'**
  String get celautErrorProtocol;

  /// No description provided for @celautErrorStorage.
  ///
  /// In en, this message translates to:
  /// **'The app cannot read or write its list of known advertisements.'**
  String get celautErrorStorage;

  /// No description provided for @celautErrorLimitReached.
  ///
  /// In en, this message translates to:
  /// **'This deposit would pass the limit that you set for this node.'**
  String get celautErrorLimitReached;

  /// No description provided for @celautErrorWallet.
  ///
  /// In en, this message translates to:
  /// **'The wallet cannot make this transaction. Check the balance and the network.'**
  String get celautErrorWallet;

  /// No description provided for @celautDetailLabel.
  ///
  /// In en, this message translates to:
  /// **'Detail: {detail}'**
  String celautDetailLabel(String detail);

  /// CPU cores. count is 1 when the value is exactly one, else 2; value is the formatted number.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{value} core} other{{value} cores}}'**
  String celautCores(int count, String value);

  /// No description provided for @celautMemoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get celautMemoryLabel;

  /// No description provided for @celautDiskLabel.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get celautDiskLabel;

  /// No description provided for @celautCpuLabel.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get celautCpuLabel;

  /// No description provided for @celautBenchmarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Benchmark'**
  String get celautBenchmarkLabel;

  /// No description provided for @celautNoExpiry.
  ///
  /// In en, this message translates to:
  /// **'no expiry given'**
  String get celautNoExpiry;

  /// No description provided for @celautExpires.
  ///
  /// In en, this message translates to:
  /// **'valid until {when}'**
  String celautExpires(String when);

  /// No description provided for @celautPerUnit.
  ///
  /// In en, this message translates to:
  /// **'{mu} MU per base unit'**
  String celautPerUnit(String mu);

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// No description provided for @networkTitle.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkTitle;

  /// No description provided for @displayTitle.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get displayTitle;

  /// No description provided for @chatSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatSettingsTitle;

  /// No description provided for @chatSettingsRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Text size, font, pinned messages, widgets'**
  String get chatSettingsRowSubtitle;

  /// No description provided for @chatSettingsTextGroup.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get chatSettingsTextGroup;

  /// No description provided for @chatSettingsFontSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get chatSettingsFontSize;

  /// No description provided for @chatSettingsFontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get chatSettingsFontFamily;

  /// No description provided for @chatSettingsPreview.
  ///
  /// In en, this message translates to:
  /// **'The assistant answer looks like this. Pick the size you read best.'**
  String get chatSettingsPreview;

  /// No description provided for @chatFontSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get chatFontSystem;

  /// No description provided for @chatFontLato.
  ///
  /// In en, this message translates to:
  /// **'Lato'**
  String get chatFontLato;

  /// No description provided for @chatFontSerif.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get chatFontSerif;

  /// No description provided for @chatFontMono.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get chatFontMono;

  /// No description provided for @chatSettingsPinnedGroup.
  ///
  /// In en, this message translates to:
  /// **'Pinned messages'**
  String get chatSettingsPinnedGroup;

  /// No description provided for @chatSettingsPinnedMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum height of a pinned message'**
  String get chatSettingsPinnedMax;

  /// No description provided for @chatSettingsPinnedNote.
  ///
  /// In en, this message translates to:
  /// **'A pinned message stays at the top of the chat. It uses at most this part of the chat height.'**
  String get chatSettingsPinnedNote;

  /// No description provided for @chatSettingsWidgetsGroup.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get chatSettingsWidgetsGroup;

  /// No description provided for @chatHtmlLoading.
  ///
  /// In en, this message translates to:
  /// **'Making the widget…'**
  String get chatHtmlLoading;

  /// No description provided for @chatKeyboardLabel.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get chatKeyboardLabel;

  /// No description provided for @chatKeyboardClose.
  ///
  /// In en, this message translates to:
  /// **'Close the keyboard'**
  String get chatKeyboardClose;

  /// No description provided for @chatSettingsHtmlWidgets.
  ///
  /// In en, this message translates to:
  /// **'HTML widgets'**
  String get chatSettingsHtmlWidgets;

  /// No description provided for @chatSettingsHtmlWidgetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show simple HTML from the assistant as widgets. If off, it shows as code. No scripts and no network.'**
  String get chatSettingsHtmlWidgetsSubtitle;

  /// No description provided for @chatSettingsKeyboardGroup.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get chatSettingsKeyboardGroup;

  /// No description provided for @chatSettingsSystemKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Use the system keyboard'**
  String get chatSettingsSystemKeyboard;

  /// No description provided for @chatSettingsSystemKeyboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If off, the chat types with the keyboard of the app, under the input. If on, the system keyboard shows, except while a form is open.'**
  String get chatSettingsSystemKeyboardSubtitle;

  /// No description provided for @chatSettingsWordSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Word suggestions'**
  String get chatSettingsWordSuggestions;

  /// No description provided for @chatSettingsWordSuggestionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The keyboard of the app shows words that complete or correct the word you write, from the words of the conversation. It never changes a word by itself. The replies that the service suggests show either way.'**
  String get chatSettingsWordSuggestionsSubtitle;

  /// No description provided for @chatSuggestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get chatSuggestionsLabel;

  /// No description provided for @chatVkBackspace.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatVkBackspace;

  /// No description provided for @chatVkShift.
  ///
  /// In en, this message translates to:
  /// **'Capital letter'**
  String get chatVkShift;

  /// No description provided for @chatVkSymbols.
  ///
  /// In en, this message translates to:
  /// **'Numbers and symbols'**
  String get chatVkSymbols;

  /// No description provided for @chatVkLetters.
  ///
  /// In en, this message translates to:
  /// **'Letters'**
  String get chatVkLetters;

  /// No description provided for @chatVkSpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get chatVkSpace;

  /// No description provided for @chatVkEnter.
  ///
  /// In en, this message translates to:
  /// **'New line'**
  String get chatVkEnter;

  /// No description provided for @chatBgNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get chatBgNone;

  /// No description provided for @chatBgDawn.
  ///
  /// In en, this message translates to:
  /// **'Dawn'**
  String get chatBgDawn;

  /// No description provided for @chatBgOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get chatBgOcean;

  /// No description provided for @chatBgForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get chatBgForest;

  /// No description provided for @chatBgDusk.
  ///
  /// In en, this message translates to:
  /// **'Dusk'**
  String get chatBgDusk;

  /// No description provided for @chatBgDots.
  ///
  /// In en, this message translates to:
  /// **'Dots'**
  String get chatBgDots;

  /// No description provided for @chatBgWaves.
  ///
  /// In en, this message translates to:
  /// **'Waves'**
  String get chatBgWaves;

  /// No description provided for @chatBgDiamonds.
  ///
  /// In en, this message translates to:
  /// **'Diamonds'**
  String get chatBgDiamonds;

  /// No description provided for @addressBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Address book'**
  String get addressBookTitle;

  /// No description provided for @settingsAboutRowTitle.
  ///
  /// In en, this message translates to:
  /// **'About Chatui'**
  String get settingsAboutRowTitle;

  /// No description provided for @settingsAboutRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version, release notes, licenses'**
  String get settingsAboutRowSubtitle;

  /// No description provided for @settingsWalletRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Addresses and backup'**
  String get settingsWalletRowTitle;

  /// No description provided for @settingsWalletRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Primary address, change policy, remove'**
  String get settingsWalletRowSubtitle;

  /// No description provided for @settingsSecurityWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Phone unlock, auto-lock'**
  String get settingsSecurityWalletSubtitle;

  /// No description provided for @settingsErgoGroup.
  ///
  /// In en, this message translates to:
  /// **'Ergo'**
  String get settingsErgoGroup;

  /// No description provided for @settingsComputeGroup.
  ///
  /// In en, this message translates to:
  /// **'Compute'**
  String get settingsComputeGroup;

  /// No description provided for @settingsGeneralGroup.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneralGroup;

  /// No description provided for @settingsScopeAppWide.
  ///
  /// In en, this message translates to:
  /// **'App-wide'**
  String get settingsScopeAppWide;

  /// No description provided for @settingsSecurityAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock, screenshots, unconfirmed funds'**
  String get settingsSecurityAppSubtitle;

  /// No description provided for @settingsRemotePreviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote previews'**
  String get settingsRemotePreviewsTitle;

  /// No description provided for @settingsRemotePreviewsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'IPFS gateway and Never load remote previews'**
  String get settingsRemotePreviewsSubtitle;

  /// No description provided for @settingsContactsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} contacts}}'**
  String settingsContactsCount(int count);

  /// No description provided for @settingsUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get settingsUnlocked;

  /// No description provided for @settingsLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get settingsLocked;

  /// No description provided for @aboutSaveSettingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the setting.'**
  String get aboutSaveSettingFailed;

  /// No description provided for @aboutAskingGithub.
  ///
  /// In en, this message translates to:
  /// **'Asking GitHub…'**
  String get aboutAskingGithub;

  /// No description provided for @aboutNotCheckedYet.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get aboutNotCheckedYet;

  /// No description provided for @aboutUpToDateChecked.
  ///
  /// In en, this message translates to:
  /// **'Up to date · checked {when}'**
  String aboutUpToDateChecked(String when);

  /// No description provided for @aboutVersionAvailableChecked.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available · checked {when}'**
  String aboutVersionAvailableChecked(String version, String when);

  /// No description provided for @aboutVersionBuild.
  ///
  /// In en, this message translates to:
  /// **'{version} · build {build}'**
  String aboutVersionBuild(String version, String build);

  /// No description provided for @aboutUpdatesGroup.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get aboutUpdatesGroup;

  /// No description provided for @aboutCheckForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get aboutCheckForUpdates;

  /// No description provided for @aboutCheckForUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Asks GitHub once a day. GitHub sees your IP address, or a Tor exit when Tor is on.'**
  String get aboutCheckForUpdatesSubtitle;

  /// No description provided for @aboutCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get aboutCheckNow;

  /// No description provided for @aboutUpdatesNote.
  ///
  /// In en, this message translates to:
  /// **'Off by default. When on, Chatui asks api.github.com for the latest release once a day as it starts. \"Check now\" does the same on request, even with this off. Nothing else is sent: no account, token, app version or device identifier. A download comes from github.com and is checked against this app\'s signing key before Android is asked to install it.'**
  String get aboutUpdatesNote;

  /// No description provided for @aboutThisBuild.
  ///
  /// In en, this message translates to:
  /// **'This build'**
  String get aboutThisBuild;

  /// No description provided for @aboutUnauditedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unaudited prototype'**
  String get aboutUnauditedTitle;

  /// No description provided for @aboutUnauditedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions on Ergo are irreversible. Use only funds you can afford to lose.'**
  String get aboutUnauditedSubtitle;

  /// No description provided for @aboutReleasesTitle.
  ///
  /// In en, this message translates to:
  /// **'Releases and notes'**
  String get aboutReleasesTitle;

  /// No description provided for @aboutReleasesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What changed in each alpha, and the latest APK.'**
  String get aboutReleasesSubtitle;

  /// No description provided for @aboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutLicenses;

  /// No description provided for @aboutLightClientNote.
  ///
  /// In en, this message translates to:
  /// **'Chatui is a light client: it talks to public Ergo nodes over HTTPS and never sends your keys anywhere.'**
  String get aboutLightClientNote;

  /// No description provided for @aboutSigningCertificate.
  ///
  /// In en, this message translates to:
  /// **'Signing certificate'**
  String get aboutSigningCertificate;

  /// No description provided for @aboutSigningCertificateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 of the key this build is signed with. An update must be signed with the same one.'**
  String get aboutSigningCertificateSubtitle;

  /// No description provided for @aboutReading.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get aboutReading;

  /// No description provided for @aboutNotAvailableOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device.'**
  String get aboutNotAvailableOnDevice;

  /// No description provided for @aboutFingerprintCopied.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint copied'**
  String get aboutFingerprintCopied;

  /// No description provided for @addressBookContactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'People you send to. Save one from the Send screen.'**
  String get addressBookContactsEmpty;

  /// No description provided for @addressBookContactsSaved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} saved}}'**
  String addressBookContactsSaved(int count);

  /// No description provided for @addressBookLabelsSection.
  ///
  /// In en, this message translates to:
  /// **'Labels for my addresses'**
  String get addressBookLabelsSection;

  /// No description provided for @addressBookNoLabelsTitle.
  ///
  /// In en, this message translates to:
  /// **'No labels yet'**
  String get addressBookNoLabelsTitle;

  /// No description provided for @addressBookNoLabelsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap any of your addresses on the home or Receive screen to name it.'**
  String get addressBookNoLabelsBody;

  /// No description provided for @addressBookRemoveLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove label'**
  String get addressBookRemoveLabel;

  /// No description provided for @displayAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get displayAppearance;

  /// No description provided for @displayFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get displayFollowSystem;

  /// No description provided for @displayAlwaysDark.
  ///
  /// In en, this message translates to:
  /// **'Always dark'**
  String get displayAlwaysDark;

  /// No description provided for @displayAlwaysLight.
  ///
  /// In en, this message translates to:
  /// **'Always light'**
  String get displayAlwaysLight;

  /// No description provided for @displaySystemPalettes.
  ///
  /// In en, this message translates to:
  /// **'Dark → {dark}, light → {light}'**
  String displaySystemPalettes(String dark, String light);

  /// No description provided for @displayDarkPalette.
  ///
  /// In en, this message translates to:
  /// **'Dark palette'**
  String get displayDarkPalette;

  /// No description provided for @displayLightPalette.
  ///
  /// In en, this message translates to:
  /// **'Light palette'**
  String get displayLightPalette;

  /// No description provided for @displayMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get displayMoney;

  /// No description provided for @displayPricesInUsd.
  ///
  /// In en, this message translates to:
  /// **'Prices in USD'**
  String get displayPricesInUsd;

  /// No description provided for @displayHideBalances.
  ///
  /// In en, this message translates to:
  /// **'Hide balances'**
  String get displayHideBalances;

  /// No description provided for @displayHideBalancesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mask amounts on the home screen'**
  String get displayHideBalancesSubtitle;

  /// No description provided for @displayVehicleMotionCues.
  ///
  /// In en, this message translates to:
  /// **'Vehicle motion cues'**
  String get displayVehicleMotionCues;

  /// No description provided for @displayVehicleMotionCuesNote.
  ///
  /// In en, this message translates to:
  /// **'Dots at the sides of the screen move with the car, bus or train, so reading on the road makes you less sick.'**
  String get displayVehicleMotionCuesNote;

  /// No description provided for @displayMotionCuesOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get displayMotionCuesOff;

  /// No description provided for @displayMotionCuesAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get displayMotionCuesAutomatic;

  /// No description provided for @displayMotionCuesAutomaticSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When the phone feels that you ride a vehicle'**
  String get displayMotionCuesAutomaticSubtitle;

  /// No description provided for @displayMotionCuesAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get displayMotionCuesAlways;

  /// No description provided for @displayMotionCuesAlwaysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All the time'**
  String get displayMotionCuesAlwaysSubtitle;

  /// No description provided for @displayMotionCuesGps.
  ///
  /// In en, this message translates to:
  /// **'Use the speed of the GPS'**
  String get displayMotionCuesGps;

  /// No description provided for @displayMotionCuesGpsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tells a vehicle from a walk better. Needs the precise location; the app keeps no position and sends nothing'**
  String get displayMotionCuesGpsSubtitle;

  /// No description provided for @displayMotionCuesGpsDenied.
  ///
  /// In en, this message translates to:
  /// **'Without the precise location the app cannot read the speed of the GPS'**
  String get displayMotionCuesGpsDenied;

  /// No description provided for @themeTealName.
  ///
  /// In en, this message translates to:
  /// **'Celaut Teal'**
  String get themeTealName;

  /// No description provided for @themeTealHint.
  ///
  /// In en, this message translates to:
  /// **'Teal, cream type, coral'**
  String get themeTealHint;

  /// No description provided for @themeCreamName.
  ///
  /// In en, this message translates to:
  /// **'Celaut Cream'**
  String get themeCreamName;

  /// No description provided for @themeCreamHint.
  ///
  /// In en, this message translates to:
  /// **'Cream, teal type, coral'**
  String get themeCreamHint;

  /// No description provided for @themeObsidianName.
  ///
  /// In en, this message translates to:
  /// **'Obsidian'**
  String get themeObsidianName;

  /// No description provided for @themeObsidianHint.
  ///
  /// In en, this message translates to:
  /// **'True black, steel accent'**
  String get themeObsidianHint;

  /// No description provided for @themeHarborName.
  ///
  /// In en, this message translates to:
  /// **'Harbor'**
  String get themeHarborName;

  /// No description provided for @themeHarborHint.
  ///
  /// In en, this message translates to:
  /// **'Deep navy, teal accent'**
  String get themeHarborHint;

  /// No description provided for @themeEmberName.
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get themeEmberName;

  /// No description provided for @themeEmberHint.
  ///
  /// In en, this message translates to:
  /// **'Warm charcoal, copper accent'**
  String get themeEmberHint;

  /// No description provided for @themeParchmentName.
  ///
  /// In en, this message translates to:
  /// **'Parchment'**
  String get themeParchmentName;

  /// No description provided for @themeParchmentHint.
  ///
  /// In en, this message translates to:
  /// **'Cream, sage accent'**
  String get themeParchmentHint;

  /// No description provided for @themeFrostName.
  ///
  /// In en, this message translates to:
  /// **'Frost'**
  String get themeFrostName;

  /// No description provided for @themeFrostHint.
  ///
  /// In en, this message translates to:
  /// **'Cool white, slate-blue accent'**
  String get themeFrostHint;

  /// No description provided for @themeCyberpunkName.
  ///
  /// In en, this message translates to:
  /// **'Cyberpunk'**
  String get themeCyberpunkName;

  /// No description provided for @themeCyberpunkHint.
  ///
  /// In en, this message translates to:
  /// **'Night violet, neon pink'**
  String get themeCyberpunkHint;

  /// No description provided for @themeAppleLightName.
  ///
  /// In en, this message translates to:
  /// **'Apple Light'**
  String get themeAppleLightName;

  /// No description provided for @themeAppleLightHint.
  ///
  /// In en, this message translates to:
  /// **'Clean white, system blue'**
  String get themeAppleLightHint;

  /// No description provided for @themeAppleDarkName.
  ///
  /// In en, this message translates to:
  /// **'Apple Dark'**
  String get themeAppleDarkName;

  /// No description provided for @themeAppleDarkHint.
  ///
  /// In en, this message translates to:
  /// **'True black, system blue'**
  String get themeAppleDarkHint;

  /// No description provided for @themeMaterialLightName.
  ///
  /// In en, this message translates to:
  /// **'Material Light'**
  String get themeMaterialLightName;

  /// No description provided for @themeMaterialLightHint.
  ///
  /// In en, this message translates to:
  /// **'Soft lilac, Material purple'**
  String get themeMaterialLightHint;

  /// No description provided for @themeMaterialDarkName.
  ///
  /// In en, this message translates to:
  /// **'Material Dark'**
  String get themeMaterialDarkName;

  /// No description provided for @themeMaterialDarkHint.
  ///
  /// In en, this message translates to:
  /// **'Dark grey, lilac accent'**
  String get themeMaterialDarkHint;

  /// No description provided for @themeNordName.
  ///
  /// In en, this message translates to:
  /// **'Nord'**
  String get themeNordName;

  /// No description provided for @themeNordHint.
  ///
  /// In en, this message translates to:
  /// **'Arctic slate, ice blue'**
  String get themeNordHint;

  /// No description provided for @themeSolarizedName.
  ///
  /// In en, this message translates to:
  /// **'Solarized'**
  String get themeSolarizedName;

  /// No description provided for @themeSolarizedHint.
  ///
  /// In en, this message translates to:
  /// **'Warm paper, blue accent'**
  String get themeSolarizedHint;

  /// No description provided for @themeDraculaName.
  ///
  /// In en, this message translates to:
  /// **'Dracula'**
  String get themeDraculaName;

  /// No description provided for @themeDraculaHint.
  ///
  /// In en, this message translates to:
  /// **'Deep indigo, purple accent'**
  String get themeDraculaHint;

  /// No description provided for @networkConnectedNode.
  ///
  /// In en, this message translates to:
  /// **'Connected node'**
  String get networkConnectedNode;

  /// No description provided for @networkChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get networkChecking;

  /// No description provided for @networkCheckNodes.
  ///
  /// In en, this message translates to:
  /// **'Check nodes'**
  String get networkCheckNodes;

  /// No description provided for @networkNodes.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get networkNodes;

  /// No description provided for @networkAddNodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Add node URL'**
  String get networkAddNodeLabel;

  /// No description provided for @networkAddNodeHint.
  ///
  /// In en, this message translates to:
  /// **'https://host  or  1.2.3.4:9053'**
  String get networkAddNodeHint;

  /// No description provided for @networkAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get networkAdd;

  /// No description provided for @networkNodesNote.
  ///
  /// In en, this message translates to:
  /// **'Tap a node to use it. Automatic picks the reachable node with extraIndex and the smallest index lag. Built-in nodes are HTTPS; you can add http://ip:port for a node you run or trust, unencrypted.'**
  String get networkNodesNote;

  /// No description provided for @networkFindMoreNodes.
  ///
  /// In en, this message translates to:
  /// **'Find more nodes'**
  String get networkFindMoreNodes;

  /// No description provided for @networkDiscovering.
  ///
  /// In en, this message translates to:
  /// **'Asking every node for its peers and checking each…'**
  String get networkDiscovering;

  /// No description provided for @networkDiscoverIntro.
  ///
  /// In en, this message translates to:
  /// **'Peers of your nodes that publish an HTTPS API.'**
  String get networkDiscoverIntro;

  /// No description provided for @networkSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get networkSearching;

  /// No description provided for @networkSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get networkSearch;

  /// No description provided for @networkOpenInExplorer.
  ///
  /// In en, this message translates to:
  /// **'Open in explorer'**
  String get networkOpenInExplorer;

  /// No description provided for @networkCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get networkCustom;

  /// No description provided for @networkCustomSiteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A website using the Ergo Platform explorer paths'**
  String get networkCustomSiteSubtitle;

  /// No description provided for @networkExplorerWebsite.
  ///
  /// In en, this message translates to:
  /// **'Explorer website'**
  String get networkExplorerWebsite;

  /// No description provided for @networkExplorerSiteNote.
  ///
  /// In en, this message translates to:
  /// **'Where transaction and token links open. This changes no data the wallet reads.'**
  String get networkExplorerSiteNote;

  /// No description provided for @networkExplorerApi.
  ///
  /// In en, this message translates to:
  /// **'Explorer API'**
  String get networkExplorerApi;

  /// No description provided for @networkCustomApiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Any server speaking the Ergo Platform explorer API'**
  String get networkCustomApiSubtitle;

  /// No description provided for @networkExplorerApiUrl.
  ///
  /// In en, this message translates to:
  /// **'Explorer API URL'**
  String get networkExplorerApiUrl;

  /// No description provided for @networkExplorerApiNote.
  ///
  /// In en, this message translates to:
  /// **'The data source for token metadata when nodes lack it. ErgExplorer and Kadia use their own APIs, so they cannot be chosen here.'**
  String get networkExplorerApiNote;

  /// No description provided for @networkAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get networkAutomatic;

  /// No description provided for @networkBestReachable.
  ///
  /// In en, this message translates to:
  /// **'Best reachable extraIndex node'**
  String get networkBestReachable;

  /// No description provided for @networkUsingHost.
  ///
  /// In en, this message translates to:
  /// **'Using {host}'**
  String networkUsingHost(String host);

  /// No description provided for @networkExtraIndexLag.
  ///
  /// In en, this message translates to:
  /// **'extraIndex, lag {lag}'**
  String networkExtraIndexLag(String lag);

  /// No description provided for @networkNoExtraIndex.
  ///
  /// In en, this message translates to:
  /// **'no extraIndex'**
  String get networkNoExtraIndex;

  /// No description provided for @networkDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get networkDisable;

  /// No description provided for @networkEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get networkEnable;

  /// No description provided for @networkNodeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get networkNodeOff;

  /// No description provided for @networkNodeInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get networkNodeInUse;

  /// No description provided for @networkNodeStandby.
  ///
  /// In en, this message translates to:
  /// **'Standby'**
  String get networkNodeStandby;

  /// No description provided for @networkNodeChosen.
  ///
  /// In en, this message translates to:
  /// **'chosen'**
  String get networkNodeChosen;

  /// No description provided for @networkNodeUnreachable.
  ///
  /// In en, this message translates to:
  /// **'unreachable'**
  String get networkNodeUnreachable;

  /// No description provided for @networkAddNodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter https://host or http://ip:port'**
  String get networkAddNodeInvalid;

  /// No description provided for @networkNodeAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Node already added'**
  String get networkNodeAlreadyAdded;

  /// No description provided for @networkSearchNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No node answered the peer request. Check your connection, or try another node.'**
  String get networkSearchNoAnswer;

  /// No description provided for @networkSearchNoNewApi.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Asked {count} node: their peers publish no HTTPS API you do not already have.} other{Asked {count} nodes: their peers publish no HTTPS API you do not already have.}}'**
  String networkSearchNoNewApi(int count);

  /// No description provided for @networkSearchNoneReachable.
  ///
  /// In en, this message translates to:
  /// **'Checked {found} found, none reachable right now.'**
  String networkSearchNoneReachable(String found);

  /// No description provided for @networkSearchNoneReachablePartial.
  ///
  /// In en, this message translates to:
  /// **'Checked {checked} of {found} found, none reachable right now.'**
  String networkSearchNoneReachablePartial(String checked, String found);

  /// No description provided for @networkSearchReachable.
  ///
  /// In en, this message translates to:
  /// **'{reachable} reachable of {found} found, best first.'**
  String networkSearchReachable(String reachable, String found);

  /// No description provided for @networkSearchReachablePartial.
  ///
  /// In en, this message translates to:
  /// **'{reachable} reachable of {checked} of {found} found, best first.'**
  String networkSearchReachablePartial(
    String reachable,
    String checked,
    String found,
  );

  /// No description provided for @pinHelper.
  ///
  /// In en, this message translates to:
  /// **'6–32 characters. Number pad first.'**
  String get pinHelper;

  /// No description provided for @pinConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirm;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get pinMismatch;

  /// No description provided for @pinIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get pinIncorrect;

  /// No description provided for @securityBiometricDisabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock disabled'**
  String get securityBiometricDisabled;

  /// No description provided for @securityBiometricDisableFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not disable biometrics'**
  String get securityBiometricDisableFailed;

  /// No description provided for @securityPinLockoutCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check PIN lockout'**
  String get securityPinLockoutCheckFailed;

  /// No description provided for @securityNoPinWalletFound.
  ///
  /// In en, this message translates to:
  /// **'No PIN-protected wallet found.'**
  String get securityNoPinWalletFound;

  /// No description provided for @securityBiometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock enabled'**
  String get securityBiometricEnabled;

  /// No description provided for @securityBiometricEnableFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not enable biometrics'**
  String get securityBiometricEnableFailed;

  /// No description provided for @securityChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get securityChangePin;

  /// No description provided for @securityNewPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get securityNewPin;

  /// No description provided for @securityChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get securityChange;

  /// No description provided for @securityNoPinWallet.
  ///
  /// In en, this message translates to:
  /// **'No PIN-protected wallet found'**
  String get securityNoPinWallet;

  /// No description provided for @securityPinChanged.
  ///
  /// In en, this message translates to:
  /// **'PIN changed'**
  String get securityPinChanged;

  /// No description provided for @securityPinChangedLockoutNotReset.
  ///
  /// In en, this message translates to:
  /// **'PIN changed but lockout state could not be reset'**
  String get securityPinChangedLockoutNotReset;

  /// No description provided for @securityChangePinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change PIN'**
  String get securityChangePinFailed;

  /// No description provided for @securityLockImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get securityLockImmediately;

  /// No description provided for @securityLockAfterSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{After {count} seconds}}'**
  String securityLockAfterSeconds(int count);

  /// No description provided for @securityLockAfterMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{After {count} minute} other{After {count} minutes}}'**
  String securityLockAfterMinutes(int count);

  /// No description provided for @securityLockWhenBackgrounded.
  ///
  /// In en, this message translates to:
  /// **'Lock when backgrounded'**
  String get securityLockWhenBackgrounded;

  /// No description provided for @securityAutoLockUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update auto-lock'**
  String get securityAutoLockUpdateFailed;

  /// No description provided for @securityAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get securityAutoLock;

  /// No description provided for @securityUnlockGroup.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get securityUnlockGroup;

  /// No description provided for @securityUnlockFirst.
  ///
  /// In en, this message translates to:
  /// **'Unlock the wallet first'**
  String get securityUnlockFirst;

  /// No description provided for @securityUnlockFirstSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric and PIN settings need an unlocked wallet.'**
  String get securityUnlockFirstSubtitle;

  /// No description provided for @securityRetryUnlockSettings.
  ///
  /// In en, this message translates to:
  /// **'Retry unlock settings'**
  String get securityRetryUnlockSettings;

  /// No description provided for @securityReadSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the current setup.'**
  String get securityReadSetupFailed;

  /// No description provided for @securityBiometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with your phone'**
  String get securityBiometricUnlock;

  /// No description provided for @securityBiometricOn.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint or screen lock'**
  String get securityBiometricOn;

  /// No description provided for @securityOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get securityOff;

  /// No description provided for @securitySetPinHint.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN when you create or restore a wallet.'**
  String get securitySetPinHint;

  /// No description provided for @securityDeviceLockNote.
  ///
  /// In en, this message translates to:
  /// **'The wallet opens with your fingerprint or the screen lock of your phone. The app has no PIN of its own.'**
  String get securityDeviceLockNote;

  /// No description provided for @securityScreen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get securityScreen;

  /// No description provided for @securityBlockScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Block screenshots'**
  String get securityBlockScreenshots;

  /// No description provided for @securityScreenshotsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Screens cannot be captured or recorded'**
  String get securityScreenshotsBlocked;

  /// No description provided for @securityScreenshotsAllowed.
  ///
  /// In en, this message translates to:
  /// **'Off: you can capture screens to report issues'**
  String get securityScreenshotsAllowed;

  /// No description provided for @securitySeedScreensNote.
  ///
  /// In en, this message translates to:
  /// **'Seed phrase screens always block capture, whatever this setting says.'**
  String get securitySeedScreensNote;

  /// No description provided for @securitySpending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get securitySpending;

  /// No description provided for @securitySpendUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Spend unconfirmed funds'**
  String get securitySpendUnconfirmed;

  /// No description provided for @securitySpendUnconfirmedOn.
  ///
  /// In en, this message translates to:
  /// **'On: received funds and change can be spent at once'**
  String get securitySpendUnconfirmedOn;

  /// No description provided for @securitySpendUnconfirmedOff.
  ///
  /// In en, this message translates to:
  /// **'Off: received funds and change wait for 1 confirmation'**
  String get securitySpendUnconfirmedOff;

  /// No description provided for @securitySpendingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the spending setting'**
  String get securitySpendingSaveFailed;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateCardVersion.
  ///
  /// In en, this message translates to:
  /// **'Chatui {version}'**
  String updateCardVersion(String version);

  /// No description provided for @updateCardVersionDate.
  ///
  /// In en, this message translates to:
  /// **'Chatui {version} · {date}'**
  String updateCardVersionDate(String version, String date);

  /// No description provided for @updateHideNotes.
  ///
  /// In en, this message translates to:
  /// **'Hide release notes'**
  String get updateHideNotes;

  /// No description provided for @updateReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get updateReleaseNotes;

  /// No description provided for @updateDownloadProgress.
  ///
  /// In en, this message translates to:
  /// **'Download progress'**
  String get updateDownloadProgress;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get updateDownloading;

  /// No description provided for @updateDownloadingOf.
  ///
  /// In en, this message translates to:
  /// **'Downloading {done} of {total}'**
  String updateDownloadingOf(String done, String total);

  /// No description provided for @updateCheckingDownload.
  ///
  /// In en, this message translates to:
  /// **'Checking the download'**
  String get updateCheckingDownload;

  /// No description provided for @updateCheckingAgainstKey.
  ///
  /// In en, this message translates to:
  /// **'Checking the download against this app\'s signing key…'**
  String get updateCheckingAgainstKey;

  /// No description provided for @updateCertMatches.
  ///
  /// In en, this message translates to:
  /// **'The signing certificate matches this app.'**
  String get updateCertMatches;

  /// No description provided for @updateCertMatchesWith.
  ///
  /// In en, this message translates to:
  /// **'The signing certificate matches this app (SHA-256 {fingerprint}…).'**
  String updateCertMatchesWith(String fingerprint);

  /// No description provided for @updateAndroidChecksSignature.
  ///
  /// In en, this message translates to:
  /// **'Android checks the signature itself when it installs.'**
  String get updateAndroidChecksSignature;

  /// No description provided for @updateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get updateInstall;

  /// No description provided for @updateTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get updateTryAgain;

  /// No description provided for @updateDownloadAndVerify.
  ///
  /// In en, this message translates to:
  /// **'Download and verify'**
  String get updateDownloadAndVerify;

  /// No description provided for @updateAssetNote.
  ///
  /// In en, this message translates to:
  /// **'{name} · {size}. Before anything is installed, Chatui checks the file against the checksum GitHub lists and against the key this app is signed with.'**
  String updateAssetNote(String name, String size);

  /// No description provided for @updateOpenReleasesPage.
  ///
  /// In en, this message translates to:
  /// **'Open the releases page'**
  String get updateOpenReleasesPage;

  /// No description provided for @updateNoApkForPhone.
  ///
  /// In en, this message translates to:
  /// **'This release has no APK for your phone.'**
  String get updateNoApkForPhone;

  /// No description provided for @updateNoticeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Chatui {version} is available.'**
  String updateNoticeAvailable(String version);

  /// No description provided for @updateNoticeView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get updateNoticeView;

  /// No description provided for @updateNoticeDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get updateNoticeDismiss;

  /// No description provided for @updateErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'GitHub did not answer in time.'**
  String get updateErrorTimeout;

  /// No description provided for @updateErrorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach GitHub. Check your connection.'**
  String get updateErrorUnreachable;

  /// No description provided for @updateErrorRouteBlocked.
  ///
  /// In en, this message translates to:
  /// **'Tor is on and not ready, so the app does not connect to GitHub. Try again when Tor is ready (Settings, Developer, Tor).'**
  String get updateErrorRouteBlocked;

  /// No description provided for @updateErrorStatus.
  ///
  /// In en, this message translates to:
  /// **'GitHub answered with an error ({status}).'**
  String updateErrorStatus(String status);

  /// No description provided for @updateErrorBadRedirect.
  ///
  /// In en, this message translates to:
  /// **'GitHub sent a redirect that was not understood.'**
  String get updateErrorBadRedirect;

  /// No description provided for @updateErrorRedirectedAway.
  ///
  /// In en, this message translates to:
  /// **'The request was redirected away from GitHub, so it was stopped.'**
  String get updateErrorRedirectedAway;

  /// No description provided for @updateErrorTooManyRedirects.
  ///
  /// In en, this message translates to:
  /// **'GitHub redirected the request too many times.'**
  String get updateErrorTooManyRedirects;

  /// No description provided for @updateErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'GitHub is limiting requests from this network. Try again later.'**
  String get updateErrorRateLimited;

  /// No description provided for @updateErrorNoRelease.
  ///
  /// In en, this message translates to:
  /// **'GitHub has no release to offer.'**
  String get updateErrorNoRelease;

  /// No description provided for @updateErrorNotUnderstood.
  ///
  /// In en, this message translates to:
  /// **'GitHub\'s answer was not understood.'**
  String get updateErrorNotUnderstood;

  /// No description provided for @updateErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'GitHub\'s answer was larger than expected.'**
  String get updateErrorTooLarge;

  /// No description provided for @updateErrorNotOnGithub.
  ///
  /// In en, this message translates to:
  /// **'The download address is not on GitHub.'**
  String get updateErrorNotOnGithub;

  /// No description provided for @updateErrorDownloadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The download is larger than Chatui will accept.'**
  String get updateErrorDownloadTooLarge;

  /// No description provided for @updateErrorStorage.
  ///
  /// In en, this message translates to:
  /// **'Chatui could not save the download. Is the phone out of storage?'**
  String get updateErrorStorage;

  /// No description provided for @updateErrorLargerThanListed.
  ///
  /// In en, this message translates to:
  /// **'The download is larger than GitHub lists it, so it was stopped.'**
  String get updateErrorLargerThanListed;

  /// No description provided for @updateErrorEndedEarly.
  ///
  /// In en, this message translates to:
  /// **'The download ended early.'**
  String get updateErrorEndedEarly;

  /// No description provided for @updateRejectedWrongSigner.
  ///
  /// In en, this message translates to:
  /// **'This download is not signed by the same key as this app, so it must not be installed. It has been deleted.'**
  String get updateRejectedWrongSigner;

  /// No description provided for @updateRejectedChecksum.
  ///
  /// In en, this message translates to:
  /// **'This download does not match the SHA-256 checksum GitHub lists for it, so it may be damaged or tampered with. It has been deleted.'**
  String get updateRejectedChecksum;

  /// No description provided for @updateRejectedUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The signing key of this download could not be read, so it was not offered for install. It has been deleted.'**
  String get updateRejectedUnreadable;

  /// No description provided for @updateRejectedAppKeyUnknown.
  ///
  /// In en, this message translates to:
  /// **'Chatui could not read its own signing key, so it cannot check this download. It has been deleted.'**
  String get updateRejectedAppKeyUnknown;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'The update check failed.'**
  String get updateCheckFailed;

  /// No description provided for @updateNoApkSeeReleases.
  ///
  /// In en, this message translates to:
  /// **'This release has no APK for your phone. The releases page has the files.'**
  String get updateNoApkSeeReleases;

  /// No description provided for @updateCannotKeepDownload.
  ///
  /// In en, this message translates to:
  /// **'This device cannot keep a download.'**
  String get updateCannotKeepDownload;

  /// No description provided for @updateDownloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled.'**
  String get updateDownloadCancelled;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The download failed.'**
  String get updateDownloadFailed;

  /// No description provided for @updateInstallPermission.
  ///
  /// In en, this message translates to:
  /// **'Android needs your permission first. Allow Chatui to install apps on the next screen, then tap Install again.'**
  String get updateInstallPermission;

  /// No description provided for @updateInstallerFailed.
  ///
  /// In en, this message translates to:
  /// **'Android could not open its installer. The releases page has the file.'**
  String get updateInstallerFailed;

  /// No description provided for @walletSettingsRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove the wallet?'**
  String get walletSettingsRemoveTitle;

  /// No description provided for @walletSettingsRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the wallet from this device. Chatui does not keep a copy of the recovery phrase; the paper you wrote when creating this wallet is the only way back in. After that, you can create or restore another wallet.'**
  String get walletSettingsRemoveBody;

  /// No description provided for @walletSettingsRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove wallet'**
  String get walletSettingsRemoveFailed;

  /// No description provided for @walletSettingsPinIndexTitle.
  ///
  /// In en, this message translates to:
  /// **'Pin address index'**
  String get walletSettingsPinIndexTitle;

  /// No description provided for @walletSettingsPinIndexIntro.
  ///
  /// In en, this message translates to:
  /// **'Derive the address at this index and use it as the primary address for send and receive. Index 0 resets to the default. The balance still counts every address of the wallet.'**
  String get walletSettingsPinIndexIntro;

  /// No description provided for @walletSettingsIndexLabel.
  ///
  /// In en, this message translates to:
  /// **'Index'**
  String get walletSettingsIndexLabel;

  /// No description provided for @walletSettingsPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get walletSettingsPin;

  /// No description provided for @walletSettingsInvalidIndex.
  ///
  /// In en, this message translates to:
  /// **'Invalid index'**
  String get walletSettingsInvalidIndex;

  /// No description provided for @walletSettingsIndexTooHigh.
  ///
  /// In en, this message translates to:
  /// **'This wallet can\'t derive past index {max}'**
  String walletSettingsIndexTooHigh(String max);

  /// No description provided for @walletSettingsCannotDerive.
  ///
  /// In en, this message translates to:
  /// **'Wallet can\'t derive index {index}'**
  String walletSettingsCannotDerive(String index);

  /// No description provided for @walletSettingsPinnedIndex.
  ///
  /// In en, this message translates to:
  /// **'Pinned index {index} · {address}'**
  String walletSettingsPinnedIndex(String index, String address);

  /// No description provided for @walletSettingsPinnedOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Pinned index #{index} can\'t be derived'**
  String walletSettingsPinnedOutOfRange(String index);

  /// No description provided for @walletSettingsPrimaryPinned.
  ///
  /// In en, this message translates to:
  /// **'Primary address: index #{index}'**
  String walletSettingsPrimaryPinned(String index);

  /// No description provided for @walletSettingsPrimaryDefault.
  ///
  /// In en, this message translates to:
  /// **'Primary address: index 0'**
  String get walletSettingsPrimaryDefault;

  /// No description provided for @walletSettingsOutOfRangeHint.
  ///
  /// In en, this message translates to:
  /// **'This wallet derives up to index {max}. Unpin or choose a lower index.'**
  String walletSettingsOutOfRangeHint(String max);

  /// No description provided for @walletSettingsPrimaryHint.
  ///
  /// In en, this message translates to:
  /// **'Receive and change default to this address until it is used.'**
  String get walletSettingsPrimaryHint;

  /// No description provided for @walletSettingsUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get walletSettingsUnpin;

  /// No description provided for @walletSettingsFreshAddresses.
  ///
  /// In en, this message translates to:
  /// **'Fresh addresses'**
  String get walletSettingsFreshAddresses;

  /// No description provided for @walletSettingsFreshAddressesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive and change on a new address each time, like Nautilus. Off: everything uses your pinned or first address.'**
  String get walletSettingsFreshAddressesSubtitle;

  /// No description provided for @walletSettingsUnlockToChange.
  ///
  /// In en, this message translates to:
  /// **'Unlock the wallet to change this setting'**
  String get walletSettingsUnlockToChange;

  /// No description provided for @walletSettingsPrivacySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update privacy setting'**
  String get walletSettingsPrivacySaveFailed;

  /// No description provided for @walletSettingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get walletSettingsBackup;

  /// No description provided for @walletSettingsBackupNote.
  ///
  /// In en, this message translates to:
  /// **'Chatui does not keep a copy of the recovery phrase. The paper you wrote at create or restore is the only way back in.'**
  String get walletSettingsBackupNote;

  /// No description provided for @walletSettingsRemoveWallet.
  ///
  /// In en, this message translates to:
  /// **'Remove wallet'**
  String get walletSettingsRemoveWallet;

  /// No description provided for @walletSettingsRemoveWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From this device only. Keep the recovery phrase.'**
  String get walletSettingsRemoveWalletSubtitle;

  /// No description provided for @secureSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get secureSaveFailed;

  /// No description provided for @secureSaveWrapKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save wrap key'**
  String get secureSaveWrapKeyFailed;

  /// No description provided for @secureSavePinWrapFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save PIN wrap'**
  String get secureSavePinWrapFailed;

  /// No description provided for @secureLoadWrapKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load wrap key'**
  String get secureLoadWrapKeyFailed;

  /// No description provided for @secureLoadPinWrapFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load PIN wrap'**
  String get secureLoadPinWrapFailed;

  /// No description provided for @secureLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get secureLoadFailed;

  /// No description provided for @secureDeleteWrapKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete wrap key: {detail}'**
  String secureDeleteWrapKeyFailed(String detail);

  /// No description provided for @secureDeleteSecretsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete wallet secrets: {detail}'**
  String secureDeleteSecretsFailed(String detail);

  /// No description provided for @secureDeleteWalletFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete wallet: {detail}'**
  String secureDeleteWalletFailed(String detail);

  /// No description provided for @secureCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check: {detail}'**
  String secureCheckFailed(String detail);

  /// No description provided for @secureCheckPinWrapFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check PIN wrap'**
  String get secureCheckPinWrapFailed;

  /// No description provided for @secureCheckWrapKeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check wrap key'**
  String get secureCheckWrapKeyFailed;

  /// No description provided for @secureCheckBiometricsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check biometrics'**
  String get secureCheckBiometricsFailed;

  /// No description provided for @secureBiometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric'**
  String get secureBiometric;

  /// No description provided for @secureLoadPinGateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load PIN gate'**
  String get secureLoadPinGateFailed;

  /// No description provided for @secureTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds}s'**
  String secureTooManyAttempts(String seconds);

  /// No description provided for @securePersistPinGateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to persist PIN gate: {detail}'**
  String securePersistPinGateFailed(String detail);

  /// No description provided for @secureListWalletsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to list wallets: {detail}'**
  String secureListWalletsFailed(String detail);

  /// No description provided for @secureBiometricChanged.
  ///
  /// In en, this message translates to:
  /// **'Biometric enrollment changed; re-enter mnemonic'**
  String get secureBiometricChanged;

  /// No description provided for @notifyChannelName.
  ///
  /// In en, this message translates to:
  /// **'Incoming payments'**
  String get notifyChannelName;

  /// No description provided for @notifyChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'A payment to one of your addresses was seen on the network.'**
  String get notifyChannelDescription;

  /// No description provided for @notifyChatDoneChannelName.
  ///
  /// In en, this message translates to:
  /// **'Finished answers'**
  String get notifyChatDoneChannelName;

  /// No description provided for @notifyChatDoneChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'A service finished an answer while you were not looking at the chat.'**
  String get notifyChatDoneChannelDescription;

  /// No description provided for @notifyIncomingBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} to {wallet}'**
  String notifyIncomingBody(String amount, String wallet);

  /// No description provided for @notifyPaymentOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Payment on the way'**
  String get notifyPaymentOnTheWay;

  /// No description provided for @notifyPaymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get notifyPaymentReceived;

  /// No description provided for @utxoBoxCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} box} other{{count} boxes}}'**
  String utxoBoxCount(int count);

  /// Always 'boxes' in English.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} boxes}}'**
  String utxoNBoxes(int count);

  /// No description provided for @utxoTokenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} token} other{{count} tokens}}'**
  String utxoTokenCount(int count);

  /// No description provided for @coinPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'These {count} boxes sit on {addresses} different addresses. Spending them together publicly links those addresses to one wallet.'**
  String coinPrivacyNote(String count, String addresses);

  /// No description provided for @coinConfirmationNote.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One of these boxes is still confirming. This transaction can confirm only after the one that created it, and fails if that one is dropped.} other{{count} of these boxes are still confirming. This transaction can confirm only after the one that created them, and fails if that one is dropped.}}'**
  String coinConfirmationNote(int count);

  /// No description provided for @coinSelectionNone.
  ///
  /// In en, this message translates to:
  /// **'No boxes chosen — Chatui will pick them.'**
  String get coinSelectionNone;

  /// count is 1 for exactly one unit, else 2; amount is the formatted number.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{amount} raw unit} other{{amount} raw units}}'**
  String coinRawUnits(int count, String amount);

  /// No description provided for @coinRawUnitsLabel.
  ///
  /// In en, this message translates to:
  /// **'raw units'**
  String get coinRawUnitsLabel;

  /// No description provided for @coinRawUnitsOf.
  ///
  /// In en, this message translates to:
  /// **'{units} of {label}'**
  String coinRawUnitsOf(String units, String label);

  /// No description provided for @pendingBalanceHidden.
  ///
  /// In en, this message translates to:
  /// **'•••• ERG pending'**
  String get pendingBalanceHidden;

  /// No description provided for @pendingBalanceTotalUnknown.
  ///
  /// In en, this message translates to:
  /// **'{total} ERG · pending'**
  String pendingBalanceTotalUnknown(String total);

  /// No description provided for @pendingBalanceTotalMoved.
  ///
  /// In en, this message translates to:
  /// **'{total} ERG · {moved} pending'**
  String pendingBalanceTotalMoved(String total, String moved);

  /// No description provided for @pendingBalanceMoved.
  ///
  /// In en, this message translates to:
  /// **'{moved} ERG pending · {confirmed} confirmed'**
  String pendingBalanceMoved(String moved, String confirmed);

  /// No description provided for @pendingBalanceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Pending · {confirmed} confirmed'**
  String pendingBalanceUnknown(String confirmed);

  /// No description provided for @spendUnconfirmedNote.
  ///
  /// In en, this message translates to:
  /// **'Off: money you receive, and the change from your own sends, waits for one confirmation (the next block, usually a few minutes) before Chatui spends it. On: it can be spent at once, but if the transaction that brought it is dropped, the one spending it fails too. Either way, coins a pending transaction is already spending are never used again.'**
  String get spendUnconfirmedNote;

  /// No description provided for @rentNoChargeZeroRate.
  ///
  /// In en, this message translates to:
  /// **'No storage rent is charged at the current rate.'**
  String get rentNoChargeZeroRate;

  /// No description provided for @rentNoChargeOverflow.
  ///
  /// In en, this message translates to:
  /// **'No storage rent can be charged on a box over {bytes} bytes under current rules.'**
  String rentNoChargeOverflow(String bytes);

  /// No description provided for @rentRatePerByte.
  ///
  /// In en, this message translates to:
  /// **'{fee} per byte'**
  String rentRatePerByte(String fee);

  /// No description provided for @rentRatePerByteDefault.
  ///
  /// In en, this message translates to:
  /// **'{fee} per byte (default rate)'**
  String rentRatePerByteDefault(String fee);

  /// No description provided for @rentWhenNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get rentWhenNow;

  /// No description provided for @rentWhenWithinDay.
  ///
  /// In en, this message translates to:
  /// **'within a day'**
  String get rentWhenWithinDay;

  /// No description provided for @rentWhenInDays.
  ///
  /// In en, this message translates to:
  /// **'in ~{days} days'**
  String rentWhenInDays(String days);

  /// No description provided for @rentWhenMonthYear.
  ///
  /// In en, this message translates to:
  /// **'~{month} {year}'**
  String rentWhenMonthYear(String month, String year);

  /// No description provided for @separateNeedsSourceAddress.
  ///
  /// In en, this message translates to:
  /// **'Refresh boxes to identify the source address.'**
  String get separateNeedsSourceAddress;

  /// No description provided for @separateMinPerBox.
  ///
  /// In en, this message translates to:
  /// **'Each token box needs at least 0.001 ERG.'**
  String get separateMinPerBox;

  /// No description provided for @separateFundingInvalid.
  ///
  /// In en, this message translates to:
  /// **'Funding must be separate ERG-only boxes at the source address.'**
  String get separateFundingInvalid;

  /// No description provided for @separateInvalidTokenAmount.
  ///
  /// In en, this message translates to:
  /// **'The source contains an invalid token amount.'**
  String get separateInvalidTokenAmount;

  /// No description provided for @separateTokenTypeRange.
  ///
  /// In en, this message translates to:
  /// **'Choose a box holding between 2 and 150 token types.'**
  String get separateTokenTypeRange;

  /// No description provided for @separateInvalidErgValue.
  ///
  /// In en, this message translates to:
  /// **'The selected boxes contain an invalid ERG value.'**
  String get separateInvalidErgValue;

  /// No description provided for @separateOverLimit.
  ///
  /// In en, this message translates to:
  /// **'The selected ERG amount exceeds the transaction limit.'**
  String get separateOverLimit;

  /// No description provided for @separateAddFunding.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} in funding boxes.'**
  String separateAddFunding(String amount);

  /// No description provided for @utxoHealthTidy.
  ///
  /// In en, this message translates to:
  /// **'Tidy'**
  String get utxoHealthTidy;

  /// No description provided for @utxoHealthTidyHint.
  ///
  /// In en, this message translates to:
  /// **'Few boxes: sends select inputs quickly and pay the least.'**
  String get utxoHealthTidyHint;

  /// No description provided for @utxoHealthModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get utxoHealthModerate;

  /// No description provided for @utxoHealthModerateHint.
  ///
  /// In en, this message translates to:
  /// **'Sends may need several inputs; consolidating dust keeps fees down.'**
  String get utxoHealthModerateHint;

  /// No description provided for @utxoHealthFragmented.
  ///
  /// In en, this message translates to:
  /// **'Fragmented'**
  String get utxoHealthFragmented;

  /// No description provided for @utxoHealthFragmentedHint.
  ///
  /// In en, this message translates to:
  /// **'Many small boxes make every send pick more inputs. Sweep dust or consolidate.'**
  String get utxoHealthFragmentedHint;

  /// No description provided for @sendRecipientPrefix.
  ///
  /// In en, this message translates to:
  /// **'Recipient {number}: '**
  String sendRecipientPrefix(String number);

  /// No description provided for @sendErrorNotErgoAddress.
  ///
  /// In en, this message translates to:
  /// **'{who}not an Ergo address'**
  String sendErrorNotErgoAddress(String who);

  /// No description provided for @sendErrorMinimum.
  ///
  /// In en, this message translates to:
  /// **'{who}minimum {amount} ERG'**
  String sendErrorMinimum(String who, String amount);

  /// No description provided for @sendErrorTokenNotInWallet.
  ///
  /// In en, this message translates to:
  /// **'{who}token is not in this wallet'**
  String sendErrorTokenNotInWallet(String who);

  /// No description provided for @sendErrorEnterTokenAmount.
  ///
  /// In en, this message translates to:
  /// **'{who}enter a token amount for {token}'**
  String sendErrorEnterTokenAmount(String who, String token);

  /// No description provided for @sendErrorTokenOverAllocated.
  ///
  /// In en, this message translates to:
  /// **'{who}you hold {amount} {token} in total across all recipients'**
  String sendErrorTokenOverAllocated(String who, String amount, String token);

  /// No description provided for @priceHistoryNeedsExtraIndex.
  ///
  /// In en, this message translates to:
  /// **'This node cannot serve price history: it needs the extra index.'**
  String get priceHistoryNeedsExtraIndex;

  /// No description provided for @oracleSigmaUsd.
  ///
  /// In en, this message translates to:
  /// **'SigmaUSD oracle'**
  String get oracleSigmaUsd;

  /// No description provided for @oracleDexyUsd.
  ///
  /// In en, this message translates to:
  /// **'Dexy USD oracle'**
  String get oracleDexyUsd;

  /// No description provided for @oracleDexyGold.
  ///
  /// In en, this message translates to:
  /// **'Dexy gold oracle'**
  String get oracleDexyGold;

  /// No description provided for @oracleAvl.
  ///
  /// In en, this message translates to:
  /// **'AVL oracle'**
  String get oracleAvl;

  /// No description provided for @priceAgeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String priceAgeMinutes(String count);

  /// No description provided for @priceAgeHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h'**
  String priceAgeHours(String count);

  /// Always 2 days or more.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String priceAgeDays(String count);

  /// How old a stale price is; age is priceAgeMinutes/Hours/Days. Also follows the source after a comma: "SigmaUSD oracle, 3 h old".
  ///
  /// In en, this message translates to:
  /// **'{age} old'**
  String priceAgeOld(String age);

  /// No description provided for @priceSourceLine.
  ///
  /// In en, this message translates to:
  /// **'{source} · ERG via {via}'**
  String priceSourceLine(String source, String via);

  /// No description provided for @priceSourceLineStale.
  ///
  /// In en, this message translates to:
  /// **'{source} · stale · ERG via {via}'**
  String priceSourceLineStale(String source, String via);

  /// No description provided for @priceHistoryUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Price history could not be read: {error}'**
  String priceHistoryUnreadable(String error);

  /// No description provided for @priceNoNode.
  ///
  /// In en, this message translates to:
  /// **'No node is connected.'**
  String get priceNoNode;

  /// No description provided for @priceNoHeight.
  ///
  /// In en, this message translates to:
  /// **'The node height is not known yet.'**
  String get priceNoHeight;

  /// No description provided for @priceNoHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'This node has no price history for {source} yet.'**
  String priceNoHistoryYet(String source);

  /// No description provided for @priceOraclePools.
  ///
  /// In en, this message translates to:
  /// **'Oracle pools'**
  String get priceOraclePools;

  /// No description provided for @priceSourceBlurb.
  ///
  /// In en, this message translates to:
  /// **'On-chain: ERG from the SigmaUSD oracle pool (the ERG/USD oracle pool), gold from the Dexy gold oracle, wrapped majors from the AVL multi-oracle. An old price is shown with its age, never as current. Reads only your node. Other tokens have no price.'**
  String get priceSourceBlurb;

  /// No description provided for @priceNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No price yet · {source} have not answered'**
  String priceNoneYet(String source);

  /// No description provided for @priceNoPool.
  ///
  /// In en, this message translates to:
  /// **'No price · no oracle pool prices this token'**
  String get priceNoPool;

  /// No description provided for @priceEach.
  ///
  /// In en, this message translates to:
  /// **'{price} each'**
  String priceEach(String price);

  /// No description provided for @priceHeld.
  ///
  /// In en, this message translates to:
  /// **'{value} held'**
  String priceHeld(String value);

  /// No description provided for @priceNotCounted.
  ///
  /// In en, this message translates to:
  /// **'not counted in totals (stale)'**
  String get priceNotCounted;

  /// No description provided for @verifiedNetaNote.
  ///
  /// In en, this message translates to:
  /// **'The anetaBTC project was abandoned by its team and holders were left without the promised product. Treat NETA as having no backing.'**
  String get verifiedNetaNote;

  /// No description provided for @tokenErrorNoName.
  ///
  /// In en, this message translates to:
  /// **'Give the token a name'**
  String get tokenErrorNoName;

  /// No description provided for @tokenErrorNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Name is too long (64 characters at most)'**
  String get tokenErrorNameTooLong;

  /// No description provided for @tokenErrorDecimalsRange.
  ///
  /// In en, this message translates to:
  /// **'Decimals must be between 0 and 18'**
  String get tokenErrorDecimalsRange;

  /// No description provided for @tokenErrorAmountMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount to issue'**
  String get tokenErrorAmountMissing;

  /// No description provided for @tokenErrorAmountZero.
  ///
  /// In en, this message translates to:
  /// **'Amount must be above zero'**
  String get tokenErrorAmountZero;

  /// No description provided for @tokenErrorAmountTooBig.
  ///
  /// In en, this message translates to:
  /// **'Amount is beyond what a box can hold'**
  String get tokenErrorAmountTooBig;

  /// No description provided for @nftErrorDecimals.
  ///
  /// In en, this message translates to:
  /// **'An NFT has no decimals'**
  String get nftErrorDecimals;

  /// No description provided for @nftErrorOneUnit.
  ///
  /// In en, this message translates to:
  /// **'An NFT is one unit'**
  String get nftErrorOneUnit;

  /// No description provided for @nftErrorHash.
  ///
  /// In en, this message translates to:
  /// **'Content hash must be 64 hex characters (SHA-256)'**
  String get nftErrorHash;

  /// No description provided for @nftErrorLink.
  ///
  /// In en, this message translates to:
  /// **'Link must start with https:// or ipfs://'**
  String get nftErrorLink;

  /// No description provided for @tokenIssue.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get tokenIssue;

  /// No description provided for @tokenBurn.
  ///
  /// In en, this message translates to:
  /// **'Burn'**
  String get tokenBurn;

  /// No description provided for @tokenIssueNftTitle.
  ///
  /// In en, this message translates to:
  /// **'Issue an NFT'**
  String get tokenIssueNftTitle;

  /// No description provided for @tokenIssueTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Issue a token'**
  String get tokenIssueTokenTitle;

  /// No description provided for @tokenIssueDetail.
  ///
  /// In en, this message translates to:
  /// **'The new token lands in this wallet. Its name, description and decimals are written on chain and cannot be changed afterwards.'**
  String get tokenIssueDetail;

  /// No description provided for @tokenSupply.
  ///
  /// In en, this message translates to:
  /// **'Supply'**
  String get tokenSupply;

  /// Supply row: the amount and the number of decimals.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{amount} · {count} decimals} other{{amount} · {count} decimals}}'**
  String tokenSupplyDecimals(int count, String amount);

  /// No description provided for @tokenDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get tokenDescription;

  /// No description provided for @tokenKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get tokenKind;

  /// No description provided for @tokenLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get tokenLink;

  /// No description provided for @tokenIdRow.
  ///
  /// In en, this message translates to:
  /// **'Token id'**
  String get tokenIdRow;

  /// No description provided for @tokenBoxValue.
  ///
  /// In en, this message translates to:
  /// **'Box value'**
  String get tokenBoxValue;

  /// No description provided for @tokenIssuanceSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Token issuance submitted'**
  String get tokenIssuanceSubmitted;

  /// No description provided for @tokenIssuanceNote.
  ///
  /// In en, this message translates to:
  /// **'The token ID remains on the issuance screen. The token appears in your assets after confirmation.'**
  String get tokenIssuanceNote;

  /// No description provided for @tokenNamedIssuanceSubmitted.
  ///
  /// In en, this message translates to:
  /// **'{name} issuance submitted'**
  String tokenNamedIssuanceSubmitted(String name);

  /// No description provided for @tokenIssuedExplainer.
  ///
  /// In en, this message translates to:
  /// **'It appears in your assets once the transaction confirms. The token id is what other wallets and sites know it by.'**
  String get tokenIssuedExplainer;

  /// No description provided for @tokenIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Token ID'**
  String get tokenIdLabel;

  /// No description provided for @tokenCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy token id'**
  String get tokenCopyId;

  /// No description provided for @tokenIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Token id copied'**
  String get tokenIdCopied;

  /// No description provided for @tokenViewReceipt.
  ///
  /// In en, this message translates to:
  /// **'View transaction receipt'**
  String get tokenViewReceipt;

  /// No description provided for @tokenTransactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get tokenTransactionId;

  /// No description provided for @tokenIssueAnother.
  ///
  /// In en, this message translates to:
  /// **'Issue another'**
  String get tokenIssueAnother;

  /// No description provided for @tokenIssueIntro.
  ///
  /// In en, this message translates to:
  /// **'A token is created by a transaction from this wallet. Its id is fixed by that transaction, and its name, description and decimals are written once, on chain.'**
  String get tokenIssueIntro;

  /// No description provided for @nftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A single unit with a content hash and a link'**
  String get nftSubtitle;

  /// No description provided for @tokenDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get tokenDescriptionOptional;

  /// No description provided for @tokenSupplyHelper.
  ///
  /// In en, this message translates to:
  /// **'Whole units, decimals allowed'**
  String get tokenSupplyHelper;

  /// No description provided for @tokenDecimals.
  ///
  /// In en, this message translates to:
  /// **'Decimals'**
  String get tokenDecimals;

  /// No description provided for @tokenDecimalsHelper.
  ///
  /// In en, this message translates to:
  /// **'0 to 18'**
  String get tokenDecimalsHelper;

  /// No description provided for @nftKindPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get nftKindPicture;

  /// No description provided for @nftKindAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get nftKindAudio;

  /// No description provided for @nftKindVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get nftKindVideo;

  /// No description provided for @nftHashLabel.
  ///
  /// In en, this message translates to:
  /// **'Content SHA-256 (hex, optional)'**
  String get nftHashLabel;

  /// No description provided for @nftHashHelper.
  ///
  /// In en, this message translates to:
  /// **'64 hex characters'**
  String get nftHashHelper;

  /// No description provided for @nftLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Link (optional)'**
  String get nftLinkLabel;

  /// No description provided for @nftLinkHelper.
  ///
  /// In en, this message translates to:
  /// **'https:// or ipfs://'**
  String get nftLinkHelper;

  /// No description provided for @tokenIssueCost.
  ///
  /// In en, this message translates to:
  /// **'Costs 0.001 ERG for the token box plus the miner fee.'**
  String get tokenIssueCost;

  /// No description provided for @tokenPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get tokenPreparing;

  /// No description provided for @tokenBurnEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter how much {token} to burn'**
  String tokenBurnEnterAmount(String token);

  /// No description provided for @tokenBurnYouHold.
  ///
  /// In en, this message translates to:
  /// **'You hold {amount} {token}'**
  String tokenBurnYouHold(String amount, String token);

  /// No description provided for @tokenBurnPick.
  ///
  /// In en, this message translates to:
  /// **'Pick a token to burn'**
  String get tokenBurnPick;

  /// No description provided for @tokenBurnTypeToGoOn.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to go on'**
  String tokenBurnTypeToGoOn(String word);

  /// No description provided for @tokenBurnTitle.
  ///
  /// In en, this message translates to:
  /// **'Burn tokens'**
  String get tokenBurnTitle;

  /// No description provided for @tokenBurnForGood.
  ///
  /// In en, this message translates to:
  /// **'Burn for good'**
  String get tokenBurnForGood;

  /// No description provided for @tokenBurnDetail.
  ///
  /// In en, this message translates to:
  /// **'These units are left out of every output of the transaction and stop existing. Nobody, including Chatui, can bring them back.'**
  String get tokenBurnDetail;

  /// No description provided for @tokenBurnBackToYou.
  ///
  /// In en, this message translates to:
  /// **'Back to you'**
  String get tokenBurnBackToYou;

  /// No description provided for @tokenBurnSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Token burn submitted'**
  String get tokenBurnSubmitted;

  /// No description provided for @tokenBurnWarning.
  ///
  /// In en, this message translates to:
  /// **'Burning destroys tokens permanently. It is not a send: the units leave the chain rather than move to anyone. Use it for tokens you are sure you never want back, such as spam or a supply you mean to cut.'**
  String get tokenBurnWarning;

  /// No description provided for @tokenBurnNoTokens.
  ///
  /// In en, this message translates to:
  /// **'This wallet holds no tokens.'**
  String get tokenBurnNoTokens;

  /// No description provided for @tokenBurnInWallet.
  ///
  /// In en, this message translates to:
  /// **'Tokens in this wallet'**
  String get tokenBurnInWallet;

  /// No description provided for @tokenBurnHeldRow.
  ///
  /// In en, this message translates to:
  /// **'{amount} held · {id}'**
  String tokenBurnHeldRow(String amount, String id);

  /// No description provided for @tokenBurnOneUnit.
  ///
  /// In en, this message translates to:
  /// **'{token}: the one unit'**
  String tokenBurnOneUnit(String token);

  /// No description provided for @tokenBurnAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'{token} to burn'**
  String tokenBurnAmountLabel(String token);

  /// No description provided for @tokenBurnOf.
  ///
  /// In en, this message translates to:
  /// **'Of {amount}'**
  String tokenBurnOf(String amount);

  /// No description provided for @tokenBurnAll.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get tokenBurnAll;

  /// No description provided for @tokenBurnTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String tokenBurnTypeToConfirm(String word);

  /// No description provided for @assetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assetsTitle;

  /// No description provided for @assetsShowList.
  ///
  /// In en, this message translates to:
  /// **'Show collectible list'**
  String get assetsShowList;

  /// No description provided for @assetsShowGrid.
  ///
  /// In en, this message translates to:
  /// **'Show collectible grid'**
  String get assetsShowGrid;

  /// No description provided for @assetsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear collectible cache (saved holdings keep their metadata)'**
  String get assetsClearCache;

  /// No description provided for @assetsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get assetsAll;

  /// No description provided for @assetsCollectibles.
  ///
  /// In en, this message translates to:
  /// **'Collectibles'**
  String get assetsCollectibles;

  /// No description provided for @assetsSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search name or token ID'**
  String get assetsSearchLabel;

  /// No description provided for @assetsClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get assetsClearSearch;

  /// No description provided for @assetsCollectibleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} identified collectible · previews load only when you choose} other{{count} identified collectibles · previews load only when you choose}}'**
  String assetsCollectibleCount(int count);

  /// No description provided for @assetsTokenIdCount.
  ///
  /// In en, this message translates to:
  /// **'{count} token IDs'**
  String assetsTokenIdCount(String count);

  /// No description provided for @assetsTokenIdCountIncomplete.
  ///
  /// In en, this message translates to:
  /// **'{count} token IDs · {unknown} with incomplete metadata'**
  String assetsTokenIdCountIncomplete(String count, String unknown);

  /// No description provided for @assetsPublicOnly.
  ///
  /// In en, this message translates to:
  /// **'Public holdings only'**
  String get assetsPublicOnly;

  /// No description provided for @assetsNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Holdings not loaded'**
  String get assetsNotLoaded;

  /// No description provided for @assetsLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Holdings last synced {age}'**
  String assetsLastSynced(String age);

  /// No description provided for @assetsHidden.
  ///
  /// In en, this message translates to:
  /// **'Assets hidden'**
  String get assetsHidden;

  /// No description provided for @assetsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No assets match your search'**
  String get assetsNoMatch;

  /// No description provided for @assetsNoCollectibles.
  ///
  /// In en, this message translates to:
  /// **'No identified collectibles in loaded holdings'**
  String get assetsNoCollectibles;

  /// No description provided for @assetsIncompleteHint.
  ///
  /// In en, this message translates to:
  /// **'Some tokens have incomplete metadata. Open them in All to inspect their details.'**
  String get assetsIncompleteHint;

  /// No description provided for @tokenCautionFlagged.
  ///
  /// In en, this message translates to:
  /// **'Caution: this token is flagged'**
  String get tokenCautionFlagged;

  /// No description provided for @assetsHeld.
  ///
  /// In en, this message translates to:
  /// **'Held: {amount}'**
  String assetsHeld(String amount);

  /// No description provided for @tokenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} token ID (incl. NFTs)} other{{count} token IDs (incl. NFTs)}}'**
  String tokenCount(int count);

  /// No description provided for @tokenCountPublic.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} public token ID (incl. NFTs)} other{{count} public token IDs (incl. NFTs)}}'**
  String tokenCountPublic(int count);

  /// No description provided for @artworkClose.
  ///
  /// In en, this message translates to:
  /// **'Close artwork'**
  String get artworkClose;

  /// No description provided for @artworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Artwork'**
  String get artworkTitle;

  /// No description provided for @artworkResetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get artworkResetZoom;

  /// No description provided for @artworkPreviewHidden.
  ///
  /// In en, this message translates to:
  /// **'Preview hidden. Reopen asset details to view it.'**
  String get artworkPreviewHidden;

  /// No description provided for @artworkZoomHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch or scroll to zoom. Drag to move.'**
  String get artworkZoomHint;

  /// No description provided for @tokenMetaAsciiProvider.
  ///
  /// In en, this message translates to:
  /// **'Configure an ASCII/punycode HTTPS metadata provider'**
  String get tokenMetaAsciiProvider;

  /// No description provided for @tokenMetaLoadFrom.
  ///
  /// In en, this message translates to:
  /// **'Load metadata from {host}'**
  String tokenMetaLoadFrom(String host);

  /// No description provided for @tokenMetaLoadFromNode.
  ///
  /// In en, this message translates to:
  /// **'Load metadata from {host} (node)'**
  String tokenMetaLoadFromNode(String host);

  /// Stands in for the host in tokenMetaLoadFromNode when the node URL has none.
  ///
  /// In en, this message translates to:
  /// **'node'**
  String get tokenMetaHostNode;

  /// Stands in for the host in tokenMetaLoadFrom when the explorer URL has none.
  ///
  /// In en, this message translates to:
  /// **'provider'**
  String get tokenMetaHostProvider;

  /// No description provided for @tokenMetaPrivacy.
  ///
  /// In en, this message translates to:
  /// **'This provider can see your IP address and the token ID requested. Issuer text may be misleading. No artwork will be downloaded.'**
  String get tokenMetaPrivacy;

  /// No description provided for @tokenMetaLoad.
  ///
  /// In en, this message translates to:
  /// **'Load metadata'**
  String get tokenMetaLoad;

  /// No description provided for @tokenMetaBusy.
  ///
  /// In en, this message translates to:
  /// **'Another metadata request is finishing — try again'**
  String get tokenMetaBusy;

  /// No description provided for @tokenMetaUnavailableFrom.
  ///
  /// In en, this message translates to:
  /// **'Metadata unavailable from {host}'**
  String tokenMetaUnavailableFrom(String host);

  /// No description provided for @tokenDetailsHidden.
  ///
  /// In en, this message translates to:
  /// **'Asset details hidden'**
  String get tokenDetailsHidden;

  /// No description provided for @tokenMetaOffline.
  ///
  /// In en, this message translates to:
  /// **'Metadata unavailable offline'**
  String get tokenMetaOffline;

  /// No description provided for @tokenMetaCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel metadata request'**
  String get tokenMetaCancel;

  /// No description provided for @tokenMetaLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading metadata…'**
  String get tokenMetaLoading;

  /// No description provided for @tokenCurated.
  ///
  /// In en, this message translates to:
  /// **'Curated token · {project}'**
  String tokenCurated(String project);

  /// No description provided for @tokenCaution.
  ///
  /// In en, this message translates to:
  /// **'Caution: {note}'**
  String tokenCaution(String note);

  /// No description provided for @tokenCautionDefault.
  ///
  /// In en, this message translates to:
  /// **'this token is flagged.'**
  String get tokenCautionDefault;

  /// No description provided for @tokenImpersonation.
  ///
  /// In en, this message translates to:
  /// **'This token is named like {ticker}, but it is not the verified {ticker} from {project}. Check the id before trusting it.'**
  String tokenImpersonation(String ticker, String project);

  /// No description provided for @artworkNoMediaLink.
  ///
  /// In en, this message translates to:
  /// **'No media link in issuance metadata.'**
  String get artworkNoMediaLink;

  /// No description provided for @artworkLoadBelow.
  ///
  /// In en, this message translates to:
  /// **'Load metadata below to check for artwork.'**
  String get artworkLoadBelow;

  /// No description provided for @artworkPreviewUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Preview not supported'**
  String get artworkPreviewUnsupported;

  /// No description provided for @artworkLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Artwork link unavailable'**
  String get artworkLinkUnavailable;

  /// No description provided for @artworkMediaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Media metadata unavailable'**
  String get artworkMediaUnavailable;

  /// No description provided for @artworkConsent.
  ///
  /// In en, this message translates to:
  /// **'Artwork is loaded only with your consent'**
  String get artworkConsent;

  /// No description provided for @tokenYouHold.
  ///
  /// In en, this message translates to:
  /// **'YOU HOLD'**
  String get tokenYouHold;

  /// No description provided for @tokenIdCaps.
  ///
  /// In en, this message translates to:
  /// **'TOKEN ID'**
  String get tokenIdCaps;

  /// No description provided for @tokenLeaveFor.
  ///
  /// In en, this message translates to:
  /// **'Leave Chatui for {host}?'**
  String tokenLeaveFor(String host);

  /// No description provided for @tokenExplorerPrivacy.
  ///
  /// In en, this message translates to:
  /// **'The explorer can see your IP address and this token ID.'**
  String get tokenExplorerPrivacy;

  /// No description provided for @tokenOpenExplorer.
  ///
  /// In en, this message translates to:
  /// **'Open explorer'**
  String get tokenOpenExplorer;

  /// No description provided for @tokenExplorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get tokenExplorer;

  /// No description provided for @tokenMetaDetails.
  ///
  /// In en, this message translates to:
  /// **'Metadata & media details'**
  String get tokenMetaDetails;

  /// No description provided for @tokenOriginalEmission.
  ///
  /// In en, this message translates to:
  /// **'Original emission: {amount} (provider reported)'**
  String tokenOriginalEmission(String amount);

  /// No description provided for @tokenOriginalEmissionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Original emission unavailable'**
  String get tokenOriginalEmissionUnavailable;

  /// No description provided for @tokenDecimalsLine.
  ///
  /// In en, this message translates to:
  /// **'Decimals: {decimals} · {evidence}'**
  String tokenDecimalsLine(String decimals, String evidence);

  /// No description provided for @tokenDecimalsDeclared.
  ///
  /// In en, this message translates to:
  /// **'declared by the issuer'**
  String get tokenDecimalsDeclared;

  /// No description provided for @tokenDecimalsNone.
  ///
  /// In en, this message translates to:
  /// **'none declared, so whole units'**
  String get tokenDecimalsNone;

  /// No description provided for @tokenDecimalsListed.
  ///
  /// In en, this message translates to:
  /// **'from a token list'**
  String get tokenDecimalsListed;

  /// No description provided for @tokenDecimalsLastShown.
  ///
  /// In en, this message translates to:
  /// **'as last shown'**
  String get tokenDecimalsLastShown;

  /// No description provided for @tokenDecimalsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Decimals unknown · amounts are shown in raw units'**
  String get tokenDecimalsUnknown;

  /// No description provided for @tokenDeclaredKind.
  ///
  /// In en, this message translates to:
  /// **'Declared artwork kind: {kind}'**
  String tokenDeclaredKind(String kind);

  /// No description provided for @tokenMetaSource.
  ///
  /// In en, this message translates to:
  /// **'Metadata source: {source}'**
  String tokenMetaSource(String source);

  /// No description provided for @tokenMediaHashMissing.
  ///
  /// In en, this message translates to:
  /// **'Issuance media hash missing or invalid'**
  String get tokenMediaHashMissing;

  /// No description provided for @tokenMediaHash.
  ///
  /// In en, this message translates to:
  /// **'Issuance media hash: {hash}'**
  String tokenMediaHash(String hash);

  /// No description provided for @tokenCopyMediaUri.
  ///
  /// In en, this message translates to:
  /// **'Copy media URI as text'**
  String get tokenCopyMediaUri;

  /// No description provided for @tokenIssuanceRegisters.
  ///
  /// In en, this message translates to:
  /// **'Original issuance registers (hex)'**
  String get tokenIssuanceRegisters;

  /// No description provided for @tokenSend.
  ///
  /// In en, this message translates to:
  /// **'Send {token}'**
  String tokenSend(String token);

  /// No description provided for @syncLockedWalletsExplainer.
  ///
  /// In en, this message translates to:
  /// **'A locked wallet refreshes from public data every 5 minutes, covering only the addresses this app already knows. Unlock it to pick up new addresses.'**
  String get syncLockedWalletsExplainer;

  /// No description provided for @syncPublicKnownOnly.
  ///
  /// In en, this message translates to:
  /// **'Public data · known addresses only'**
  String get syncPublicKnownOnly;

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncSyncing;

  /// No description provided for @syncOutOfSync.
  ///
  /// In en, this message translates to:
  /// **'Out of sync'**
  String get syncOutOfSync;

  /// No description provided for @syncHistoryIncomplete.
  ///
  /// In en, this message translates to:
  /// **'History incomplete'**
  String get syncHistoryIncomplete;

  /// No description provided for @syncSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncSynced;

  /// No description provided for @syncNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get syncNotSynced;

  /// No description provided for @syncPinIssue.
  ///
  /// In en, this message translates to:
  /// **'Pinned index {index} can\'t be derived (max {max}). Reset it in Settings.'**
  String syncPinIssue(String index, String max);

  /// No description provided for @dashboardStartupError.
  ///
  /// In en, this message translates to:
  /// **'Error: {detail}'**
  String dashboardStartupError(String detail);

  /// No description provided for @dashboardUnlockForErgoPay.
  ///
  /// In en, this message translates to:
  /// **'Unlock a wallet to continue with the ErgoPay request.'**
  String get dashboardUnlockForErgoPay;

  /// No description provided for @dashboardUnlockForNotification.
  ///
  /// In en, this message translates to:
  /// **'Unlock a wallet to open what the notification is about.'**
  String get dashboardUnlockForNotification;

  /// No description provided for @dashboardScanNotErgo.
  ///
  /// In en, this message translates to:
  /// **'Not an Ergo address or ErgoPay link'**
  String get dashboardScanNotErgo;

  /// No description provided for @dashboardOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open wallet: {detail}'**
  String dashboardOpenFailed(String detail);

  /// No description provided for @dashboardWalletRemoved.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" removed'**
  String dashboardWalletRemoved(String name);

  /// No description provided for @dashboardNoAddressDerived.
  ///
  /// In en, this message translates to:
  /// **'Unlocked, but no address could be derived'**
  String get dashboardNoAddressDerived;

  /// No description provided for @dashboardPinLockoutCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check PIN lockout'**
  String get dashboardPinLockoutCheckFailed;

  /// No description provided for @dashboardNoPinWallet.
  ///
  /// In en, this message translates to:
  /// **'No PIN-protected wallet found.'**
  String get dashboardNoPinWallet;

  /// No description provided for @dashboardBiometricNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'This wallet has no key stored on this device.'**
  String get dashboardBiometricNotSetUp;

  /// No description provided for @dashboardBiometricCancelled.
  ///
  /// In en, this message translates to:
  /// **'Unlock cancelled. Tap Unlock to try again.'**
  String get dashboardBiometricCancelled;

  /// No description provided for @dashboardWalletDataMissing.
  ///
  /// In en, this message translates to:
  /// **'Wallet data not found on this device.'**
  String get dashboardWalletDataMissing;

  /// No description provided for @dashboardNoWalletFound.
  ///
  /// In en, this message translates to:
  /// **'No wallet found. Create or restore.'**
  String get dashboardNoWalletFound;

  /// No description provided for @dashboardSetPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get dashboardSetPinTitle;

  /// No description provided for @dashboardLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get dashboardLater;

  /// No description provided for @dashboardUnlockFirst.
  ///
  /// In en, this message translates to:
  /// **'Unlock the wallet first'**
  String get dashboardUnlockFirst;

  /// No description provided for @dashboardAddressLoading.
  ///
  /// In en, this message translates to:
  /// **'Address is still loading'**
  String get dashboardAddressLoading;

  /// No description provided for @dashboardScanQrTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get dashboardScanQrTooltip;

  /// No description provided for @dashboardWalletSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Wallet settings'**
  String get dashboardWalletSettingsTooltip;

  /// No description provided for @homeUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get homeUnlocked;

  /// No description provided for @homeLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get homeLocked;

  /// No description provided for @offlineNoNodes.
  ///
  /// In en, this message translates to:
  /// **'No reachable nodes. Tap Retry to check.'**
  String get offlineNoNodes;

  /// No description provided for @discoverTokensBlurb.
  ///
  /// In en, this message translates to:
  /// **'Issue a token or an NFT, or burn tokens you hold.'**
  String get discoverTokensBlurb;

  /// No description provided for @discoverTokensWhat.
  ///
  /// In en, this message translates to:
  /// **'Any Ergo transaction can create a new token: its id is the id of the first input box, its name, decimals and description live in the registers of the box that carries it (EIP-4). An NFT is a token with one unit and a link to its media.'**
  String get discoverTokensWhat;

  /// No description provided for @discoverTokensCanIssue.
  ///
  /// In en, this message translates to:
  /// **'Issue a fungible token with a name, decimals and supply'**
  String get discoverTokensCanIssue;

  /// No description provided for @discoverTokensCanNft.
  ///
  /// In en, this message translates to:
  /// **'Issue an NFT pointing at an image, audio or video'**
  String get discoverTokensCanNft;

  /// No description provided for @discoverTokensCanBurn.
  ///
  /// In en, this message translates to:
  /// **'Burn tokens you hold so they leave circulation'**
  String get discoverTokensCanBurn;

  /// No description provided for @discoverTokensRiskName.
  ///
  /// In en, this message translates to:
  /// **'A token\'s name is not unique: anyone can issue one with the same name'**
  String get discoverTokensRiskName;

  /// No description provided for @discoverTokensRiskBurn.
  ///
  /// In en, this message translates to:
  /// **'Burning is final; the supply cannot be restored'**
  String get discoverTokensRiskBurn;

  /// No description provided for @discoverTokensRiskCost.
  ///
  /// In en, this message translates to:
  /// **'Issuing costs a miner fee and locks the minimum box value with the token'**
  String get discoverTokensRiskCost;

  /// No description provided for @discoverTokensGo.
  ///
  /// In en, this message translates to:
  /// **'Open tokens'**
  String get discoverTokensGo;

  /// No description provided for @homeUtxoManagement.
  ///
  /// In en, this message translates to:
  /// **'UTXO management'**
  String get homeUtxoManagement;

  /// No description provided for @discoverUtxosBlurb.
  ///
  /// In en, this message translates to:
  /// **'Consolidate, split and restructure the boxes your money sits in.'**
  String get discoverUtxosBlurb;

  /// No description provided for @discoverUtxosWhat.
  ///
  /// In en, this message translates to:
  /// **'On Ergo your balance is a set of boxes, each a separate coin. Many small boxes make every send bigger and slower to build; one huge box links everything you own in one place. This tool reshapes them.'**
  String get discoverUtxosWhat;

  /// No description provided for @discoverUtxosCanConsolidate.
  ///
  /// In en, this message translates to:
  /// **'Consolidate many small boxes into one'**
  String get discoverUtxosCanConsolidate;

  /// No description provided for @discoverUtxosCanSplit.
  ///
  /// In en, this message translates to:
  /// **'Split a box into several of a chosen size'**
  String get discoverUtxosCanSplit;

  /// No description provided for @discoverUtxosCanRestructure.
  ///
  /// In en, this message translates to:
  /// **'Restructure holdings so tokens sit in boxes of their own'**
  String get discoverUtxosCanRestructure;

  /// No description provided for @discoverUtxosRiskPublic.
  ///
  /// In en, this message translates to:
  /// **'Every reshape is a transaction: it costs a miner fee and is public'**
  String get discoverUtxosRiskPublic;

  /// No description provided for @discoverUtxosRiskLinks.
  ///
  /// In en, this message translates to:
  /// **'Consolidating links every box it spends to one owner'**
  String get discoverUtxosRiskLinks;

  /// No description provided for @discoverUtxosRiskMinimum.
  ///
  /// In en, this message translates to:
  /// **'A box below the minimum value cannot be made'**
  String get discoverUtxosRiskMinimum;

  /// No description provided for @discoverUtxosGo.
  ///
  /// In en, this message translates to:
  /// **'Open UTXO management'**
  String get discoverUtxosGo;

  /// No description provided for @discoverWhatYouCanDo.
  ///
  /// In en, this message translates to:
  /// **'WHAT YOU CAN DO'**
  String get discoverWhatYouCanDo;

  /// No description provided for @discoverWatchFor.
  ///
  /// In en, this message translates to:
  /// **'WATCH FOR'**
  String get discoverWatchFor;

  /// No description provided for @discoverIntro.
  ///
  /// In en, this message translates to:
  /// **'What Chatui can do beyond sending and receiving. Each one says what it is, what you can do with it, and what to watch for before it opens.'**
  String get discoverIntro;

  /// No description provided for @discoverTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get discoverTools;

  /// No description provided for @discoverRowHint.
  ///
  /// In en, this message translates to:
  /// **'What it is, and the way in'**
  String get discoverRowHint;

  /// No description provided for @navActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get navActivity;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navActivityPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{Activity, {count} pending}}'**
  String navActivityPending(int count);

  /// age is how old, e.g. "3 h".
  ///
  /// In en, this message translates to:
  /// **'prices {age} old'**
  String homePricesOld(String age);

  /// No description provided for @homePricesStale.
  ///
  /// In en, this message translates to:
  /// **'prices stale'**
  String get homePricesStale;

  /// when is a sync age, e.g. "5m ago".
  ///
  /// In en, this message translates to:
  /// **'prices as of {when}'**
  String homePricesAsOf(String when);

  /// No description provided for @homePriceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get homePriceUnavailable;

  /// No description provided for @homePriceUnavailableRetrying.
  ///
  /// In en, this message translates to:
  /// **'unavailable · retrying'**
  String get homePriceUnavailableRetrying;

  /// No description provided for @homeNetworkConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get homeNetworkConnected;

  /// No description provided for @homeNetworkLooking.
  ///
  /// In en, this message translates to:
  /// **'Looking for a node…'**
  String get homeNetworkLooking;

  /// No description provided for @homeNoReachableNodes.
  ///
  /// In en, this message translates to:
  /// **'No reachable nodes'**
  String get homeNoReachableNodes;

  /// age is how old a price is, e.g. "3 h".
  ///
  /// In en, this message translates to:
  /// **'{age} old'**
  String homeAgeOld(String age);

  /// How old a price is; when is a sync age, e.g. "5m ago".
  ///
  /// In en, this message translates to:
  /// **'as of {when}'**
  String homePriceAsOf(String when);

  /// No description provided for @homeHistoryOutOfDate.
  ///
  /// In en, this message translates to:
  /// **'{source} history is out of date'**
  String homeHistoryOutOfDate(String source);

  /// No description provided for @homeLegsMore.
  ///
  /// In en, this message translates to:
  /// **'{first} + {count} more'**
  String homeLegsMore(String first, String count);

  /// n is count with thousands separators.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} wallet not loaded} other{{n} wallets not loaded}}'**
  String homeWalletsNotLoaded(int count, String n);

  /// How old the figures are; when is a sync age, e.g. "3h ago".
  ///
  /// In en, this message translates to:
  /// **'as of {when}'**
  String homeAsOf(String when);

  /// No description provided for @homeSpokenLoading.
  ///
  /// In en, this message translates to:
  /// **'{label} loading'**
  String homeSpokenLoading(String label);

  /// No description provided for @homeSpokenUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{label} unavailable'**
  String homeSpokenUnavailable(String label);

  /// No description provided for @homeSpokenHidden.
  ///
  /// In en, this message translates to:
  /// **'{label} hidden'**
  String homeSpokenHidden(String label);

  /// No description provided for @homeSpokenSomethingPending.
  ///
  /// In en, this message translates to:
  /// **'something pending'**
  String get homeSpokenSomethingPending;

  /// No description provided for @homeSpokenAbout.
  ///
  /// In en, this message translates to:
  /// **'about {value} {code}'**
  String homeSpokenAbout(String value, String code);

  /// No description provided for @homeSpokenUnpriced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} tokens unpriced}}'**
  String homeSpokenUnpriced(int count);

  /// No description provided for @homeUnpricedTokens.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} unpriced token} other{{count} unpriced tokens}}'**
  String homeUnpricedTokens(int count);

  /// No description provided for @homeSpokenPinnedAddress.
  ///
  /// In en, this message translates to:
  /// **'Pinned address #{index}, {address}'**
  String homeSpokenPinnedAddress(String index, String address);

  /// No description provided for @homeSpokenAddress.
  ///
  /// In en, this message translates to:
  /// **'Address {address}'**
  String homeSpokenAddress(String address);

  /// No description provided for @homeCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get homeCopyAddress;

  /// No description provided for @homeErgPriceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'ERG price unavailable'**
  String get homeErgPriceUnavailable;

  /// No description provided for @homePriceVia.
  ///
  /// In en, this message translates to:
  /// **'{window} via {source}'**
  String homePriceVia(String window, String source);

  /// No description provided for @homeSpokenErgPrice.
  ///
  /// In en, this message translates to:
  /// **'ERG price {value} {code}'**
  String homeSpokenErgPrice(String value, String code);

  /// No description provided for @homeSpokenUp.
  ///
  /// In en, this message translates to:
  /// **'up {percent}% over {window}'**
  String homeSpokenUp(String percent, String window);

  /// No description provided for @homeSpokenDown.
  ///
  /// In en, this message translates to:
  /// **'down {percent}% over {window}'**
  String homeSpokenDown(String percent, String window);

  /// No description provided for @homeShowBalances.
  ///
  /// In en, this message translates to:
  /// **'Show balances'**
  String get homeShowBalances;

  /// No description provided for @homeHideBalances.
  ///
  /// In en, this message translates to:
  /// **'Hide balances'**
  String get homeHideBalances;

  /// No description provided for @homeNetworkSettings.
  ///
  /// In en, this message translates to:
  /// **'Network settings'**
  String get homeNetworkSettings;

  /// No description provided for @homeBlock.
  ///
  /// In en, this message translates to:
  /// **'Block {height}'**
  String homeBlock(String height);

  /// No description provided for @homeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get homeLoading;

  /// No description provided for @homeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get homeEmpty;

  /// n is count with thousands separators.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{n} token} other{{n} tokens}}'**
  String homeTokenCount(int count, String n);

  /// No description provided for @homeAsOfCompact.
  ///
  /// In en, this message translates to:
  /// **'as of {when}'**
  String homeAsOfCompact(String when);

  /// No description provided for @homeOpensWallet.
  ///
  /// In en, this message translates to:
  /// **'Opens the wallet'**
  String get homeOpensWallet;

  /// No description provided for @homeSpokenUnlocked.
  ///
  /// In en, this message translates to:
  /// **'unlocked'**
  String get homeSpokenUnlocked;

  /// No description provided for @homeSpokenBalanceHidden.
  ///
  /// In en, this message translates to:
  /// **'balance hidden'**
  String get homeSpokenBalanceHidden;

  /// No description provided for @homeSpokenIncl.
  ///
  /// In en, this message translates to:
  /// **'incl. {other}'**
  String homeSpokenIncl(String other);

  /// No description provided for @homePriceNote.
  ///
  /// In en, this message translates to:
  /// **'Price {note}'**
  String homePriceNote(String note);

  /// No description provided for @homeAssetHidden.
  ///
  /// In en, this message translates to:
  /// **'Asset hidden'**
  String get homeAssetHidden;

  /// No description provided for @homeSpokenVerified.
  ///
  /// In en, this message translates to:
  /// **'verified'**
  String get homeSpokenVerified;

  /// No description provided for @homeSpokenCaution.
  ///
  /// In en, this message translates to:
  /// **'caution, named like a verified token'**
  String get homeSpokenCaution;

  /// No description provided for @homeSpokenPrice.
  ///
  /// In en, this message translates to:
  /// **'price {value}'**
  String homeSpokenPrice(String value);

  /// No description provided for @homeSpokenPending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get homeSpokenPending;

  /// No description provided for @homeSpokenAmountHidden.
  ///
  /// In en, this message translates to:
  /// **'amount hidden'**
  String get homeSpokenAmountHidden;

  /// No description provided for @overviewOpenToLoad.
  ///
  /// In en, this message translates to:
  /// **'Open to load'**
  String get overviewOpenToLoad;

  /// No description provided for @overviewNotLoadedYet.
  ///
  /// In en, this message translates to:
  /// **'Not loaded yet'**
  String get overviewNotLoadedYet;

  /// No description provided for @overviewTagline.
  ///
  /// In en, this message translates to:
  /// **'Decentralized compute'**
  String get overviewTagline;

  /// No description provided for @overviewTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get overviewTotalBalance;

  /// No description provided for @overviewWalletRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet details'**
  String get overviewWalletRowTitle;

  /// No description provided for @overviewPrototypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Prototype software'**
  String get overviewPrototypeTitle;

  /// No description provided for @overviewPrototypeBody.
  ///
  /// In en, this message translates to:
  /// **'Chatui is an unaudited prototype. Transactions on Ergo are irreversible — use only funds you can afford to lose.'**
  String get overviewPrototypeBody;

  /// No description provided for @overviewGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get overviewGotIt;

  /// No description provided for @overviewPrototypeNote.
  ///
  /// In en, this message translates to:
  /// **'Unaudited prototype. Use only funds you can afford to lose.'**
  String get overviewPrototypeNote;

  /// No description provided for @overviewLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get overviewLearnMore;

  /// No description provided for @overviewWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your wallet lives here'**
  String get overviewWelcomeTitle;

  /// No description provided for @overviewWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'No wallet yet. Create a new wallet, or restore one from its recovery phrase. The app holds one wallet, and it opens from this screen.'**
  String get overviewWelcomeBody;

  /// No description provided for @overviewCreateWallet.
  ///
  /// In en, this message translates to:
  /// **'Create a wallet'**
  String get overviewCreateWallet;

  /// No description provided for @overviewRestoreWallet.
  ///
  /// In en, this message translates to:
  /// **'Restore from recovery phrase'**
  String get overviewRestoreWallet;

  /// No description provided for @homeBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get homeBalanceLabel;

  /// No description provided for @homeUnlockPrompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock to see activity, send and receive.'**
  String get homeUnlockPrompt;

  /// No description provided for @homeUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get homeUnlock;

  /// No description provided for @homeUsePin.
  ///
  /// In en, this message translates to:
  /// **'Use PIN'**
  String get homeUsePin;

  /// No description provided for @homeUseBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get homeUseBiometrics;

  /// No description provided for @homeUnlockAndSetPin.
  ///
  /// In en, this message translates to:
  /// **'Unlock and set PIN'**
  String get homeUnlockAndSetPin;

  /// No description provided for @homeKeysNotHere.
  ///
  /// In en, this message translates to:
  /// **'This wallet\'s keys are not stored on this device.'**
  String get homeKeysNotHere;

  /// No description provided for @homeActionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get homeActionSend;

  /// No description provided for @homeActionReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get homeActionReceive;

  /// No description provided for @homeActionMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get homeActionMore;

  /// No description provided for @homeToolTokensBlurb.
  ///
  /// In en, this message translates to:
  /// **'Issue tokens and NFTs, or burn tokens.'**
  String get homeToolTokensBlurb;

  /// No description provided for @homeToolUtxosBlurb.
  ///
  /// In en, this message translates to:
  /// **'Consolidate, split and tidy up your boxes.'**
  String get homeToolUtxosBlurb;

  /// No description provided for @homeToolAddressesBlurb.
  ///
  /// In en, this message translates to:
  /// **'Each address of this wallet and what it holds.'**
  String get homeToolAddressesBlurb;

  /// No description provided for @homeToolLock.
  ///
  /// In en, this message translates to:
  /// **'Lock wallet'**
  String get homeToolLock;

  /// No description provided for @homeToolLockBlurb.
  ///
  /// In en, this message translates to:
  /// **'Opening it again asks for your fingerprint or screen lock.'**
  String get homeToolLockBlurb;

  /// No description provided for @homeBreakdownIntro.
  ///
  /// In en, this message translates to:
  /// **'The wallet is shown as one address, but its balance covers every address it knows. Any of them can spend from this wallet.'**
  String get homeBreakdownIntro;

  /// No description provided for @homeBreakdownEmptyOthers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} other known address holds nothing.} other{{count} other known addresses hold nothing.}}'**
  String homeBreakdownEmptyOthers(int count);

  /// No description provided for @homeLongPressCopy.
  ///
  /// In en, this message translates to:
  /// **'Long press to copy'**
  String get homeLongPressCopy;

  /// No description provided for @homeNameAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Names this address. Long press to copy'**
  String get homeNameAddressHint;

  /// No description provided for @homeSpokenShownAs.
  ///
  /// In en, this message translates to:
  /// **'shown as this wallet'**
  String get homeSpokenShownAs;

  /// No description provided for @homeShownAs.
  ///
  /// In en, this message translates to:
  /// **'Shown as this wallet'**
  String get homeShownAs;

  /// No description provided for @homeAllWallets.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get homeAllWallets;

  /// No description provided for @homeOtherAddressesHint.
  ///
  /// In en, this message translates to:
  /// **'Shows each address and what it holds'**
  String get homeOtherAddressesHint;

  /// No description provided for @homeUtxos.
  ///
  /// In en, this message translates to:
  /// **'UTXOs'**
  String get homeUtxos;

  /// count is already formatted with thousands separators.
  ///
  /// In en, this message translates to:
  /// **'{count} UTXOs'**
  String homeUtxoCount(String count);

  /// No description provided for @homeUtxoTools.
  ///
  /// In en, this message translates to:
  /// **'UTXO tools'**
  String get homeUtxoTools;

  /// No description provided for @homeSpokenFragmented.
  ///
  /// In en, this message translates to:
  /// **'{utxos}, fragmented. Tidy up'**
  String homeSpokenFragmented(String utxos);

  /// No description provided for @homeTidyUp.
  ///
  /// In en, this message translates to:
  /// **'Tidy up'**
  String get homeTidyUp;

  /// No description provided for @homeFragmented.
  ///
  /// In en, this message translates to:
  /// **'Fragmented'**
  String get homeFragmented;

  /// No description provided for @homeAllAssets.
  ///
  /// In en, this message translates to:
  /// **'All assets'**
  String get homeAllAssets;

  /// No description provided for @homeAllAssetsCount.
  ///
  /// In en, this message translates to:
  /// **'All {count} assets'**
  String homeAllAssetsCount(String count);

  /// No description provided for @homeRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get homeRecentActivity;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// No description provided for @homeReadingActivity.
  ///
  /// In en, this message translates to:
  /// **'Reading activity'**
  String get homeReadingActivity;

  /// No description provided for @homeReadingActivityEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Reading activity…'**
  String get homeReadingActivityEllipsis;

  /// No description provided for @homeFullHistory.
  ///
  /// In en, this message translates to:
  /// **'Full history'**
  String get homeFullHistory;

  /// No description provided for @homeEveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Every address and what it holds'**
  String get homeEveryAddress;

  /// No description provided for @homeNoAddresses.
  ///
  /// In en, this message translates to:
  /// **'No addresses read yet'**
  String get homeNoAddresses;

  /// No description provided for @homeNoAddressesDot.
  ///
  /// In en, this message translates to:
  /// **'No addresses read yet.'**
  String get homeNoAddressesDot;

  /// No description provided for @homeSpokenCountFragmented.
  ///
  /// In en, this message translates to:
  /// **'{count}, fragmented'**
  String homeSpokenCountFragmented(String count);

  /// No description provided for @homeAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get homeAssets;

  /// No description provided for @homeShowMyAddress.
  ///
  /// In en, this message translates to:
  /// **'Show my address'**
  String get homeShowMyAddress;

  /// No description provided for @homeNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get homeNoActivity;

  /// No description provided for @activityTitleReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get activityTitleReceived;

  /// No description provided for @activityTitleSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get activityTitleSent;

  /// No description provided for @activityTitleMoved.
  ///
  /// In en, this message translates to:
  /// **'Moved'**
  String get activityTitleMoved;

  /// No description provided for @activityTitleConsolidated.
  ///
  /// In en, this message translates to:
  /// **'Consolidated'**
  String get activityTitleConsolidated;

  /// No description provided for @activityTitleBurned.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Burned token} other{Burned tokens}}'**
  String activityTitleBurned(int count);

  /// No description provided for @activityTitleIssued.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Issued token} other{Issued tokens}}'**
  String activityTitleIssued(int count);

  /// No description provided for @activityTitleContractInteraction.
  ///
  /// In en, this message translates to:
  /// **'Contract interaction'**
  String get activityTitleContractInteraction;

  /// No description provided for @activityTitleContract.
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get activityTitleContract;

  /// No description provided for @activityFrom.
  ///
  /// In en, this message translates to:
  /// **'from {address}'**
  String activityFrom(String address);

  /// No description provided for @activityFromContract.
  ///
  /// In en, this message translates to:
  /// **'from contract {address}'**
  String activityFromContract(String address);

  /// No description provided for @activityTo.
  ///
  /// In en, this message translates to:
  /// **'to {address}'**
  String activityTo(String address);

  /// No description provided for @activityToContract.
  ///
  /// In en, this message translates to:
  /// **'to contract {address}'**
  String activityToContract(String address);

  /// No description provided for @activityContract.
  ///
  /// In en, this message translates to:
  /// **'contract {address}'**
  String activityContract(String address);

  /// who is 'from 9fRx…3kQe' or 'to contract …'; count is how many other addresses.
  ///
  /// In en, this message translates to:
  /// **'{who} and {count} more'**
  String activityAndMore(String who, String count);

  /// No description provided for @activityArgusAppFee.
  ///
  /// In en, this message translates to:
  /// **'Argus app fee'**
  String get activityArgusAppFee;

  /// No description provided for @activityBetweenYourAddresses.
  ///
  /// In en, this message translates to:
  /// **'between your addresses'**
  String get activityBetweenYourAddresses;

  /// Before an amount: 'Fee 0.0011 ERG'. Shown lowercased as the second figure of a row.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get activityFeeLabel;

  /// No description provided for @activityMoreTokens.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} more token} other{{count} more tokens}}'**
  String activityMoreTokens(int count);

  /// No description provided for @activityPlusMore.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String activityPlusMore(String count);

  /// No description provided for @activityScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityScreenTitle;

  /// No description provided for @activityPartial.
  ///
  /// In en, this message translates to:
  /// **'Some addresses could not be checked. Activity is incomplete.'**
  String get activityPartial;

  /// No description provided for @activityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load activity: {error}'**
  String activityLoadFailed(String error);

  /// No description provided for @activityLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load older activity: {error}'**
  String activityLoadMoreFailed(String error);

  /// No description provided for @activityNoneToExport.
  ///
  /// In en, this message translates to:
  /// **'No transactions to export'**
  String get activityNoneToExport;

  /// No description provided for @activityExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String activityExportFailed(String error);

  /// count is a number, followed by + when more can be loaded.
  ///
  /// In en, this message translates to:
  /// **'{count} transactions'**
  String activityCount(String count);

  /// No description provided for @activityExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get activityExportCsv;

  /// No description provided for @activityEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get activityEmptyTitle;

  /// No description provided for @activityEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Transactions to and from this wallet will show up here, newest first.'**
  String get activityEmptyBody;

  /// No description provided for @activityRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get activityRefresh;

  /// No description provided for @ergopayErrorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the dApp: {detail}'**
  String ergopayErrorUnreachable(String detail);

  /// No description provided for @ergopayErrorHttp.
  ///
  /// In en, this message translates to:
  /// **'The dApp answered HTTP {status}'**
  String ergopayErrorHttp(String status);

  /// No description provided for @ergopayErrorUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The dApp sent an unreadable signing request'**
  String get ergopayErrorUnreadable;

  /// No description provided for @ergopayErrorNotify.
  ///
  /// In en, this message translates to:
  /// **'Could not notify the dApp: {detail}'**
  String ergopayErrorNotify(String detail);

  /// No description provided for @ergopayErrorReplyRejected.
  ///
  /// In en, this message translates to:
  /// **'The dApp rejected the reply (HTTP {status})'**
  String ergopayErrorReplyRejected(String status);

  /// No description provided for @ergopayWarningInputsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Input values could not be fetched from the node, so the total you spend is unknown. Check the outputs carefully.'**
  String get ergopayWarningInputsUnknown;

  /// No description provided for @ergopayWarningForeignInputs.
  ///
  /// In en, this message translates to:
  /// **'Some inputs are not from this wallet. The dApp is adding its own boxes to this transaction.'**
  String get ergopayWarningForeignInputs;

  /// No description provided for @ergopayRowRecipients.
  ///
  /// In en, this message translates to:
  /// **'Recipients'**
  String get ergopayRowRecipients;

  /// No description provided for @ergopayRowSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get ergopayRowSent;

  /// No description provided for @ergopayRowTokensOut.
  ///
  /// In en, this message translates to:
  /// **'Tokens out'**
  String get ergopayRowTokensOut;

  /// No description provided for @ergopayRowChange.
  ///
  /// In en, this message translates to:
  /// **'Change to you'**
  String get ergopayRowChange;

  /// No description provided for @ergopayRowYouSpend.
  ///
  /// In en, this message translates to:
  /// **'You spend'**
  String get ergopayRowYouSpend;

  /// No description provided for @ergopayRowInputs.
  ///
  /// In en, this message translates to:
  /// **'Inputs'**
  String get ergopayRowInputs;

  /// No description provided for @ergopayStatusContacting.
  ///
  /// In en, this message translates to:
  /// **'Contacting the dApp…'**
  String get ergopayStatusContacting;

  /// No description provided for @ergopayNotALink.
  ///
  /// In en, this message translates to:
  /// **'This is not an ErgoPay link.'**
  String get ergopayNotALink;

  /// No description provided for @ergopayWrongAddress.
  ///
  /// In en, this message translates to:
  /// **'This request is for {address}, which is not an address of this wallet.'**
  String ergopayWrongAddress(String address);

  /// No description provided for @ergopayStatusReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the transaction…'**
  String get ergopayStatusReading;

  /// No description provided for @ergopayPickAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Which address should the dApp use?'**
  String get ergopayPickAddressTitle;

  /// No description provided for @ergopayMainAddress.
  ///
  /// In en, this message translates to:
  /// **'Main address'**
  String get ergopayMainAddress;

  /// No description provided for @ergopaySignTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign for dApp'**
  String get ergopaySignTitle;

  /// No description provided for @ergopayNodeNotChosen.
  ///
  /// In en, this message translates to:
  /// **'Node not chosen yet'**
  String get ergopayNodeNotChosen;

  /// No description provided for @ergopayStatusSigning.
  ///
  /// In en, this message translates to:
  /// **'Signing…'**
  String get ergopayStatusSigning;

  /// No description provided for @ergopayStatusBroadcasting.
  ///
  /// In en, this message translates to:
  /// **'Broadcasting…'**
  String get ergopayStatusBroadcasting;

  /// No description provided for @ergopayStatusNotifying.
  ///
  /// In en, this message translates to:
  /// **'Telling the dApp…'**
  String get ergopayStatusNotifying;

  /// Headline after a transaction (feminine in Spanish) was signed and broadcast.
  ///
  /// In en, this message translates to:
  /// **'Signed and sent'**
  String get ergopaySignedAndSent;

  /// No description provided for @ergopayNoTransaction.
  ///
  /// In en, this message translates to:
  /// **'The dApp did not send a transaction to sign.'**
  String get ergopayNoTransaction;

  /// No description provided for @ergopayThisTransaction.
  ///
  /// In en, this message translates to:
  /// **'This transaction'**
  String get ergopayThisTransaction;

  /// No description provided for @ergopayReviewAndSign.
  ///
  /// In en, this message translates to:
  /// **'Review & sign'**
  String get ergopayReviewAndSign;

  /// No description provided for @ergopayDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get ergopayDecline;

  /// No description provided for @ergopayNotifyFailed.
  ///
  /// In en, this message translates to:
  /// **'The transaction is on the network, but the dApp could not be notified: {error}'**
  String ergopayNotifyFailed(String error);

  /// No description provided for @errorSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorSomethingWentWrong;

  /// No description provided for @errorCopied.
  ///
  /// In en, this message translates to:
  /// **'Error copied'**
  String get errorCopied;

  /// No description provided for @errorContractRejected.
  ///
  /// In en, this message translates to:
  /// **'A contract rejected this transaction, so it was not signed. Nothing was sent.'**
  String get errorContractRejected;

  /// No description provided for @errorNothingSent.
  ///
  /// In en, this message translates to:
  /// **'Nothing was sent.'**
  String get errorNothingSent;

  /// No description provided for @errorSigningFailed.
  ///
  /// In en, this message translates to:
  /// **'Signing failed'**
  String get errorSigningFailed;

  /// No description provided for @errorBroadcastMayHaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Broadcast may have failed'**
  String get errorBroadcastMayHaveFailed;

  /// No description provided for @errorCheckActivity.
  ///
  /// In en, this message translates to:
  /// **'Check Activity before retrying; the transaction may already be on the network.'**
  String get errorCheckActivity;

  /// No description provided for @contactsNoneToExport.
  ///
  /// In en, this message translates to:
  /// **'No contacts to export'**
  String get contactsNoneToExport;

  /// No description provided for @contactsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String contactsExportFailed(String error);

  /// No description provided for @contactsSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select contact'**
  String get contactsSelectTitle;

  /// No description provided for @contactsExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export contacts'**
  String get contactsExportTooltip;

  /// No description provided for @contactsEmptySelect.
  ///
  /// In en, this message translates to:
  /// **'No saved contacts yet.'**
  String get contactsEmptySelect;

  /// No description provided for @contactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved contacts yet.\nTap + to add one.'**
  String get contactsEmpty;

  /// No description provided for @contactsYourWallets.
  ///
  /// In en, this message translates to:
  /// **'Your wallets'**
  String get contactsYourWallets;

  /// No description provided for @contactsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete contact?'**
  String get contactsDeleteTitle;

  /// No description provided for @contactsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get contactsDelete;

  /// No description provided for @contactsInvalidAddress.
  ///
  /// In en, this message translates to:
  /// **'Not a valid Ergo address'**
  String get contactsInvalidAddress;

  /// No description provided for @contactsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get contactsAddTitle;

  /// No description provided for @contactsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit contact'**
  String get contactsEditTitle;

  /// No description provided for @contactsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get contactsAdd;

  /// No description provided for @createPhraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'Confirmation does not match the recovery phrase'**
  String get createPhraseMismatch;

  /// No description provided for @createSkipTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip the check?'**
  String get createSkipTitle;

  /// No description provided for @createSkipBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing will prove that your written phrase is complete and in order. If a word is wrong or missing, the funds of this wallet cannot be recovered.'**
  String get createSkipBody;

  /// No description provided for @createSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get createSkip;

  /// No description provided for @createFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not create the wallet'**
  String get createFailedTitle;

  /// No description provided for @createTitle.
  ///
  /// In en, this message translates to:
  /// **'Create wallet'**
  String get createTitle;

  /// No description provided for @createWriteDownTitle.
  ///
  /// In en, this message translates to:
  /// **'Write these words down'**
  String get createWriteDownTitle;

  /// No description provided for @createWriteDownBody.
  ///
  /// In en, this message translates to:
  /// **'Paper only. They are the only way to recover this wallet. Android blocks screenshots here; iOS hides the app in the switcher and during screen recording.'**
  String get createWriteDownBody;

  /// No description provided for @createGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate recovery phrase'**
  String get createGenerate;

  /// No description provided for @createHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get createHide;

  /// No description provided for @createReveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get createReveal;

  /// No description provided for @createWroteDown.
  ///
  /// In en, this message translates to:
  /// **'I wrote these down'**
  String get createWroteDown;

  /// No description provided for @createConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm the phrase'**
  String get createConfirmTitle;

  /// No description provided for @createConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Type the words back in order. This proves the backup is readable.'**
  String get createConfirmBody;

  /// No description provided for @createPhraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase'**
  String get createPhraseLabel;

  /// No description provided for @createContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get createContinue;

  /// No description provided for @createSkipCheck.
  ///
  /// In en, this message translates to:
  /// **'Skip this check'**
  String get createSkipCheck;

  /// No description provided for @createSetPin.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get createSetPin;

  /// No description provided for @createPinBody.
  ///
  /// In en, this message translates to:
  /// **'The PIN unwraps the key on this device. It is not a backup.'**
  String get createPinBody;

  /// No description provided for @createReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace existing wallet?'**
  String get createReplaceTitle;

  /// No description provided for @createReplaceBody.
  ///
  /// In en, this message translates to:
  /// **'A wallet is already stored on this device. Replacing it overwrites the encrypted seed. The recovery phrase is the only way to recover the old wallet.'**
  String get createReplaceBody;

  /// No description provided for @createReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get createReplace;

  /// No description provided for @createScreenshotBlockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Screenshot blocking is unavailable on this device'**
  String get createScreenshotBlockUnavailable;

  /// No description provided for @restoreEnterPhrase.
  ///
  /// In en, this message translates to:
  /// **'Enter a recovery phrase'**
  String get restoreEnterPhrase;

  /// No description provided for @restoreWordCount.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase must be 12, 15, 18, 21, or 24 words'**
  String get restoreWordCount;

  /// No description provided for @restoreFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the wallet'**
  String get restoreFailedTitle;

  /// No description provided for @restoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore wallet'**
  String get restoreTitle;

  /// No description provided for @restoreIntro.
  ///
  /// In en, this message translates to:
  /// **'12, 15, 18, 21, or 24 words, in order — 15 is the Ergo standard. Optional BIP-39 passphrase if you used one.'**
  String get restoreIntro;

  /// No description provided for @restorePhraseHint.
  ///
  /// In en, this message translates to:
  /// **'12, 15, 18, 21, or 24 words'**
  String get restorePhraseHint;

  /// No description provided for @restorePassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'BIP-39 passphrase (optional)'**
  String get restorePassphraseLabel;

  /// No description provided for @restoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreButton;

  /// address is a shortened address (feminine in Spanish).
  ///
  /// In en, this message translates to:
  /// **'{address} copied'**
  String receiveCopied(String address);

  /// No description provided for @receiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receiveTitle;

  /// No description provided for @receiveUnusedAddress.
  ///
  /// In en, this message translates to:
  /// **'Unused address'**
  String get receiveUnusedAddress;

  /// No description provided for @receiveAddress.
  ///
  /// In en, this message translates to:
  /// **'Receive address'**
  String get receiveAddress;

  /// No description provided for @receiveFreshNote.
  ///
  /// In en, this message translates to:
  /// **'A new address is shown after this one is used.'**
  String get receiveFreshNote;

  /// Fresh addresses is the name of a switch in Settings.
  ///
  /// In en, this message translates to:
  /// **'This address stays the same. Turn on Fresh addresses in Settings to use a new one after each payment.'**
  String get receiveStaticNote;

  /// No description provided for @receiveAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Optional amount (ERG)'**
  String get receiveAmountLabel;

  /// No description provided for @receiveAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add label'**
  String get receiveAddLabel;

  /// No description provided for @receiveEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit label'**
  String get receiveEditLabel;

  /// No description provided for @receiveCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get receiveCopyAddress;

  /// No description provided for @receiveShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get receiveShare;

  /// No description provided for @receiveUsedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Used addresses'**
  String get receiveUsedAddresses;

  /// No description provided for @receiveUsedAddressesNote.
  ///
  /// In en, this message translates to:
  /// **'Older addresses keep working; tap one to copy it.'**
  String get receiveUsedAddressesNote;

  /// No description provided for @receiveAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Amount must be a decimal number, like 0.001'**
  String get receiveAmountInvalid;

  /// No description provided for @receiveAmountNotPositive.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero'**
  String get receiveAmountNotPositive;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanTitle;

  /// No description provided for @scanCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is unavailable. Allow camera access and try again.'**
  String get scanCameraUnavailable;

  /// No description provided for @scanBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get scanBack;

  /// No description provided for @txArgusFee.
  ///
  /// In en, this message translates to:
  /// **'Argus fee'**
  String get txArgusFee;

  /// No description provided for @txLeftWallet.
  ///
  /// In en, this message translates to:
  /// **'Left your wallet'**
  String get txLeftWallet;

  /// No description provided for @txBurned.
  ///
  /// In en, this message translates to:
  /// **'Burned'**
  String get txBurned;

  /// No description provided for @txBurnedNote.
  ///
  /// In en, this message translates to:
  /// **'No output holds these any more: they no longer exist.'**
  String get txBurnedNote;

  /// No description provided for @txIssued.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get txIssued;

  /// No description provided for @txArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get txArrived;

  /// No description provided for @txFees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get txFees;

  /// No description provided for @txMovedBetween.
  ///
  /// In en, this message translates to:
  /// **'Moved between your addresses'**
  String get txMovedBetween;

  /// No description provided for @txMovedNote.
  ///
  /// In en, this message translates to:
  /// **'Change and boxes that stayed in this wallet.'**
  String get txMovedNote;

  /// No description provided for @txTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get txTo;

  /// No description provided for @txFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get txFrom;

  /// No description provided for @txContract.
  ///
  /// In en, this message translates to:
  /// **'Contract'**
  String get txContract;

  /// No description provided for @txIncompleteInputs.
  ///
  /// In en, this message translates to:
  /// **'Some inputs of this pending transaction are not readable yet; what the other side put in may be missing.'**
  String get txIncompleteInputs;

  /// No description provided for @txSentAmount.
  ///
  /// In en, this message translates to:
  /// **'Sent {amount}'**
  String txSentAmount(String amount);

  /// No description provided for @txReceivedAmount.
  ///
  /// In en, this message translates to:
  /// **'Received {amount}'**
  String txReceivedAmount(String amount);

  /// No description provided for @txTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get txTitle;

  /// height is the block height, like #1856438.
  ///
  /// In en, this message translates to:
  /// **'Confirmed {height}'**
  String txConfirmedAt(String height);

  /// No description provided for @txConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get txConfirmed;

  /// No description provided for @txNotInBlock.
  ///
  /// In en, this message translates to:
  /// **'Not yet in a block'**
  String get txNotInBlock;

  /// No description provided for @txTokensSent.
  ///
  /// In en, this message translates to:
  /// **'Tokens sent'**
  String get txTokensSent;

  /// No description provided for @txIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Id'**
  String get txIdLabel;

  /// No description provided for @txTokensReceived.
  ///
  /// In en, this message translates to:
  /// **'Tokens received'**
  String get txTokensReceived;

  /// No description provided for @txFurtherTokenIds.
  ///
  /// In en, this message translates to:
  /// **'{count} further token id(s) involved — see explorer.'**
  String txFurtherTokenIds(String count);

  /// No description provided for @txIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Transaction id copied'**
  String get txIdCopied;

  /// No description provided for @txExplorerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open explorer'**
  String get txExplorerFailed;

  /// No description provided for @txOpenExplorer.
  ///
  /// In en, this message translates to:
  /// **'Open in explorer'**
  String get txOpenExplorer;

  /// No description provided for @txDetailsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the transaction details: {error}'**
  String txDetailsLoadFailed(String error);

  /// No description provided for @txChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get txChange;

  /// No description provided for @txInputsCount.
  ///
  /// In en, this message translates to:
  /// **'Inputs ({count})'**
  String txInputsCount(String count);

  /// An input (feminine in Spanish) owned by this wallet.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get txYours;

  /// No description provided for @txInput.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get txInput;

  /// No description provided for @txValueUnknown.
  ///
  /// In en, this message translates to:
  /// **'value unknown'**
  String get txValueUnknown;

  /// No description provided for @txOutputsCount.
  ///
  /// In en, this message translates to:
  /// **'Outputs ({count})'**
  String txOutputsCount(String count);

  /// Label of the miner fee line under Fees.
  ///
  /// In en, this message translates to:
  /// **'Miner'**
  String get txMiner;

  /// No description provided for @txDataInputsCount.
  ///
  /// In en, this message translates to:
  /// **'Data inputs ({count})'**
  String txDataInputsCount(String count);

  /// No description provided for @txBox.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get txBox;

  /// No description provided for @txIdHeading.
  ///
  /// In en, this message translates to:
  /// **'Transaction id'**
  String get txIdHeading;

  /// No description provided for @txUnsignedCopied.
  ///
  /// In en, this message translates to:
  /// **'Unsigned transaction copied'**
  String get txUnsignedCopied;

  /// No description provided for @txCopyUnsigned.
  ///
  /// In en, this message translates to:
  /// **'Copy unsigned transaction'**
  String get txCopyUnsigned;

  /// No description provided for @dialogBiometricTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics?'**
  String get dialogBiometricTitle;

  /// No description provided for @dialogBiometricBody.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or face to unlock this wallet instead of typing the PIN each time. You can change this later under Settings › Security.'**
  String get dialogBiometricBody;

  /// No description provided for @dialogNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get dialogNotNow;

  /// No description provided for @dialogEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get dialogEnable;

  /// No description provided for @dialogBiometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock enabled'**
  String get dialogBiometricEnabled;

  /// No description provided for @dialogBiometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not enable biometrics; try again under Settings › Security'**
  String get dialogBiometricFailed;

  /// No description provided for @entryCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get entryCurrentPin;

  /// No description provided for @entryContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get entryContinue;

  /// No description provided for @labelDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Address label'**
  String get labelDialogTitle;

  /// No description provided for @labelOptional.
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get labelOptional;

  /// No description provided for @coreTokenMetadataInvalid.
  ///
  /// In en, this message translates to:
  /// **'Metadata invalid'**
  String get coreTokenMetadataInvalid;

  /// No description provided for @coreTokenMetadataConflict.
  ///
  /// In en, this message translates to:
  /// **'Metadata conflict'**
  String get coreTokenMetadataConflict;

  /// No description provided for @coreTokenCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection token'**
  String get coreTokenCollection;

  /// No description provided for @coreTokenDeclaredNftUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Declared NFT · unsupported type'**
  String get coreTokenDeclaredNftUnsupported;

  /// kind is the declared asset kind as the code names it (picture, audio, video…).
  ///
  /// In en, this message translates to:
  /// **'Single-unit artwork · {kind}'**
  String coreTokenSingleUnitArtwork(String kind);

  /// No description provided for @coreTokenDeclaredArtworkMultiple.
  ///
  /// In en, this message translates to:
  /// **'Declared artwork · multiple units'**
  String get coreTokenDeclaredArtworkMultiple;

  /// No description provided for @coreTokenDeclaredArtworkUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Declared artwork · supply unconfirmed'**
  String get coreTokenDeclaredArtworkUnconfirmed;

  /// No description provided for @coreTokenSingleUnit.
  ///
  /// In en, this message translates to:
  /// **'Single-unit token'**
  String get coreTokenSingleUnit;

  /// No description provided for @coreTokenMetadataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Token · metadata unavailable'**
  String get coreTokenMetadataUnavailable;

  /// No description provided for @corePinLength.
  ///
  /// In en, this message translates to:
  /// **'PIN must be 6-32 characters'**
  String get corePinLength;

  /// Default name of a new wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet {number}'**
  String coreWalletNumbered(String number);

  /// No description provided for @coreCuratedTokenSource.
  ///
  /// In en, this message translates to:
  /// **'Argus curated token list'**
  String get coreCuratedTokenSource;

  /// No description provided for @coreBroadcastActivityWarning.
  ///
  /// In en, this message translates to:
  /// **'Transaction submitted, but Activity could not be updated: {error}. Keep this transaction ID.'**
  String coreBroadcastActivityWarning(String error);

  /// No description provided for @coreActivityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load activity'**
  String get coreActivityLoadFailed;

  /// No description provided for @coreWalletLocked.
  ///
  /// In en, this message translates to:
  /// **'Wallet is locked'**
  String get coreWalletLocked;

  /// No description provided for @holdingsTokenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 token} other{{count} tokens}}'**
  String holdingsTokenCount(int count);

  /// parts: the ERG amount and/or the token count, joined by ' · '.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{incl. {parts} on 1 other address} other{incl. {parts} on {count} other addresses}}'**
  String holdingsFundsElsewhere(String parts, int count);

  /// No description provided for @holdingsFundsElsewhereHidden.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{incl. funds on 1 other address} other{incl. funds on {count} other addresses}}'**
  String holdingsFundsElsewhereHidden(int count);

  /// No description provided for @previewGatewayOriginRule.
  ///
  /// In en, this message translates to:
  /// **'Use an HTTPS gateway origin on port 443, without credentials, path or query.'**
  String get previewGatewayOriginRule;

  /// No description provided for @previewGatewayNotPublic.
  ///
  /// In en, this message translates to:
  /// **'Gateway address is not public.'**
  String get previewGatewayNotPublic;

  /// No description provided for @previewGatewayPublicHostname.
  ///
  /// In en, this message translates to:
  /// **'Use a public gateway hostname.'**
  String get previewGatewayPublicHostname;

  /// No description provided for @previewCidMalformed.
  ///
  /// In en, this message translates to:
  /// **'Malformed IPFS CID.'**
  String get previewCidMalformed;

  /// No description provided for @previewOnlyIpfs.
  ///
  /// In en, this message translates to:
  /// **'Only IPFS artwork can be displayed. Issuer hosts are refused because the issuer would choose who learns you looked.'**
  String get previewOnlyIpfs;

  /// No description provided for @previewCidNoncanonical.
  ///
  /// In en, this message translates to:
  /// **'Noncanonical IPFS CID.'**
  String get previewCidNoncanonical;

  /// No description provided for @previewCidUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported IPFS CID.'**
  String get previewCidUnsupported;

  /// No description provided for @previewCidFormat.
  ///
  /// In en, this message translates to:
  /// **'Use a CIDv0 or lowercase base32 CIDv1 IPFS URI.'**
  String get previewCidFormat;

  /// No description provided for @previewPathUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported IPFS path.'**
  String get previewPathUnsupported;

  /// No description provided for @previewImageDimensions.
  ///
  /// In en, this message translates to:
  /// **'Image dimensions exceed 4096 per axis or 8 megapixels.'**
  String get previewImageDimensions;

  /// No description provided for @previewArtworkTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Artwork exceeds 5 MiB.'**
  String get previewArtworkTooLarge;

  /// No description provided for @previewPngMalformed.
  ///
  /// In en, this message translates to:
  /// **'Malformed PNG.'**
  String get previewPngMalformed;

  /// No description provided for @previewPngAnimated.
  ///
  /// In en, this message translates to:
  /// **'Animated PNG is unsupported.'**
  String get previewPngAnimated;

  /// No description provided for @previewJpegMalformed.
  ///
  /// In en, this message translates to:
  /// **'Malformed JPEG.'**
  String get previewJpegMalformed;

  /// No description provided for @previewJpegFrame.
  ///
  /// In en, this message translates to:
  /// **'Unsupported JPEG frame.'**
  String get previewJpegFrame;

  /// No description provided for @previewFormatMismatch.
  ///
  /// In en, this message translates to:
  /// **'Only static PNG and JPEG with matching bytes and MIME are supported.'**
  String get previewFormatMismatch;

  /// No description provided for @previewHashMismatch.
  ///
  /// In en, this message translates to:
  /// **'Content differs from issuance hash.'**
  String get previewHashMismatch;

  /// No description provided for @previewSaveSettingFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save preview setting.'**
  String get previewSaveSettingFailed;

  /// No description provided for @previewSaveGatewayFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save gateway.'**
  String get previewSaveGatewayFailed;

  /// No description provided for @previewRequestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Preview request timed out.'**
  String get previewRequestTimedOut;

  /// No description provided for @previewConnectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Preview connection timed out.'**
  String get previewConnectionTimedOut;

  /// No description provided for @previewCancelled.
  ///
  /// In en, this message translates to:
  /// **'Preview cancelled.'**
  String get previewCancelled;

  /// No description provided for @previewConnectionRefused.
  ///
  /// In en, this message translates to:
  /// **'Preview connection refused.'**
  String get previewConnectionRefused;

  /// No description provided for @previewHostBindingFailed.
  ///
  /// In en, this message translates to:
  /// **'Gateway hostname binding failed.'**
  String get previewHostBindingFailed;

  /// No description provided for @previewRedirectBlocked.
  ///
  /// In en, this message translates to:
  /// **'Redirect blocked.'**
  String get previewRedirectBlocked;

  /// No description provided for @previewNoArtwork.
  ///
  /// In en, this message translates to:
  /// **'Gateway did not return artwork.'**
  String get previewNoArtwork;

  /// No description provided for @previewCompressionRefused.
  ///
  /// In en, this message translates to:
  /// **'Transport compression refused.'**
  String get previewCompressionRefused;

  /// No description provided for @previewStaticOnly.
  ///
  /// In en, this message translates to:
  /// **'Only static PNG and JPEG are supported.'**
  String get previewStaticOnly;

  /// No description provided for @previewBusy.
  ///
  /// In en, this message translates to:
  /// **'Another preview is still finishing.'**
  String get previewBusy;

  /// No description provided for @previewIntegrityConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'View without integrity check requires explicit consent.'**
  String get previewIntegrityConsentRequired;

  /// No description provided for @previewAnimatedUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Animated artwork is unsupported.'**
  String get previewAnimatedUnsupported;

  /// No description provided for @previewDecodedTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Decoded preview exceeds target size.'**
  String get previewDecodedTooLarge;

  /// No description provided for @previewLoadThroughTitle.
  ///
  /// In en, this message translates to:
  /// **'Load preview through {host}?'**
  String previewLoadThroughTitle(String host);

  /// No description provided for @previewLoadConsentBody.
  ///
  /// In en, this message translates to:
  /// **'This gateway can see your IP address and which artwork was requested. Up to 5 MiB will be downloaded. Artwork may contain unsolicited or misleading content.'**
  String get previewLoadConsentBody;

  /// No description provided for @previewLoad.
  ///
  /// In en, this message translates to:
  /// **'Load preview'**
  String get previewLoad;

  /// No description provided for @previewHashMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Issuance hash missing or invalid'**
  String get previewHashMissingTitle;

  /// No description provided for @previewHashMissingBody.
  ///
  /// In en, this message translates to:
  /// **'The format and dimensions passed the preview checks, but these bytes cannot be compared with an issuance hash.'**
  String get previewHashMissingBody;

  /// No description provided for @previewViewWithoutIntegrity.
  ///
  /// In en, this message translates to:
  /// **'View without integrity check'**
  String get previewViewWithoutIntegrity;

  /// No description provided for @previewMatchesHash.
  ///
  /// In en, this message translates to:
  /// **'Matches issuance hash'**
  String get previewMatchesHash;

  /// No description provided for @previewViewedWithoutIntegrity.
  ///
  /// In en, this message translates to:
  /// **'Viewed without integrity check'**
  String get previewViewedWithoutIntegrity;

  /// No description provided for @previewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Preview could not be loaded.'**
  String get previewLoadFailed;

  /// No description provided for @previewMetadataUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Preview not supported for this metadata.'**
  String get previewMetadataUnsupported;

  /// No description provided for @previewDisabled.
  ///
  /// In en, this message translates to:
  /// **'Remote previews disabled.'**
  String get previewDisabled;

  /// No description provided for @previewNoGateway.
  ///
  /// In en, this message translates to:
  /// **'No gateway configured. Previews are unavailable.'**
  String get previewNoGateway;

  /// No description provided for @previewUnavailableNow.
  ///
  /// In en, this message translates to:
  /// **'Previews unavailable while locked, hidden, offline or outside this session.'**
  String get previewUnavailableNow;

  /// No description provided for @previewViewArtwork.
  ///
  /// In en, this message translates to:
  /// **'View artwork'**
  String get previewViewArtwork;

  /// No description provided for @previewHide.
  ///
  /// In en, this message translates to:
  /// **'Hide preview'**
  String get previewHide;

  /// No description provided for @previewLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading preview…'**
  String get previewLoading;

  /// No description provided for @previewCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel preview'**
  String get previewCancel;

  /// No description provided for @previewSettingsLink.
  ///
  /// In en, this message translates to:
  /// **'Remote preview settings'**
  String get previewSettingsLink;

  /// No description provided for @previewGatewaySaved.
  ///
  /// In en, this message translates to:
  /// **'Gateway saved. Each artwork still requires consent.'**
  String get previewGatewaySaved;

  /// No description provided for @previewSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remote previews'**
  String get previewSettingsTitle;

  /// No description provided for @previewNeverTitle.
  ///
  /// In en, this message translates to:
  /// **'Never load remote previews'**
  String get previewNeverTitle;

  /// No description provided for @previewNeverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disables loading and clears open previews. Image decoding has no enforceable total allocation ceiling and an active native decode cannot be interrupted. Use this switch to avoid decoder memory or security risks.'**
  String get previewNeverSubtitle;

  /// No description provided for @previewSettingsIpfsOnly.
  ///
  /// In en, this message translates to:
  /// **'Only IPFS artwork can be displayed. Issuer-selected hosts are refused because the issuer would choose who learns you looked. There is no default gateway or fallback.'**
  String get previewSettingsIpfsOnly;

  /// No description provided for @previewGatewayFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Your HTTPS IPFS gateway'**
  String get previewGatewayFieldLabel;

  /// No description provided for @previewGatewayFieldHelper.
  ///
  /// In en, this message translates to:
  /// **'Origin only, port 443. Leave empty to remove.'**
  String get previewGatewayFieldHelper;

  /// No description provided for @previewGatewayCheckInfo.
  ///
  /// In en, this message translates to:
  /// **'Saving resolves the gateway hostname to check that its addresses are public. Loading checks again and connects only to that address. The gateway can see your IP and which artwork you request.'**
  String get previewGatewayCheckInfo;

  /// No description provided for @previewCheckingGateway.
  ///
  /// In en, this message translates to:
  /// **'Checking gateway…'**
  String get previewCheckingGateway;

  /// No description provided for @previewSaveGateway.
  ///
  /// In en, this message translates to:
  /// **'Save gateway'**
  String get previewSaveGateway;

  /// No description provided for @sendNoSpendableAddresses.
  ///
  /// In en, this message translates to:
  /// **'No spendable addresses'**
  String get sendNoSpendableAddresses;

  /// No description provided for @sendCouldNotListBoxes.
  ///
  /// In en, this message translates to:
  /// **'Could not list your boxes'**
  String get sendCouldNotListBoxes;

  /// No description provided for @sendContactName.
  ///
  /// In en, this message translates to:
  /// **'Contact: {name}'**
  String sendContactName(String name);

  /// No description provided for @sendSpendableUnknown.
  ///
  /// In en, this message translates to:
  /// **'Spendable balance is unknown'**
  String get sendSpendableUnknown;

  /// No description provided for @sendNotEnoughForFee.
  ///
  /// In en, this message translates to:
  /// **'Not enough ERG for fee and change'**
  String get sendNotEnoughForFee;

  /// No description provided for @sendNoTokenSelected.
  ///
  /// In en, this message translates to:
  /// **'No token selected'**
  String get sendNoTokenSelected;

  /// No description provided for @sendSaveToContacts.
  ///
  /// In en, this message translates to:
  /// **'Save to contacts'**
  String get sendSaveToContacts;

  /// No description provided for @sendContactSaved.
  ///
  /// In en, this message translates to:
  /// **'Contact saved'**
  String get sendContactSaved;

  /// No description provided for @sendExceedsBalance.
  ///
  /// In en, this message translates to:
  /// **'Amount plus fee exceeds your {balance}'**
  String sendExceedsBalance(String balance);

  /// No description provided for @sendCouldNotPrepare.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the send'**
  String get sendCouldNotPrepare;

  /// No description provided for @sendClipboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Clipboard holds another address'**
  String get sendClipboardTitle;

  /// No description provided for @sendClipboardDiffersOne.
  ///
  /// In en, this message translates to:
  /// **'Something you copied earlier is an Ergo address that differs from the recipient. Malware can swap addresses on the clipboard. Verify every character.'**
  String get sendClipboardDiffersOne;

  /// No description provided for @sendClipboardDiffersMany.
  ///
  /// In en, this message translates to:
  /// **'Something you copied earlier is an Ergo address that differs from every recipient. Malware can swap addresses on the clipboard. Verify every character.'**
  String get sendClipboardDiffersMany;

  /// No description provided for @sendRecipientLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient:'**
  String get sendRecipientLabel;

  /// No description provided for @sendRecipientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipients:'**
  String get sendRecipientsLabel;

  /// No description provided for @sendClipboardLabel.
  ///
  /// In en, this message translates to:
  /// **'Clipboard:'**
  String get sendClipboardLabel;

  /// No description provided for @sendGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get sendGoBack;

  /// No description provided for @sendRecipientCorrect.
  ///
  /// In en, this message translates to:
  /// **'Recipient is correct'**
  String get sendRecipientCorrect;

  /// No description provided for @sendRecipientsCorrect.
  ///
  /// In en, this message translates to:
  /// **'Recipients are correct'**
  String get sendRecipientsCorrect;

  /// No description provided for @sendTotalSent.
  ///
  /// In en, this message translates to:
  /// **'Total sent'**
  String get sendTotalSent;

  /// No description provided for @sendAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get sendAmount;

  /// No description provided for @sendFeePaidIn.
  ///
  /// In en, this message translates to:
  /// **'Miner fee paid in {token}'**
  String sendFeePaidIn(String token);

  /// Stands for a token whose name is unknown.
  ///
  /// In en, this message translates to:
  /// **'token'**
  String get sendTokenFallback;

  /// No description provided for @sendTokensFor.
  ///
  /// In en, this message translates to:
  /// **'{tokens} for {erg}'**
  String sendTokensFor(String tokens, String erg);

  /// No description provided for @sendConfirmMulti.
  ///
  /// In en, this message translates to:
  /// **'Confirm multi-recipient send'**
  String get sendConfirmMulti;

  /// No description provided for @sendConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm send'**
  String get sendConfirm;

  /// No description provided for @sendSent.
  ///
  /// In en, this message translates to:
  /// **'Sent!'**
  String get sendSent;

  /// No description provided for @sendAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available {amount}'**
  String sendAvailable(String amount);

  /// No description provided for @sendAllAddresses.
  ///
  /// In en, this message translates to:
  /// **'All {all} addresses'**
  String sendAllAddresses(String all);

  /// No description provided for @sendSomeAddresses.
  ///
  /// In en, this message translates to:
  /// **'{picked} of {all} addresses'**
  String sendSomeAddresses(String picked, String all);

  /// No description provided for @sendBoxesChosen.
  ///
  /// In en, this message translates to:
  /// **'{count} boxes chosen'**
  String sendBoxesChosen(String count);

  /// No description provided for @sendFeeErg.
  ///
  /// In en, this message translates to:
  /// **'Fee {amount} ERG'**
  String sendFeeErg(String amount);

  /// No description provided for @sendFeeIn.
  ///
  /// In en, this message translates to:
  /// **'Fee in {token}'**
  String sendFeeIn(String token);

  /// No description provided for @sendTokensPage.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens selected · Page {page} of {pages}'**
  String sendTokensPage(String count, String page, String pages);

  /// No description provided for @sendPreviousTokens.
  ///
  /// In en, this message translates to:
  /// **'Previous tokens'**
  String get sendPreviousTokens;

  /// No description provided for @sendNextTokens.
  ///
  /// In en, this message translates to:
  /// **'Next tokens'**
  String get sendNextTokens;

  /// No description provided for @sendSendsOne.
  ///
  /// In en, this message translates to:
  /// **'Sends 1 {token} · Available 1'**
  String sendSendsOne(String token);

  /// No description provided for @sendTokenAmount.
  ///
  /// In en, this message translates to:
  /// **'{token} amount'**
  String sendTokenAmount(String token);

  /// No description provided for @sendMax.
  ///
  /// In en, this message translates to:
  /// **'MAX'**
  String get sendMax;

  /// No description provided for @sendEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get sendEnterAmount;

  /// No description provided for @sendTooMuch.
  ///
  /// In en, this message translates to:
  /// **'Too much'**
  String get sendTooMuch;

  /// No description provided for @sendRemoveToken.
  ///
  /// In en, this message translates to:
  /// **'Remove {token}'**
  String sendRemoveToken(String token);

  /// No description provided for @sendPlusTokens.
  ///
  /// In en, this message translates to:
  /// **' + {count} tokens'**
  String sendPlusTokens(String count);

  /// No description provided for @sendRawTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw signed transaction'**
  String get sendRawTitle;

  /// No description provided for @sendRawNote.
  ///
  /// In en, this message translates to:
  /// **'Transaction is signed but not broadcast. Share or save the raw transaction to submit later via an explorer or another wallet.'**
  String get sendRawNote;

  /// No description provided for @sendDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get sendDestination;

  /// No description provided for @sendRecipientAddress.
  ///
  /// In en, this message translates to:
  /// **'Recipient address'**
  String get sendRecipientAddress;

  /// No description provided for @sendRecipientHint.
  ///
  /// In en, this message translates to:
  /// **'Or tap contacts to pick a saved one'**
  String get sendRecipientHint;

  /// No description provided for @sendRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get sendRequired;

  /// No description provided for @sendAsset.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get sendAsset;

  /// No description provided for @sendChooseTokens.
  ///
  /// In en, this message translates to:
  /// **'Choose tokens'**
  String get sendChooseTokens;

  /// No description provided for @sendChooseTokensCount.
  ///
  /// In en, this message translates to:
  /// **'Choose tokens ({count})'**
  String sendChooseTokensCount(String count);

  /// No description provided for @sendMinimumBox.
  ///
  /// In en, this message translates to:
  /// **'Minimum 0.001 ERG'**
  String get sendMinimumBox;

  /// No description provided for @sendErgWithIt.
  ///
  /// In en, this message translates to:
  /// **'ERG to send with it (optional)'**
  String get sendErgWithIt;

  /// No description provided for @sendBlankFundsTokens.
  ///
  /// In en, this message translates to:
  /// **'Blank funds the minimum ERG for these tokens. Review shows the exact amount. {available}'**
  String sendBlankFundsTokens(String available);

  /// No description provided for @sendAdditionalRecipients.
  ///
  /// In en, this message translates to:
  /// **'Additional recipients'**
  String get sendAdditionalRecipients;

  /// No description provided for @sendRecipientNAddress.
  ///
  /// In en, this message translates to:
  /// **'Recipient {number} address'**
  String sendRecipientNAddress(String number);

  /// No description provided for @sendAmountErg.
  ///
  /// In en, this message translates to:
  /// **'Amount (ERG)'**
  String get sendAmountErg;

  /// No description provided for @sendBlankFundsToken.
  ///
  /// In en, this message translates to:
  /// **'Blank funds the minimum ERG for this token.'**
  String get sendBlankFundsToken;

  /// No description provided for @sendTokenNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get sendTokenNone;

  /// No description provided for @sendEnterTokenAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a token amount'**
  String get sendEnterTokenAmount;

  /// No description provided for @sendYouHold.
  ///
  /// In en, this message translates to:
  /// **'You hold {amount}'**
  String sendYouHold(String amount);

  /// No description provided for @sendAddRecipient.
  ///
  /// In en, this message translates to:
  /// **'Add another recipient'**
  String get sendAddRecipient;

  /// No description provided for @sendAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sendAdvanced;

  /// No description provided for @sendErgCarried.
  ///
  /// In en, this message translates to:
  /// **'ERG carried with the token'**
  String get sendErgCarried;

  /// No description provided for @sendBlankMinimumBox.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for the minimum box value of {amount}.'**
  String sendBlankMinimumBox(String amount);

  /// No description provided for @sendChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get sendChoose;

  /// No description provided for @sendSpendFrom.
  ///
  /// In en, this message translates to:
  /// **'Spend from'**
  String get sendSpendFrom;

  /// No description provided for @sendDeselectedNote.
  ///
  /// In en, this message translates to:
  /// **'Deselected addresses are excluded from coin selection.'**
  String get sendDeselectedNote;

  /// No description provided for @sendUseAllAddresses.
  ///
  /// In en, this message translates to:
  /// **'Use all addresses'**
  String get sendUseAllAddresses;

  /// No description provided for @sendPayFeeIn.
  ///
  /// In en, this message translates to:
  /// **'Pay the miner fee in'**
  String get sendPayFeeIn;

  /// No description provided for @sendPayFeeInHelp.
  ///
  /// In en, this message translates to:
  /// **'A token fee is bought from a babel box on chain at its posted price; the ERG fee below is what it buys.'**
  String get sendPayFeeInHelp;

  /// No description provided for @sendMinerFeeErg.
  ///
  /// In en, this message translates to:
  /// **'Miner fee (ERG)'**
  String get sendMinerFeeErg;

  /// No description provided for @sendBlankDefaultFee.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for the default {amount}.'**
  String sendBlankDefaultFee(String amount);

  /// No description provided for @sendMinimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum {amount}'**
  String sendMinimum(String amount);

  /// No description provided for @sendReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get sendReview;

  /// No description provided for @sendChooseInputs.
  ///
  /// In en, this message translates to:
  /// **'Choose inputs'**
  String get sendChooseInputs;

  /// No description provided for @sendAutoInputsNote.
  ///
  /// In en, this message translates to:
  /// **'Chatui will pick boxes for you. Choose some to control exactly what this transaction spends.'**
  String get sendAutoInputsNote;

  /// No description provided for @sendShortBy.
  ///
  /// In en, this message translates to:
  /// **'Short by {amount} for this amount plus fees.'**
  String sendShortBy(String amount);

  /// No description provided for @sendBoxTokens.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 token} other{{count} tokens}}'**
  String sendBoxTokens(int count);

  /// No description provided for @sendBoxBlock.
  ///
  /// In en, this message translates to:
  /// **'block {height}'**
  String sendBoxBlock(String height);

  /// No description provided for @utxoLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load UTXOs: {error}'**
  String utxoLoadFailed(String error);

  /// No description provided for @utxoSpreadOut.
  ///
  /// In en, this message translates to:
  /// **'Your boxes are spread over many addresses, and merging them would link those addresses. Consolidate does it anyway.'**
  String get utxoSpreadOut;

  /// No description provided for @utxoNothingToClean.
  ///
  /// In en, this message translates to:
  /// **'Nothing to clean up right now'**
  String get utxoNothingToClean;

  /// No description provided for @utxoConsolidateNeedsTwo.
  ///
  /// In en, this message translates to:
  /// **'Consolidation needs at least 2 boxes'**
  String get utxoConsolidateNeedsTwo;

  /// No description provided for @utxoConsolidateTitle.
  ///
  /// In en, this message translates to:
  /// **'Consolidate UTXOs'**
  String get utxoConsolidateTitle;

  /// No description provided for @utxoConsolidateInN.
  ///
  /// In en, this message translates to:
  /// **'Consolidate in {count} transactions'**
  String utxoConsolidateInN(String count);

  /// No description provided for @utxoBoxesMerged.
  ///
  /// In en, this message translates to:
  /// **'Boxes merged'**
  String get utxoBoxesMerged;

  /// No description provided for @utxoInto.
  ///
  /// In en, this message translates to:
  /// **'Into'**
  String get utxoInto;

  /// No description provided for @utxoTotalValueIn.
  ///
  /// In en, this message translates to:
  /// **'Total value in'**
  String get utxoTotalValueIn;

  /// No description provided for @utxoTokenTypesCarried.
  ///
  /// In en, this message translates to:
  /// **'Token types carried'**
  String get utxoTokenTypesCarried;

  /// No description provided for @utxoValueAfterFees.
  ///
  /// In en, this message translates to:
  /// **'Value after fees'**
  String get utxoValueAfterFees;

  /// No description provided for @utxoConsolidateOneDetail.
  ///
  /// In en, this message translates to:
  /// **'Every selected box is spent into one new box holding all its ERG and tokens.'**
  String get utxoConsolidateOneDetail;

  /// No description provided for @utxoConsolidateManyDetail.
  ///
  /// In en, this message translates to:
  /// **'Ergo transactions are kept under {max} inputs each, so this runs as {count} transactions back to back. You can consolidate the results again afterwards.'**
  String utxoConsolidateManyDetail(String max, String count);

  /// No description provided for @utxoSignBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Sign & broadcast'**
  String get utxoSignBroadcast;

  /// No description provided for @utxoSignBroadcastN.
  ///
  /// In en, this message translates to:
  /// **'Sign & broadcast {count}'**
  String utxoSignBroadcastN(String count);

  /// No description provided for @utxoStoppedAfter.
  ///
  /// In en, this message translates to:
  /// **'Stopped after {done} of {total}. Refresh boxes and check Activity before retrying.'**
  String utxoStoppedAfter(String done, String total);

  /// No description provided for @utxoConsolidationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Consolidation submitted'**
  String get utxoConsolidationSubmitted;

  /// No description provided for @utxoRefreshBeforeRetry.
  ///
  /// In en, this message translates to:
  /// **'Refresh boxes and check Activity before retrying.'**
  String get utxoRefreshBeforeRetry;

  /// No description provided for @utxoFewDust.
  ///
  /// In en, this message translates to:
  /// **'Fewer than two dust boxes to sweep'**
  String get utxoFewDust;

  /// No description provided for @utxoNewRent.
  ///
  /// In en, this message translates to:
  /// **'{fee}, due {when}'**
  String utxoNewRent(String fee, String when);

  /// No description provided for @utxoNewRentCapped.
  ///
  /// In en, this message translates to:
  /// **'{fee}, due {when}; it holds no more than that'**
  String utxoNewRentCapped(String fee, String when);

  /// No description provided for @utxoSuggestedCleanup.
  ///
  /// In en, this message translates to:
  /// **'Suggested cleanup'**
  String get utxoSuggestedCleanup;

  /// No description provided for @utxoMergedAtAddress.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} at this address'**
  String utxoMergedAtAddress(String count, String total);

  /// No description provided for @utxoResultingBoxes.
  ///
  /// In en, this message translates to:
  /// **'Resulting boxes'**
  String get utxoResultingBoxes;

  /// No description provided for @utxoOneOrMore.
  ///
  /// In en, this message translates to:
  /// **'1 or more'**
  String get utxoOneOrMore;

  /// No description provided for @utxoRentClocksRestarted.
  ///
  /// In en, this message translates to:
  /// **'Rent clocks restarted'**
  String get utxoRentClocksRestarted;

  /// No description provided for @utxoNewBoxRent.
  ///
  /// In en, this message translates to:
  /// **'New box rent'**
  String get utxoNewBoxRent;

  /// No description provided for @utxoCleanupDetail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every listed box is spent into one new box at this address, holding all their ERG and tokens. A moved box starts a new 4-year storage-rent clock. Only boxes from this one address are merged, so no addresses are linked.} other{Every listed box is spent into {count} new boxes at this address, holding all their ERG and tokens. A moved box starts a new 4-year storage-rent clock. Only boxes from this one address are merged, so no addresses are linked.}}'**
  String utxoCleanupDetail(int count);

  /// No description provided for @utxoCleanupSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Cleanup submitted'**
  String get utxoCleanupSubmitted;

  /// No description provided for @utxoAtRisk.
  ///
  /// In en, this message translates to:
  /// **'{count} at risk'**
  String utxoAtRisk(String count);

  /// No description provided for @utxoSplitTitle.
  ///
  /// In en, this message translates to:
  /// **'Split UTXO'**
  String get utxoSplitTitle;

  /// No description provided for @utxoOutputsCreated.
  ///
  /// In en, this message translates to:
  /// **'Outputs Created'**
  String get utxoOutputsCreated;

  /// No description provided for @utxoBoxesN.
  ///
  /// In en, this message translates to:
  /// **'{count} boxes'**
  String utxoBoxesN(String count);

  /// No description provided for @utxoAmountPerBox.
  ///
  /// In en, this message translates to:
  /// **'Amount per Box'**
  String get utxoAmountPerBox;

  /// No description provided for @utxoTokensN.
  ///
  /// In en, this message translates to:
  /// **'{count} tokens'**
  String utxoTokensN(String count);

  /// No description provided for @utxoChangeReturned.
  ///
  /// In en, this message translates to:
  /// **'Change Returned'**
  String get utxoChangeReturned;

  /// No description provided for @utxoMinerFeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Miner Fee'**
  String get utxoMinerFeeTitle;

  /// No description provided for @utxoFeeByBuilder.
  ///
  /// In en, this message translates to:
  /// **'Fee is computed by the transaction builder.'**
  String get utxoFeeByBuilder;

  /// No description provided for @utxoSignBroadcastSplit.
  ///
  /// In en, this message translates to:
  /// **'Sign & broadcast split'**
  String get utxoSignBroadcastSplit;

  /// No description provided for @utxoSplitSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Split submitted'**
  String get utxoSplitSubmitted;

  /// No description provided for @utxoSeparateTitle.
  ///
  /// In en, this message translates to:
  /// **'Separate {count} token types'**
  String utxoSeparateTitle(String count);

  /// No description provided for @utxoSourceBox.
  ///
  /// In en, this message translates to:
  /// **'Source box'**
  String get utxoSourceBox;

  /// No description provided for @utxoInputsSpent.
  ///
  /// In en, this message translates to:
  /// **'Inputs spent'**
  String get utxoInputsSpent;

  /// No description provided for @utxoTokenBoxes.
  ///
  /// In en, this message translates to:
  /// **'Token boxes'**
  String get utxoTokenBoxes;

  /// No description provided for @utxoRawUnits.
  ///
  /// In en, this message translates to:
  /// **'{amount} ({raw} raw units)'**
  String utxoRawUnits(String amount, String raw);

  /// No description provided for @utxoErgInTokenBoxes.
  ///
  /// In en, this message translates to:
  /// **'ERG in token boxes'**
  String get utxoErgInTokenBoxes;

  /// No description provided for @utxoErgChange.
  ///
  /// In en, this message translates to:
  /// **'ERG change'**
  String get utxoErgChange;

  /// No description provided for @utxoSeparateDetail.
  ///
  /// In en, this message translates to:
  /// **'Each token type keeps its full balance in a separate box at your source address. All remaining ERG is returned to your wallet.'**
  String get utxoSeparateDetail;

  /// No description provided for @utxoSignBroadcastSeparation.
  ///
  /// In en, this message translates to:
  /// **'Sign & broadcast separation'**
  String get utxoSignBroadcastSeparation;

  /// No description provided for @utxoSeparationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Token separation submitted'**
  String get utxoSeparationSubmitted;

  /// No description provided for @utxoRestructureTitle.
  ///
  /// In en, this message translates to:
  /// **'Restructure UTXOs'**
  String get utxoRestructureTitle;

  /// No description provided for @utxoInputsConsumed.
  ///
  /// In en, this message translates to:
  /// **'Inputs Consumed'**
  String get utxoInputsConsumed;

  /// No description provided for @utxoOutputsGenerated.
  ///
  /// In en, this message translates to:
  /// **'Outputs Generated'**
  String get utxoOutputsGenerated;

  /// No description provided for @utxoTotalValueInTitle.
  ///
  /// In en, this message translates to:
  /// **'Total Value In'**
  String get utxoTotalValueInTitle;

  /// No description provided for @utxoAllocatedToOutputs.
  ///
  /// In en, this message translates to:
  /// **'Allocated to Outputs'**
  String get utxoAllocatedToOutputs;

  /// No description provided for @utxoChangeOutput.
  ///
  /// In en, this message translates to:
  /// **'Change Output'**
  String get utxoChangeOutput;

  /// No description provided for @utxoSignBroadcastRestructure.
  ///
  /// In en, this message translates to:
  /// **'Sign & broadcast restructure'**
  String get utxoSignBroadcastRestructure;

  /// No description provided for @utxoRestructureSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Restructure submitted'**
  String get utxoRestructureSubmitted;

  /// No description provided for @utxoScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet boxes'**
  String get utxoScreenTitle;

  /// No description provided for @utxoLastConsolidation.
  ///
  /// In en, this message translates to:
  /// **'Last consolidation result'**
  String get utxoLastConsolidation;

  /// No description provided for @utxoRefreshBoxes.
  ///
  /// In en, this message translates to:
  /// **'Refresh boxes'**
  String get utxoRefreshBoxes;

  /// No description provided for @utxoCount.
  ///
  /// In en, this message translates to:
  /// **'{count} UTXOs'**
  String utxoCount(String count);

  /// No description provided for @utxoValueTokens.
  ///
  /// In en, this message translates to:
  /// **'{value} · {count} tokens'**
  String utxoValueTokens(String value, String count);

  /// No description provided for @utxoDustLine.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 dust box under {limit}.} other{{count} dust boxes under {limit}.}}'**
  String utxoDustLine(int count, String limit);

  /// No description provided for @utxoOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest boxes first. Automatic sends prefer older eligible boxes to reduce storage-rent risk; privacy rules and your manual selection still apply.'**
  String get utxoOldestFirst;

  /// No description provided for @utxoConsolidate.
  ///
  /// In en, this message translates to:
  /// **'Consolidate'**
  String get utxoConsolidate;

  /// No description provided for @utxoSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get utxoSplit;

  /// No description provided for @utxoRestructure.
  ///
  /// In en, this message translates to:
  /// **'Restructure'**
  String get utxoRestructure;

  /// No description provided for @utxoSeparateTokenTypes.
  ///
  /// In en, this message translates to:
  /// **'Separate token types'**
  String get utxoSeparateTokenTypes;

  /// No description provided for @utxoSweepDust.
  ///
  /// In en, this message translates to:
  /// **'Sweep {count} dust boxes into one'**
  String utxoSweepDust(String count);

  /// No description provided for @utxoSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search box ID or token...'**
  String get utxoSearchHint;

  /// No description provided for @utxoFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String utxoFilterAll(String count);

  /// No description provided for @utxoFilterErgOnly.
  ///
  /// In en, this message translates to:
  /// **'ERG Only ({count})'**
  String utxoFilterErgOnly(String count);

  /// No description provided for @utxoFilterTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens ({count})'**
  String utxoFilterTokens(String count);

  /// No description provided for @utxoFilterDust.
  ///
  /// In en, this message translates to:
  /// **'Dust ({count})'**
  String utxoFilterDust(String count);

  /// No description provided for @utxoFilterRent.
  ///
  /// In en, this message translates to:
  /// **'Rent ({count})'**
  String utxoFilterRent(String count);

  /// No description provided for @utxoClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear ({count})'**
  String utxoClearSelection(String count);

  /// No description provided for @utxoSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get utxoSelectAll;

  /// No description provided for @utxoNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No UTXOs match criteria'**
  String get utxoNoMatch;

  /// No description provided for @utxoCopyBoxId.
  ///
  /// In en, this message translates to:
  /// **'Copy Box ID'**
  String get utxoCopyBoxId;

  /// No description provided for @utxoBoxIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Box ID copied'**
  String get utxoBoxIdCopied;

  /// No description provided for @utxoHeight.
  ///
  /// In en, this message translates to:
  /// **'H: {height}'**
  String utxoHeight(String height);

  /// No description provided for @utxoSplitEqual.
  ///
  /// In en, this message translates to:
  /// **'{count} boxes of {amount}'**
  String utxoSplitEqual(String count, String amount);

  /// No description provided for @utxoSplitWithChange.
  ///
  /// In en, this message translates to:
  /// **'{count} boxes of {amount} · {change} change'**
  String utxoSplitWithChange(String count, String amount, String change);

  /// No description provided for @utxoSplitToken.
  ///
  /// In en, this message translates to:
  /// **'{count} boxes of {amount} {token}, each with {erg}'**
  String utxoSplitToken(String count, String amount, String token, String erg);

  /// No description provided for @utxoSplitNotEnough.
  ///
  /// In en, this message translates to:
  /// **'Not enough ERG for {count} boxes after fees'**
  String utxoSplitNotEnough(String count);

  /// No description provided for @utxoSplitEnterErg.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount of at least 0.001 ERG that fits the selection'**
  String get utxoSplitEnterErg;

  /// No description provided for @utxoSplitEnterToken.
  ///
  /// In en, this message translates to:
  /// **'Enter a token amount that fits the selection'**
  String get utxoSplitEnterToken;

  /// No description provided for @utxoSplitFrom.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{From 1 box holding {total}.} other{From {count} boxes holding {total}.}}'**
  String utxoSplitFrom(int count, String total);

  /// No description provided for @utxoEqualParts.
  ///
  /// In en, this message translates to:
  /// **'Equal parts'**
  String get utxoEqualParts;

  /// No description provided for @utxoAmountEach.
  ///
  /// In en, this message translates to:
  /// **'Amount each'**
  String get utxoAmountEach;

  /// No description provided for @utxoHowManyBoxes.
  ///
  /// In en, this message translates to:
  /// **'HOW MANY BOXES'**
  String get utxoHowManyBoxes;

  /// No description provided for @utxoCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get utxoCustom;

  /// No description provided for @utxoTokenAvailable.
  ///
  /// In en, this message translates to:
  /// **'{token} · {amount} available'**
  String utxoTokenAvailable(String token, String amount);

  /// No description provided for @utxoPerBox.
  ///
  /// In en, this message translates to:
  /// **'{token} per box'**
  String utxoPerBox(String token);

  /// No description provided for @utxoErgPerBox.
  ///
  /// In en, this message translates to:
  /// **'ERG per box'**
  String get utxoErgPerBox;

  /// No description provided for @utxoAdjustCount.
  ///
  /// In en, this message translates to:
  /// **'Adjust the count or amount until it fits the selection.'**
  String get utxoAdjustCount;

  /// No description provided for @utxoSplitFeeNote.
  ///
  /// In en, this message translates to:
  /// **'Miner fee: {fee}. Remaining ERG and every token return to you as change.'**
  String utxoSplitFeeNote(String fee);

  /// No description provided for @utxoPreviewSplit.
  ///
  /// In en, this message translates to:
  /// **'Preview split'**
  String get utxoPreviewSplit;

  /// No description provided for @utxoCustomRestructure.
  ///
  /// In en, this message translates to:
  /// **'Custom Restructure'**
  String get utxoCustomRestructure;

  /// No description provided for @utxoAddOutput.
  ///
  /// In en, this message translates to:
  /// **'Add output'**
  String get utxoAddOutput;

  /// No description provided for @utxoDefineOutputs.
  ///
  /// In en, this message translates to:
  /// **'Define desired output boxes. Remainder returns to change.'**
  String get utxoDefineOutputs;

  /// No description provided for @utxoBoxErgAmount.
  ///
  /// In en, this message translates to:
  /// **'Box #{number} ERG Amount'**
  String utxoBoxErgAmount(String number);

  /// No description provided for @utxoInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount: min 0.001 ERG per box'**
  String get utxoInvalidAmount;

  /// No description provided for @utxoPreviewRestructure.
  ///
  /// In en, this message translates to:
  /// **'Preview Restructure'**
  String get utxoPreviewRestructure;

  /// No description provided for @utxoSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Selected'**
  String utxoSelectedCount(String count);

  /// No description provided for @rentDueWithin.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 due within {days} days} other{{count} due within {days} days}}'**
  String rentDueWithin(int count, String days);

  /// No description provided for @rentBlock.
  ///
  /// In en, this message translates to:
  /// **'block {height}'**
  String rentBlock(String height);

  /// No description provided for @rentAtRiskNow.
  ///
  /// In en, this message translates to:
  /// **'At risk: it holds no more than its {fee} rent, so it can be collected now, tokens included.'**
  String rentAtRiskNow(String fee);

  /// No description provided for @rentAtRiskFrom.
  ///
  /// In en, this message translates to:
  /// **'At risk: it holds no more than its {fee} rent. From {block} ({when}) it can be collected whole, tokens included.'**
  String rentAtRiskFrom(String fee, String block, String when);

  /// No description provided for @rentWholeNow.
  ///
  /// In en, this message translates to:
  /// **'Rent would take this whole box ({whole}); it can be collected now.'**
  String rentWholeNow(String whole);

  /// No description provided for @rentWholeFrom.
  ///
  /// In en, this message translates to:
  /// **'Rent would take this whole box ({whole}), from {block} ({when}).'**
  String rentWholeFrom(String whole, String block, String when);

  /// No description provided for @rentChargeableNow.
  ///
  /// In en, this message translates to:
  /// **'Storage rent of {fee} can be charged now (due {block}).'**
  String rentChargeableNow(String fee, String block);

  /// No description provided for @rentDue.
  ///
  /// In en, this message translates to:
  /// **'Storage rent of {fee} due {when} ({block}).'**
  String rentDue(String fee, String when, String block);

  /// No description provided for @rentIntoOne.
  ///
  /// In en, this message translates to:
  /// **'into one'**
  String get rentIntoOne;

  /// No description provided for @rentIntoCount.
  ///
  /// In en, this message translates to:
  /// **'into {count}'**
  String rentIntoCount(String count);

  /// No description provided for @rentIntoOneOrMore.
  ///
  /// In en, this message translates to:
  /// **'into one or more'**
  String get rentIntoOneOrMore;

  /// No description provided for @rentFewerBoxes.
  ///
  /// In en, this message translates to:
  /// **'Fewer boxes keep every send small and cheap.'**
  String get rentFewerBoxes;

  /// No description provided for @rentMovingRestarts.
  ///
  /// In en, this message translates to:
  /// **'Moving old boxes also restarts their 4-year storage-rent clock.'**
  String get rentMovingRestarts;

  /// No description provided for @rentMergeBoxes.
  ///
  /// In en, this message translates to:
  /// **'Merge {count} boxes at {address} {into}.'**
  String rentMergeBoxes(String count, String address, String into);

  /// No description provided for @rentMergeBoxesOf.
  ///
  /// In en, this message translates to:
  /// **'Merge {count} of {total} boxes at {address} {into}.'**
  String rentMergeBoxesOf(
    String count,
    String total,
    String address,
    String into,
  );

  /// No description provided for @rentCleanupFee.
  ///
  /// In en, this message translates to:
  /// **'Fee {fee}. Only this address\'s boxes move, so no addresses are linked.'**
  String rentCleanupFee(String fee);

  /// No description provided for @rentReviewCleanup.
  ///
  /// In en, this message translates to:
  /// **'Review cleanup'**
  String get rentReviewCleanup;

  /// No description provided for @rentCantCover.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 box can\'t cover its storage rent} other{{count} boxes can\'t cover their storage rent}}'**
  String rentCantCover(int count);

  /// No description provided for @rentFallsDue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 falls due within {days} days} other{{count} fall due within {days} days}}'**
  String rentFallsDue(int count, String days);

  /// No description provided for @rentReasonAnd.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String rentReasonAnd(String first, String second);

  /// No description provided for @rentReasonMoving.
  ///
  /// In en, this message translates to:
  /// **'{reason}. Moving them starts a new 4-year rent clock.'**
  String rentReasonMoving(String reason);

  /// No description provided for @rentChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking storage rent…'**
  String get rentChecking;

  /// No description provided for @rentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Storage rent unavailable: your node could not be read. Refresh to try again.'**
  String get rentUnavailable;

  /// No description provided for @rentNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Storage rent not checked yet.'**
  String get rentNotChecked;

  /// No description provided for @rentAtRiskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 box at risk of collection} other{{count} boxes at risk of collection}}'**
  String rentAtRiskCount(int count);

  /// No description provided for @rentUnmeasured.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 box could not be measured.} other{{count} boxes could not be measured.}}'**
  String rentUnmeasured(int count);

  /// No description provided for @rentRateLine.
  ///
  /// In en, this message translates to:
  /// **'Rate {rate}.'**
  String rentRateLine(String rate);

  /// No description provided for @rentErgOnlyWhole.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 ERG-only box is worth no more than its rent, which would take it whole.} other{{count} ERG-only boxes are worth no more than their rent, which would take them whole.}}'**
  String rentErgOnlyWhole(int count);

  /// No description provided for @rentLeadParts.
  ///
  /// In en, this message translates to:
  /// **'Storage rent: {parts}.'**
  String rentLeadParts(String parts);

  /// No description provided for @rentLeadAllCovered.
  ///
  /// In en, this message translates to:
  /// **'Storage rent: nothing due within {days} days, and every box covers its rent.'**
  String rentLeadAllCovered(String days);

  /// No description provided for @rentLeadAllMeasuredCovered.
  ///
  /// In en, this message translates to:
  /// **'Storage rent: nothing due within {days} days, and every measured box covers its rent.'**
  String rentLeadAllMeasuredCovered(String days);

  /// No description provided for @rentLeadNoTokenRisk.
  ///
  /// In en, this message translates to:
  /// **'Storage rent: no box with tokens is at risk, and nothing else is due within {days} days.'**
  String rentLeadNoTokenRisk(String days);

  /// No description provided for @rentLeadNoMeasuredTokenRisk.
  ///
  /// In en, this message translates to:
  /// **'Storage rent: no measured box with tokens is at risk, and nothing else is due within {days} days.'**
  String rentLeadNoMeasuredTokenRisk(String days);

  /// No description provided for @confirmSignBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Sign & broadcast'**
  String get confirmSignBroadcast;

  /// No description provided for @confirmWarnBroadcast.
  ///
  /// In en, this message translates to:
  /// **'This will sign and broadcast a transaction to the network. It cannot be undone once confirmed.'**
  String get confirmWarnBroadcast;

  /// No description provided for @confirmWarnPage.
  ///
  /// In en, this message translates to:
  /// **'This will sign a transaction and hand it to the page, which broadcasts it. Once broadcast it cannot be undone.'**
  String get confirmWarnPage;

  /// No description provided for @confirmTo.
  ///
  /// In en, this message translates to:
  /// **'TO'**
  String get confirmTo;

  /// No description provided for @confirmDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get confirmDetails;

  /// No description provided for @confirmSignOnly.
  ///
  /// In en, this message translates to:
  /// **'Sign only'**
  String get confirmSignOnly;

  /// No description provided for @confirmTxDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction details'**
  String get confirmTxDetails;

  /// No description provided for @rentHintDefaultRate.
  ///
  /// In en, this message translates to:
  /// **' at the default rate'**
  String get rentHintDefaultRate;

  /// No description provided for @rentHintCharge.
  ///
  /// In en, this message translates to:
  /// **'Ergo charges storage rent on boxes left unmoved for 4 years: about {fee}{rate} for this {bytes}-byte box.'**
  String rentHintCharge(String fee, String rate, String bytes);

  /// No description provided for @rentHintCovers.
  ///
  /// In en, this message translates to:
  /// **'This amount covers it.'**
  String get rentHintCovers;

  /// No description provided for @rentHintLess.
  ///
  /// In en, this message translates to:
  /// **'A box holding less can be collected whole, tokens included.'**
  String get rentHintLess;

  /// No description provided for @rentHintExtraBoxes.
  ///
  /// In en, this message translates to:
  /// **'These tokens need {count} boxes; the extra ones carry only their minimum ERG.'**
  String rentHintExtraBoxes(String count);

  /// No description provided for @rentHintSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested {amount}'**
  String rentHintSuggested(String amount);

  /// No description provided for @rentHintUseSuggested.
  ///
  /// In en, this message translates to:
  /// **'Use suggested'**
  String get rentHintUseSuggested;

  /// No description provided for @txResultId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get txResultId;

  /// No description provided for @txResultIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID copied'**
  String get txResultIdCopied;

  /// No description provided for @txViewOnExplorer.
  ///
  /// In en, this message translates to:
  /// **'View on explorer'**
  String get txViewOnExplorer;

  /// No description provided for @txBookkeepingFailed.
  ///
  /// In en, this message translates to:
  /// **'Transaction submitted, but local tracking could not be updated: {error}. Keep this transaction ID and check Activity before retrying.'**
  String txBookkeepingFailed(String error);

  /// No description provided for @txBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Consolidation result'**
  String get txBatchTitle;

  /// No description provided for @txBatchSubmitted.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} transactions submitted'**
  String txBatchSubmitted(String done, String total);

  /// No description provided for @txBatchStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped early after {done} of {total}. No further batches were attempted.'**
  String txBatchStopped(String done, String total);

  /// No description provided for @txBatchItem.
  ///
  /// In en, this message translates to:
  /// **'Transaction {number}'**
  String txBatchItem(String number);

  /// No description provided for @pickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search name or token id'**
  String get pickerSearchHint;

  /// No description provided for @pickerNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No tokens match that search.'**
  String get pickerNoMatch;

  /// No description provided for @pickerSelect.
  ///
  /// In en, this message translates to:
  /// **'Select {token}'**
  String pickerSelect(String token);

  /// No description provided for @pickerSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String pickerSelectedCount(String count);

  /// No description provided for @amountEnterErg.
  ///
  /// In en, this message translates to:
  /// **'Enter ERG'**
  String get amountEnterErg;

  /// No description provided for @amountEnterFiat.
  ///
  /// In en, this message translates to:
  /// **'Enter {currency}'**
  String amountEnterFiat(String currency);

  /// No description provided for @separateTitle.
  ///
  /// In en, this message translates to:
  /// **'Separate tokens'**
  String get separateTitle;

  /// No description provided for @separateIntro.
  ///
  /// In en, this message translates to:
  /// **'Move each token type, with its full balance, into a separate box in your wallet. This uses one transaction.'**
  String get separateIntro;

  /// No description provided for @separateNoSource.
  ///
  /// In en, this message translates to:
  /// **'No boxes contain multiple token types.'**
  String get separateNoSource;

  /// No description provided for @separateSourceItem.
  ///
  /// In en, this message translates to:
  /// **'{box} · {count} tokens · {value}'**
  String separateSourceItem(String box, String count, String value);

  /// No description provided for @separateEachHolds.
  ///
  /// In en, this message translates to:
  /// **'Each token box holds at least {min}. Miner fee {fee}.'**
  String separateEachHolds(String min, String fee);

  /// No description provided for @separateMinimumNeeded.
  ///
  /// In en, this message translates to:
  /// **'Minimum ERG needed: {amount}'**
  String separateMinimumNeeded(String amount);

  /// No description provided for @separateTokensToSeparate.
  ///
  /// In en, this message translates to:
  /// **'Tokens to separate'**
  String get separateTokensToSeparate;

  /// No description provided for @separateRawUnits.
  ///
  /// In en, this message translates to:
  /// **'{tokenId}\n{amount} raw units'**
  String separateRawUnits(String tokenId, String amount);

  /// No description provided for @separateAddFundingTitle.
  ///
  /// In en, this message translates to:
  /// **'Add ERG funding'**
  String get separateAddFundingTitle;

  /// No description provided for @separateFundingNote.
  ///
  /// In en, this message translates to:
  /// **'Only ERG-only boxes at the source address are listed, oldest first. Select any you want to spend.'**
  String get separateFundingNote;

  /// No description provided for @separateFundingItem.
  ///
  /// In en, this message translates to:
  /// **'{box} · Height {height}'**
  String separateFundingItem(String box, String height);

  /// No description provided for @separateHeightUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get separateHeightUnknown;

  /// No description provided for @separatePlanLine.
  ///
  /// In en, this message translates to:
  /// **'{inputs, plural, =1{1 input box → {tokens} token boxes} other{{inputs} input boxes → {tokens} token boxes}}'**
  String separatePlanLine(int inputs, String tokens);

  /// No description provided for @separatePlanLineChange.
  ///
  /// In en, this message translates to:
  /// **'{inputs, plural, =1{1 input box → {tokens} token boxes + ERG change} other{{inputs} input boxes → {tokens} token boxes + ERG change}}'**
  String separatePlanLineChange(int inputs, String tokens);

  /// No description provided for @separateChangeReturned.
  ///
  /// In en, this message translates to:
  /// **'ERG returned as change: {amount}'**
  String separateChangeReturned(String amount);

  /// No description provided for @separateStayNote.
  ///
  /// In en, this message translates to:
  /// **'Every token and all remaining ERG stay in your wallet. A remainder below 0.001 ERG is kept in the first token box.'**
  String get separateStayNote;

  /// No description provided for @separateReview.
  ///
  /// In en, this message translates to:
  /// **'Review separation'**
  String get separateReview;

  /// No description provided for @homeOnAnotherAddress.
  ///
  /// In en, this message translates to:
  /// **'on another address'**
  String get homeOnAnotherAddress;

  /// No description provided for @homeOnOtherAddresses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{on {n} other address} other{on {n} other addresses}}'**
  String homeOnOtherAddresses(int count, String n);

  /// No description provided for @homeFundsWhere.
  ///
  /// In en, this message translates to:
  /// **'Funds {where}'**
  String homeFundsWhere(String where);

  /// No description provided for @homeInclFundsWhere.
  ///
  /// In en, this message translates to:
  /// **'incl. funds {where}'**
  String homeInclFundsWhere(String where);

  /// No description provided for @homePartsWhere.
  ///
  /// In en, this message translates to:
  /// **'{parts} {where}'**
  String homePartsWhere(String parts, String where);

  /// No description provided for @homeInclPartsWhere.
  ///
  /// In en, this message translates to:
  /// **'incl. {parts} {where}'**
  String homeInclPartsWhere(String parts, String where);

  /// No description provided for @homeErgPendingFigure.
  ///
  /// In en, this message translates to:
  /// **'{figure} ERG pending'**
  String homeErgPendingFigure(String figure);

  /// No description provided for @homePendingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'{lead} · {confirmed} confirmed'**
  String homePendingConfirmed(String lead, String confirmed);

  /// No description provided for @homeLockedCaps.
  ///
  /// In en, this message translates to:
  /// **'LOCKED'**
  String get homeLockedCaps;

  /// No description provided for @formatUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Unconfirmed'**
  String get formatUnconfirmed;

  /// No description provided for @celautDepositRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Celaut deposit'**
  String get celautDepositRowTitle;

  /// No description provided for @celautDepositRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay a node in ERG from the wallet'**
  String get celautDepositRowSubtitle;

  /// No description provided for @celautDepositScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Celaut deposit'**
  String get celautDepositScreenTitle;

  /// No description provided for @celautDepositIntro.
  ///
  /// In en, this message translates to:
  /// **'Pay ERG to a node to get MU, the unit of account of the node. The wallet of the app pays. The node gets a plain payment and can keep it, so deposit small amounts. The balance stays with the client id of the app on that node, which the app keeps in its encrypted Celaut database.'**
  String get celautDepositIntro;

  /// No description provided for @celautDepositNodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Node address'**
  String get celautDepositNodeLabel;

  /// No description provided for @celautDepositNodeHint.
  ///
  /// In en, this message translates to:
  /// **'host:port'**
  String get celautDepositNodeHint;

  /// No description provided for @celautDepositCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the node'**
  String get celautDepositCheck;

  /// No description provided for @celautDepositChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the node…'**
  String get celautDepositChecking;

  /// No description provided for @celautDepositNodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Contract of the node'**
  String get celautDepositNodeTitle;

  /// No description provided for @celautDepositPayTo.
  ///
  /// In en, this message translates to:
  /// **'Pay to {address}'**
  String celautDepositPayTo(String address);

  /// No description provided for @celautDepositRate.
  ///
  /// In en, this message translates to:
  /// **'{mu} MU per nanoERG'**
  String celautDepositRate(String mu);

  /// No description provided for @celautDepositBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance of the client: {mu} MU'**
  String celautDepositBalance(String mu);

  /// No description provided for @celautDepositUsed.
  ///
  /// In en, this message translates to:
  /// **'Deposits to this node: {used} of {limit}'**
  String celautDepositUsed(String used, String limit);

  /// Value of the row of the deposits to a node, in the confirmation sheet; the row label says what it is.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit}'**
  String celautDepositUsedValue(String used, String limit);

  /// No description provided for @celautDepositLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Limit for this node in ERG'**
  String get celautDepositLimitLabel;

  /// No description provided for @celautDepositLimitHelper.
  ///
  /// In en, this message translates to:
  /// **'1 ERG at most'**
  String get celautDepositLimitHelper;

  /// No description provided for @celautDepositSetLimit.
  ///
  /// In en, this message translates to:
  /// **'Set the limit'**
  String get celautDepositSetLimit;

  /// No description provided for @celautDepositLimitInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a limit in ERG, from 0 to 1.'**
  String get celautDepositLimitInvalid;

  /// No description provided for @celautDepositAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount in ERG'**
  String get celautDepositAmountLabel;

  /// No description provided for @celautDepositAmountHint.
  ///
  /// In en, this message translates to:
  /// **'0.001 ERG or more'**
  String get celautDepositAmountHint;

  /// No description provided for @celautDepositAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount of 0.001 ERG or more.'**
  String get celautDepositAmountInvalid;

  /// No description provided for @celautDepositPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare the deposit'**
  String get celautDepositPrepare;

  /// No description provided for @celautDepositPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get celautDepositPreparing;

  /// No description provided for @celautDepositConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm the deposit'**
  String get celautDepositConfirmTitle;

  /// No description provided for @celautDepositConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get celautDepositConfirmLabel;

  /// No description provided for @celautDepositRowNode.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get celautDepositRowNode;

  /// No description provided for @celautDepositRowAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get celautDepositRowAmount;

  /// No description provided for @celautDepositRowMu.
  ///
  /// In en, this message translates to:
  /// **'Buys'**
  String get celautDepositRowMu;

  /// No description provided for @celautDepositRowRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get celautDepositRowRate;

  /// No description provided for @celautDepositRowTotal.
  ///
  /// In en, this message translates to:
  /// **'Total from the wallet'**
  String get celautDepositRowTotal;

  /// No description provided for @celautDepositRowUsed.
  ///
  /// In en, this message translates to:
  /// **'Deposits to this node'**
  String get celautDepositRowUsed;

  /// No description provided for @celautDepositConfirmDetail.
  ///
  /// In en, this message translates to:
  /// **'The node can keep a plain payment. The app tells the node once, when the explorer shows the box. The token of this deposit expires in {minutes} minutes.'**
  String celautDepositConfirmDetail(String minutes);

  /// No description provided for @celautDepositWaiting.
  ///
  /// In en, this message translates to:
  /// **'Sent. The app waits until the explorer shows the box…'**
  String get celautDepositWaiting;

  /// No description provided for @celautDepositWaitAgain.
  ///
  /// In en, this message translates to:
  /// **'Wait again'**
  String get celautDepositWaitAgain;

  /// No description provided for @celautDepositTx.
  ///
  /// In en, this message translates to:
  /// **'Transaction: {id}'**
  String celautDepositTx(String id);

  /// No description provided for @celautDepositBox.
  ///
  /// In en, this message translates to:
  /// **'Deposit box: {id}'**
  String celautDepositBox(String id);

  /// No description provided for @celautDepositAccepted.
  ///
  /// In en, this message translates to:
  /// **'The node accepted the deposit. Balance of the client: {mu} MU.'**
  String celautDepositAccepted(String mu);

  /// No description provided for @celautDepositRefused.
  ///
  /// In en, this message translates to:
  /// **'The node refused the payment: {message}'**
  String celautDepositRefused(String message);

  /// No description provided for @celautDepositCancelled.
  ///
  /// In en, this message translates to:
  /// **'The deposit was cancelled. Nothing was sent.'**
  String get celautDepositCancelled;

  /// No description provided for @celautDepositSendFailed.
  ///
  /// In en, this message translates to:
  /// **'The transaction was not sent: {error}'**
  String celautDepositSendFailed(String error);

  /// No description provided for @celautUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get celautUnknown;

  /// No description provided for @celautNoFullWallet.
  ///
  /// In en, this message translates to:
  /// **'This needs a wallet with its recovery phrase on this device. Create or restore a wallet first.'**
  String get celautNoFullWallet;

  /// No description provided for @celautDepositPayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Paying wallet'**
  String get celautDepositPayerTitle;

  /// No description provided for @celautDepositPayerBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance: {amount}'**
  String celautDepositPayerBalance(String amount);

  /// No description provided for @celautDepositPayerOpen.
  ///
  /// In en, this message translates to:
  /// **'This wallet is open. The app asks for your fingerprint or screen lock before the deposit.'**
  String get celautDepositPayerOpen;

  /// No description provided for @celautDepositPayerLocked.
  ///
  /// In en, this message translates to:
  /// **'This wallet is locked. The app asks for your fingerprint or screen lock before the deposit, and opens it.'**
  String get celautDepositPayerLocked;

  /// No description provided for @celautDepositRowPayer.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get celautDepositRowPayer;

  /// No description provided for @celautDepositRowPayerBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance of the paying wallet'**
  String get celautDepositRowPayerBalance;

  /// No description provided for @celautDepositSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Sent deposits'**
  String get celautDepositSentTitle;

  /// No description provided for @celautDepositSentRow.
  ///
  /// In en, this message translates to:
  /// **'{amount} ({mu} MU) to {node}'**
  String celautDepositSentRow(String amount, String mu, String node);

  /// No description provided for @celautDepositSentExpired.
  ///
  /// In en, this message translates to:
  /// **'The deposit token expired. The node refuses this deposit now.'**
  String get celautDepositSentExpired;

  /// No description provided for @celautComputeHomeRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats home'**
  String get celautComputeHomeRowTitle;

  /// No description provided for @celautComputeHomeRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app opens on the list of conversations. This is the default. Turn it off to see the wallets list first.'**
  String get celautComputeHomeRowSubtitle;

  /// No description provided for @celautHomeComputeTitle.
  ///
  /// In en, this message translates to:
  /// **'Offered compute'**
  String get celautHomeComputeTitle;

  /// No description provided for @celautHomeOfferedNote.
  ///
  /// In en, this message translates to:
  /// **'Sums of what the reachable nodes advertise: offered, not free.'**
  String get celautHomeOfferedNote;

  /// No description provided for @celautHomeNodes.
  ///
  /// In en, this message translates to:
  /// **'Nodes counted: {counted}. Not reachable: {unreachable}.'**
  String celautHomeNodes(String counted, String unreachable);

  /// No description provided for @celautHomeNoNodes.
  ///
  /// In en, this message translates to:
  /// **'The node list is empty. Add a node with Nodes.'**
  String get celautHomeNoNodes;

  /// No description provided for @celautHomeMoneyTitle.
  ///
  /// In en, this message translates to:
  /// **'Money for compute'**
  String get celautHomeMoneyTitle;

  /// No description provided for @celautHomeInstancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Running instances'**
  String get celautHomeInstancesTitle;

  /// No description provided for @celautHomeNoInstances.
  ///
  /// In en, this message translates to:
  /// **'No instance runs.'**
  String get celautHomeNoInstances;

  /// No description provided for @celautHomeCostSoFar.
  ///
  /// In en, this message translates to:
  /// **'Cost so far: {mu} ({amount})'**
  String celautHomeCostSoFar(String mu, String amount);

  /// No description provided for @celautHomeStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get celautHomeStop;

  /// No description provided for @celautHomeStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped. Refund: {mu}.'**
  String celautHomeStopped(String mu);

  /// No description provided for @celautHomeWallets.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get celautHomeWallets;

  /// No description provided for @celautHomeRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get celautHomeRefresh;

  /// No description provided for @celautHomeLoading.
  ///
  /// In en, this message translates to:
  /// **'Asking the nodes…'**
  String get celautHomeLoading;

  /// No description provided for @celautErrorClientUnknown.
  ///
  /// In en, this message translates to:
  /// **'The node does not know the client of this app: it forgot it. Choose a new client or retry later.'**
  String get celautErrorClientUnknown;

  /// No description provided for @celautAtLeast.
  ///
  /// In en, this message translates to:
  /// **'at least {value} ({count, plural, =1{1 node unknown} other{{count} nodes unknown}})'**
  String celautAtLeast(String value, int count);

  /// No description provided for @celautAtLeastWallets.
  ///
  /// In en, this message translates to:
  /// **'at least {value} ({count, plural, =1{1 wallet unknown} other{{count} wallets unknown}})'**
  String celautAtLeastWallets(String value, int count);

  /// No description provided for @celautHomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Compute'**
  String get celautHomeTagline;

  /// No description provided for @celautHomeFullWallets.
  ///
  /// In en, this message translates to:
  /// **'Full wallets · can pay'**
  String get celautHomeFullWallets;

  /// No description provided for @celautHomePaidCredit.
  ///
  /// In en, this message translates to:
  /// **'Paid credit on nodes'**
  String get celautHomePaidCredit;

  /// No description provided for @celautHomeFreeCredit.
  ///
  /// In en, this message translates to:
  /// **'Free credit on nodes'**
  String get celautHomeFreeCredit;

  /// No description provided for @celautHomeUsd.
  ///
  /// In en, this message translates to:
  /// **'≈ {amount}'**
  String celautHomeUsd(String amount);

  /// No description provided for @celautHomeUsdUnknown.
  ///
  /// In en, this message translates to:
  /// **'USD unknown'**
  String get celautHomeUsdUnknown;

  /// No description provided for @celautHomeUsdSource.
  ///
  /// In en, this message translates to:
  /// **'USD from the ERG/USD oracle pool price, read on-chain. The free credit counts as spent first.'**
  String get celautHomeUsdSource;

  /// No description provided for @celautHomeNodeCredit.
  ///
  /// In en, this message translates to:
  /// **'Paid {paid} · free {free} · {rate} MU per nanoERG'**
  String celautHomeNodeCredit(String paid, String free, String rate);

  /// No description provided for @celautHomeNodeUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Not reachable'**
  String get celautHomeNodeUnreachable;

  /// No description provided for @celautHomeNodesButton.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get celautHomeNodesButton;

  /// No description provided for @celautHomeClientUnknownAction.
  ///
  /// In en, this message translates to:
  /// **'Choose what to do'**
  String get celautHomeClientUnknownAction;

  /// No description provided for @celautOpenFullWalletNeeded.
  ///
  /// In en, this message translates to:
  /// **'Start and stop need the wallet open. The app asks for your fingerprint or screen lock first.'**
  String get celautOpenFullWalletNeeded;

  /// No description provided for @celautClientUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'The node forgot the client'**
  String get celautClientUnknownTitle;

  /// No description provided for @celautClientUnknownBody.
  ///
  /// In en, this message translates to:
  /// **'The node {node} does not know the client id of this app. Make a new client now, or retry later.'**
  String celautClientUnknownBody(String node);

  /// No description provided for @celautClientUnknownWarning.
  ///
  /// In en, this message translates to:
  /// **'A new client starts with only the free credit of the node. The balance of the old client is lost, also the ERG that you deposited to it.'**
  String get celautClientUnknownWarning;

  /// No description provided for @celautClientUnknownNew.
  ///
  /// In en, this message translates to:
  /// **'New client'**
  String get celautClientUnknownNew;

  /// No description provided for @celautClientUnknownRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry later'**
  String get celautClientUnknownRetry;

  /// No description provided for @celautClientUnknownDone.
  ///
  /// In en, this message translates to:
  /// **'The app now uses a new client on this node.'**
  String get celautClientUnknownDone;

  /// No description provided for @celautNodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get celautNodesTitle;

  /// No description provided for @celautNodesIntro.
  ///
  /// In en, this message translates to:
  /// **'The node list of the app. Add a node by its address or with a QR code. Only these nodes are in the sums of the home screen. A removed node keeps its deposits and its client in the app, so adding it again restores them.'**
  String get celautNodesIntro;

  /// No description provided for @celautNodesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get celautNodesAdd;

  /// No description provided for @celautNodesEmpty.
  ///
  /// In en, this message translates to:
  /// **'The node list is empty.'**
  String get celautNodesEmpty;

  /// No description provided for @celautNodesRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get celautNodesRemove;

  /// No description provided for @celautNodesSupport.
  ///
  /// In en, this message translates to:
  /// **'Support chat'**
  String get celautNodesSupport;

  /// No description provided for @celautSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Support chat'**
  String get celautSupportTitle;

  /// No description provided for @celautSupportHint.
  ///
  /// In en, this message translates to:
  /// **'Write to the operator of the node'**
  String get celautSupportHint;

  /// No description provided for @celautSupportSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get celautSupportSend;

  /// No description provided for @celautSupportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. If you have a problem with this node, write to its operator here. The operator reads the messages and can answer.'**
  String get celautSupportEmpty;

  /// No description provided for @celautSupportUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This node has no support chat.'**
  String get celautSupportUnsupported;

  /// No description provided for @celautSupportRefused.
  ///
  /// In en, this message translates to:
  /// **'The node did not take the message: {reason}'**
  String celautSupportRefused(String reason);

  /// No description provided for @celautNodesRemoved.
  ///
  /// In en, this message translates to:
  /// **'The node was removed. Its deposits stay in the app.'**
  String get celautNodesRemoved;

  /// No description provided for @celautNodesAdded.
  ///
  /// In en, this message translates to:
  /// **'The node was added.'**
  String get celautNodesAdded;

  /// No description provided for @celautNodesDeposited.
  ///
  /// In en, this message translates to:
  /// **'Deposits of the app: {amount}'**
  String celautNodesDeposited(String amount);

  /// No description provided for @celautUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'PIN of {name}'**
  String celautUnlockTitle(String name);

  /// No description provided for @celautUnlockFailed.
  ///
  /// In en, this message translates to:
  /// **'The wallet did not open.'**
  String get celautUnlockFailed;

  /// No description provided for @celautDepositAuthNeeded.
  ///
  /// In en, this message translates to:
  /// **'The deposit needs the fingerprint or screen lock for the paying wallet. Nothing was sent.'**
  String get celautDepositAuthNeeded;

  /// No description provided for @celautNodesRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add and remove the nodes in the sums of the home screen'**
  String get celautNodesRowSubtitle;

  /// No description provided for @celautNodesScan.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get celautNodesScan;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'Say something to start the conversation.'**
  String get chatEmpty;

  /// No description provided for @chatStarting.
  ///
  /// In en, this message translates to:
  /// **'The service is starting. It can take a minute before it answers.'**
  String get chatStarting;

  /// No description provided for @chatStop.
  ///
  /// In en, this message translates to:
  /// **'Stop the instance'**
  String get chatStop;

  /// No description provided for @chatErrorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The service did not answer. Your message may not have arrived. Try again.'**
  String get chatErrorUnreachable;

  /// No description provided for @chatErrorBadAnswer.
  ///
  /// In en, this message translates to:
  /// **'The service answered in a way that this app does not understand.'**
  String get chatErrorBadAnswer;

  /// No description provided for @chatErrorHistoryFull.
  ///
  /// In en, this message translates to:
  /// **'This conversation is full. Start a new instance for a new conversation.'**
  String get chatErrorHistoryFull;

  /// No description provided for @chatErrorStorageFull.
  ///
  /// In en, this message translates to:
  /// **'The service has no room to keep this file. The message was not sent.'**
  String get chatErrorStorageFull;

  /// No description provided for @chatErrorBusy.
  ///
  /// In en, this message translates to:
  /// **'The service is too busy to take this message. Try again in a moment.'**
  String get chatErrorBusy;

  /// No description provided for @chatErrorOther.
  ///
  /// In en, this message translates to:
  /// **'The service refused the message.'**
  String get chatErrorOther;

  /// No description provided for @chatAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach a photo or an audio file'**
  String get chatAttach;

  /// No description provided for @chatAttachmentRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove the file'**
  String get chatAttachmentRemove;

  /// No description provided for @chatAttachmentShare.
  ///
  /// In en, this message translates to:
  /// **'Open or share the file'**
  String get chatAttachmentShare;

  /// No description provided for @chatAttachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'The file did not load.'**
  String get chatAttachmentFailed;

  /// No description provided for @chatErrorUnsupportedMedia.
  ///
  /// In en, this message translates to:
  /// **'The service does not accept this kind of file.'**
  String get chatErrorUnsupportedMedia;

  /// No description provided for @chatErrorFile.
  ///
  /// In en, this message translates to:
  /// **'A file is empty or too big. Each file can have 4 MiB at most, and each message 4 files.'**
  String get chatErrorFile;

  /// No description provided for @chatSkippedDuplicate.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file is already attached} other{{count} files are already attached}}'**
  String chatSkippedDuplicate(int count);

  /// No description provided for @chatSkippedInvalid.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file is empty, too big or not a JPEG, PNG, MP3 or WAV file} other{{count} files are empty, too big or not JPEG, PNG, MP3 or WAV files}}'**
  String chatSkippedInvalid(int count);

  /// No description provided for @chatSkippedTooMany.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file was left out: a message has 4 files at most} other{{count} files were left out: a message has 4 files at most}}'**
  String chatSkippedTooMany(int count);

  /// No description provided for @chatImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get chatImage;

  /// No description provided for @chatTyping.
  ///
  /// In en, this message translates to:
  /// **'The service is answering…'**
  String get chatTyping;

  /// No description provided for @chatSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get chatSending;

  /// No description provided for @chatReasoning.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get chatReasoning;

  /// No description provided for @chatAnswerFailed.
  ///
  /// In en, this message translates to:
  /// **'The answer stopped before the end.'**
  String get chatAnswerFailed;

  /// No description provided for @chatAnswerCancelled.
  ///
  /// In en, this message translates to:
  /// **'The answer was cancelled.'**
  String get chatAnswerCancelled;

  /// No description provided for @chatWaitingSeconds.
  ///
  /// In en, this message translates to:
  /// **'Still working… {seconds} s'**
  String chatWaitingSeconds(int seconds);

  /// No description provided for @chatStopped.
  ///
  /// In en, this message translates to:
  /// **'The instance stopped. Refund: {refund}'**
  String chatStopped(String refund);

  /// No description provided for @chatsMenuMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatsMenuMore;

  /// No description provided for @chatsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get chatsNewTitle;

  /// No description provided for @chatsServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get chatsServicesTitle;

  /// No description provided for @chatsOtherTitle.
  ///
  /// In en, this message translates to:
  /// **'Other instances'**
  String get chatsOtherTitle;

  /// No description provided for @chatsOtherEmpty.
  ///
  /// In en, this message translates to:
  /// **'No other instances. A service that has no conversation shows here while it runs.'**
  String get chatsOtherEmpty;

  /// No description provided for @chatsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatsEmptyTitle;

  /// No description provided for @chatsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Each conversation is a service that runs on a node. Start one with the pencil button.'**
  String get chatsEmptyBody;

  /// No description provided for @chatsPaneEmpty.
  ///
  /// In en, this message translates to:
  /// **'Choose a conversation from the list, or start a new one.'**
  String get chatsPaneEmpty;

  /// No description provided for @chatsTabChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTabChats;

  /// No description provided for @chatsTabWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get chatsTabWallet;

  /// No description provided for @chatsTabCompute.
  ///
  /// In en, this message translates to:
  /// **'Compute'**
  String get chatsTabCompute;

  /// No description provided for @chatsDepositRow.
  ///
  /// In en, this message translates to:
  /// **'Deposit to a node'**
  String get chatsDepositRow;

  /// No description provided for @chatsDepositRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Credit on a node for its services, paid from the wallet'**
  String get chatsDepositRowSubtitle;

  /// No description provided for @chatsNodesRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a node by its address or a QR code'**
  String get chatsNodesRowSubtitle;

  /// No description provided for @chatsServicesRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import a service file, or run a service'**
  String get chatsServicesRowSubtitle;

  /// No description provided for @chatsOtherRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Instances without a conversation'**
  String get chatsOtherRowSubtitle;

  /// No description provided for @chatsStateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get chatsStateChecking;

  /// No description provided for @chatsStateStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get chatsStateStarting;

  /// No description provided for @chatsStateRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get chatsStateRunning;

  /// No description provided for @chatsStateUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Not answering'**
  String get chatsStateUnreachable;

  /// No description provided for @chatsStateStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get chatsStateStopped;

  /// No description provided for @chatsNoPreview.
  ///
  /// In en, this message translates to:
  /// **'No message seen since the app opened'**
  String get chatsNoPreview;

  /// No description provided for @chatsNoChatSlot.
  ///
  /// In en, this message translates to:
  /// **'No conversation: this service has no chat slot'**
  String get chatsNoChatSlot;

  /// No description provided for @chatsNoInterface.
  ///
  /// In en, this message translates to:
  /// **'No interface: this service has no chat or web slot'**
  String get chatsNoInterface;

  /// No description provided for @chatsWebPreview.
  ///
  /// In en, this message translates to:
  /// **'Web service · opens in the browser'**
  String get chatsWebPreview;

  /// No description provided for @chatsOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get chatsOpenInBrowser;

  /// No description provided for @chatsBrowserFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser'**
  String get chatsBrowserFailed;

  /// No description provided for @chatsPreviewYou.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String chatsPreviewYou(String text);

  /// No description provided for @chatsPreviewPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatsPreviewPhoto;

  /// No description provided for @chatsPreviewAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get chatsPreviewAudio;

  /// No description provided for @chatsPreviewNamed.
  ///
  /// In en, this message translates to:
  /// **'{kind}: {name}'**
  String chatsPreviewNamed(String kind, String name);

  /// No description provided for @chatMute.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get chatMute;

  /// No description provided for @chatUnmute.
  ///
  /// In en, this message translates to:
  /// **'Turn notifications on'**
  String get chatUnmute;

  /// No description provided for @chatMutedHint.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for this chat'**
  String get chatMutedHint;

  /// No description provided for @chatMic.
  ///
  /// In en, this message translates to:
  /// **'Record a voice message'**
  String get chatMic;

  /// No description provided for @chatMicCancel.
  ///
  /// In en, this message translates to:
  /// **'Discard the recording'**
  String get chatMicCancel;

  /// No description provided for @chatMicDone.
  ///
  /// In en, this message translates to:
  /// **'Attach the recording'**
  String get chatMicDone;

  /// No description provided for @chatMicDenied.
  ///
  /// In en, this message translates to:
  /// **'The app has no permission to use the microphone.'**
  String get chatMicDenied;

  /// No description provided for @chatMicLimit.
  ///
  /// In en, this message translates to:
  /// **'The recording reached the size limit and stopped. It is attached.'**
  String get chatMicLimit;

  /// No description provided for @chatPinnedExpand.
  ///
  /// In en, this message translates to:
  /// **'Show more of the pinned message'**
  String get chatPinnedExpand;

  /// No description provided for @chatPinnedCollapse.
  ///
  /// In en, this message translates to:
  /// **'Show less of the pinned message'**
  String get chatPinnedCollapse;

  /// No description provided for @chatPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatPin;

  /// No description provided for @chatUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatUnpin;

  /// No description provided for @chatCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopy;

  /// No description provided for @chatCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied.'**
  String get chatCopied;

  /// No description provided for @chatPinnedIcon.
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get chatPinnedIcon;

  /// No description provided for @chatNotifyDoneBody.
  ///
  /// In en, this message translates to:
  /// **'The answer is ready.'**
  String get chatNotifyDoneBody;

  /// No description provided for @chatsBackground.
  ///
  /// In en, this message translates to:
  /// **'Chat background'**
  String get chatsBackground;

  /// No description provided for @chatsActionInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get chatsActionInfo;

  /// No description provided for @chatsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatsDelete;

  /// No description provided for @chatsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatsRename;

  /// No description provided for @chatsRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatsRenameTitle;

  /// No description provided for @chatsRenameNote.
  ///
  /// In en, this message translates to:
  /// **'Only this phone sees this name. The node does not get it. Leave it empty to remove it.'**
  String get chatsRenameNote;

  /// No description provided for @chatsRenameNoteOriginal.
  ///
  /// In en, this message translates to:
  /// **'Only this phone sees this name. The node does not get it. Leave it empty to show \"{name}\" again.'**
  String chatsRenameNoteOriginal(String name);

  /// No description provided for @chatsShowStopped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 stopped instance} other{Show {count} stopped instances}}'**
  String chatsShowStopped(int count);

  /// No description provided for @chatsHideStopped.
  ///
  /// In en, this message translates to:
  /// **'Hide stopped instances'**
  String get chatsHideStopped;

  /// No description provided for @chatsStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop {name}?'**
  String chatsStopTitle(String name);

  /// No description provided for @chatsStopBody.
  ///
  /// In en, this message translates to:
  /// **'The conversation ends, and the node refunds what is left of the instance.'**
  String get chatsStopBody;

  /// No description provided for @chatsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String chatsDeleteTitle(String name);

  /// No description provided for @chatsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The instance is stopped. Delete takes it out of the app, with its token.'**
  String get chatsDeleteBody;

  /// No description provided for @chatsStartedOther.
  ///
  /// In en, this message translates to:
  /// **'The service started on {node}. It has no conversation: find it in Compute, under Services, in the page of the service.'**
  String chatsStartedOther(String node);

  /// No description provided for @chatsInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Instance'**
  String get chatsInfoTitle;

  /// No description provided for @chatsInfoStatus.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get chatsInfoStatus;

  /// No description provided for @chatsInfoNode.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get chatsInfoNode;

  /// No description provided for @chatsInfoPeer.
  ///
  /// In en, this message translates to:
  /// **'Peer id of the node'**
  String get chatsInfoPeer;

  /// No description provided for @chatsInfoServiceId.
  ///
  /// In en, this message translates to:
  /// **'Service id'**
  String get chatsInfoServiceId;

  /// No description provided for @chatsInfoInstanceId.
  ///
  /// In en, this message translates to:
  /// **'Instance id (token)'**
  String get chatsInfoInstanceId;

  /// No description provided for @chatsInfoSlot.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get chatsInfoSlot;

  /// No description provided for @chatsInfoChatSlot.
  ///
  /// In en, this message translates to:
  /// **'Chat over HTTP'**
  String get chatsInfoChatSlot;

  /// No description provided for @chatsInfoNoChatSlot.
  ///
  /// In en, this message translates to:
  /// **'No chat interface'**
  String get chatsInfoNoChatSlot;

  /// No description provided for @chatsInfoStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get chatsInfoStarted;

  /// No description provided for @chatsInfoCost.
  ///
  /// In en, this message translates to:
  /// **'Cost so far'**
  String get chatsInfoCost;

  /// No description provided for @chatsInfoRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund at the stop'**
  String get chatsInfoRefund;

  /// No description provided for @chatsInfoStopNote.
  ///
  /// In en, this message translates to:
  /// **'Stop ends the conversation. The node refunds what is left of the instance.'**
  String get chatsInfoStopNote;

  /// No description provided for @chatsInfoDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Only a stopped instance can be deleted. The app keeps every other instance, even if its node does not answer.'**
  String get chatsInfoDeleteNote;

  /// No description provided for @chatsReceiptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get chatsReceiptsTitle;

  /// No description provided for @chatsReceiptsStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get chatsReceiptsStart;

  /// No description provided for @chatsReceiptsCheckpoints.
  ///
  /// In en, this message translates to:
  /// **'Checkpoints'**
  String get chatsReceiptsCheckpoints;

  /// No description provided for @chatsReceiptsClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get chatsReceiptsClose;

  /// No description provided for @chatsReceiptsNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get chatsReceiptsNone;

  /// No description provided for @chatsReceiptsNoTunnel.
  ///
  /// In en, this message translates to:
  /// **'no tunnel yet'**
  String get chatsReceiptsNoTunnel;

  /// No description provided for @chatsReceiptsCancelled.
  ///
  /// In en, this message translates to:
  /// **'none (cancelled)'**
  String get chatsReceiptsCancelled;

  /// No description provided for @chatsReceiptsOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get chatsReceiptsOpen;

  /// No description provided for @chatsReceiptsFaultSent.
  ///
  /// In en, this message translates to:
  /// **'The node signed data that does not match what this phone sent'**
  String get chatsReceiptsFaultSent;

  /// No description provided for @chatsReceiptsFaultReceived.
  ///
  /// In en, this message translates to:
  /// **'The node signed data that does not match what this phone received'**
  String get chatsReceiptsFaultReceived;

  /// No description provided for @chatsReceiptsFaultEnvs.
  ///
  /// In en, this message translates to:
  /// **'The node signed environment variables that this phone did not send'**
  String get chatsReceiptsFaultEnvs;

  /// No description provided for @chatsReceiptsFaultService.
  ///
  /// In en, this message translates to:
  /// **'The node signed a different service from the one that this phone started'**
  String get chatsReceiptsFaultService;

  /// No description provided for @chatsReceiptsFaultAmount.
  ///
  /// In en, this message translates to:
  /// **'The node signed a different start balance from the one that this phone asked for'**
  String get chatsReceiptsFaultAmount;

  /// No description provided for @chatsReceiptsFaultInvalid.
  ///
  /// In en, this message translates to:
  /// **'A receipt does not verify'**
  String get chatsReceiptsFaultInvalid;

  /// No description provided for @chatsReceiptsFaultOmitted.
  ///
  /// In en, this message translates to:
  /// **'The node gave no start receipt, but it gave one before'**
  String get chatsReceiptsFaultOmitted;

  /// No description provided for @chatsReceiptsDropped.
  ///
  /// In en, this message translates to:
  /// **'Tunnels dropped'**
  String get chatsReceiptsDropped;

  /// No description provided for @chatsReceiptsExport.
  ///
  /// In en, this message translates to:
  /// **'Export receipts'**
  String get chatsReceiptsExport;

  /// No description provided for @chatsReceiptsExportNone.
  ///
  /// In en, this message translates to:
  /// **'There are no receipts to export.'**
  String get chatsReceiptsExportNone;

  /// No description provided for @chatsReceiptsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String chatsReceiptsExportFailed(String error);

  /// No description provided for @chatsReceiptsNote.
  ///
  /// In en, this message translates to:
  /// **'The node signs these receipts. They are evidence against the node. You can give them to other people. A tunnel with no close is not always a fault. For example, this phone or the node can stop the tunnel.'**
  String get chatsReceiptsNote;

  /// No description provided for @celautErrorNodeClosed.
  ///
  /// In en, this message translates to:
  /// **'The node is closed now: its operator accepts new work only at certain hours. Try later or choose another node.'**
  String get celautErrorNodeClosed;

  /// No description provided for @celautErrorNoRoom.
  ///
  /// In en, this message translates to:
  /// **'The node has not enough free resources for this service now. Try later or choose another node.'**
  String get celautErrorNoRoom;

  /// No description provided for @celautErrorServiceMissing.
  ///
  /// In en, this message translates to:
  /// **'The node does not have this service. Choose a node that has it.'**
  String get celautErrorServiceMissing;

  /// No description provided for @celautErrorPolicyRefused.
  ///
  /// In en, this message translates to:
  /// **'The policy of the node does not allow what this service connects to. Choose another node.'**
  String get celautErrorPolicyRefused;

  /// No description provided for @celautErrorUnsupportedArchitecture.
  ///
  /// In en, this message translates to:
  /// **'The node does not run this kind of service (it needs another processor architecture). Choose another node.'**
  String get celautErrorUnsupportedArchitecture;

  /// No description provided for @celautErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The node limits the calls of this app for a short time. Wait a moment and try again.'**
  String get celautErrorRateLimited;

  /// No description provided for @celautErrorRecursionLimit.
  ///
  /// In en, this message translates to:
  /// **'The node refused the request because it went round or too deep. Try again.'**
  String get celautErrorRecursionLimit;

  /// No description provided for @celautErrorInsufficientCredit.
  ///
  /// In en, this message translates to:
  /// **'Your credit on the node is less than the price of the service. Add a deposit on this node or choose another one.'**
  String get celautErrorInsufficientCredit;

  /// No description provided for @celautErrorLaunchFailed.
  ///
  /// In en, this message translates to:
  /// **'The node tried to start the service and could not.'**
  String get celautErrorLaunchFailed;

  /// No description provided for @celautRunTitle.
  ///
  /// In en, this message translates to:
  /// **'Run a service'**
  String get celautRunTitle;

  /// No description provided for @celautRunSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search skills and tags'**
  String get celautRunSearchHint;

  /// No description provided for @celautRunLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading skills…'**
  String get celautRunLoading;

  /// No description provided for @celautRunEmpty.
  ///
  /// In en, this message translates to:
  /// **'No skill matches.'**
  String get celautRunEmpty;

  /// No description provided for @celautRunCatalogError.
  ///
  /// In en, this message translates to:
  /// **'The skill catalog is not available now.'**
  String get celautRunCatalogError;

  /// No description provided for @celautRunRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get celautRunRetry;

  /// No description provided for @celautRunServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Services with this skill'**
  String get celautRunServicesTitle;

  /// No description provided for @celautRunNoServices.
  ///
  /// In en, this message translates to:
  /// **'No service has this skill yet.'**
  String get celautRunNoServices;

  /// No description provided for @celautRunBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get celautRunBest;

  /// No description provided for @celautRunScore.
  ///
  /// In en, this message translates to:
  /// **'Score {score}'**
  String celautRunScore(String score);

  /// No description provided for @celautRunButton.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get celautRunButton;

  /// No description provided for @celautRunLaunching.
  ///
  /// In en, this message translates to:
  /// **'Launching {name}…'**
  String celautRunLaunching(String name);

  /// No description provided for @celautRunLaunchingNote.
  ///
  /// In en, this message translates to:
  /// **'The app asks the nodes, then starts the service on the best one.'**
  String get celautRunLaunchingNote;

  /// No description provided for @celautRunStepNodes.
  ///
  /// In en, this message translates to:
  /// **'Asking the nodes for a price'**
  String get celautRunStepNodes;

  /// No description provided for @celautRunStepReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the service'**
  String get celautRunStepReading;

  /// No description provided for @celautRunStepStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting it on the best node'**
  String get celautRunStepStarting;

  /// No description provided for @celautRunStarted.
  ///
  /// In en, this message translates to:
  /// **'Started on {node}. Start cost: {cost}.'**
  String celautRunStarted(String node, String cost);

  /// No description provided for @celautRunOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get celautRunOpenChat;

  /// No description provided for @celautRunFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'The service did not start'**
  String get celautRunFailedTitle;

  /// No description provided for @celautRunFailedNoNodes.
  ///
  /// In en, this message translates to:
  /// **'There is no node to ask. Add a node in the Nodes list.'**
  String get celautRunFailedNoNodes;

  /// No description provided for @celautRunFailedNoQuotes.
  ///
  /// In en, this message translates to:
  /// **'No node gave a price. Here is why:'**
  String get celautRunFailedNoQuotes;

  /// No description provided for @celautRunFailedAll.
  ///
  /// In en, this message translates to:
  /// **'Some nodes gave a price, but none of them started the service. Here is why:'**
  String get celautRunFailedAll;

  /// No description provided for @celautRunNeedsCredit.
  ///
  /// In en, this message translates to:
  /// **'Your credit on this node is {credit}, and the service costs {cost}. Add a deposit on this node or choose another one.'**
  String celautRunNeedsCredit(String credit, String cost);

  /// No description provided for @celautRunLeftOut.
  ///
  /// In en, this message translates to:
  /// **'Left out: it did not answer the last checks.'**
  String get celautRunLeftOut;

  /// No description provided for @celautRunDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get celautRunDetails;

  /// No description provided for @celautRunClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get celautRunClose;

  /// No description provided for @celautRunDeposit.
  ///
  /// In en, this message translates to:
  /// **'Add a deposit'**
  String get celautRunDeposit;

  /// No description provided for @celautNodeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available · {ms} ms'**
  String celautNodeAvailable(String ms);

  /// No description provided for @celautNodeSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow · {ms} ms'**
  String celautNodeSlow(String ms);

  /// No description provided for @celautNodeUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Not answering'**
  String get celautNodeUnreachable;

  /// No description provided for @celautNodeUnknownState.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get celautNodeUnknownState;

  /// No description provided for @celautNodeLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last answer {ago} ago'**
  String celautNodeLastSeen(String ago);

  /// No description provided for @celautNodeNeverSeen.
  ///
  /// In en, this message translates to:
  /// **'It has never answered'**
  String get celautNodeNeverSeen;

  /// No description provided for @celautNodeChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get celautNodeChecking;

  /// No description provided for @celautAgoSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n} s'**
  String celautAgoSeconds(String n);

  /// No description provided for @celautAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String celautAgoMinutes(String n);

  /// No description provided for @celautAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h'**
  String celautAgoHours(String n);

  /// No description provided for @celautAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{n} d'**
  String celautAgoDays(String n);

  /// No description provided for @celautNodesCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get celautNodesCheckNow;

  /// No description provided for @celautRunPreview.
  ///
  /// In en, this message translates to:
  /// **'Best node now: {node} · start cost {cost}'**
  String celautRunPreview(String node, String cost);

  /// No description provided for @celautRunPreviewLoading.
  ///
  /// In en, this message translates to:
  /// **'Looking for the best node…'**
  String get celautRunPreviewLoading;

  /// No description provided for @celautRunConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Run {name}?'**
  String celautRunConfirmTitle(String name);

  /// No description provided for @celautRunConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The service runs on a node and uses your credit there until it stops. Stop it from its conversation, its info page or the list of conversations.'**
  String get celautRunConfirmBody;

  /// No description provided for @celautRunConfirmNoQuote.
  ///
  /// In en, this message translates to:
  /// **'No node gave a price yet. Run asks every node of the list.'**
  String get celautRunConfirmNoQuote;

  /// No description provided for @celautRunSurvivalLabel.
  ///
  /// In en, this message translates to:
  /// **'Keep it running at least'**
  String get celautRunSurvivalLabel;

  /// No description provided for @celautRunSurvivalHint.
  ///
  /// In en, this message translates to:
  /// **'Empty: the default start balance'**
  String get celautRunSurvivalHint;

  /// No description provided for @celautRunSurvivalWrong.
  ///
  /// In en, this message translates to:
  /// **'From 1 minute to 30 days.'**
  String get celautRunSurvivalWrong;

  /// No description provided for @celautRunDefaultBalance.
  ///
  /// In en, this message translates to:
  /// **'Start balance {balance} (the default).'**
  String celautRunDefaultBalance(String balance);

  /// No description provided for @celautRunDefaultBalanceLasts.
  ///
  /// In en, this message translates to:
  /// **'Start balance {balance} (the default): about {time} on this node.'**
  String celautRunDefaultBalanceLasts(String balance, String time);

  /// No description provided for @celautRunSurvivalNoPrice.
  ///
  /// In en, this message translates to:
  /// **'This node gives no price for its time. The app uses the default start balance.'**
  String get celautRunSurvivalNoPrice;

  /// No description provided for @celautRunSurvivalEstimate.
  ///
  /// In en, this message translates to:
  /// **'Start cost about {cost}, with a balance of {balance} for at least {time} at the price of the node now. A busy node, and the traffic of the conversation, cost more. The node gives back what the instance does not use.'**
  String celautRunSurvivalEstimate(String cost, String balance, String time);

  /// No description provided for @celautTopUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep running'**
  String get celautTopUpTitle;

  /// No description provided for @celautTopUpThreshold.
  ///
  /// In en, this message translates to:
  /// **'When an instance would last less than'**
  String get celautTopUpThreshold;

  /// No description provided for @celautTopUpAmount.
  ///
  /// In en, this message translates to:
  /// **'Each time, add this much time'**
  String get celautTopUpAmount;

  /// No description provided for @celautTopUpRange.
  ///
  /// In en, this message translates to:
  /// **'From {min} to {max} minutes.'**
  String celautTopUpRange(String min, String max);

  /// No description provided for @celautTopUpNote.
  ///
  /// In en, this message translates to:
  /// **'The app checks the instances that you keep running when the list of conversations opens and once a minute while the app runs. A top-up moves credit that you already have on the node of the instance (ModifyDeposit): nothing is paid on the blockchain and nothing is signed. If that credit is too low, the app does not pay: it asks you, and a deposit always needs your confirmation and your fingerprint or screen lock. The app does not run when it is closed: then nothing is added, and the node stops the instance when its balance runs out.'**
  String get celautTopUpNote;

  /// No description provided for @celautTopUpNeedLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get celautTopUpNeedLater;

  /// No description provided for @celautTopUpNeedDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get celautTopUpNeedDeposit;

  /// No description provided for @celautErrorTransferFailed.
  ///
  /// In en, this message translates to:
  /// **'The transfer of the service stopped (the file could not be read, it is cut, or it was cancelled). The node did not keep the cut service. Try again.'**
  String get celautErrorTransferFailed;

  /// No description provided for @celautSendMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'The service is not on these nodes'**
  String get celautSendMissingTitle;

  /// No description provided for @celautSendFromNode.
  ///
  /// In en, this message translates to:
  /// **'Send it from {from} to {to}'**
  String celautSendFromNode(String from, String to);

  /// No description provided for @celautSendFromFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a .celaut.bee file and send it to {to}'**
  String celautSendFromFile(String to);

  /// No description provided for @celautSendNoHolder.
  ///
  /// In en, this message translates to:
  /// **'No node of your list has this service. You can give it to a node from a .celaut.bee file.'**
  String get celautSendNoHolder;

  /// No description provided for @celautSendConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Send the service?'**
  String get celautSendConfirmTitle;

  /// No description provided for @celautSendConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The whole service goes through this phone to the node, and a service can be large. The node keeps it, so later launches on that node do not send it again.'**
  String get celautSendConfirmBody;

  /// No description provided for @celautSendMetered.
  ///
  /// In en, this message translates to:
  /// **'You are on mobile data: this can use a lot of it.'**
  String get celautSendMetered;

  /// No description provided for @celautSendConfirm.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get celautSendConfirm;

  /// No description provided for @celautSendCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get celautSendCancel;

  /// No description provided for @celautSendFetching.
  ///
  /// In en, this message translates to:
  /// **'Getting the service from the node…'**
  String get celautSendFetching;

  /// No description provided for @celautSendSending.
  ///
  /// In en, this message translates to:
  /// **'Giving the service to the node…'**
  String get celautSendSending;

  /// No description provided for @celautSendStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting the transfer…'**
  String get celautSendStarting;

  /// No description provided for @celautImportReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the service file…'**
  String get celautImportReading;

  /// No description provided for @celautImportReadingNote.
  ///
  /// In en, this message translates to:
  /// **'The app copies the file into its own storage first. A large file takes some time.'**
  String get celautImportReadingNote;

  /// No description provided for @celautImportChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the service file…'**
  String get celautImportChecking;

  /// No description provided for @celautImportNote.
  ///
  /// In en, this message translates to:
  /// **'The app hashes every block, so a damaged file is found here and not after it goes to a node.'**
  String get celautImportNote;

  /// No description provided for @celautSendProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} ({percent}%)'**
  String celautSendProgress(String done, String total, String percent);

  /// No description provided for @celautSendSoFar.
  ///
  /// In en, this message translates to:
  /// **'{done} so far'**
  String celautSendSoFar(String done);

  /// No description provided for @celautSendDone.
  ///
  /// In en, this message translates to:
  /// **'The node has the service now. Starting it…'**
  String get celautSendDone;

  /// No description provided for @celautSendFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'The service was not sent'**
  String get celautSendFailedTitle;

  /// No description provided for @celautSendOtherService.
  ///
  /// In en, this message translates to:
  /// **'This file holds another service.'**
  String get celautSendOtherService;

  /// No description provided for @celautSendNoServicePart.
  ///
  /// In en, this message translates to:
  /// **'This file has no service in it.'**
  String get celautSendNoServicePart;

  /// No description provided for @celautSendNoDirectory.
  ///
  /// In en, this message translates to:
  /// **'The app has no place to keep the service.'**
  String get celautSendNoDirectory;

  /// No description provided for @celautPkgTitle.
  ///
  /// In en, this message translates to:
  /// **'Your services'**
  String get celautPkgTitle;

  /// No description provided for @celautPkgImport.
  ///
  /// In en, this message translates to:
  /// **'Import a service file'**
  String get celautPkgImport;

  /// No description provided for @celautPkgEmpty.
  ///
  /// In en, this message translates to:
  /// **'No service file is loaded. Import a .celaut.bee file to run a service that no node has yet.'**
  String get celautPkgEmpty;

  /// No description provided for @celautPkgRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get celautPkgRemove;

  /// No description provided for @celautPkgRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this service file?'**
  String get celautPkgRemoveTitle;

  /// No description provided for @celautPkgRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is deleted from this app. The nodes that have the service keep it.'**
  String celautPkgRemoveBody(String name);

  /// No description provided for @celautPkgLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded {name}.'**
  String celautPkgLoaded(String name);

  /// No description provided for @celautPkgBadFile.
  ///
  /// In en, this message translates to:
  /// **'This file is not a service package: {reason}'**
  String celautPkgBadFile(String reason);

  /// No description provided for @celautPkgUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The app cannot read this file: {reason}'**
  String celautPkgUnreadable(String reason);

  /// No description provided for @celautPkgAgainTitle.
  ///
  /// In en, this message translates to:
  /// **'Already in the app'**
  String get celautPkgAgainTitle;

  /// No description provided for @celautPkgAgainBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is already in the app, with the same size. Import it again?'**
  String celautPkgAgainBody(String name);

  /// No description provided for @celautPkgAgainImport.
  ///
  /// In en, this message translates to:
  /// **'Import again'**
  String get celautPkgAgainImport;

  /// No description provided for @celautPkgReplaced.
  ///
  /// In en, this message translates to:
  /// **'Loaded {name} again. It replaces the file that the app had.'**
  String celautPkgReplaced(String name);

  /// No description provided for @celautPkgMissing.
  ///
  /// In en, this message translates to:
  /// **'The file is gone. Import it again.'**
  String get celautPkgMissing;

  /// No description provided for @celautPkgRedownload.
  ///
  /// In en, this message translates to:
  /// **'Download the file again and try once more: a browser sometimes saves it damaged.'**
  String get celautPkgRedownload;

  /// No description provided for @celautSendFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Send your loaded file to {to}'**
  String celautSendFromLibrary(String to);

  /// No description provided for @celautHomeNodesReady.
  ///
  /// In en, this message translates to:
  /// **'{ready} of {total} nodes ready'**
  String celautHomeNodesReady(String ready, String total);

  /// No description provided for @celautHomeCreditOnNodes.
  ///
  /// In en, this message translates to:
  /// **'Credit on nodes'**
  String get celautHomeCreditOnNodes;

  /// No description provided for @celautNodeCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit: {credit}'**
  String celautNodeCredit(String credit);

  /// No description provided for @celautEnvTitle.
  ///
  /// In en, this message translates to:
  /// **'Environment variables'**
  String get celautEnvTitle;

  /// No description provided for @celautEnvRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Values that a service can get when it starts'**
  String get celautEnvRowSubtitle;

  /// No description provided for @celautEnvIntro.
  ///
  /// In en, this message translates to:
  /// **'Named values that you can give to a service when you run it, for example a key. They stay encrypted on this phone. A service only gets the ones that you choose.'**
  String get celautEnvIntro;

  /// No description provided for @celautEnvEmpty.
  ///
  /// In en, this message translates to:
  /// **'No variables yet.'**
  String get celautEnvEmpty;

  /// No description provided for @celautEnvAdd.
  ///
  /// In en, this message translates to:
  /// **'Add variable'**
  String get celautEnvAdd;

  /// No description provided for @celautEnvEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String celautEnvEditTitle(String name);

  /// No description provided for @celautEnvName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get celautEnvName;

  /// No description provided for @celautEnvValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get celautEnvValue;

  /// No description provided for @celautEnvShow.
  ///
  /// In en, this message translates to:
  /// **'Show the value'**
  String get celautEnvShow;

  /// No description provided for @celautEnvHide.
  ///
  /// In en, this message translates to:
  /// **'Hide the value'**
  String get celautEnvHide;

  /// No description provided for @celautEnvEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get celautEnvEdit;

  /// No description provided for @celautEnvDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get celautEnvDelete;

  /// No description provided for @celautEnvDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String celautEnvDeleteTitle(String name);

  /// No description provided for @celautEnvDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Services that you run later cannot use it. Instances that already run keep what they got.'**
  String get celautEnvDeleteBody;

  /// No description provided for @celautEnvNameBad.
  ///
  /// In en, this message translates to:
  /// **'The name must start with a letter or _ and have only letters, digits and _.'**
  String get celautEnvNameBad;

  /// No description provided for @celautEnvNameReserved.
  ///
  /// In en, this message translates to:
  /// **'This name is reserved for the name of the instance.'**
  String get celautEnvNameReserved;

  /// No description provided for @celautEnvNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A variable with this name exists. Edit it instead.'**
  String get celautEnvNameTaken;

  /// No description provided for @celautEnvValueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Write a value.'**
  String get celautEnvValueEmpty;

  /// No description provided for @celautEnvValueLong.
  ///
  /// In en, this message translates to:
  /// **'The value is longer than 8192 bytes.'**
  String get celautEnvValueLong;

  /// No description provided for @celautEnvValueNul.
  ///
  /// In en, this message translates to:
  /// **'The value cannot have a NUL character.'**
  String get celautEnvValueNul;

  /// No description provided for @celautEnvTooMany.
  ///
  /// In en, this message translates to:
  /// **'There are 256 variables. Delete one first.'**
  String get celautEnvTooMany;

  /// No description provided for @celautEnvAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Variables of the service'**
  String get celautEnvAskTitle;

  /// No description provided for @celautEnvAskStep.
  ///
  /// In en, this message translates to:
  /// **'Variable {current} of {total}'**
  String celautEnvAskStep(int current, int total);

  /// No description provided for @celautEnvAskNoText.
  ///
  /// In en, this message translates to:
  /// **'The service gives no description of this variable.'**
  String get celautEnvAskNoText;

  /// No description provided for @celautEnvAskPick.
  ///
  /// In en, this message translates to:
  /// **'Choose from my variables'**
  String get celautEnvAskPick;

  /// No description provided for @celautEnvAskPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a variable'**
  String get celautEnvAskPickTitle;

  /// No description provided for @celautEnvAskPickEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no variables yet. Add them in Settings, Environment variables.'**
  String get celautEnvAskPickEmpty;

  /// No description provided for @celautEnvAskType.
  ///
  /// In en, this message translates to:
  /// **'Type a value'**
  String get celautEnvAskType;

  /// No description provided for @celautEnvAskUse.
  ///
  /// In en, this message translates to:
  /// **'Use this value'**
  String get celautEnvAskUse;

  /// No description provided for @celautEnvAskSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get celautEnvAskSkip;

  /// No description provided for @celautEnvAskSkipHint.
  ///
  /// In en, this message translates to:
  /// **'The service does not get this variable.'**
  String get celautEnvAskSkipHint;

  /// No description provided for @celautEnvAskBadName.
  ///
  /// In en, this message translates to:
  /// **'The node cannot give this variable, because its name is not valid. You can only skip it.'**
  String get celautEnvAskBadName;

  /// No description provided for @celautEnvAskChosen.
  ///
  /// In en, this message translates to:
  /// **'Chosen: {what}'**
  String celautEnvAskChosen(String what);

  /// No description provided for @celautEnvAskBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get celautEnvAskBack;

  /// No description provided for @celautEnvReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get celautEnvReviewTitle;

  /// No description provided for @celautEnvReviewFromContainer.
  ///
  /// In en, this message translates to:
  /// **'My variable {name}'**
  String celautEnvReviewFromContainer(String name);

  /// No description provided for @celautEnvReviewTyped.
  ///
  /// In en, this message translates to:
  /// **'Typed value'**
  String get celautEnvReviewTyped;

  /// No description provided for @celautEnvReviewSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get celautEnvReviewSkipped;

  /// No description provided for @celautEnvReviewNote.
  ///
  /// In en, this message translates to:
  /// **'The node that starts the service reads these values. A node that refuses the start has read them too.'**
  String get celautEnvReviewNote;

  /// No description provided for @celautEnvRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get celautEnvRun;

  /// No description provided for @celautEnvDeclUnreadableTitle.
  ///
  /// In en, this message translates to:
  /// **'The service could not be read'**
  String get celautEnvDeclUnreadableTitle;

  /// No description provided for @celautEnvDeclUnreadableBody.
  ///
  /// In en, this message translates to:
  /// **'The app could not read the interface and the variables of this service, so it cannot tell if Chatui supports it or if it needs variables. Run it anyway, or cancel.'**
  String get celautEnvDeclUnreadableBody;

  /// No description provided for @celautEnvRunWithout.
  ///
  /// In en, this message translates to:
  /// **'Run anyway'**
  String get celautEnvRunWithout;

  /// No description provided for @celautInviteConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected by {address}. The node is in your list.'**
  String celautInviteConnected(String address);

  /// No description provided for @celautInviteFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the invited node'**
  String get celautInviteFailedTitle;

  /// No description provided for @celautInviteNoAddress.
  ///
  /// In en, this message translates to:
  /// **'The invitation has no address that this app can use.'**
  String get celautInviteNoAddress;

  /// No description provided for @celautInviteOnionNeedsProxy.
  ///
  /// In en, this message translates to:
  /// **'Not tried. An onion address needs Tor through an external proxy such as Orbot. A direct connection and the Tor client of the app cannot open it.'**
  String get celautInviteOnionNeedsProxy;

  /// No description provided for @celautInvitePrivateOverTor.
  ///
  /// In en, this message translates to:
  /// **'Not tried. An address on a private network cannot be reached through Tor.'**
  String get celautInvitePrivateOverTor;

  /// No description provided for @serviceInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Service details'**
  String get serviceInfoTitle;

  /// No description provided for @serviceInfoLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading the service…'**
  String get serviceInfoLoading;

  /// No description provided for @serviceInfoReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The service could not be read'**
  String get serviceInfoReadFailed;

  /// No description provided for @serviceInfoTruncated.
  ///
  /// In en, this message translates to:
  /// **'This service is too large to read from a node, so only what comes first is shown. Load its file to see everything.'**
  String get serviceInfoTruncated;

  /// No description provided for @serviceInfoChatSupported.
  ///
  /// In en, this message translates to:
  /// **'It follows the chat convention of Chatui, so it opens as a conversation.'**
  String get serviceInfoChatSupported;

  /// No description provided for @serviceInfoChatUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Chatui does not support its interface: no port speaks the chat convention (tcp, then http2, grpc and chat above it). It can run, but Chatui cannot open a conversation with it.'**
  String get serviceInfoChatUnsupported;

  /// No description provided for @serviceInfoChatUnknown.
  ///
  /// In en, this message translates to:
  /// **'The app could not read the interface of this service, so it cannot tell if it works as a conversation.'**
  String get serviceInfoChatUnknown;

  /// No description provided for @serviceInfoAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get serviceInfoAbout;

  /// No description provided for @serviceInfoNoProse.
  ///
  /// In en, this message translates to:
  /// **'The service gives no description.'**
  String get serviceInfoNoProse;

  /// No description provided for @serviceInfoArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get serviceInfoArchitecture;

  /// No description provided for @serviceInfoEntry.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get serviceInfoEntry;

  /// No description provided for @serviceInfoFilesystem.
  ///
  /// In en, this message translates to:
  /// **'Filesystem'**
  String get serviceInfoFilesystem;

  /// No description provided for @serviceInfoConfigFile.
  ///
  /// In en, this message translates to:
  /// **'Configuration file'**
  String get serviceInfoConfigFile;

  /// No description provided for @serviceInfoResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get serviceInfoResources;

  /// No description provided for @serviceInfoAtStart.
  ///
  /// In en, this message translates to:
  /// **'Needs at the start'**
  String get serviceInfoAtStart;

  /// No description provided for @serviceInfoAtMost.
  ///
  /// In en, this message translates to:
  /// **'Can use at most'**
  String get serviceInfoAtMost;

  /// No description provided for @serviceInfoNoResources.
  ///
  /// In en, this message translates to:
  /// **'The service does not say what it needs.'**
  String get serviceInfoNoResources;

  /// No description provided for @serviceInfoCoreSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed of one core'**
  String get serviceInfoCoreSpeed;

  /// No description provided for @serviceInfoInterface.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get serviceInfoInterface;

  /// No description provided for @serviceInfoNoInterface.
  ///
  /// In en, this message translates to:
  /// **'The service declares no port.'**
  String get serviceInfoNoInterface;

  /// No description provided for @serviceInfoSlot.
  ///
  /// In en, this message translates to:
  /// **'Interface {n}'**
  String serviceInfoSlot(int n);

  /// No description provided for @serviceInfoChatReady.
  ///
  /// In en, this message translates to:
  /// **'Chat ready'**
  String get serviceInfoChatReady;

  /// No description provided for @serviceInfoPricePerCall.
  ///
  /// In en, this message translates to:
  /// **'MU per call'**
  String get serviceInfoPricePerCall;

  /// No description provided for @serviceInfoNetworks.
  ///
  /// In en, this message translates to:
  /// **'Networks'**
  String get serviceInfoNetworks;

  /// No description provided for @serviceInfoNoNetworks.
  ///
  /// In en, this message translates to:
  /// **'The service does not connect to any network.'**
  String get serviceInfoNoNetworks;

  /// No description provided for @serviceInfoAnyAddress.
  ///
  /// In en, this message translates to:
  /// **'Every address'**
  String get serviceInfoAnyAddress;

  /// No description provided for @serviceInfoPeersSpeak.
  ///
  /// In en, this message translates to:
  /// **'Peers speak: {protocols}'**
  String serviceInfoPeersSpeak(String protocols);

  /// No description provided for @serviceInfoEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment variables'**
  String get serviceInfoEnvironment;

  /// No description provided for @serviceInfoNoEnvironment.
  ///
  /// In en, this message translates to:
  /// **'The service declares no variables.'**
  String get serviceInfoNoEnvironment;

  /// No description provided for @serviceInfoMore.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get serviceInfoMore;

  /// No description provided for @serviceInfoNodeProtocols.
  ///
  /// In en, this message translates to:
  /// **'Protocols that it expects from the node'**
  String get serviceInfoNodeProtocols;

  /// No description provided for @serviceInfoWorkloads.
  ///
  /// In en, this message translates to:
  /// **'Instances that it can start'**
  String get serviceInfoWorkloads;

  /// No description provided for @serviceInfoWorkload.
  ///
  /// In en, this message translates to:
  /// **'{count} × instance'**
  String serviceInfoWorkload(int count);

  /// No description provided for @serviceInfoWorkloadService.
  ///
  /// In en, this message translates to:
  /// **'of a service'**
  String get serviceInfoWorkloadService;

  /// No description provided for @serviceInfoWorkloadsSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 scenario is too large to show.} other{{count} scenarios are too large to show.}}'**
  String serviceInfoWorkloadsSkipped(int count);

  /// No description provided for @celautChatUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Chatui does not support this interface'**
  String get celautChatUnsupportedTitle;

  /// No description provided for @celautChatUnsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'This service does not follow the chat convention that Chatui uses, so Chatui cannot open a conversation with it. If you run it, it shows in Compute, and you cannot talk to it from here.'**
  String get celautChatUnsupportedBody;

  /// No description provided for @celautChatRunAnyway.
  ///
  /// In en, this message translates to:
  /// **'Run anyway'**
  String get celautChatRunAnyway;

  /// No description provided for @celautChatDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get celautChatDetails;

  /// No description provided for @celautRunConfirmDetails.
  ///
  /// In en, this message translates to:
  /// **'Service details'**
  String get celautRunConfirmDetails;

  /// No description provided for @chatsInfoServiceDetails.
  ///
  /// In en, this message translates to:
  /// **'Service details'**
  String get chatsInfoServiceDetails;

  /// No description provided for @serviceInfoPartsSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 part of the service is too large to show.} other{{count} parts of the service are too large to show.}}'**
  String serviceInfoPartsSkipped(int count);

  /// No description provided for @walletSummaryDetails.
  ///
  /// In en, this message translates to:
  /// **'Wallet details'**
  String get walletSummaryDetails;

  /// No description provided for @walletSummaryLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest transactions'**
  String get walletSummaryLatest;

  /// No description provided for @walletSummaryNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get walletSummaryNoTransactions;

  /// No description provided for @chatSelectText.
  ///
  /// In en, this message translates to:
  /// **'Select text'**
  String get chatSelectText;

  /// No description provided for @celautRunMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more options'**
  String celautRunMoreOptions(String count);

  /// No description provided for @celautRunFewerOptions.
  ///
  /// In en, this message translates to:
  /// **'Show fewer options'**
  String get celautRunFewerOptions;

  /// No description provided for @celautRunCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get celautRunCategoryAll;

  /// No description provided for @celautRunOnPhone.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get celautRunOnPhone;

  /// No description provided for @celautRunImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get celautRunImport;

  /// No description provided for @celautRunPhoneServices.
  ///
  /// In en, this message translates to:
  /// **'Run the services on this phone'**
  String get celautRunPhoneServices;

  /// No description provided for @celautStoreFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get celautStoreFeatured;

  /// No description provided for @celautStoreFeaturedHint.
  ///
  /// In en, this message translates to:
  /// **'One skill of each field, from the publisher with the most reputation'**
  String get celautStoreFeaturedHint;

  /// No description provided for @celautStoreSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested for you'**
  String get celautStoreSuggested;

  /// No description provided for @celautStoreSuggestedHint.
  ///
  /// In en, this message translates to:
  /// **'In the fields of the skills that you ran'**
  String get celautStoreSuggestedHint;

  /// No description provided for @celautStoreNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get celautStoreNew;

  /// No description provided for @celautStoreNewHint.
  ///
  /// In en, this message translates to:
  /// **'The last skills published on Ergo'**
  String get celautStoreNewHint;

  /// No description provided for @celautStorePopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get celautStorePopular;

  /// No description provided for @celautStorePopularHint.
  ///
  /// In en, this message translates to:
  /// **'The skills with the most services'**
  String get celautStorePopularHint;

  /// No description provided for @celautStoreCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get celautStoreCategories;

  /// No description provided for @celautStoreAll.
  ///
  /// In en, this message translates to:
  /// **'All skills'**
  String get celautStoreAll;

  /// No description provided for @celautStoreServices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 service} other{{count} services}}'**
  String celautStoreServices(int count);

  /// No description provided for @celautStoreSkills.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 skill} other{{count} skills}}'**
  String celautStoreSkills(int count);

  /// No description provided for @celautEnvSensitive.
  ///
  /// In en, this message translates to:
  /// **'Sensitive'**
  String get celautEnvSensitive;

  /// No description provided for @celautEnvNotSensitive.
  ///
  /// In en, this message translates to:
  /// **'Not sensitive'**
  String get celautEnvNotSensitive;

  /// No description provided for @celautEnvSensitiveHint.
  ///
  /// In en, this message translates to:
  /// **'A password, a key or a token. Before a sensitive value goes where others can read it, the app warns you.'**
  String get celautEnvSensitiveHint;

  /// No description provided for @celautEnvMarkSensitive.
  ///
  /// In en, this message translates to:
  /// **'Mark as sensitive'**
  String get celautEnvMarkSensitive;

  /// No description provided for @celautEnvMarkNotSensitive.
  ///
  /// In en, this message translates to:
  /// **'Mark as not sensitive'**
  String get celautEnvMarkNotSensitive;

  /// No description provided for @celautEnvEgressSteers.
  ///
  /// In en, this message translates to:
  /// **'This variable sets where the service connects.'**
  String get celautEnvEgressSteers;

  /// No description provided for @celautEnvEgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Your sensitive values can leave the node'**
  String get celautEnvEgressTitle;

  /// No description provided for @celautEnvEgressBody.
  ///
  /// In en, this message translates to:
  /// **'This service can connect outside the node, to: {exits}. It can send your sensitive values there.'**
  String celautEnvEgressBody(String exits);

  /// No description provided for @celautEnvEgressAnyAddress.
  ///
  /// In en, this message translates to:
  /// **'any address'**
  String get celautEnvEgressAnyAddress;

  /// No description provided for @celautEnvNetworksTitle.
  ///
  /// In en, this message translates to:
  /// **'The service shares networks on the node'**
  String get celautEnvNetworksTitle;

  /// No description provided for @celautEnvNetworksBody.
  ///
  /// In en, this message translates to:
  /// **'This service can connect to other services on the node, in the networks: {networks}. It can give them your sensitive values.'**
  String celautEnvNetworksBody(String networks);

  /// No description provided for @celautEnvNodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Nodes that you do not fully trust'**
  String get celautEnvNodesTitle;

  /// No description provided for @celautEnvNodesBody.
  ///
  /// In en, this message translates to:
  /// **'These nodes can start the service, and you did not mark them as fully trusted: {nodes}. The node that gets the start reads your sensitive values. To mark a node, go to Compute, Nodes.'**
  String celautEnvNodesBody(String nodes);

  /// No description provided for @celautEnvDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get celautEnvDeny;

  /// No description provided for @celautEnvRunAnyway.
  ///
  /// In en, this message translates to:
  /// **'Send the values and run'**
  String get celautEnvRunAnyway;

  /// No description provided for @celautNodesTrusted.
  ///
  /// In en, this message translates to:
  /// **'Fully trusted'**
  String get celautNodesTrusted;

  /// No description provided for @celautNodesTrustedHint.
  ///
  /// In en, this message translates to:
  /// **'Your node, or a node of family, friends or your company. The app does not warn before it gives this node your sensitive values.'**
  String get celautNodesTrustedHint;

  /// No description provided for @celautNodesPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority: {value} of 100'**
  String celautNodesPriority(int value);

  /// No description provided for @celautNodesPriorityFullTrust.
  ///
  /// In en, this message translates to:
  /// **'Priority: 100 of 100 (full trust)'**
  String get celautNodesPriorityFullTrust;

  /// No description provided for @celautNodesPriorityHint.
  ///
  /// In en, this message translates to:
  /// **'Your reputation for this node, from 0 to 100 (50 is neutral). When the app compares prices, a higher number favors this node. Full trust is always 100.'**
  String get celautNodesPriorityHint;

  /// No description provided for @balancerTitle.
  ///
  /// In en, this message translates to:
  /// **'Balancer weights'**
  String get balancerTitle;

  /// No description provided for @balancerRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How the app chooses the node that runs a service'**
  String get balancerRowSubtitle;

  /// No description provided for @balancerIntro.
  ///
  /// In en, this message translates to:
  /// **'To choose a node, the app asks each one for a price and gives it a score: the price term plus the terms below, each multiplied by its weight. The node with the highest score goes first. A higher weight makes that term count more; 0 switches it off. A free offer always comes first.'**
  String get balancerIntro;

  /// No description provided for @balancerPriceName.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get balancerPriceName;

  /// No description provided for @balancerPriceDesc.
  ///
  /// In en, this message translates to:
  /// **'How much a cheaper quote counts. Each time the price is divided by e (about 2.7), the score rises by this weight.'**
  String get balancerPriceDesc;

  /// No description provided for @balancerReputationName.
  ///
  /// In en, this message translates to:
  /// **'Local reputation'**
  String get balancerReputationName;

  /// No description provided for @balancerReputationDesc.
  ///
  /// In en, this message translates to:
  /// **'What this app learned from its own history with each node. There are no recorded events yet, so this term is 0 for now.'**
  String get balancerReputationDesc;

  /// No description provided for @balancerOnchainName.
  ///
  /// In en, this message translates to:
  /// **'On-chain reputation'**
  String get balancerOnchainName;

  /// No description provided for @balancerOnchainDesc.
  ///
  /// In en, this message translates to:
  /// **'The opinion that other publishers record on the blockchain. Not read by the app yet, so this term is 0 for now.'**
  String get balancerOnchainDesc;

  /// No description provided for @balancerDonationName.
  ///
  /// In en, this message translates to:
  /// **'Donations'**
  String get balancerDonationName;

  /// No description provided for @balancerDonationDesc.
  ///
  /// In en, this message translates to:
  /// **'A bonus for nodes that donate. Not used by the app yet, so this term is 0 for now.'**
  String get balancerDonationDesc;

  /// No description provided for @balancerPriorityName.
  ///
  /// In en, this message translates to:
  /// **'Your priority for each node'**
  String get balancerPriorityName;

  /// No description provided for @balancerPriorityDesc.
  ///
  /// In en, this message translates to:
  /// **'The 0 to 100 priority that you give each node in the node list (50 is neutral, full trust is 100).'**
  String get balancerPriorityDesc;

  /// No description provided for @balancerDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get balancerDefaultLabel;

  /// No description provided for @balancerOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get balancerOffLabel;

  /// No description provided for @balancerReset.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get balancerReset;

  /// No description provided for @balancerPresetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick setups'**
  String get balancerPresetsLabel;

  /// No description provided for @balancerPresetBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get balancerPresetBalanced;

  /// No description provided for @balancerPresetCheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest first'**
  String get balancerPresetCheapest;

  /// No description provided for @balancerPresetTrusted.
  ///
  /// In en, this message translates to:
  /// **'My nodes first'**
  String get balancerPresetTrusted;

  /// No description provided for @balancerCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom mix'**
  String get balancerCustom;

  /// No description provided for @balancerMainTitle.
  ///
  /// In en, this message translates to:
  /// **'What matters to you'**
  String get balancerMainTitle;

  /// No description provided for @balancerExampleTitle.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get balancerExampleTitle;

  /// No description provided for @balancerExampleIntro.
  ///
  /// In en, this message translates to:
  /// **'Three example nodes. Move the sliders and watch the order change. Your real nodes follow the same rule.'**
  String get balancerExampleIntro;

  /// No description provided for @balancerExampleCheap.
  ///
  /// In en, this message translates to:
  /// **'Cheap node'**
  String get balancerExampleCheap;

  /// No description provided for @balancerExampleTrusted.
  ///
  /// In en, this message translates to:
  /// **'Your trusted node'**
  String get balancerExampleTrusted;

  /// No description provided for @balancerExampleRisky.
  ///
  /// In en, this message translates to:
  /// **'Cheapest, little trust'**
  String get balancerExampleRisky;

  /// No description provided for @balancerAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms without data yet'**
  String get balancerAdvancedTitle;

  /// No description provided for @balancerAdvancedNote.
  ///
  /// In en, this message translates to:
  /// **'These terms add nothing today because the app does not have their data yet. You can set their weight now for when it does.'**
  String get balancerAdvancedNote;

  /// No description provided for @balancerRestoreTerm.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get balancerRestoreTerm;

  /// No description provided for @balancerScaleLow.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get balancerScaleLow;

  /// No description provided for @balancerScaleHigh.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get balancerScaleHigh;

  /// No description provided for @balancerReadingNothing.
  ///
  /// In en, this message translates to:
  /// **'With both at 0, nothing separates the nodes.'**
  String get balancerReadingNothing;

  /// No description provided for @balancerReadingPriceIgnored.
  ///
  /// In en, this message translates to:
  /// **'The price is ignored: only your priority decides.'**
  String get balancerReadingPriceIgnored;

  /// No description provided for @balancerReadingPriorityIgnored.
  ///
  /// In en, this message translates to:
  /// **'Your priority is ignored: the cheapest node always goes first.'**
  String get balancerReadingPriorityIgnored;

  /// No description provided for @balancerReadingTradeoff.
  ///
  /// In en, this message translates to:
  /// **'A node you fully trust can win against one up to {factor}× cheaper.'**
  String balancerReadingTradeoff(String factor);

  /// No description provided for @balancerExampleDetail.
  ///
  /// In en, this message translates to:
  /// **'Costs {cost}× · priority {priority}'**
  String balancerExampleDetail(String cost, String priority);

  /// No description provided for @balancerExampleFirst.
  ///
  /// In en, this message translates to:
  /// **'{name} goes first.'**
  String balancerExampleFirst(String name);

  /// No description provided for @celautRunModeTime.
  ///
  /// In en, this message translates to:
  /// **'For a time'**
  String get celautRunModeTime;

  /// No description provided for @celautRunModeKeep.
  ///
  /// In en, this message translates to:
  /// **'Until I stop it'**
  String get celautRunModeKeep;

  /// No description provided for @celautRunButtonKeep.
  ///
  /// In en, this message translates to:
  /// **'Run until stopped'**
  String get celautRunButtonKeep;

  /// No description provided for @celautKeepWarning.
  ///
  /// In en, this message translates to:
  /// **'Risk: the app will keep adding time to this instance from your credit on this node until you stop it. If you forget it, it can use all of that credit. It works while the app runs and while there is credit; if the credit runs out, the instance stops.'**
  String get celautKeepWarning;

  /// No description provided for @celautKeepLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Spending limit (optional)'**
  String get celautKeepLimitLabel;

  /// No description provided for @celautKeepLimitHint.
  ///
  /// In en, this message translates to:
  /// **'Empty: no limit'**
  String get celautKeepLimitHint;

  /// No description provided for @celautKeepLimitWrong.
  ///
  /// In en, this message translates to:
  /// **'A number of MU above zero.'**
  String get celautKeepLimitWrong;

  /// No description provided for @celautKeepRate.
  ///
  /// In en, this message translates to:
  /// **'This node charges about {rate} per hour. Your credit there is {credit}: about {time}.'**
  String celautKeepRate(String rate, String credit, String time);

  /// No description provided for @celautKeepRateOnly.
  ///
  /// In en, this message translates to:
  /// **'This node charges about {rate} per hour.'**
  String celautKeepRateOnly(String rate);

  /// No description provided for @celautKeepCredit.
  ///
  /// In en, this message translates to:
  /// **'Your credit on this node is {credit}.'**
  String celautKeepCredit(String credit);

  /// No description provided for @celautKeepLowCredit.
  ///
  /// In en, this message translates to:
  /// **'Your credit there covers only a few hours. Make a deposit first if you want it to run longer.'**
  String get celautKeepLowCredit;

  /// No description provided for @celautKeepBadge.
  ///
  /// In en, this message translates to:
  /// **'Runs until you stop it'**
  String get celautKeepBadge;

  /// No description provided for @celautTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Time and credit'**
  String get celautTimeTitle;

  /// No description provided for @celautTimeBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance of the instance'**
  String get celautTimeBalance;

  /// No description provided for @celautTimeCredit.
  ///
  /// In en, this message translates to:
  /// **'Your credit on this node'**
  String get celautTimeCredit;

  /// No description provided for @celautTimeAbout.
  ///
  /// In en, this message translates to:
  /// **'about {time}'**
  String celautTimeAbout(String time);

  /// No description provided for @celautKeepSwitch.
  ///
  /// In en, this message translates to:
  /// **'Keep it running until I stop it'**
  String get celautKeepSwitch;

  /// No description provided for @celautKeepOnNoLimit.
  ///
  /// In en, this message translates to:
  /// **'The app adds time by itself while you have credit. Added so far: {spent}. No limit.'**
  String celautKeepOnNoLimit(String spent);

  /// No description provided for @celautKeepOnLimit.
  ///
  /// In en, this message translates to:
  /// **'The app adds time by itself while you have credit. Added so far: {spent} of {limit}.'**
  String celautKeepOnLimit(String spent, String limit);

  /// No description provided for @celautKeepOff.
  ///
  /// In en, this message translates to:
  /// **'It stops when its balance runs out.'**
  String get celautKeepOff;

  /// No description provided for @celautKeepEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep it running?'**
  String get celautKeepEnableTitle;

  /// No description provided for @celautKeepEnableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Keep running'**
  String get celautKeepEnableConfirm;

  /// No description provided for @celautAddTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get celautAddTime;

  /// No description provided for @celautAddTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get celautAddTimeMinutes;

  /// No description provided for @celautAddTimeCost.
  ///
  /// In en, this message translates to:
  /// **'It costs {cost}. You keep {left} on this node: about {time} more for this instance.'**
  String celautAddTimeCost(String cost, String left, String time);

  /// No description provided for @celautAddTimeCostOnly.
  ///
  /// In en, this message translates to:
  /// **'It costs {cost}.'**
  String celautAddTimeCostOnly(String cost);

  /// No description provided for @celautAddTimeNoCredit.
  ///
  /// In en, this message translates to:
  /// **'It costs {cost}, and your credit on this node is {credit}. Make a deposit to add this time.'**
  String celautAddTimeNoCredit(String cost, String credit);

  /// No description provided for @celautAddTimeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get celautAddTimeConfirm;

  /// No description provided for @celautAddTimeDone.
  ///
  /// In en, this message translates to:
  /// **'Time added.'**
  String get celautAddTimeDone;

  /// No description provided for @celautKeepNeed.
  ///
  /// In en, this message translates to:
  /// **'Keep running: your credit on {node} is too low to add time to an instance. Make a deposit to keep it running.'**
  String celautKeepNeed(String node);

  /// No description provided for @celautKeepNeedBudget.
  ///
  /// In en, this message translates to:
  /// **'An instance on {node} reached the spending limit that you set. It stops when its balance runs out. Turn \"keep it running\" off and on again on its info page to set a new limit.'**
  String celautKeepNeedBudget(String node);

  /// No description provided for @celautTopUpRow.
  ///
  /// In en, this message translates to:
  /// **'When to add time to the instances that you keep running'**
  String get celautTopUpRow;

  /// No description provided for @celautTopUpIntro.
  ///
  /// In en, this message translates to:
  /// **'For the instances that you keep running until you stop them (set it when you run one, or on its info page). The app adds time from your credit on their node; it never makes a deposit by itself.'**
  String get celautTopUpIntro;

  /// No description provided for @celautTopUpSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get celautTopUpSaved;

  /// No description provided for @chatsGroupsMenu.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get chatsGroupsMenu;

  /// No description provided for @chatsGroupsViewGrouped.
  ///
  /// In en, this message translates to:
  /// **'Show in groups'**
  String get chatsGroupsViewGrouped;

  /// No description provided for @chatsGroupsViewFlat.
  ///
  /// In en, this message translates to:
  /// **'Show as one list'**
  String get chatsGroupsViewFlat;

  /// No description provided for @chatsGroupsNew.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get chatsGroupsNew;

  /// No description provided for @chatsGroupsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get chatsGroupsNameLabel;

  /// No description provided for @chatsGroupsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get chatsGroupsRename;

  /// No description provided for @chatsGroupsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get chatsGroupsDelete;

  /// No description provided for @chatsGroupsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group {name}?'**
  String chatsGroupsDeleteTitle(String name);

  /// No description provided for @chatsGroupsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The conversations in it are not deleted: they go back to the list with no group.'**
  String get chatsGroupsDeleteBody;

  /// No description provided for @chatsGroupsMove.
  ///
  /// In en, this message translates to:
  /// **'Move to a group'**
  String get chatsGroupsMove;

  /// No description provided for @chatsGroupsNone.
  ///
  /// In en, this message translates to:
  /// **'Remove from its group'**
  String get chatsGroupsNone;

  /// No description provided for @chatsGroupsUngrouped.
  ///
  /// In en, this message translates to:
  /// **'No group'**
  String get chatsGroupsUngrouped;

  /// No description provided for @chatSettingsListGroup.
  ///
  /// In en, this message translates to:
  /// **'Chat list'**
  String get chatSettingsListGroup;

  /// No description provided for @chatSettingsGroupedView.
  ///
  /// In en, this message translates to:
  /// **'Organize in groups'**
  String get chatSettingsGroupedView;

  /// No description provided for @chatSettingsGroupedViewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off: one flat list. On: collapsible groups. Long-press a conversation to move it to a group.'**
  String get chatSettingsGroupedViewSubtitle;

  /// No description provided for @celautEnvAskSave.
  ///
  /// In en, this message translates to:
  /// **'Save in my variables'**
  String get celautEnvAskSave;

  /// No description provided for @celautEnvAskSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Saved as {name}, with the mark above.'**
  String celautEnvAskSaveHint(String name);

  /// No description provided for @celautEnvAskSaveReplaces.
  ///
  /// In en, this message translates to:
  /// **'Replaces the value that you saved as {name}.'**
  String celautEnvAskSaveReplaces(String name);

  /// No description provided for @celautEnvSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The value was not saved in your variables.'**
  String get celautEnvSaveFailed;

  /// No description provided for @celautSecretAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Secret for the service'**
  String get celautSecretAskTitle;

  /// No description provided for @celautSecretReviewNote.
  ///
  /// In en, this message translates to:
  /// **'The service and the node of this instance read the value. The value is not kept in the conversation.'**
  String get celautSecretReviewNote;

  /// No description provided for @celautSecretSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get celautSecretSend;

  /// No description provided for @celautSecretSendAnyway.
  ///
  /// In en, this message translates to:
  /// **'Send the value'**
  String get celautSecretSendAnyway;

  /// No description provided for @chatSecretCardTitle.
  ///
  /// In en, this message translates to:
  /// **'The service asks for {name}'**
  String chatSecretCardTitle(String name);

  /// No description provided for @chatSecretAnswer.
  ///
  /// In en, this message translates to:
  /// **'Choose a value'**
  String get chatSecretAnswer;

  /// No description provided for @chatSecretSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get chatSecretSent;

  /// No description provided for @chatSecretSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get chatSecretSkipped;

  /// No description provided for @chatSecretFailed.
  ///
  /// In en, this message translates to:
  /// **'The answer did not reach the service. Try again.'**
  String get chatSecretFailed;

  /// No description provided for @chatSecretMissing.
  ///
  /// In en, this message translates to:
  /// **'{name} is not in your variables any more.'**
  String chatSecretMissing(String name);

  /// No description provided for @btcTitle.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin'**
  String get btcTitle;

  /// No description provided for @btcRefresh.
  ///
  /// In en, this message translates to:
  /// **'Read again'**
  String get btcRefresh;

  /// No description provided for @btcLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlock the wallet to open the Bitcoin wallet.'**
  String get btcLocked;

  /// No description provided for @btcUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get btcUnlock;

  /// No description provided for @btcTestNetwork.
  ///
  /// In en, this message translates to:
  /// **'{network}: a test network. These coins have no value.'**
  String btcTestNetwork(String network);

  /// No description provided for @btcMainnetNote.
  ///
  /// In en, this message translates to:
  /// **'Mainnet: real bitcoin. A send cannot be undone.'**
  String get btcMainnetNote;

  /// No description provided for @btcConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get btcConfirmed;

  /// No description provided for @btcPending.
  ///
  /// In en, this message translates to:
  /// **'{amount} BTC not confirmed yet'**
  String btcPending(String amount);

  /// No description provided for @btcImmature.
  ///
  /// In en, this message translates to:
  /// **'{amount} BTC mined, not mature yet'**
  String btcImmature(String amount);

  /// No description provided for @btcReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get btcReceive;

  /// No description provided for @btcSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get btcSend;

  /// No description provided for @btcDepositAction.
  ///
  /// In en, this message translates to:
  /// **'Deposit to a node'**
  String get btcDepositAction;

  /// No description provided for @btcHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get btcHistory;

  /// No description provided for @btcNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get btcNoHistory;

  /// No description provided for @btcUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed'**
  String get btcUnconfirmed;

  /// No description provided for @btcConfirmations.
  ///
  /// In en, this message translates to:
  /// **'Confirmations: {count}'**
  String btcConfirmations(String count);

  /// No description provided for @btcTxCopied.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID copied'**
  String get btcTxCopied;

  /// No description provided for @btcReceiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive bitcoin'**
  String get btcReceiveTitle;

  /// No description provided for @btcReceiveNote.
  ///
  /// In en, this message translates to:
  /// **'Send only {network} bitcoin to this address. After it receives, the wallet shows a new address.'**
  String btcReceiveNote(String network);

  /// No description provided for @btcCopyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get btcCopyAddress;

  /// No description provided for @btcAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get btcAddressCopied;

  /// No description provided for @btcSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send bitcoin'**
  String get btcSendTitle;

  /// No description provided for @btcSendTo.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin address'**
  String get btcSendTo;

  /// No description provided for @btcSendToInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a Bitcoin address of {network}'**
  String btcSendToInvalid(String network);

  /// No description provided for @btcSendAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (BTC)'**
  String get btcSendAmount;

  /// No description provided for @btcSendAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Type an amount in BTC, with 8 decimals or fewer'**
  String get btcSendAmountInvalid;

  /// No description provided for @btcSendAll.
  ///
  /// In en, this message translates to:
  /// **'Send everything'**
  String get btcSendAll;

  /// No description provided for @btcSendAllHint.
  ///
  /// In en, this message translates to:
  /// **'The fee comes out of the amount'**
  String get btcSendAllHint;

  /// No description provided for @btcFeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Fee rate'**
  String get btcFeeTitle;

  /// No description provided for @btcFeeFast.
  ///
  /// In en, this message translates to:
  /// **'Fast · {rate} sat/vB'**
  String btcFeeFast(String rate);

  /// No description provided for @btcFeeNormal.
  ///
  /// In en, this message translates to:
  /// **'About 1 hour · {rate} sat/vB'**
  String btcFeeNormal(String rate);

  /// No description provided for @btcFeeSlow.
  ///
  /// In en, this message translates to:
  /// **'About 1 day · {rate} sat/vB'**
  String btcFeeSlow(String rate);

  /// No description provided for @btcFeeNoEstimate.
  ///
  /// In en, this message translates to:
  /// **'The server gives no estimate. The app uses the lowest rate.'**
  String get btcFeeNoEstimate;

  /// No description provided for @btcReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get btcReview;

  /// No description provided for @btcConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Send bitcoin?'**
  String get btcConfirmTitle;

  /// No description provided for @btcRowNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get btcRowNetwork;

  /// No description provided for @btcRowAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get btcRowAmount;

  /// No description provided for @btcRowFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get btcRowFee;

  /// No description provided for @btcRowFeeRate.
  ///
  /// In en, this message translates to:
  /// **'Fee rate'**
  String get btcRowFeeRate;

  /// No description provided for @btcRowChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get btcRowChange;

  /// No description provided for @btcRowTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get btcRowTotal;

  /// No description provided for @btcSendLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign and send'**
  String get btcSendLabel;

  /// No description provided for @btcSent.
  ///
  /// In en, this message translates to:
  /// **'Sent: {txid}'**
  String btcSent(String txid);

  /// No description provided for @btcConsentNeeded.
  ///
  /// In en, this message translates to:
  /// **'The send needs the fingerprint or the screen lock. Nothing was sent.'**
  String get btcConsentNeeded;

  /// No description provided for @btcErrLocked.
  ///
  /// In en, this message translates to:
  /// **'The wallet is locked. Unlock it first.'**
  String get btcErrLocked;

  /// No description provided for @btcErrFunds.
  ///
  /// In en, this message translates to:
  /// **'There is not enough confirmed bitcoin.'**
  String get btcErrFunds;

  /// No description provided for @btcErrUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The Bitcoin server does not answer. Check the network or the server in the Bitcoin settings.'**
  String get btcErrUnreachable;

  /// No description provided for @btcErrOther.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin: {reason}'**
  String btcErrOther(String reason);

  /// No description provided for @btcSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin settings'**
  String get btcSettingsTitle;

  /// No description provided for @btcNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get btcNetworkTitle;

  /// No description provided for @btcNetMainnet.
  ///
  /// In en, this message translates to:
  /// **'Mainnet (real bitcoin)'**
  String get btcNetMainnet;

  /// No description provided for @btcNetTestnet.
  ///
  /// In en, this message translates to:
  /// **'Testnet (test)'**
  String get btcNetTestnet;

  /// No description provided for @btcNetSignet.
  ///
  /// In en, this message translates to:
  /// **'Signet (test)'**
  String get btcNetSignet;

  /// No description provided for @btcNetRegtest.
  ///
  /// In en, this message translates to:
  /// **'Regtest (local test)'**
  String get btcNetRegtest;

  /// No description provided for @btcMainnetWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Use real bitcoin?'**
  String get btcMainnetWarnTitle;

  /// No description provided for @btcMainnetWarnBody.
  ///
  /// In en, this message translates to:
  /// **'On mainnet the coins have value, and a send cannot be undone. The Bitcoin wallet of Chatui is new: use small amounts.'**
  String get btcMainnetWarnBody;

  /// No description provided for @btcMainnetWarnOk.
  ///
  /// In en, this message translates to:
  /// **'Use mainnet'**
  String get btcMainnetWarnOk;

  /// No description provided for @btcServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Esplora server'**
  String get btcServerTitle;

  /// No description provided for @btcServerHint.
  ///
  /// In en, this message translates to:
  /// **'Empty: {url}'**
  String btcServerHint(String url);

  /// No description provided for @btcServerNoDefault.
  ///
  /// In en, this message translates to:
  /// **'Regtest has no public server. Type one.'**
  String get btcServerNoDefault;

  /// No description provided for @btcServerInvalid.
  ///
  /// In en, this message translates to:
  /// **'The address must start with https:// or http://'**
  String get btcServerInvalid;

  /// No description provided for @btcSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get btcSave;

  /// No description provided for @btcSeedNote.
  ///
  /// In en, this message translates to:
  /// **'The Bitcoin wallet uses the words of your wallet, on the BIP-84 path (native SegWit). Any standard Bitcoin wallet opens the same funds with the same words.'**
  String get btcSeedNote;

  /// No description provided for @btcDepTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit in BTC'**
  String get btcDepTitle;

  /// No description provided for @btcDepNode.
  ///
  /// In en, this message translates to:
  /// **'Node address (host:port)'**
  String get btcDepNode;

  /// No description provided for @btcDepNodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Type the address as host:port'**
  String get btcDepNodeInvalid;

  /// No description provided for @btcDepCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get btcDepCheck;

  /// No description provided for @btcDepNoBtc.
  ///
  /// In en, this message translates to:
  /// **'This node does not take BTC on {network}.'**
  String btcDepNoBtc(String network);

  /// No description provided for @btcDepNodeNetworks.
  ///
  /// In en, this message translates to:
  /// **'It takes BTC on: {networks}'**
  String btcDepNodeNetworks(String networks);

  /// No description provided for @btcDepPayTo.
  ///
  /// In en, this message translates to:
  /// **'Pays to'**
  String get btcDepPayTo;

  /// No description provided for @btcDepRate.
  ///
  /// In en, this message translates to:
  /// **'{mu} MU per sat'**
  String btcDepRate(String mu);

  /// No description provided for @btcDepCredit.
  ///
  /// In en, this message translates to:
  /// **'Your credit on the node: {mu} MU'**
  String btcDepCredit(String mu);

  /// No description provided for @btcDepWaitsFor.
  ///
  /// In en, this message translates to:
  /// **'The node checks the deposit after {count} confirmations.'**
  String btcDepWaitsFor(String count);

  /// No description provided for @btcDepWaitsDefault.
  ///
  /// In en, this message translates to:
  /// **'The node does not say how many confirmations it wants. The app waits for {count} before it tells the node.'**
  String btcDepWaitsDefault(String count);

  /// No description provided for @btcDepAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (sat)'**
  String get btcDepAmount;

  /// No description provided for @btcDepAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Type {min} sat or more'**
  String btcDepAmountInvalid(String min);

  /// No description provided for @btcDepPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare the deposit'**
  String get btcDepPrepare;

  /// No description provided for @btcDepConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposit BTC to the node?'**
  String get btcDepConfirmTitle;

  /// No description provided for @btcDepConfirmDetail.
  ///
  /// In en, this message translates to:
  /// **'The deposit token of the node goes in an OP_RETURN output. The app tells the node after {count} confirmations. The token expires 6 hours after it was made.'**
  String btcDepConfirmDetail(String count);

  /// No description provided for @btcDepRowNode.
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get btcDepRowNode;

  /// No description provided for @btcDepRowMu.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get btcDepRowMu;

  /// No description provided for @btcDepWaiting.
  ///
  /// In en, this message translates to:
  /// **'Confirmations: {have} of {need}'**
  String btcDepWaiting(String have, String need);

  /// No description provided for @btcDepUnknownTx.
  ///
  /// In en, this message translates to:
  /// **'The server does not know the transaction yet.'**
  String get btcDepUnknownTx;

  /// No description provided for @btcDepTelling.
  ///
  /// In en, this message translates to:
  /// **'Asking the server…'**
  String get btcDepTelling;

  /// No description provided for @btcDepAccepted.
  ///
  /// In en, this message translates to:
  /// **'The node accepted the deposit. Credit now: {mu} MU'**
  String btcDepAccepted(String mu);

  /// No description provided for @btcDepRefused.
  ///
  /// In en, this message translates to:
  /// **'The node refused the deposit: {reason}'**
  String btcDepRefused(String reason);

  /// No description provided for @btcDepPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Deposits that wait'**
  String get btcDepPendingTitle;

  /// No description provided for @btcDepWait.
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get btcDepWait;

  /// No description provided for @btcDepForget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get btcDepForget;

  /// No description provided for @btcDepPayInBtc.
  ///
  /// In en, this message translates to:
  /// **'Pay in BTC'**
  String get btcDepPayInBtc;

  /// No description provided for @btcDepPayInBtcSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This node takes BTC on {network}'**
  String btcDepPayInBtcSubtitle(String network);

  /// No description provided for @btcWalletButton.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin wallet'**
  String get btcWalletButton;

  /// No description provided for @celautEnvShare.
  ///
  /// In en, this message translates to:
  /// **'Share by QR'**
  String get celautEnvShare;

  /// No description provided for @celautEnvShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share {name}'**
  String celautEnvShareTitle(String name);

  /// No description provided for @celautEnvShareWarn.
  ///
  /// In en, this message translates to:
  /// **'Whoever scans this code gets the value in plain text. Show it only to people you trust.'**
  String get celautEnvShareWarn;

  /// No description provided for @celautEnvShareWarnSensitive.
  ///
  /// In en, this message translates to:
  /// **'This variable is sensitive. Whoever scans this code gets the value in plain text. Show it only to people you trust, and make sure nobody else sees or records your screen.'**
  String get celautEnvShareWarnSensitive;

  /// No description provided for @celautEnvShareTooBig.
  ///
  /// In en, this message translates to:
  /// **'This value is too large for a QR code.'**
  String get celautEnvShareTooBig;

  /// No description provided for @celautEnvScan.
  ///
  /// In en, this message translates to:
  /// **'Receive by QR'**
  String get celautEnvScan;

  /// No description provided for @celautEnvAskScan.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get celautEnvAskScan;

  /// No description provided for @celautEnvScanNotVariable.
  ///
  /// In en, this message translates to:
  /// **'That QR code is not a shared variable.'**
  String get celautEnvScanNotVariable;

  /// No description provided for @chatsStateHibernated.
  ///
  /// In en, this message translates to:
  /// **'Hibernated'**
  String get chatsStateHibernated;

  /// No description provided for @chatsHibernate.
  ///
  /// In en, this message translates to:
  /// **'Hibernate'**
  String get chatsHibernate;

  /// No description provided for @chatsWake.
  ///
  /// In en, this message translates to:
  /// **'Wake'**
  String get chatsWake;

  /// No description provided for @chatsHibernateTitle.
  ///
  /// In en, this message translates to:
  /// **'Hibernate {name}?'**
  String chatsHibernateTitle(String name);

  /// No description provided for @chatsHibernateBody.
  ///
  /// In en, this message translates to:
  /// **'The instance stops using CPU and RAM, and the node charges only for its disk. The process state is lost: when you wake the instance, the service starts again from its entrypoint. The address and the ports stay. The app keeps the CPU and RAM that the instance has now, and wakes it with them. Hibernating costs the instance two call fees.'**
  String get chatsHibernateBody;

  /// No description provided for @chatsHibernated.
  ///
  /// In en, this message translates to:
  /// **'The instance is hibernated.'**
  String get chatsHibernated;

  /// No description provided for @chatsWakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Wake {name}?'**
  String chatsWakeTitle(String name);

  /// No description provided for @chatsWakeBody.
  ///
  /// In en, this message translates to:
  /// **'The instance starts again with {cpu} and {ram}. The process state was lost: the service starts from its entrypoint. Waking costs the instance one call fee.'**
  String chatsWakeBody(String cpu, String ram);

  /// No description provided for @chatsWakeLastKnown.
  ///
  /// In en, this message translates to:
  /// **'The app does not know if these values are the ones that the instance had when it hibernated. They are the last that the app got from the node.'**
  String get chatsWakeLastKnown;

  /// No description provided for @chatsWakeUnknown.
  ///
  /// In en, this message translates to:
  /// **'The app does not know the CPU and RAM of this instance, so it cannot wake it.'**
  String get chatsWakeUnknown;

  /// No description provided for @chatsWoken.
  ///
  /// In en, this message translates to:
  /// **'The instance is awake.'**
  String get chatsWoken;

  /// No description provided for @chatsResourcesCpu.
  ///
  /// In en, this message translates to:
  /// **'{cores} CPU cores'**
  String chatsResourcesCpu(String cores);

  /// No description provided for @chatsRefusalSharedFilesystem.
  ///
  /// In en, this message translates to:
  /// **'The node does not hibernate this instance: it shares a filesystem with other instances.'**
  String get chatsRefusalSharedFilesystem;

  /// No description provided for @chatsRefusalNotRevivable.
  ///
  /// In en, this message translates to:
  /// **'The node does not hibernate this instance: it cannot start again from its own disk.'**
  String get chatsRefusalNotRevivable;

  /// No description provided for @chatsRefusalInstanceBalance.
  ///
  /// In en, this message translates to:
  /// **'The instance has not enough balance to pay the fee of this call. Add time to the instance, then try again.'**
  String get chatsRefusalInstanceBalance;

  /// No description provided for @chatsRefusalDoesNotFit.
  ///
  /// In en, this message translates to:
  /// **'The node has no room for the CPU and RAM of this instance now. The instance stays hibernated. Try again later.'**
  String get chatsRefusalDoesNotFit;

  /// No description provided for @chatsRefusalNoLocalInstance.
  ///
  /// In en, this message translates to:
  /// **'This instance runs on a peer of the node, or it is gone. The node cannot hibernate or wake it.'**
  String get chatsRefusalNoLocalInstance;

  /// No description provided for @chatsRefusalNotTheFather.
  ///
  /// In en, this message translates to:
  /// **'The node says that this app is not the owner of the instance, so it does not accept the call.'**
  String get chatsRefusalNotTheFather;

  /// No description provided for @chatsRefusalNoResources.
  ///
  /// In en, this message translates to:
  /// **'The app could not read the CPU and RAM of the instance, so it did not hibernate it. Nothing changed.'**
  String get chatsRefusalNoResources;

  /// No description provided for @chatsRefusalUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This node does not support hibernation. It is older than the feature, so the app hides the hibernate and wake actions for its instances. Nothing was charged.'**
  String get chatsRefusalUnsupported;

  /// No description provided for @chatsRefusalNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'The node did not confirm the hibernation. Nothing changed in the app.'**
  String get chatsRefusalNotConfirmed;

  /// No description provided for @chatsRefusalOther.
  ///
  /// In en, this message translates to:
  /// **'The node refused the call: {message}'**
  String chatsRefusalOther(String message);

  /// No description provided for @chatsInfoResources.
  ///
  /// In en, this message translates to:
  /// **'CPU and RAM'**
  String get chatsInfoResources;

  /// No description provided for @chatsInfoResourcesNone.
  ///
  /// In en, this message translates to:
  /// **'Not known yet'**
  String get chatsInfoResourcesNone;

  /// No description provided for @chatsInfoResourcesLastKnown.
  ///
  /// In en, this message translates to:
  /// **'{resources} (last known values)'**
  String chatsInfoResourcesLastKnown(String resources);

  /// No description provided for @chatsInfoHibernatedSince.
  ///
  /// In en, this message translates to:
  /// **'Hibernated since'**
  String get chatsInfoHibernatedSince;

  /// No description provided for @chatsInfoHibernateNote.
  ///
  /// In en, this message translates to:
  /// **'Hibernate frees the CPU and RAM, and the node charges only for the disk. The process state is lost when the instance wakes.'**
  String get chatsInfoHibernateNote;

  /// No description provided for @chatsInfoHibernatedNote.
  ///
  /// In en, this message translates to:
  /// **'A hibernated instance pays only for its disk. Wake it to use it again. Stop it to get the refund; only a stopped instance can be deleted.'**
  String get chatsInfoHibernatedNote;

  /// No description provided for @coinErgo.
  ///
  /// In en, this message translates to:
  /// **'Ergo'**
  String get coinErgo;

  /// No description provided for @coinBitcoin.
  ///
  /// In en, this message translates to:
  /// **'Bitcoin'**
  String get coinBitcoin;

  /// No description provided for @coinTestNetwork.
  ///
  /// In en, this message translates to:
  /// **'{network} · test network'**
  String coinTestNetwork(String network);

  /// No description provided for @homeCoinPendingFigure.
  ///
  /// In en, this message translates to:
  /// **'{figure} {unit} pending'**
  String homeCoinPendingFigure(String figure, String unit);

  /// No description provided for @btcOverviewUnlockOnce.
  ///
  /// In en, this message translates to:
  /// **'Unlock the wallet one time to read the Bitcoin wallet.'**
  String get btcOverviewUnlockOnce;

  /// No description provided for @btcOverviewUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The Bitcoin server did not answer. The figures can be old.'**
  String get btcOverviewUnreachable;

  /// No description provided for @btcWalletRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The same words as the Ergo wallet'**
  String get btcWalletRowSubtitle;

  /// No description provided for @btcSettingsRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Network and server'**
  String get btcSettingsRowSubtitle;

  /// No description provided for @btcReceiveAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount to ask for (BTC), optional'**
  String get btcReceiveAmount;

  /// No description provided for @btcReceiveAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'The QR code asks for this amount'**
  String get btcReceiveAmountHelp;

  /// No description provided for @btcScanNotBitcoin.
  ///
  /// In en, this message translates to:
  /// **'This QR code is not a Bitcoin address of {network}'**
  String btcScanNotBitcoin(String network);

  /// No description provided for @btcFeeCustom.
  ///
  /// In en, this message translates to:
  /// **'Other rate'**
  String get btcFeeCustom;

  /// No description provided for @btcFeeCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Fee rate'**
  String get btcFeeCustomLabel;

  /// No description provided for @btcFeeCustomInvalid.
  ///
  /// In en, this message translates to:
  /// **'Type a rate from 1 to 1000 sat/vB'**
  String get btcFeeCustomInvalid;

  /// No description provided for @btcTxTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get btcTxTime;

  /// No description provided for @btcTxSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get btcTxSize;

  /// No description provided for @btcTxData.
  ///
  /// In en, this message translates to:
  /// **'Data (OP_RETURN)'**
  String get btcTxData;

  /// No description provided for @btcTxUnknownScript.
  ///
  /// In en, this message translates to:
  /// **'Not an address'**
  String get btcTxUnknownScript;

  /// No description provided for @btcTxYours.
  ///
  /// In en, this message translates to:
  /// **'yours'**
  String get btcTxYours;

  /// No description provided for @btcBump.
  ///
  /// In en, this message translates to:
  /// **'Raise the fee'**
  String get btcBump;

  /// No description provided for @btcBumpHint.
  ///
  /// In en, this message translates to:
  /// **'The payment goes again with a higher fee and replaces the payment that waits (RBF). The fee comes out of the change.'**
  String get btcBumpHint;

  /// No description provided for @btcBumpNow.
  ///
  /// In en, this message translates to:
  /// **'The fee rate is {rate} sat/vB now. The new rate must be {min} sat/vB or more.'**
  String btcBumpNow(String rate, String min);

  /// No description provided for @btcBumpTooLow.
  ///
  /// In en, this message translates to:
  /// **'The rate must be {min} sat/vB or more'**
  String btcBumpTooLow(String min);

  /// No description provided for @btcBumpConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Send again with a higher fee?'**
  String get btcBumpConfirmTitle;

  /// No description provided for @btcBumpOldFee.
  ///
  /// In en, this message translates to:
  /// **'Fee before'**
  String get btcBumpOldFee;

  /// No description provided for @btcBumped.
  ///
  /// In en, this message translates to:
  /// **'Sent again with a higher fee: {txid}'**
  String btcBumped(String txid);

  /// No description provided for @btcAddressReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive #{index}'**
  String btcAddressReceive(String index);

  /// No description provided for @btcAddressChange.
  ///
  /// In en, this message translates to:
  /// **'Change #{index}'**
  String btcAddressChange(String index);

  /// No description provided for @btcAddressUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get btcAddressUsed;

  /// No description provided for @btcAddressUnused.
  ///
  /// In en, this message translates to:
  /// **'Not used'**
  String get btcAddressUnused;

  /// No description provided for @btcUtxosTitle.
  ///
  /// In en, this message translates to:
  /// **'Unspent outputs'**
  String get btcUtxosTitle;

  /// No description provided for @btcUtxosNone.
  ///
  /// In en, this message translates to:
  /// **'The wallet has no unspent outputs.'**
  String get btcUtxosNone;

  /// No description provided for @btcOutpointCopied.
  ///
  /// In en, this message translates to:
  /// **'Output copied'**
  String get btcOutpointCopied;

  /// No description provided for @btcBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase'**
  String get btcBackupTitle;

  /// No description provided for @btcBackupBody.
  ///
  /// In en, this message translates to:
  /// **'The Bitcoin wallet has no recovery phrase of its own. Its keys come from the words of the wallet (BIP-84). Keep those words: they restore the Ergo wallet and the Bitcoin wallet. Any standard Bitcoin wallet opens the same bitcoin with the same words.'**
  String get btcBackupBody;

  /// No description provided for @btcToolAddressesBlurb.
  ///
  /// In en, this message translates to:
  /// **'Each address, what it holds and its label'**
  String get btcToolAddressesBlurb;

  /// No description provided for @btcToolUtxosBlurb.
  ///
  /// In en, this message translates to:
  /// **'The coins of the wallet, one by one'**
  String get btcToolUtxosBlurb;

  /// No description provided for @btcToolNetworkBlurb.
  ///
  /// In en, this message translates to:
  /// **'The network and the Esplora server'**
  String get btcToolNetworkBlurb;

  /// No description provided for @btcToolBackupBlurb.
  ///
  /// In en, this message translates to:
  /// **'The same words as the wallet'**
  String get btcToolBackupBlurb;

  /// No description provided for @btcToolLockBlurb.
  ///
  /// In en, this message translates to:
  /// **'Lock the wallet: Ergo and Bitcoin'**
  String get btcToolLockBlurb;

  /// No description provided for @celautErrorNoDescendants.
  ///
  /// In en, this message translates to:
  /// **'This node does not support descendants.'**
  String get celautErrorNoDescendants;

  /// No description provided for @descendantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Descendants'**
  String get descendantsTitle;

  /// No description provided for @descendantsNote.
  ///
  /// In en, this message translates to:
  /// **'Instances that this instance started, and the ones that they started. The app finds them when you check. A check asks the node and costs MU.'**
  String get descendantsNote;

  /// No description provided for @descendantsThisInstance.
  ///
  /// In en, this message translates to:
  /// **'This instance'**
  String get descendantsThisInstance;

  /// No description provided for @descendantsStateAlive.
  ///
  /// In en, this message translates to:
  /// **'Alive'**
  String get descendantsStateAlive;

  /// No description provided for @descendantsStateStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get descendantsStateStopped;

  /// No description provided for @descendantsStateNotVerifiable.
  ///
  /// In en, this message translates to:
  /// **'Not verifiable'**
  String get descendantsStateNotVerifiable;

  /// No description provided for @descendantsStateNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get descendantsStateNotChecked;

  /// No description provided for @descendantsService.
  ///
  /// In en, this message translates to:
  /// **'Service {id}'**
  String descendantsService(String id);

  /// No description provided for @descendantsServiceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Service unknown'**
  String get descendantsServiceUnknown;

  /// No description provided for @descendantsLastCheck.
  ///
  /// In en, this message translates to:
  /// **'Last check: {time}'**
  String descendantsLastCheck(String time);

  /// No description provided for @descendantsNeverChecked.
  ///
  /// In en, this message translates to:
  /// **'Never checked'**
  String get descendantsNeverChecked;

  /// No description provided for @descendantsCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get descendantsCheck;

  /// No description provided for @descendantsCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Check with the node?'**
  String get descendantsCheckTitle;

  /// No description provided for @descendantsCheckBody.
  ///
  /// In en, this message translates to:
  /// **'The app asks the node {node} for a signed statement of the account. This costs MU and writes a movement on the node. It can cost up to the maximum below, and no more.'**
  String descendantsCheckBody(String node);

  /// No description provided for @descendantsMaxLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum MU'**
  String get descendantsMaxLabel;

  /// No description provided for @descendantsMaxInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of MU.'**
  String get descendantsMaxInvalid;

  /// No description provided for @descendantsCheckConfirm.
  ///
  /// In en, this message translates to:
  /// **'Check and pay'**
  String get descendantsCheckConfirm;

  /// No description provided for @descendantsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get descendantsCancel;

  /// No description provided for @descendantsQuoteFailed.
  ///
  /// In en, this message translates to:
  /// **'The app cannot find the cost: {error}'**
  String descendantsQuoteFailed(String error);

  /// No description provided for @descendantsCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'The check failed: {error}'**
  String descendantsCheckFailed(String error);

  /// No description provided for @descendantsFoundNew.
  ///
  /// In en, this message translates to:
  /// **'New descendants found: {count}'**
  String descendantsFoundNew(String count);

  /// No description provided for @descendantsFoundNone.
  ///
  /// In en, this message translates to:
  /// **'No new descendant.'**
  String get descendantsFoundNone;

  /// No description provided for @descendantsDiedWithMuTitle.
  ///
  /// In en, this message translates to:
  /// **'A node ended an instance that still had MU'**
  String get descendantsDiedWithMuTitle;

  /// No description provided for @descendantsDiedWithMu.
  ///
  /// In en, this message translates to:
  /// **'The account ended with {mu} still on it. Reason: {reason}. The MU stayed with the node.'**
  String descendantsDiedWithMu(String mu, String reason);

  /// No description provided for @descendantsFatherGone.
  ///
  /// In en, this message translates to:
  /// **'The father was gone, so the node gave the MU to nobody.'**
  String get descendantsFatherGone;

  /// No description provided for @descendantsRefusedTitle.
  ///
  /// In en, this message translates to:
  /// **'The node refused the check'**
  String get descendantsRefusedTitle;

  /// No description provided for @descendantsRefused.
  ///
  /// In en, this message translates to:
  /// **'The node refused to show the statement, so the app cannot verify this descendant. If it died with MU, the app cannot see it.'**
  String get descendantsRefused;

  /// No description provided for @descendantsClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get descendantsClose;

  /// No description provided for @descendantsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open page'**
  String get descendantsOpen;

  /// No description provided for @descendantsNoWeb.
  ///
  /// In en, this message translates to:
  /// **'The service declares no page to open.'**
  String get descendantsNoWeb;

  /// No description provided for @descendantsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'The page did not open: {error}'**
  String descendantsOpenFailed(String error);

  /// No description provided for @descendantsChatSlots.
  ///
  /// In en, this message translates to:
  /// **'The service declares a chat port. The app does not open it yet.'**
  String get descendantsChatSlots;

  /// No description provided for @descendantsDepth.
  ///
  /// In en, this message translates to:
  /// **'Level {depth}'**
  String descendantsDepth(String depth);

  /// No description provided for @descendantsRelayed.
  ///
  /// In en, this message translates to:
  /// **'Relayed. Another node wrote this statement. The node of this instance signed it again, and the app cannot check the other node.'**
  String get descendantsRelayed;

  /// No description provided for @descendantsUnreadRows.
  ///
  /// In en, this message translates to:
  /// **'Partly checked. Some movements are not read, and one of them can be a stop. Check again.'**
  String get descendantsUnreadRows;

  /// No description provided for @descendantsOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open with the node?'**
  String get descendantsOpenTitle;

  /// No description provided for @descendantsOpenBody.
  ///
  /// In en, this message translates to:
  /// **'The app opens one stream to the descendant for each connection of the page, through the node {node}. One stream can cost up to {perStream} MU to open ({hops} hops at most). The traffic costs more. The port stops after the streams that the budget below pays for.'**
  String descendantsOpenBody(String node, String perStream, String hops);

  /// No description provided for @descendantsOpenStreams.
  ///
  /// In en, this message translates to:
  /// **'The budget pays for {count} streams.'**
  String descendantsOpenStreams(String count);

  /// No description provided for @descendantsOpenBudgetTooSmall.
  ///
  /// In en, this message translates to:
  /// **'The budget does not pay for one stream.'**
  String get descendantsOpenBudgetTooSmall;

  /// No description provided for @descendantsOpenConfirm.
  ///
  /// In en, this message translates to:
  /// **'Open and pay'**
  String get descendantsOpenConfirm;

  /// No description provided for @serviceInfoWorkloadsInitial.
  ///
  /// In en, this message translates to:
  /// **'First instances that it starts'**
  String get serviceInfoWorkloadsInitial;

  /// No description provided for @serviceInfoWorkloadOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get serviceInfoWorkloadOr;

  /// No description provided for @cardsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the cards…'**
  String get cardsLoading;

  /// No description provided for @cardsNoDeck.
  ///
  /// In en, this message translates to:
  /// **'The service has no cards now.'**
  String get cardsNoDeck;

  /// No description provided for @cardsEnd.
  ///
  /// In en, this message translates to:
  /// **'No more cards.'**
  String get cardsEnd;

  /// No description provided for @cardsBackToChat.
  ///
  /// In en, this message translates to:
  /// **'Back to the chat'**
  String get cardsBackToChat;

  /// No description provided for @cardsUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get cardsUndo;

  /// No description provided for @cardsProgress.
  ///
  /// In en, this message translates to:
  /// **'{position} of {total}'**
  String cardsProgress(int position, int total);

  /// No description provided for @cardsWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 move waits to be sent} other{{count} moves wait to be sent}}'**
  String cardsWaiting(int count);

  /// No description provided for @cardsConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get cardsConnecting;

  /// No description provided for @cardsTapForDetail.
  ///
  /// In en, this message translates to:
  /// **'Tap the card for details'**
  String get cardsTapForDetail;

  /// No description provided for @chatOpenCards.
  ///
  /// In en, this message translates to:
  /// **'Open the cards'**
  String get chatOpenCards;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
