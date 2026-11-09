
import '../bridge/api/celaut.dart';
import '../bridge/api/celaut_env.dart';
import '../bridge/api/celaut_health.dart';
import '../bridge/api/celaut_home.dart';
import '../bridge/api/celaut_service.dart';
import 'host_port.dart';
import 'maintenance_price.dart';

typedef QuoteCall = Future<QuotesView> Function({
  required List<NodeAddress> nodes,
  required String serviceIdHex,
  String? initialMu,
});

/// Keep the price of the node of a started instance (`celautSetInstancePricing`).
typedef PricingCall = void Function({
  required String instanceId,
  required String maintenanceMu,
  required int maintenanceSeconds,
  required double variance,
});

/// Turn "run until I stop it" on for a started instance (`celautSetKeepAlive`).
typedef KeepAliveCall = void Function({
  required String instanceId,
  required bool enabled,
  String? budgetMu,
});

typedef StartCall = Future<InstanceView> Function({
  required NodeAddress node,
  required String serviceIdHex,
  String? initialMu,
  required List<EnvChoice> environment,
});

/// The question about the environment variables of the service (`docs/celaut/env-variables.md`),
/// asked after the quotes and before the first start. It gives the values that the user
/// chose (a variable that the user skipped is not in the list), or null if the user
/// cancelled the launch.
typedef EnvironmentStep = Future<List<EnvChoice>?> Function(QuotesView quotes);

/// The user cancelled the launch in the question about the variables. Nothing was sent
/// to a node except the quotes.
class LaunchCancelled implements Exception {
  const LaunchCancelled();

  @override
  String toString() => 'LaunchCancelled()';
}

/// A node that gave a quote but did not start the service.
class LaunchSkip {
  const LaunchSkip(this.quote, this.error);

  final QuoteView quote;

  /// Why. The `message` is the text of the node (without the wrapper of the transport),
  /// or, for [CelautErrorKind.insufficientCredit], the numbers.
  final CelautError error;

  /// True if the app did not ask the node to start: the balance of the client on the node
  /// is less than the price. [quote] has both numbers.
  bool get isCreditProblem => error.kind == CelautErrorKind.insufficientCredit;
}

/// A node that was not asked because its last checks say that it does not answer.
class LeftOutNode {
  const LeftOutNode({
    required this.address,
    required this.peerId,
    this.kind,
    this.message = '',
  });

  /// The address of the node (`host:port`).
  final String address;
  final String peerId;

  /// Why its last check failed, if the record says.
  final CelautErrorKind? kind;

  /// The text of its last failure, if the record has it.
  final String message;
}

/// The service started on the node of [quote], the best one that could start it.
class LaunchOutcome {
  const LaunchOutcome({
    required this.quote,
    required this.instance,
    required this.skipped,
    this.leftOut = const [],
  });

  final QuoteView quote;
  final InstanceView instance;

  /// The nodes that were better than [quote] and did not start the service.
  final List<LaunchSkip> skipped;

  /// The nodes that were not asked, because their last checks say that they do not answer.
  final List<LeftOutNode> leftOut;
}

enum LaunchFailureKind {
  /// No node to ask: none typed and none known.
  noNodes,

  /// No node gave a quote.
  noQuotes,

  /// Nodes gave quotes, and none of them started the service.
  allFailed,
}

class LaunchFailure implements Exception {
  const LaunchFailure(
    this.kind, {
    this.quoteFailures = const [],
    this.skipped = const [],
    this.leftOut = const [],
  });

  final LaunchFailureKind kind;
  final List<QuoteFailureView> quoteFailures;
  final List<LaunchSkip> skipped;

  /// The nodes that were not asked, because their last checks say that they do not answer.
  final List<LeftOutNode> leftOut;

  /// The nodes that forgot the client id of the app. The app asks the user what to do;
  /// it never makes a new client by itself (`docs/celaut/ui.md`).
  List<LaunchSkip> get clientUnknown => [
        for (final s in skipped)
          if (s.error.kind == CelautErrorKind.clientUnknown) s,
      ];

  @override
  String toString() => 'LaunchFailure($kind, skipped: ${skipped.length})';
}

/// The nodes to ask when the user typed none: the most recent address of each known
/// node. An address that does not parse is left out.
List<NodeAddress> knownNodeAddresses(List<KnownNodeView> known) {
  final nodes = <NodeAddress>[];
  for (final node in known) {
    if (node.addresses.isEmpty) continue;
    final parsed = parseHostPort(node.addresses.first).value;
    if (parsed != null) nodes.add(NodeAddress(host: parsed.host, port: parsed.port));
  }
  return nodes;
}

/// The longest minimum time of a launch: 30 days.
const maxMinSurvival = Duration(days: 30);

/// The balance that keeps an instance on the node of [quote] for at least [time]
/// (Josemi, 2026-10-23): the node charges the maintenance at the start
/// (`init_maintenance_cost`) once each `maintenance_seconds_loop`, so the balance is the
/// periods in [time], plus one for the period that runs at the end, each with the margin
/// of the node for the difference of the real cost (`cost * (1 + variance)`, as nodo's
/// `variance_cost_normalization` with k = 1), rounded up. Null if the quote gives no
/// maintenance price.
BigInt? survivalBalanceMu(QuoteView quote, Duration time) => quotePrice(quote)?.balanceFor(time);

/// How long the balance [balanceMu] keeps an instance on the node of [quote], the inverse
/// of [survivalBalanceMu]. Null if the quote gives no maintenance price.
Duration? survivalOf(QuoteView quote, BigInt balanceMu) => quotePrice(quote)?.lasts(balanceMu);

/// The maintenance price of the node of [quote]; null if the quote gives none.
MaintenancePrice? quotePrice(QuoteView quote) => MaintenancePrice.of(
      perPeriodMu: quote.initMaintenanceMu,
      periodSeconds: quote.maintenanceSecondsLoop,
      variance: quote.variance,
    );

/// The start cost of [quote] with the balance [balanceMu] instead of [quotedBalanceMu],
/// the balance that the quote was asked with: the quote is the build plus that balance
/// (nodo #563). Null if the quote is less than its balance (a node that does not follow
/// #563).
BigInt? startCostWith(QuoteView quote, BigInt quotedBalanceMu, BigInt balanceMu) {
  final cost = BigInt.tryParse(quote.costMu);
  if (cost == null || cost < quotedBalanceMu) return null;
  return cost - quotedBalanceMu + balanceMu;
}

/// False if the credit of the client on the node of [q] is less than the price: then
/// [launchService] does not ask the node to start, and the node never reads the values.
bool wouldAskToStart(QuoteView q) {
  final credit = BigInt.tryParse(q.clientBalanceMu);
  final cost = BigInt.tryParse(q.costMu);
  return !(credit != null && cost != null && credit < cost);
}

/// A node whose last checks failed this many times in a row is left out of the quotes.
const leaveOutAfterFailures = 2;

String _hostPort(NodeAddress a) => '${a.host}:${a.port}';

/// Split [asked] into the nodes to ask and the nodes to leave out: the ones that the
/// health records say are unreachable after [leaveOutAfterFailures] checks in a row. If
/// that would leave no node, all of them are asked: a node may be back.
({List<NodeAddress> ask, List<LeftOutNode> leftOut}) chooseNodesToAsk(
  List<NodeAddress> asked,
  List<NodeHealthView> health,
) {
  final down = <String, NodeHealthView>{
    for (final h in health)
      if (h.availability == NodeAvailability.unreachable && h.failures >= leaveOutAfterFailures)
        h.address: h,
  };
  final ask = <NodeAddress>[];
  final leftOut = <LeftOutNode>[];
  for (final a in asked) {
    final h = down[_hostPort(a)];
    if (h == null) {
      ask.add(a);
    } else {
      leftOut.add(
        LeftOutNode(
          address: h.address,
          peerId: h.peerId,
          kind: h.errorKind,
          message: h.error ?? '',
        ),
      );
    }
  }
  if (ask.isEmpty) return (ask: asked, leftOut: const []);
  return (ask: ask, leftOut: leftOut);
}

/// Start a service on the best node (`docs/celaut/balancer.md`): ask every node for a
/// quote, take the quotes best first, and use the first node that starts the service.
/// A node that fails is skipped, and the next one is tried.
///
/// Two checks save time and give a reason:
/// - A node whose last checks say that it does not answer is not asked (see
///   [chooseNodesToAsk]).
/// - A node where the balance of the client is less than the price is not asked to
///   start: it would refuse. It is skipped with [CelautErrorKind.insufficientCredit].
///
/// [nodes] are the nodes to ask. Without them, the known nodes of the app.
///
/// [environment] asks the user for the environment variables of the service once the
/// quotes are in. A quote carries no variable: only a start does, so a node that only
/// prices the service never reads them. Throws [LaunchCancelled] if the user cancels.
///
/// [minSurvival] is the least time that the instance must run. The first quotes give the
/// price of the maintenance of each node; the nodes are then asked again with the balance
/// that keeps the instance for that time on the most expensive of them
/// ([survivalBalanceMu]), so the quote and the start balance are right on every node. A
/// node keeps what the instance did not use and gives it back at the stop.
///
/// [keepAlive] makes the instance run until the user stops it (Josemi, 2026-10-29): the app
/// tops it up when its balance is low (`AutoTopUp`). [budgetMu] is the most that it may
/// move for that; null is no limit. After the start, the app keeps the price of the node
/// with the instance, so that it can say how long a balance lasts. A failure of that is
/// not a failure of the launch: the instance runs.
Future<LaunchOutcome> launchService({
  required String serviceIdHex,
  String? initialMu,
  Duration? minSurvival,
  bool keepAlive = false,
  String? budgetMu,
  List<NodeAddress>? nodes,
  EnvironmentStep? environment,
  QuoteCall quote = celautQuoteService,
  StartCall start = celautStartService,
  PricingCall setPricing = celautSetInstancePricing,
  KeepAliveCall setKeepAlive = celautSetKeepAlive,
  List<KnownNodeView> Function() knownNodes = celautKnownNodes,
  List<NodeHealthView> Function() health = celautNodesHealth,
}) async {
  final all = nodes ?? knownNodeAddresses(knownNodes());
  if (all.isEmpty) throw const LaunchFailure(LaunchFailureKind.noNodes);
  final chosen = chooseNodesToAsk(all, health());
  final leftOut = chosen.leftOut;
  var quotes = await quote(nodes: chosen.ask, serviceIdHex: serviceIdHex, initialMu: initialMu);
  if (minSurvival != null && quotes.quotes.isNotEmpty) {
    BigInt? need;
    for (final q in quotes.quotes) {
      final b = survivalBalanceMu(q, minSurvival);
      if (b != null && (need == null || b > need)) need = b;
    }
    if (need != null && need.toString() != initialMu) {
      quotes = await quote(nodes: chosen.ask, serviceIdHex: serviceIdHex, initialMu: need.toString());
    }
  }
  if (quotes.quotes.isEmpty) {
    throw LaunchFailure(
      LaunchFailureKind.noQuotes,
      quoteFailures: quotes.failures,
      leftOut: leftOut,
    );
  }
  final values = environment == null ? const <EnvChoice>[] : await environment(quotes);
  if (values == null) throw const LaunchCancelled();
  final skipped = <LaunchSkip>[];
  for (final candidate in quotes.quotes) {
    if (!wouldAskToStart(candidate)) {
      skipped.add(
        LaunchSkip(
          candidate,
          CelautError(
            kind: CelautErrorKind.insufficientCredit,
            message: 'credit ${candidate.clientBalanceMu} MU, price ${candidate.costMu} MU',
          ),
        ),
      );
      continue;
    }
    try {
      final instance = await start(
        node: candidate.address,
        serviceIdHex: serviceIdHex,
        // The node takes the build out of initial_mu, and its quote is the build plus
        // the balance asked for: the least that a start needs.
        initialMu: candidate.costMu,
        environment: values,
      );
      _keepPlan(instance.instanceId, candidate, keepAlive, budgetMu, setPricing, setKeepAlive);
      return LaunchOutcome(
        quote: candidate,
        instance: instance,
        skipped: skipped,
        leftOut: leftOut,
      );
    } on CelautError catch (e) {
      skipped.add(LaunchSkip(candidate, e));
    }
  }
  throw LaunchFailure(
    LaunchFailureKind.allFailed,
    quoteFailures: quotes.failures,
    skipped: skipped,
    leftOut: leftOut,
  );
}

/// Keep the price of the winning node with the new instance, and turn keep-alive on if the
/// user asked for it. The instance already runs: an error here is dropped.
void _keepPlan(
  String instanceId,
  QuoteView quote,
  bool keepAlive,
  String? budgetMu,
  PricingCall setPricing,
  KeepAliveCall setKeepAlive,
) {
  try {
    if (quotePrice(quote) != null) {
      setPricing(
        instanceId: instanceId,
        maintenanceMu: quote.initMaintenanceMu,
        maintenanceSeconds: quote.maintenanceSecondsLoop,
        variance: quote.variance,
      );
    }
    if (keepAlive) setKeepAlive(instanceId: instanceId, enabled: true, budgetMu: budgetMu);
  } on Object {
    // The instance runs; the user can turn keep-alive on from its info page.
  }
}
