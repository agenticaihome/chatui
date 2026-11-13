import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/bridge/api/celaut_spending.dart';
import 'package:argus_wallet/ui/celaut/node_spending.dart';

// A fake of the calls of the balance and the spending (issue #136): no node, no Rust.

/// An account that the app never read: every value is unknown.
AccountSpendingView unreadAccount() => AccountSpendingView(
      readAt: 0,
      balanceMu: '',
      spentMu: '',
      receivedMu: '',
      returnedMu: '',
      since: 0,
      partial: false,
      incomplete: false,
      stopped: false,
      kinds: const [],
    );

/// An account read at [readAt] with these sums.
AccountSpendingView readAccount({
  int readAt = 1790000000,
  String balance = '0',
  String spent = '0',
  String received = '0',
  String returned = '0',
  int since = 1789990000,
  bool partial = false,
  bool incomplete = false,
  List<KindFlowView> kinds = const [],
}) =>
    AccountSpendingView(
      readAt: readAt,
      balanceMu: balance,
      spentMu: spent,
      receivedMu: received,
      returnedMu: returned,
      since: since,
      partial: partial,
      incomplete: incomplete,
      stopped: false,
      kinds: kinds,
    );

NodeSpendingView nodeSpending({
  required String peerId,
  String address = 'node.example:8090',
  AccountSpendingView? account,
  String statements = '',
  String starting = '',
  List<InstanceSpendingView> instances = const [],
}) =>
    NodeSpendingView(
      peerId: peerId,
      address: address,
      account: account ?? unreadAccount(),
      statementsMu: statements,
      startingMu: starting,
      instances: instances,
    );

class FakeSpendingApi extends SpendingApi {
  FakeSpendingApi({
    Map<String, NodeSpendingView>? views,
    this.list = const [],
    this.creditAnswer = '1000000',
    this.quote,
  }) : views = views ?? {};

  final Map<String, NodeSpendingView> views;
  final List<InstanceListView> list;

  /// The free balance of the client; null makes the call fail.
  String? creditAnswer;

  /// The quote of the next read; null means the default one (2,000 MU).
  SpendingQuoteView? quote;

  /// What a read gives; an error is thrown.
  NodeSpendingView? afterNodeRead;
  AccountSpendingView? afterInstanceRead;
  Object? readError;

  final nodeReads = <String>[];
  final instanceReads = <String>[];
  var credits = 0;

  SpendingQuoteView get _quote => quote ?? SpendingQuoteView(maxMu: '2000', fromSeq: BigInt.one);

  @override
  NodeSpendingView spending(String peerId) => views[peerId] ?? nodeSpending(peerId: peerId);

  @override
  List<NodeSpendingView> overview() => views.values.toList();

  @override
  List<InstanceListView> instances() => list;

  @override
  Future<String> credit(NodeAddress node) async {
    credits++;
    final c = creditAnswer;
    if (c == null) throw const CelautError(kind: CelautErrorKind.unreachable, message: 'no');
    return c;
  }

  @override
  Future<SpendingQuoteView> quoteNode(NodeAddress node) async => _quote;

  @override
  Future<NodeSpendingView> readNode(NodeAddress node, String maxMu) async {
    nodeReads.add('${node.host}:${node.port} $maxMu');
    final e = readError;
    if (e != null) throw e;
    final v = afterNodeRead!;
    views[v.peerId] = v;
    return v;
  }

  @override
  Future<SpendingQuoteView> quoteInstance(String instanceId) async => _quote;

  @override
  Future<AccountSpendingView> readInstance(String instanceId, String maxMu) async {
    instanceReads.add('$instanceId $maxMu');
    final e = readError;
    if (e != null) throw e;
    return afterInstanceRead!;
  }
}
