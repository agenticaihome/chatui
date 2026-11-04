import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_deposit.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/bridge/frb_generated.dart';
import 'package:argus_wallet/celaut/deposit_strings.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/format.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/deposit_confirm.dart';
import 'package:argus_wallet/ui/celaut/deposit_screen.dart';
import 'package:argus_wallet/ui/confirm_transaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_bitcoin.dart';

final _peer = 'ab' * 32;
const _address = '9fRAWhdxEsTcdb8PhGNrZfwqa65zfkuYHAMmkQLcic1gdLSV5vA';
final _tx = '7c' * 32;

DepositPreparedView _prepared({int amount = 10000000, String mu = '10000000'}) =>
    DepositPreparedView(
      depositId: 'dep-1',
      preparationId: BigInt.from(42),
      peerId: _peer,
      payToAddress: _address,
      amountNanoErg: BigInt.from(amount),
      amountMu: mu,
      muPerNanoErg: '1',
      minerFeeNanoErg: 1100000,
      changeNanoErg: 88900000,
      inputCount: 1,
      txId: _tx,
      boxId: 'b0' * 32,
      limitNanoErg: BigInt.from(50000000),
      depositedNanoErg: BigInt.from(amount),
      tokenSeconds: 3600,
    );

class DepositApi extends RustLibApi {
  final nodeCalls = <NodeAddress>[];
  final limits = <({String peer, BigInt limit})>[];
  final cancels = <String>[];
  final notifies = <({String deposit, String tx})>[];
  final notifyAnswers = <Object>[];
  final sending = <String>[];
  var sent = <DepositSentView>[];
  String balance = '4500000';

  /// Errors for the next node checks, the first first.
  final nodeErrors = <CelautError>[];

  @override
  Future<String> crateApiCelautDepositCelautDepositSending({required String depositId}) async {
    sending.add(depositId);
    return _tx;
  }

  @override
  List<DepositSentView> crateApiCelautDepositCelautSentDeposits() => sent;

  @override
  Future<DepositNodeView> crateApiCelautDepositCelautDepositNode({
    required NodeAddress node,
  }) async {
    nodeCalls.add(node);
    if (nodeErrors.isNotEmpty) throw nodeErrors.removeAt(0);
    return DepositNodeView(
      peerId: _peer,
      payToAddress: _address,
      muPerNanoErg: '1',
      clientBalanceMu: balance,
      limitNanoErg: limits.isEmpty ? BigInt.from(1000000000) : limits.last.limit,
      depositedNanoErg: BigInt.zero,
    );
  }

  @override
  Future<void> crateApiCelautDepositCelautSetDepositLimit({
    required String peerId,
    required BigInt limitNanoErg,
  }) async => limits.add((peer: peerId, limit: limitNanoErg));

  @override
  Future<void> crateApiCelautDepositCelautDepositCancel({required String depositId}) async =>
      cancels.add(depositId);

  @override
  Future<DepositDoneView> crateApiCelautDepositCelautDepositNotify({
    required String depositId,
    required String txId,
  }) async {
    notifies.add((deposit: depositId, tx: txId));
    final a = notifyAnswers.removeAt(0);
    if (a is CelautError) throw a;
    return a as DepositDoneView;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _main = PayerWallet(walletId: 'w1', name: 'Main', balanceNano: 250000000, open: true);
const _spare = PayerWallet(walletId: 'w2', name: 'Spare', balanceNano: null, open: false);

class FakeWallets implements DepositWallets {
  FakeWallets([this.list = const [_main]]);

  List<PayerWallet> list;

  /// True if the user gives the PIN or the fingerprint when the screen asks.
  bool consent = true;
  final unlocks = <String>[];

  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async {
    unlocks.add(wallet.walletId);
    if (!consent) return false;
    // The wallet is now open.
    list = [
      for (final p in list)
        PayerWallet(
          walletId: p.walletId,
          name: p.name,
          balanceNano: p.balanceNano,
          open: p.walletId == wallet.walletId,
        ),
    ];
    return true;
  }
  final prepares = <({String payer, NodeAddress node, int amount})>[];
  final sends = <int>[];

  @override
  Future<List<PayerWallet>> payers() async => list;

  @override
  Future<DepositPreparedView> prepare(
    PayerWallet payer,
    NodeAddress node,
    int amountNanoErg,
  ) async {
    prepares.add((payer: payer.walletId, node: node, amount: amountNanoErg));
    return _prepared(amount: amountNanoErg, mu: '$amountNanoErg');
  }

  @override
  Future<String> send(int preparationId) async {
    sends.add(preparationId);
    return _tx;
  }
}

DepositDoneView _done({bool accepted = true}) => DepositDoneView(
  depositId: 'dep-1',
  txId: _tx,
  boxId: 'b0' * 32,
  accepted: accepted,
  nodeMessage: accepted ? null : 'Error: payment not valid.',
  clientBalanceMu: accepted ? '14500000' : '4500000',
);

void main() {
  final api = DepositApi();
  setUpAll(() => RustLib.initMock(api: api));
  setUp(() {
    api.nodeCalls.clear();
    api.limits.clear();
    api.cancels.clear();
    api.notifies.clear();
    api.notifyAnswers.clear();
    api.sending.clear();
    api.sent = [];
  });

  group('confirmation sheet', () {
    Widget host(void Function(ConfirmChoice) onResult) => MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => onResult(await showDepositConfirmation(ctx, _prepared(), _main)),
          child: const Text('open'),
        ),
      ),
    );

    testWidgets('shows the ERG, the MU that it buys, the fee and the limit', (tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ConfirmChoice? result;
      await tester.pumpWidget(host((r) => result = r));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(DepositStrings.confirmTitle), findsOneWidget);
      // The wallet that pays and its balance (docs/celaut/ui.md, section 1).
      expect(find.text(DepositStrings.rowPayer), findsOneWidget);
      expect(find.text('Main'), findsOneWidget);
      expect(find.text(DepositStrings.rowPayerBalance), findsOneWidget);
      expect(find.text(formatErg(250000000)), findsOneWidget);
      expect(find.text(formatErg(10000000)), findsOneWidget);
      expect(find.text('10,000,000 MU'), findsOneWidget);
      expect(find.text(DepositStrings.rate('1')), findsOneWidget);
      expect(find.text(formatErg(1100000)), findsOneWidget);
      expect(find.text(formatErg(11100000)), findsOneWidget);
      expect(
        find.text(DepositStrings.usedValue(formatErg(10000000), formatErg(50000000))),
        findsOneWidget,
      );
      expect(find.text(_address), findsOneWidget);
      expect(find.text(DepositStrings.confirmDetail(60)), findsOneWidget);
      // No "sign only": the app must follow the transaction to tell the node.
      expect(find.text('Sign only'), findsNothing);

      await tester.tap(find.text(DepositStrings.confirmLabel));
      await tester.pumpAndSettle();
      expect(result, ConfirmChoice.broadcast);
    });

    test('MU are grouped like token amounts', () {
      expect(groupMu('0'), '0');
      expect(groupMu('999'), '999');
      expect(groupMu('1000'), '1,000');
      expect(groupMu('14500000'), '14,500,000');
      expect(groupMu('n/a'), 'n/a');
    });
  });

  group('deposit screen', () {
    late FakeWallets wallet;

    Future<void> pump(WidgetTester tester, [FakeWallets? wallets, ThemeData? theme]) async {
      tester.view.physicalSize = const Size(390, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      wallet = wallets ?? FakeWallets();
      await tester.pumpWidget(MaterialApp(theme: theme, home: DepositScreen(wallets: wallet)));
      await tester.pumpAndSettle();
    }

    Future<void> check(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('deposit-node')), '127.0.0.1:18460');
      await tester.tap(find.byKey(const Key('deposit-check')));
      await tester.pumpAndSettle();
    }

    for (final accepts in [true, false]) {
      testWidgets('BTC is offered only when the node takes BTC on the wallet network ($accepts)', (tester) async {
        tester.view.physicalSize = const Size(390, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        wallet = FakeWallets();
        final btc = FakeBitcoin(accepts: accepts);
        await tester.pumpWidget(MaterialApp(home: DepositScreen(wallets: wallet, bitcoin: btc)));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('deposit-pay-btc')), findsNothing);
        await check(tester);
        expect(btc.calls, ['node 127.0.0.1:18460']);
        expect(find.byKey(const Key('deposit-pay-btc')), accepts ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('checks the node, deposits, waits for the box and shows the balance', (
      tester,
    ) async {
      await pump(tester);
      await check(tester);
      expect(api.nodeCalls.single, const NodeAddress(host: '127.0.0.1', port: 18460));
      expect(find.text(DepositStrings.payTo(_address)), findsOneWidget);
      expect(find.text(DepositStrings.balance('4,500,000')), findsOneWidget);

      api.notifyAnswers.add(_done());
      await tester.tap(find.byKey(const Key('deposit-prepare')));
      await tester.pumpAndSettle();
      expect(wallet.prepares.single.amount, 10000000);
      expect(find.text('10,000,000 MU'), findsOneWidget);

      await tester.tap(find.text(DepositStrings.confirmLabel));
      await tester.pumpAndSettle();
      expect(wallet.prepares.single.payer, 'w1');
      // The PIN or fingerprint of the paying wallet was asked, though it was open.
      expect(wallet.unlocks, ['w1']);
      // The deposit is "sent" in the database before the send.
      expect(api.sending.single, 'dep-1');
      expect(wallet.sends.single, 42);
      expect(api.notifies.single, (deposit: 'dep-1', tx: _tx));
      expect(api.cancels, isEmpty);
      expect(find.text(DepositStrings.accepted('14,500,000')), findsOneWidget);
      expect(find.text(DepositStrings.tx(_tx)), findsOneWidget);
    });

    testWidgets('a cancelled confirmation gives the deposit back', (tester) async {
      await pump(tester);
      await check(tester);
      await tester.enterText(find.byKey(const Key('deposit-amount')), '0.002');
      await tester.tap(find.byKey(const Key('deposit-prepare')));
      await tester.pumpAndSettle();
      expect(wallet.prepares.single.amount, 2000000);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.cancels.single, 'dep-1');
      expect(wallet.sends, isEmpty);
      expect(api.notifies, isEmpty);
      expect(find.text(DepositStrings.cancelled), findsOneWidget);
    });

    testWidgets('a box that is late can be waited for again; a refusal is shown', (tester) async {
      await pump(tester);
      await check(tester);
      api.notifyAnswers.addAll([
        CelautError(kind: CelautErrorKind.timeout, message: 'the explorer does not show it'),
        _done(accepted: false),
      ]);
      await tester.tap(find.byKey(const Key('deposit-prepare')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(DepositStrings.confirmLabel));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('deposit-error')), findsOneWidget);
      expect(find.byKey(const Key('deposit-wait-again')), findsOneWidget);

      await tester.tap(find.byKey(const Key('deposit-wait-again')));
      await tester.pumpAndSettle();
      expect(api.notifies.length, 2);
      expect(api.notifies.last, (deposit: 'dep-1', tx: _tx));
      expect(wallet.sends.length, 1);
      expect(find.text(DepositStrings.refused('Error: payment not valid.')), findsOneWidget);
      expect(find.byKey(const Key('deposit-wait-again')), findsNothing);
    });

    testWidgets('bad amounts, and no PIN or fingerprint, prepare nothing', (tester) async {
      await pump(tester, FakeWallets(const [_spare]));
      await check(tester);
      for (final bad in ['', '0.0005', 'lots']) {
        await tester.enterText(find.byKey(const Key('deposit-amount')), bad);
        await tester.tap(find.byKey(const Key('deposit-prepare')));
        await tester.pumpAndSettle();
        expect(find.text(DepositStrings.amountInvalid), findsOneWidget, reason: bad);
      }
      expect(wallet.unlocks, isEmpty);
      await tester.enterText(find.byKey(const Key('deposit-amount')), '0.01');
      wallet.consent = false;
      await tester.tap(find.byKey(const Key('deposit-prepare')));
      await tester.pumpAndSettle();
      expect(wallet.unlocks, ['w2']);
      expect(find.text(appL10n.celautDepositAuthNeeded), findsOneWidget);
      expect(wallet.prepares, isEmpty);
    });

    testWidgets('a locked payer opens with its PIN or fingerprint, then pays', (tester) async {
      await pump(tester, FakeWallets(const [_spare]));
      await check(tester);
      expect(find.text(DepositStrings.payerLocked), findsOneWidget);
      await tester.tap(find.byKey(const Key('deposit-prepare')));
      await tester.pumpAndSettle();
      expect(wallet.unlocks, ['w2']);
      expect(wallet.prepares.single.payer, 'w2');
      // The confirmation is up; cancel it: nothing is sent.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(wallet.sends, isEmpty);
      expect(api.cancels.single, 'dep-1');
    });

    testWidgets('a node that forgot the client: the user chooses', (tester) async {
      final made = <String>[];
      tester.view.physicalSize = const Size(390, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      wallet = FakeWallets();
      await tester.pumpWidget(
        MaterialApp(
          home: DepositScreen(
            wallets: wallet,
            newClient: (node) async {
              made.add('${node.host}:${node.port}');
              return NewClientView(peerId: _peer, earlierClients: 1);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      const forgot = CelautError(
        kind: CelautErrorKind.clientUnknown,
        message: 'This RPC requires a client_id minted by GenerateClient first.',
      );
      // "Retry later": nothing changes.
      api.nodeErrors.add(forgot);
      await check(tester);
      expect(find.byKey(const Key('client-unknown-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('client-unknown-retry')));
      await tester.pumpAndSettle();
      expect(made, isEmpty);
      expect(api.nodeCalls.length, 1);
      // "New client": the app makes it, then checks the node again.
      api.nodeErrors.add(forgot);
      await check(tester);
      await tester.tap(find.byKey(const Key('client-unknown-new')));
      await tester.pumpAndSettle();
      expect(made, ['127.0.0.1:18460']);
      expect(api.nodeCalls.length, 3);
      expect(find.text(DepositStrings.payTo(_address)), findsOneWidget);
    });

    testWidgets('with no full wallet the screen says so and does not start', (tester) async {
      await pump(tester, FakeWallets(const []));
      expect(find.byKey(const Key('deposit-no-full-wallet')), findsOneWidget);
      expect(find.text(DepositStrings.noFullWallet), findsOneWidget);
      // No payer, no node, no deposit.
      expect(find.byKey(const Key('deposit-payer')), findsNothing);
      expect(find.byKey(const Key('deposit-node')), findsNothing);
      expect(find.byKey(const Key('deposit-prepare')), findsNothing);
      expect(api.nodeCalls, isEmpty);
    });

    testWidgets('shows the paying wallet and its balance', (tester) async {
      await pump(tester);
      expect(find.text('Main'), findsOneWidget);
      expect(find.text(DepositStrings.payerBalance(formatErg(250000000))), findsOneWidget);
      expect(find.text(DepositStrings.payerOpen), findsOneWidget);
      // No choice of payer and no default: the app has one wallet.
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('a locked wallet with an unknown balance says so, not 0', (tester) async {
      await pump(tester, FakeWallets(const [_spare]));
      expect(find.text('Spare'), findsOneWidget);
      expect(find.text(DepositStrings.payerBalance(DepositStrings.unknown)), findsOneWidget);
      expect(find.text(DepositStrings.payerLocked), findsOneWidget);
    });

    testWidgets('a deposit sent in an earlier run can be waited for', (tester) async {
      api.sent = [
        DepositSentView(
          depositId: 'dep-old',
          peerId: _peer,
          address: '127.0.0.1:18460',
          txId: _tx,
          amountNanoErg: BigInt.from(10000000),
          amountMu: '10000000',
          madeAt: 1,
          expired: false,
        ),
      ];
      api.notifyAnswers.add(_done());
      await pump(tester, FakeWallets(const []));
      expect(find.byKey(const Key('deposit-sent-dep-old')), findsOneWidget);
      await tester.tap(find.byKey(const Key('deposit-sent-wait-dep-old')));
      await tester.pumpAndSettle();
      expect(api.notifies.single, (deposit: 'dep-old', tx: _tx));
      expect(find.text(DepositStrings.accepted('14,500,000')), findsOneWidget);
    });

    testWidgets('the limit of the node is set in ERG', (tester) async {
      await pump(tester);
      await check(tester);
      await tester.enterText(find.byKey(const Key('deposit-limit')), '0.02');
      await tester.tap(find.byKey(const Key('deposit-set-limit')));
      await tester.pumpAndSettle();
      expect(api.limits.single, (peer: _peer, limit: BigInt.from(20000000)));
      expect(api.nodeCalls.length, 2);
      expect(find.text(DepositStrings.used(formatErg(0), formatErg(20000000))), findsOneWidget);

      for (final bad in ['x', '1.5', '-1']) {
        await tester.enterText(find.byKey(const Key('deposit-limit')), bad);
        await tester.tap(find.byKey(const Key('deposit-set-limit')));
        await tester.pumpAndSettle();
        expect(find.text(DepositStrings.limitInvalid), findsOneWidget, reason: bad);
      }
      expect(api.limits.length, 1);
      // 1 ERG is the largest limit.
      await tester.enterText(find.byKey(const Key('deposit-limit')), '1');
      await tester.tap(find.byKey(const Key('deposit-set-limit')));
      await tester.pumpAndSettle();
      expect(api.limits.last.limit, BigInt.from(1000000000));
    });

    testWidgets('the buttons after the check have semantics labels', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await check(tester);
      for (final (key, label) in [
        ('deposit-set-limit', DepositStrings.setLimit),
        ('deposit-prepare', DepositStrings.prepare),
      ]) {
        expect(tester.getSemantics(find.byKey(Key(key))).label, label);
      }
      handle.dispose();
    });

    testWidgets('the card after the check lays out with the app theme', (tester) async {
      // The theme gives buttons an infinite minimum width. In a Row that fails.
      await pump(tester, null, argusTheme(watchful: false));
      await check(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const Key('deposit-set-limit'))).width, lessThan(390));
    });

    testWidgets('the keys of the keyboard: Go checks the node, Done sets the limit', (tester) async {
      await pump(tester);
      final node = tester.widget<TextField>(find.byKey(const Key('deposit-node')));
      expect(node.keyboardType, TextInputType.url);
      expect(node.textInputAction, TextInputAction.go);
      await tester.enterText(find.byKey(const Key('deposit-node')), '127.0.0.1:18460');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(api.nodeCalls.length, 1);
      // The keyboard closed, so the contract of the node shows.
      expect(tester.testTextInput.isVisible, isFalse);

      final amount = tester.widget<TextField>(find.byKey(const Key('deposit-amount')));
      expect(amount.keyboardType, const TextInputType.numberWithOptions(decimal: true));
      expect(amount.textInputAction, TextInputAction.done);
      // Done in the amount only closes the keyboard: no deposit starts.
      await tester.enterText(find.byKey(const Key('deposit-amount')), '0.01');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(DepositStrings.confirmTitle), findsNothing);

      await tester.enterText(find.byKey(const Key('deposit-limit')), '0.02');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.limits.single, (peer: _peer, limit: BigInt.from(20000000)));
    });

    testWidgets('the label of the limit is not cut: the maximum is under the field', (tester) async {
      await pump(tester);
      await check(tester);
      expect(find.text(DepositStrings.limitLabel), findsOneWidget);
      expect(find.text(DepositStrings.limitHelper), findsOneWidget);
    });

    testWidgets('a bad node address calls nothing', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('deposit-node')), 'node.example');
      await tester.tap(find.byKey(const Key('deposit-check')));
      await tester.pumpAndSettle();
      expect(api.nodeCalls, isEmpty);
      expect(find.byKey(const Key('deposit-prepare')), findsNothing);
    });
  });
}
