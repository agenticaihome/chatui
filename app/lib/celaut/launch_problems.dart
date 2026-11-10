import '../bridge/api/celaut.dart';
import '../bridge/api/celaut_service.dart';
import 'launcher.dart';

/// What the user can do about a node that did not start a service.
enum ProblemAction {
  /// Wait: the node may take the service later.
  retryLater,

  /// This node will not run this service: use another node.
  chooseOtherNode,

  /// The credit on the node is less than the price: deposit, or use another node.
  addDeposit,

  /// The node forgot the client id: the app asks the user what to do (a new client or
  /// a retry later). It never makes a new client by itself.
  askClientChoice,

  /// No action to suggest.
  none,
}

/// The action for a reason (`docs/celaut/ui.md`, the feedback of a refused launch).
ProblemAction actionFor(CelautErrorKind kind) => switch (kind) {
  CelautErrorKind.nodeClosed ||
  CelautErrorKind.noRoom ||
  CelautErrorKind.rateLimited ||
  CelautErrorKind.recursionLimit ||
  CelautErrorKind.launchFailed ||
  CelautErrorKind.unreachable ||
  CelautErrorKind.timeout => ProblemAction.retryLater,
  CelautErrorKind.serviceMissing ||
  CelautErrorKind.policyRefused ||
  CelautErrorKind.unsupportedArchitecture ||
  CelautErrorKind.identityMismatch ||
  CelautErrorKind.badCertificate ||
  CelautErrorKind.badSignature ||
  CelautErrorKind.staleTimestamp ||
  CelautErrorKind.unsupportedScheme => ProblemAction.chooseOtherNode,
  CelautErrorKind.insufficientCredit => ProblemAction.addDeposit,
  CelautErrorKind.clientUnknown => ProblemAction.askClientChoice,
  _ => ProblemAction.none,
};

/// One node and why it did not start the service.
class LaunchProblem {
  const LaunchProblem({
    required this.address,
    required this.kind,
    required this.message,
    required this.action,
    this.creditMu,
    this.costMu,
    this.leftOut = false,
    this.opensAt = 0,
  });

  /// The address of the node (`host:port`).
  final String address;

  /// The reason. [CelautErrorKind.unreachable] if the app has no better one.
  final CelautErrorKind kind;

  /// The text of the node, as it came. Empty if there is none.
  final String message;

  final ProblemAction action;

  /// The balance of the client on the node and the price, in MU, for a credit problem.
  final String? creditMu;
  final String? costMu;

  /// True if the app did not ask the node, because its last checks failed.
  final bool leftOut;

  /// With [CelautErrorKind.nodeClosed]: when the node opens again, by the schedule that it
  /// announced (nodo#344), in unix seconds; 0 if the app does not know it.
  final int opensAt;
}

/// When the node of [address] opens again, by its announced schedule; 0 if unknown. 0
/// too when the bridge is not loaded (widget tests).
int nodeOpensAt(NodeAddress address) {
  try {
    return celautNodeOpensAt(node: address);
  } on Object {
    return 0;
  }
}

String _address(NodeAddress address) => '${address.host}:${address.port}';

/// The problems of a failed launch, one for each node: the nodes that gave no quote, the
/// nodes that gave a quote and did not start, and the nodes left out. Nodes that failed
/// after a quote come in the order in which the app tried them.
///
/// A node that is closed (nodo#344) says when it opens again: a quote failure carries it,
/// and for a start that the node refused, [opensAt] reads it from the node's schedule.
List<LaunchProblem> problemsOf(
  LaunchFailure failure, {
  int Function(NodeAddress) opensAt = nodeOpensAt,
}) => [
  for (final f in failure.quoteFailures)
    LaunchProblem(
      address: _address(f.address),
      kind: f.kind,
      message: f.message,
      action: actionFor(f.kind),
      opensAt: f.kind == CelautErrorKind.nodeClosed ? f.opensAt : 0,
    ),
  for (final s in failure.skipped)
    LaunchProblem(
      address: _address(s.quote.address),
      kind: s.error.kind,
      message: s.isCreditProblem ? '' : s.error.message,
      action: actionFor(s.error.kind),
      creditMu: s.isCreditProblem ? s.quote.clientBalanceMu : null,
      costMu: s.isCreditProblem ? s.quote.costMu : null,
      opensAt: s.error.kind == CelautErrorKind.nodeClosed ? opensAt(s.quote.address) : 0,
    ),
  for (final n in failure.leftOut)
    LaunchProblem(
      address: n.address,
      kind: n.kind ?? CelautErrorKind.unreachable,
      message: n.message,
      action: actionFor(n.kind ?? CelautErrorKind.unreachable),
      leftOut: true,
    ),
];
