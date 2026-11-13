import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/auto_top_up.dart';
import 'package:argus_wallet/celaut/maintenance_price.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/instance_time_section.dart';
import 'package:argus_wallet/ui/celaut/move_mu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Issue #136: add MU to a running instance or take it back (ModifyDeposit), with the
// balances before and after, the fee, a second yes, and the note of the automatic top-up.

class _Wallets implements FullWallets {
  _Wallets({required this.unlocks});

  final bool unlocks;

  @override
  Future<List<PayerWallet>> payers() async =>
      [const PayerWallet(walletId: 'w1', name: 'Main', balanceNano: 1, open: false)];

  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async => unlocks;
}

InstancePlanView _plan({bool keep = false}) => InstancePlanView(
      closesAt: 0,
      onClose: OnCloseView.refuse,
      keepAlive: keep,
      budgetMu: '',
      spentMu: keep ? '0' : '',
      maintenanceMu: '100',
      maintenanceSeconds: 60,
      volatility: 0,
      volatilityPeriodSeconds: 0,
      startedAt: 0,
      hibernated: false,
      diskOnly: false,
      wakeFeeMu: '',
    );

void main() {
  late List<String> moves;
  late Object? moveError;
  var deposits = 0;

  Future<TopUpView> move(String id, String amount, bool back) async {
    moves.add('$id $amount ${back ? 'back' : 'add'}');
    final e = moveError;
    if (e != null) throw e;
    return TopUpView(
      instanceBalanceMu: back ? '2100' : '4100',
      clientBalanceMu: back ? '51000' : '49000',
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    moves = [];
    moveError = null;
    deposits = 0;
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    required bool takeBack,
    String? balance = '3100',
    String? credit = '50000',
    bool auto = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: argusTheme(watchful: false),
        home: Scaffold(
          body: MoveMuSheet(
            instanceId: 'i',
            takeBack: takeBack,
            node: 'node.example:8090',
            balance: balance == null ? null : BigInt.parse(balance),
            credit: credit == null ? null : BigInt.parse(credit),
            autoTopUp: auto,
            price: MaintenancePrice.of(perPeriodMu: '100', periodSeconds: 60),
            move: move,
            openDeposit: () => deposits++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

  FilledButton ok(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('move-mu-ok')));

  testWidgets('add: the amount shows the balances before and after, and the fee', (tester) async {
    await pumpSheet(tester, takeBack: false, credit: '150000');
    final l = appL10n;
    expect(ok(tester).onPressed, isNull);
    expect(text(tester, 'move-mu-balance'), '3,100 MU');
    // Quick values: only the ones that the credit covers.
    expect(find.byKey(const Key('move-mu-chip-1000000')), findsNothing);
    await tester.tap(find.byKey(const Key('move-mu-chip-100000')));
    await tester.pump();
    expect(text(tester, 'move-mu-balance'), '3,100 MU → 103,100 MU');
    expect(text(tester, 'move-mu-credit'), '150,000 MU → 50,000 MU');
    await tester.enterText(find.byKey(const Key('move-mu-amount')), '1000');
    await tester.pump();
    expect(text(tester, 'move-mu-balance'), '3,100 MU → 4,100 MU');
    expect(text(tester, 'move-mu-credit'), '150,000 MU → 149,000 MU');
    expect(text(tester, 'move-mu-fee'), l.celautMoveFee);
    // 4,100 MU at 100 MU a minute.
    expect(text(tester, 'move-mu-lasts'), l.celautMoveLasts('40 min'));
    expect(find.byKey(const Key('move-mu-auto')), findsNothing);
    expect(ok(tester).onPressed, isNotNull);
  });

  testWidgets('add: more than the credit is refused, and offers a deposit', (tester) async {
    await pumpSheet(tester, takeBack: false);
    await tester.enterText(find.byKey(const Key('move-mu-amount')), '50001');
    await tester.pump();
    expect(find.text(appL10n.celautMoveOverCredit('50,000 MU')), findsOneWidget);
    expect(ok(tester).onPressed, isNull);
    await tester.tap(find.byKey(const Key('move-mu-deposit')));
    await tester.pumpAndSettle();
    expect(deposits, 1);
    expect(moves, isEmpty);
  });

  testWidgets('zero is refused', (tester) async {
    await pumpSheet(tester, takeBack: true);
    await tester.enterText(find.byKey(const Key('move-mu-amount')), '0');
    await tester.pump();
    expect(find.text(appL10n.celautMoveZero), findsOneWidget);
    expect(ok(tester).onPressed, isNull);
  });

  testWidgets('the move needs a second yes: Cancel moves nothing, Move moves it', (tester) async {
    await pumpSheet(tester, takeBack: false);
    await tester.enterText(find.byKey(const Key('move-mu-amount')), '1000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('move-mu-ok')));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.celautMoveConfirmAddBody('1,000 MU', 'node.example:8090')), findsOneWidget);
    await tester.tap(find.byKey(const Key('move-mu-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(moves, isEmpty);
    await tester.tap(find.byKey(const Key('move-mu-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move-mu-confirm-ok')));
    await tester.pumpAndSettle();
    expect(moves, ['i 1000 add']);
  });

  testWidgets('take back: half or all of the balance, never more', (tester) async {
    await pumpSheet(tester, takeBack: true);
    final l = appL10n;
    await tester.tap(find.byKey(const Key('move-mu-chip-1550')));
    await tester.pump();
    expect(text(tester, 'move-mu-balance'), '3,100 MU → 1,550 MU');
    expect(text(tester, 'move-mu-credit'), '50,000 MU → 51,550 MU');
    await tester.tap(find.byKey(const Key('move-mu-chip-3100')));
    await tester.pump();
    expect(text(tester, 'move-mu-balance'), '3,100 MU → 0 MU');
    // Nothing left: the node stops it at its next charge.
    expect(text(tester, 'move-mu-lasts'), l.celautMoveStops);
    await tester.enterText(find.byKey(const Key('move-mu-amount')), '3101');
    await tester.pump();
    expect(find.text(l.celautMoveOverBalance('3,100 MU')), findsOneWidget);
    expect(ok(tester).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('move-mu-amount')), '1000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('move-mu-ok')));
    await tester.pumpAndSettle();
    expect(find.text(l.celautMoveConfirmTakeBackBody('1,000 MU', 'node.example:8090')), findsOneWidget);
    await tester.tap(find.byKey(const Key('move-mu-confirm-ok')));
    await tester.pumpAndSettle();
    expect(moves, ['i 1000 back']);
  });

  testWidgets('with the automatic top-up on, the sheet says so', (tester) async {
    await pumpSheet(tester, takeBack: true, auto: true);
    expect(text(tester, 'move-mu-auto'), appL10n.celautMoveAutoOnTakeBack);
    await pumpSheet(tester, takeBack: false, auto: true);
    expect(text(tester, 'move-mu-auto'), appL10n.celautMoveAutoOnAdd);
  });

  testWidgets('a refusal of the node is shown with its reason', (tester) async {
    moveError = const CelautError(
      kind: CelautErrorKind.protocol,
      message: 'the node did not move the credit: The instance does not have that balance',
    );
    await pumpSheet(tester, takeBack: true);
    await tester.enterText(find.byKey(const Key('move-mu-amount')), '10');
    await tester.pump();
    await tester.tap(find.byKey(const Key('move-mu-ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move-mu-confirm-ok')));
    await tester.pumpAndSettle();
    expect(
      text(tester, 'move-mu-error'),
      appL10n.celautMoveRefused('the node did not move the credit: The instance does not have that balance'),
    );
    // The sheet stays, and the user can try again.
    expect(ok(tester).onPressed, isNotNull);
  });

  testWidgets('a balance that the app could not read: nothing moves', (tester) async {
    await pumpSheet(tester, takeBack: true, balance: null);
    expect(find.byKey(const Key('move-mu-no-balance')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('move-mu-amount')), '10');
    await tester.pump();
    expect(ok(tester).onPressed, isNull);
  });

  group('time section', () {
    AutoTopUp engine({bool keep = false}) => AutoTopUp(
          topUp: (id, mu) async => const TopUpView(instanceBalanceMu: '0', clientBalanceMu: '0'),
          instances: () => const [],
          plan: (id) => _plan(keep: keep),
          setKeepAlive: (id, enabled, budget) {},
          periodic: false,
        );

    Future<void> pump(WidgetTester tester, {String balance = '3100', bool unlocks = true, bool keep = false}) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: false),
          home: Scaffold(
            body: SingleChildScrollView(
              child: InstanceTimeSection(
                instanceId: 'i',
                node: 'node.example:8090',
                topUp: engine(keep: keep),
                wallets: _Wallets(unlocks: unlocks),
                loadStatus: (id) async =>
                    InstanceStatusView(instanceBalanceMu: balance, costSoFarMu: '1', streamsOpened: BigInt.zero),
                loadCredit: (id) async => '50000',
                move: move,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Add MU and Take back MU open the sheet; the balances follow the move', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const Key('info-add-mu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('move-mu-sheet-add')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('move-mu-amount')), '1000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('move-mu-ok')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('move-mu-confirm-ok')));
      await tester.pumpAndSettle();
      expect(moves, ['i 1000 add']);
      expect(find.byKey(const Key('move-mu-sheet-add')), findsNothing);
      expect(find.text(appL10n.celautMoveDone('4,100 MU', '49,000 MU')), findsOneWidget);

      await tester.tap(find.byKey(const Key('info-take-back-mu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('move-mu-sheet-back')), findsOneWidget);
    });

    testWidgets('the sheet says when the automatic top-up is on', (tester) async {
      await pump(tester, keep: true);
      await tester.tap(find.byKey(const Key('info-take-back-mu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('move-mu-auto')), findsOneWidget);
    });

    testWidgets('an empty instance has nothing to take back', (tester) async {
      await pump(tester, balance: '0');
      expect(
        tester.widget<ButtonStyleButton>(find.byKey(const Key('info-take-back-mu'))).onPressed,
        isNull,
      );
    });

    testWidgets('a locked wallet moves nothing', (tester) async {
      await pump(tester, unlocks: false);
      await tester.tap(find.byKey(const Key('info-add-mu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('move-mu-sheet-add')), findsNothing);
      expect(find.text(appL10n.celautOpenFullWalletNeeded), findsOneWidget);
      expect(moves, isEmpty);
    });
  });
}
