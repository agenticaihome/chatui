
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
  required double volatility,
  required int volatilityPeriodSeconds,
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
    this.sentMu,
  });

  final QuoteView quote;
  final InstanceView instance;

  /// The `initial_mu` that the app sent to start the instance, in MU; null if it sent
  /// none, and the node chose the start balance (nodo#636: `cost` plus the funding of
  /// `deposits.DEFAULT_INITIAL_PERIODS` periods).
  final String? sentMu;

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
/// (nodo#636): the funding of the maintenance periods in [time], plus one for the period
/// that runs at the end, each at most `init_maintenance_cost * (1 + price_volatility)^k`
/// (`MaintenancePrice`), rounded up. Null if the quote gives no maintenance price.
BigInt? survivalBalanceMu(QuoteView quote, Duration time) => quotePrice(quote)?.balanceFor(time);

/// How long the balance [balanceMu] keeps an instance on the node of [quote], the inverse
/// of [survivalBalanceMu]. Null if the quote gives no maintenance price.
Duration? survivalOf(QuoteView quote, BigInt balanceMu) => quotePrice(quote)?.lasts(balanceMu);

/// The maintenance price of the node of [quote]; null if the quote gives none. A quote
/// that is not bounded (`price_bounded` false) promises no limit to the rise: the app
/// counts each period at the price of the quote, as nodo's `funding_sum_mu` does.
MaintenancePrice? quotePrice(QuoteView quote) => MaintenancePrice.of(
      perPeriodMu: quote.initMaintenanceMu,
      periodSeconds: quote.maintenanceSecondsLoop,
      volatility: quoteVolatility(quote),
      volatilityPeriodSeconds: quote.volatilityPeriodSeconds,
    );

/// The volatility that the app counts for [quote]: `price_volatility` if the quote is
/// bounded, else 0.
double quoteVolatility(QuoteView quote) => quote.priceBounded ? quote.priceVolatility : 0.0;

/// The `initial_mu` of a start on the node of [quote] (nodo#636): the `cost` of the
/// quote (the builds) plus the balance that keeps the instance for [minSurvival]. Null
/// when the app lets the node choose the balance: no [minSurvival] (the instance runs
/// until the user stops it, or for the default time of the node), or a quote that gives
/// no maintenance price. The node then charges `cost` plus the funding of its
/// `deposits.DEFAULT_INITIAL_PERIODS` periods, as for `nodo execute`.
///
/// [balanceMu], the balance that the user typed on the service debug screen, wins over
/// [minSurvival].
BigInt? startMuFor(QuoteView quote, Duration? minSurvival, {BigInt? balanceMu}) {
  final cost = BigInt.tryParse(quote.costMu);
  if (cost == null) return null;
  if (balanceMu != null) return cost + balanceMu;
  if (minSurvival == null) return null;
  final balance = survivalBalanceMu(quote, minSurvival);
  return balance == null ? null : cost + balance;
}

/// False if the credit of the client on the node of [q] is less than what the start
/// takes: [startMu], or, when the node chooses the balance, at least the `cost` of the
/// quote. Then [launchService] does not ask the node to start, and the node never reads
/// the values.
bool wouldAskToStart(QuoteView q, {BigInt? startMu}) {
  final credit = BigInt.tryParse(q.clientBalanceMu);
  final need = startMu ?? BigInt.tryParse(q.costMu);
  return !(credit != null && need != null && credit < need);
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
/// The nodes are asked for a quote with no `initial_mu`: the `cost` of a quote is the
/// builds only (nodo#636), and the balance is added by the start ([startMuFor]).
///
/// [minSurvival] is the least time that the instance must run: each node gets its `cost`
/// plus the balance that keeps the instance for that time at its own price
/// ([survivalBalanceMu]). Without it, the app sends no `initial_mu`, and the node chooses
/// the balance (issue #119: no constant balance of the app). A node keeps what the
/// instance did not use and gives it back at the stop.
///
/// [balanceMu] is a balance that the user typed (the service debug screen): each node
/// gets its `cost` plus it.
///
/// [keepAlive] makes the instance run until the user stops it (Josemi, 2026-10-29): the app
/// tops it up when its balance is low (`AutoTopUp`). [budgetMu] is the most that it may
/// move for that; null is no limit. After the start, the app keeps the price of the node
/// with the instance, so that it can say how long a balance lasts. A failure of that is
/// not a failure of the launch: the instance runs.
Future<LaunchOutcome> launchService({
  required String serviceIdHex,
  Duration? minSurvival,
  String? balanceMu,
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
  final quotes = await quote(nodes: chosen.ask, serviceIdHex: serviceIdHex);
  final typed = balanceMu == null ? null : BigInt.tryParse(balanceMu);
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
    final startMu = startMuFor(candidate, minSurvival, balanceMu: typed);
    if (!wouldAskToStart(candidate, startMu: startMu)) {
      skipped.add(
        LaunchSkip(
          candidate,
          CelautError(
            kind: CelautErrorKind.insufficientCredit,
            message: 'credit ${candidate.clientBalanceMu} MU, price ${startMu ?? candidate.costMu} MU',
          ),
        ),
      );
      continue;
    }
    try {
      final instance = await start(
        node: candidate.address,
        serviceIdHex: serviceIdHex,
        // The node takes the builds out of initial_mu, and the rest is the balance of the
        // instance. None: the node adds its default balance to the cost.
        initialMu: startMu?.toString(),
        environment: values,
      );
      _keepPlan(instance.instanceId, candidate, keepAlive, budgetMu, setPricing, setKeepAlive);
      return LaunchOutcome(
        quote: candidate,
        instance: instance,
        skipped: skipped,
        leftOut: leftOut,
        sentMu: startMu?.toString(),
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
        volatility: quoteVolatility(quote),
        volatilityPeriodSeconds: quote.volatilityPeriodSeconds,
      );
    }
    if (keepAlive) setKeepAlive(instanceId: instanceId, enabled: true, budgetMu: budgetMu);
  } on Object {
    // The instance runs; the user can turn keep-alive on from its info page.
  }
}
