import '../bridge/api/celaut.dart';
import '../l10n/l10n.dart';

/// Every text that the Celaut screens show, in one place. The texts are in
/// lib/l10n/app_*.arb (keys `celaut…`); a new text needs a key in each ARB
/// file and a getter here.
class CelautStrings {
  const CelautStrings._();

  // Settings
  static String get nodeRowTitle => appL10n.celautNodeRowTitle;
  static String get nodeRowSubtitle => appL10n.celautNodeRowSubtitle;

  // Screen
  static String get screenTitle => appL10n.celautScreenTitle;
  static String get intro => appL10n.celautIntro;
  static String get addressLabel => appL10n.celautAddressLabel;
  static String get addressHint => appL10n.celautAddressHint;
  static String get expectedLabel => appL10n.celautExpectedLabel;
  static String get expectedHint => appL10n.celautExpectedHint;
  static String get connect => appL10n.celautConnect;
  static String get connecting => appL10n.celautConnecting;

  // Result
  static String get identityTitle => appL10n.celautIdentityTitle;
  static String get peerIdLabel => appL10n.celautPeerIdLabel;
  static String get advertisedLabel => appL10n.celautAdvertisedLabel;
  static String get urisTitle => appL10n.celautUrisTitle;
  static String get ratesTitle => appL10n.celautRatesTitle;
  static String get contractsTitle => appL10n.celautContractsTitle;
  static String get resourcesTitle => appL10n.celautResourcesTitle;
  static String get proofsLabel => appL10n.celautProofsLabel;
  static String get noUris => appL10n.celautNoUris;
  static String get noRates => appL10n.celautNoRates;
  static String get noContracts => appL10n.celautNoContracts;
  static String get noResources => appL10n.celautNoResources;
  static String get ratesNote => appL10n.celautRatesNote;
  static String get verifiedNote => appL10n.celautVerifiedNote;

  // Input errors
  static String get addressEmpty => appL10n.celautAddressEmpty;
  static String get addressInvalid => appL10n.celautAddressInvalid;
  static String get portInvalid => appL10n.celautPortInvalid;
  static String get expectedInvalid => appL10n.celautExpectedInvalid;

  // Errors of the connection and of the checks
  static String get errorTitle => appL10n.celautErrorTitle;

  static String errorText(CelautErrorKind kind) => switch (kind) {
        CelautErrorKind.invalidInput => appL10n.celautErrorInvalidInput,
        CelautErrorKind.unreachable => appL10n.celautErrorUnreachable,
        CelautErrorKind.timeout => appL10n.celautErrorTimeout,
        CelautErrorKind.identityMismatch => appL10n.celautErrorIdentityMismatch,
        CelautErrorKind.badCertificate => appL10n.celautErrorBadCertificate,
        CelautErrorKind.badSignature => appL10n.celautErrorBadSignature,
        CelautErrorKind.staleTimestamp => appL10n.celautErrorStaleTimestamp,
        CelautErrorKind.unsupportedScheme => appL10n.celautErrorUnsupportedScheme,
        CelautErrorKind.proofOfWork => appL10n.celautErrorProofOfWork,
        CelautErrorKind.protocol => appL10n.celautErrorProtocol,
        CelautErrorKind.storage => appL10n.celautErrorStorage,
        CelautErrorKind.limitReached => appL10n.celautErrorLimitReached,
        CelautErrorKind.wallet => appL10n.celautErrorWallet,
        CelautErrorKind.clientUnknown => appL10n.celautErrorClientUnknown,
        CelautErrorKind.nodeClosed => appL10n.celautErrorNodeClosed,
        CelautErrorKind.noRoom => appL10n.celautErrorNoRoom,
        CelautErrorKind.serviceMissing => appL10n.celautErrorServiceMissing,
        CelautErrorKind.policyRefused => appL10n.celautErrorPolicyRefused,
        CelautErrorKind.unsupportedArchitecture => appL10n.celautErrorUnsupportedArchitecture,
        CelautErrorKind.rateLimited => appL10n.celautErrorRateLimited,
        CelautErrorKind.recursionLimit => appL10n.celautErrorRecursionLimit,
        CelautErrorKind.insufficientCredit => appL10n.celautErrorInsufficientCredit,
        CelautErrorKind.launchFailed => appL10n.celautErrorLaunchFailed,
        CelautErrorKind.transferFailed => appL10n.celautErrorTransferFailed,
        CelautErrorKind.noDescendants => appL10n.celautErrorNoDescendants,
      };

  static String detailLabel(String detail) => appL10n.celautDetailLabel(detail);

  // Values
  static String cores(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return appL10n.celautCores(value == 1 ? 1 : 2, text);
  }

  static String bytes(int value) {
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    var size = value.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final text = unit == 0 || size >= 100 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$text ${units[unit]}';
  }

  static String get memoryLabel => appL10n.celautMemoryLabel;
  static String get diskLabel => appL10n.celautDiskLabel;
  static String get cpuLabel => appL10n.celautCpuLabel;
  static String get benchmarkLabel => appL10n.celautBenchmarkLabel;
  static String get noExpiry => appL10n.celautNoExpiry;
  static String expires(String when) => appL10n.celautExpires(when);
  static String perUnit(String mu) => appL10n.celautPerUnit(mu);
}
