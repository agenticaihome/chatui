import 'dart:async';
import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_catalog.dart';
import 'package:argus_wallet/bridge/api/celaut_home.dart';
import 'package:argus_wallet/bridge/api/celaut_package.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/chat_client.dart';
import 'package:argus_wallet/celaut/chat_prefs.dart';
import 'package:argus_wallet/celaut/conversations.dart';
import 'package:argus_wallet/celaut/launcher.dart';
import 'package:argus_wallet/celaut/package_channel.dart';
import 'package:argus_wallet/celaut/package_library.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/celaut/stopped_filter.dart';
import 'package:argus_wallet/celaut/wallet_money.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/home_tabs.dart';
import 'package:argus_wallet/ui/celaut/instance_list.dart';
import 'package:argus_wallet/ui/celaut/run_service_screen.dart';
import 'package:argus_wallet/ui/celaut/run_service_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _echoId = '65' * 32;

InstanceListView _instance(
  String id, {
  String name = 'Echo chat',
  bool chat = true,
  bool web = false,
  int startedAt = 100,
  String address = 'node.example:53460',
  int? stoppedAt,
  String refundMu = '',
}) =>
    InstanceListView(
      instanceId: id,
      peerId: 'aa' * 32,
      address: address,
      serviceId: _echoId,
      slots: Uint16List.fromList([8080]),
      chatSlots: Uint16List.fromList(chat ? [8080] : []),
      cardsSlots: Uint16List(0),
      webSlots: Uint16List.fromList(web ? [3000] : []),
      startedAt: startedAt,
      startChargeMu: '1000',
      name: name,
      alias: '',
      title: '',
      stoppedAt: stoppedAt,
      refundMu: refundMu,
    );

InstanceListView _stopped(InstanceListView i, String refundMu) => InstanceListView(
      instanceId: i.instanceId,
      peerId: i.peerId,
      address: i.address,
      serviceId: i.serviceId,
      slots: i.slots,
      chatSlots: i.chatSlots,
      cardsSlots: i.cardsSlots,
      webSlots: i.webSlots,
      startedAt: i.startedAt,
      startChargeMu: i.startChargeMu,
      name: i.name,
      alias: i.alias,
      title: i.title,
      stoppedAt: 500,
      refundMu: refundMu,
    );

const _noTotal = NanoErgTotalView(total: null, known: '0', unknownNodes: 0, atLeast: false);
const _noBytes = BytesTotalView(total: null, known: 0, unknownNodes: 0, atLeast: false);

ComputeOverviewView _noNodes() => const ComputeOverviewView(
      nodesCounted: 0,
      nodesUnreachable: 0,
      cpuCores: CoresTotalView(total: null, known: 0, unknownNodes: 0, atLeast: false),
      memBytes: _noBytes,
      diskBytes: _noBytes,
      creditNanoErg: _noTotal,
      paidNanoErg: _noTotal,
      freeNanoErg: _noTotal,
      nodes: [],
      instances: [],
    );

InstanceStatusView _status(String cost) =>
    InstanceStatusView(instanceBalanceMu: '900', costSoFarMu: cost, streamsOpened: BigInt.one);

class _Wallets implements FullWallets {
  _Wallets({this.full = true});

  final bool full;

  @override
  Future<List<PayerWallet>> payers() async => full
      ? [const PayerWallet(walletId: 'w1', name: 'Main', balanceNano: 1, open: true)]
      : const [];

  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async => true;
}

/// The database and the nodes, in memory.
class _Node {
  List<InstanceListView> db = [];

  /// The answer of the node for each instance: a status, or an error.
  final Map<String, Object> answers = {};
  final stops = <String>[];
  final forgotten = <String>[];
  final tunnels = <String>[];
  final renamed = <String>[];

  List<InstanceListView> load() => List.of(db);

  /// As `celaut_rename_instance`: the name stays in the database; the node gets nothing.
  void rename(String id, String alias) {
    renamed.add('$id $alias');
    db = [for (final i in db) i.instanceId == id ? withAlias(i, alias) : i];
  }

  Future<InstanceStatusView> status(String id) async {
    final a = answers[id];
    if (a is InstanceStatusView) return a;
    throw a ?? const CelautError(kind: CelautErrorKind.unreachable, message: 'no route');
  }

  /// The node stops the instance: the database keeps it, stopped, with the refund.
  Future<StopView> stop(String id) async {
    final down = answers[id];
    if (down is CelautError) throw down;
    stops.add(id);
    db = [for (final i in db) i.instanceId == id ? _stopped(i, '700') : i];
    return const StopView(refundMu: '700', clientBalanceMu: '5000');
  }

  /// As `celaut_forget_instance`: only a stopped instance leaves the database.
  void forget(String id) {
    final i = db.firstWhere((i) => i.instanceId == id);
    if (i.stoppedAt == null) {
      throw const CelautError(kind: CelautErrorKind.invalidInput, message: 'not stopped');
    }
    forgotten.add(id);
    db.removeWhere((i) => i.instanceId == id);
  }

  Future<int> openTunnel(String id, int slot) async {
    tunnels.add('$id:$slot');
    return 4321;
  }
}

/// The page of a place of a tab, in tests.
class _Place extends StatelessWidget {
  const _Place(this.place);

  final HomePlace place;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(), body: Text('page ${place.name}'));
}

/// The Wallet tab, in tests: a counter shows that the tab keeps its state.
class _WalletTab extends StatefulWidget {
  const _WalletTab(this.deposit);

  final Widget deposit;

  @override
  State<_WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<_WalletTab> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('the wallet')),
        body: ListView(
          children: [
            TextButton(
              key: const Key('wallet-count'),
              onPressed: () => setState(() => _taps++),
              child: Text('taps $_taps'),
            ),
            widget.deposit,
          ],
        ),
      );
}

void main() {
  late _Node node;
  late ConversationNotes notes;
  late List<String> tabs;
  late int computeLoads;
  late List<String> named;
  late List<String> launched;
  // Most tests show the stopped instances; the group "the filter of stopped instances"
  // checks the default, which hides them.
  late StoppedFilter filter;

  setUp(() async {
    // The Settings tab is the settings screen of the app.
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.argus.wallet/secure_storage'),
      (call) async => call.method == 'listWalletIds' ? const <String>[] : null,
    );
    node = _Node();
    notes = ConversationNotes();
    tabs = [];
    computeLoads = 0;
    named = [];
    launched = [];
    filter = StoppedFilter();
    await filter.set(false);
  });

  InstanceList list(GlobalKey<InstanceListState> key, Widget empty, {bool full = true}) =>
      InstanceList(
        key: key,
        chats: true,
        empty: empty,
        wallets: _Wallets(full: full),
        notes: notes,
        load: node.load,
        loadStatus: node.status,
        stop: node.stop,
        forget: node.forget,
        rename: node.rename,
        openTunnel: node.openTunnel,
        filter: filter,
        chatPage: (i, port, starting) => Scaffold(
          appBar: AppBar(),
          body: Text('chat ${i.instanceId} ${i.name} $port ${starting ? 'starting' : 'running'}'),
        ),
      );

  /// The picker of a new conversation, with the catalog and the launch in memory.
  Widget picker(String title, StartedCall onStarted) => RunServiceScreen(
        title: title,
        section: RunServiceSection(
          showTitle: false,
          wallets: _Wallets(),
          onStarted: onStarted,
          nameInstance: (id, name) => named.add('$id $name'),
          loadSkills: () async => const [
            SkillView(boxId: 'skill-echo', name: 'Echo chat', prose: 'Says it back.', tags: [], domain: '', height: 0, serviceIds: const [], publisherReputation: 0),
          ],
          loadServices: (_) async =>
              [SkillServiceView(serviceId: _echoId, score: 0.9, direct: true)],
          previewQuote: (_) async => null,
          library: PackageLibrary(
            importPackage: (path, name, dir) async => throw UnimplementedError(),
            list: () => const <LibraryPackageView>[],
            remove: (_) async {},
            privateDir: () async => '/data',
          ),
          launch: ({required serviceIdHex, initialMu, minSurvival, keepAlive = false, budgetMu, environment}) async {
            launched.add(serviceIdHex);
            final started = _instance('new-1', name: 'Echo chat', startedAt: 999);
            node.db.add(started);
            return LaunchOutcome(
              quote: QuoteView(
                address: const NodeAddress(host: 'node.example', port: 53460),
                peerId: 'aa' * 32,
                costMu: '1000',
                initMaintenanceMu: '1',
                maxMaintenanceMu: '1',
                maintenanceSecondsLoop: 10,
                variance: 0,
                comparedNanoErg: '1',
                clientBalanceMu: '',
              ),
              instance: InstanceView(
                instanceId: 'new-1',
                peerId: 'aa' * 32,
                slots: started.slots,
                chatSlots: started.chatSlots,
                cardsSlots: started.cardsSlots,
                webSlots: started.webSlots,
                clientBalanceMu: '5',
              ),
              skipped: const [],
            );
          },
        ),
      );

  Future<void> open(
    WidgetTester tester, {
    bool full = true,
    bool settle = true,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        // The theme of the app: its buttons ask for the full width, which a row cannot
        // give (the bug of the Run screen). The layout is checked with it.
        theme: argusTheme(watchful: false),
        home: HomeTabs(
          money: const WalletMoney(
            full: WalletSum(count: 1, unknown: 0, knownNano: 1500000000),
            gate: FullWalletGate.open,
          ),
          onTab: (t) => tabs.add(t.name),
          notes: notes,
          wallets: _Wallets(full: full),
          list: (key, empty) => list(key, empty, full: full),
          runPage: picker,
          loadCompute: () async {
            computeLoads++;
            return _noNodes();
          },
          wallet: (context, deposit) => _WalletTab(deposit),
          page: _Place.new,
          importPage: (file) => Scaffold(body: Text('import ${file.name}')),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('a file opened in a file manager opens its import over the chats, from any tab', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('tab-compute')));
    await tester.pumpAndSettle();
    final home = tester.state<HomeTabsState>(find.byType(HomeTabs));
    unawaited(home.importFile(const ChosenFile(uri: 'content://downloads/1', name: 'echo.celaut.bee')));
    await tester.pumpAndSettle();
    expect(find.text('import echo.celaut.bee'), findsOneWidget);
    expect(home.tab, HomeTab.chats);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chats-empty')), findsOneWidget);
  });

  group('the list of conversations', () {
    testWidgets('with no instance it says how to start one, and its button opens the picker', (
      tester,
    ) async {
      await open(tester);
      expect(find.byKey(const Key('chats-empty')), findsOneWidget);
      expect(find.text(appL10n.chatsEmptyTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('chats-empty-new')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.chatsNewTitle), findsOneWidget);
      expect(find.byKey(const Key('run-skill-skill-echo')), findsOneWidget);
    });

    testWidgets('a row has the robot, the name, the cost, the preview, the state and the node', (
      tester,
    ) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('2500');
      notes.saw('i1', const [ChatMessage(seq: 1, role: 'assistant', text: 'two')]);
      await open(tester);
      expect(find.byKey(const Key('chats-row-i1')), findsOneWidget);
      expect(find.byKey(const Key('robot-i1')), findsOneWidget);
      expect(find.text('Echo chat'), findsOneWidget);
      expect(find.text('2,500 MU'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('chats-state-i1'))).data,
        '${appL10n.chatsStateRunning} · node.example:53460',
      );
    });

    testWidgets('the preview of a message of the user says "You"', (tester) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      notes.saw('i1', const [ChatMessage(seq: 0, role: 'user', text: 'hello')]);
      await open(tester);
      expect(find.text(appL10n.chatsPreviewYou('hello')), findsOneWidget);
    });

    testWidgets('a message with only a file shows the file, in one line', (tester) async {
      node.db = [_instance('i1'), _instance('i2'), _instance('i3')];
      node.answers['i1'] = _status('1');
      notes
        ..saw('i1', const [
          ChatMessage(
            seq: 0,
            role: 'user',
            text: '',
            attachments: [
              ChatAttachment(kind: 'image', mime: 'image/png', size: 3, name: 'dot.png')
            ],
          ),
        ])
        ..saw('i2', const [
          ChatMessage(
            seq: 0,
            role: 'assistant',
            text: ' \n ',
            attachments: [ChatAttachment(kind: 'audio', mime: 'audio/wav', size: 3)],
          ),
        ])
        ..saw('i3', const [ChatMessage(seq: 0, role: 'assistant', text: 'a\n\n  b')]);
      await open(tester);
      final photo = appL10n.chatsPreviewNamed(appL10n.chatsPreviewPhoto, 'dot.png');
      expect(find.text(appL10n.chatsPreviewYou(photo)), findsOneWidget);
      expect(find.text(appL10n.chatsPreviewAudio), findsOneWidget);
      expect(find.text('a b'), findsOneWidget);
    });

    testWidgets('the title of the service shows in the row, after the name of the user', (tester) async {
      node.db = [_instance('i1')];
      await open(tester);
      expect(find.text('Echo chat'), findsOneWidget);
      // The chat kept a title of the service in the database (chat.md, section 6.10).
      node.db = [withTitle(_instance('i1'), 'Trip to Lisbon')];
      notes.titled('i1');
      await tester.pump();
      expect(find.text('Trip to Lisbon'), findsOneWidget);
      expect(find.text('Echo chat'), findsNothing);
      // A name of the user is stronger.
      node.db = [withAlias(withTitle(_instance('i1'), 'Trip to Lisbon'), 'Mine')];
      notes.titled('i1');
      await tester.pump();
      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Trip to Lisbon'), findsNothing);
    });

    testWidgets('without a name the row shows the short service id', (tester) async {
      node.db = [_instance('i1', name: '')];
      await open(tester);
      expect(find.text('65656565…656565'), findsOneWidget);
    });

    testWidgets('the states: running, starting, not answering, stopped; the newest first', (
      tester,
    ) async {
      node.db = [
        _instance('run', startedAt: 5),
        _instance('down', startedAt: 4),
        _instance('new', startedAt: 3),
        _instance('gone', startedAt: 9, stoppedAt: 50, refundMu: '700'),
      ];
      node.answers['run'] = _status('1');
      node.answers['down'] = const CelautError(kind: CelautErrorKind.timeout, message: 'late');
      node.answers['new'] = _status('1');
      notes.markStarting('new');
      await open(tester);
      String state(String id) => tester.widget<Text>(find.byKey(Key('chats-state-$id'))).data!;
      expect(state('run'), startsWith(appL10n.chatsStateRunning));
      expect(state('down'), startsWith(appL10n.chatsStateUnreachable));
      expect(state('new'), startsWith(appL10n.chatsStateStarting));
      expect(state('gone'), startsWith(appL10n.chatsStateStopped));
      // The running ones by start, the newest first; the stopped ones after them.
      final ys = [
        for (final id in ['run', 'down', 'new', 'gone'])
          tester.getTopLeft(find.byKey(Key('chats-row-$id'))).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('a row that the node does not answer for yet says "Checking"', (tester) async {
      final pending = Completer<InstanceStatusView>();
      node.db = [_instance('i1')];
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: false),
          home: Scaffold(
            body: InstanceList(
              chats: true,
              notes: notes,
              load: node.load,
              loadStatus: (_) => pending.future,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('chats-state-i1'))).data,
        startsWith(appL10n.chatsStateChecking),
      );
      pending.complete(_status('1'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('chats-state-i1'))).data,
        startsWith(appL10n.chatsStateRunning),
      );
    });

    testWidgets('an instance with no chat and no web slot is in the list, and a tap says that it has no interface',
        (tester) async {
      node.db = [_instance('plain', chat: false)];
      await open(tester);
      expect(find.byKey(const Key('chats-row-plain')), findsOneWidget);
      expect(find.text(appL10n.chatsNoInterface), findsOneWidget);
      await tester.tap(find.byKey(const Key('chats-row-plain')));
      await tester.pumpAndSettle();
      expect(node.tunnels, isEmpty);
      expect(find.text(appL10n.chatsNoInterface), findsNWidgets(2));
    });

    testWidgets('an instance with a web slot is in the list, and a tap opens a port for the browser',
        (tester) async {
      node.db = [_instance('web1', chat: false, web: true)];
      await open(tester);
      expect(find.text(appL10n.chatsWebPreview), findsOneWidget);
      await tester.tap(find.byKey(const Key('chats-row-web1')));
      await tester.pumpAndSettle();
      // The tunnel is to the web slot, and no conversation opens.
      expect(node.tunnels, ['web1:3000']);
      expect(find.textContaining('chat web1'), findsNothing);
    });

    testWidgets('a tap opens the conversation of a running instance, which reads it again', (
      tester,
    ) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      await open(tester);
      await tester.tap(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      expect(node.tunnels, ['i1:8080']);
      expect(find.text('chat i1 Echo chat 4321 running'), findsOneWidget);
      // Back: the list is there, and the instance is still in it.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-row-i1')), findsOneWidget);
      expect(node.stops, isEmpty);
    });

    testWidgets('the conversation shows at once, with a spinner while the tunnel opens', (
      tester,
    ) async {
      node.db = [_instance('i1', name: 'Echo chat')];
      final tunnel = Completer<int>();
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: false),
          home: Scaffold(
            body: InstanceList(
              chats: true,
              notes: notes,
              load: node.load,
              loadStatus: node.status,
              openTunnel: (_, _) => tunnel.future,
              chatPage: (i, port, s) => Text('chat $port'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-row-i1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('chat-connecting')), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Echo chat')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      tunnel.complete(4321);
      await tester.pump();
      expect(find.byKey(const Key('chat-connecting')), findsNothing);
      expect(find.text('chat 4321'), findsOneWidget);
    });

    testWidgets('back while the tunnel opens goes back to the list', (tester) async {
      node.db = [_instance('i1')];
      final tunnel = Completer<int>();
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: false),
          home: Scaffold(
            body: InstanceList(
              chats: true,
              notes: notes,
              load: node.load,
              loadStatus: node.status,
              openTunnel: (_, _) => tunnel.future,
              chatPage: (i, port, s) => Text('chat $port'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-row-i1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-connecting')), findsNothing);
      expect(find.byKey(const Key('chats-row-i1')), findsOneWidget);
      tunnel.complete(4321);
      await tester.pumpAndSettle();
      expect(find.text('chat 4321'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a tunnel that fails closes the conversation and says why', (tester) async {
      node.db = [_instance('i1')];
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: false),
          home: Scaffold(
            body: InstanceList(
              chats: true,
              notes: notes,
              load: node.load,
              loadStatus: node.status,
              openTunnel: (_, _) async =>
                  throw const CelautError(kind: CelautErrorKind.unreachable, message: 'x'),
              chatPage: (i, port, s) => const Text('chat'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      expect(find.text('chat'), findsNothing);
      expect(find.byKey(const Key('chat-connecting')), findsNothing);
      expect(find.byKey(const Key('chats-row-i1')), findsOneWidget);
      expect(find.text(appL10n.celautErrorUnreachable), findsOneWidget);
    });

    testWidgets('a tap on a stopped instance opens its info page, with the refund and Delete', (
      tester,
    ) async {
      node.db = [_instance('gone', stoppedAt: 50, refundMu: '700')];
      await open(tester);
      await tester.tap(find.byKey(const Key('chats-row-gone')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.chatsInfoTitle), findsOneWidget);
      expect(tester.widget<SelectableText>(find.byKey(const Key('info-refund'))).data, '700 MU');
      expect(find.byKey(const Key('info-stop')), findsNothing);
      expect(node.tunnels, isEmpty);
      // The node is not asked for a stopped instance.
      expect(node.stops, isEmpty);
      await tester.ensureVisible(find.byKey(const Key('info-delete')));
      await tester.tap(find.byKey(const Key('info-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-ok')));
      await tester.pumpAndSettle();
      expect(node.forgotten, ['gone']);
      expect(find.byKey(const Key('chats-row-gone')), findsNothing);
      expect(find.byKey(const Key('chats-empty')), findsOneWidget);
    });

    testWidgets('a stopped instance stays in the list when the list is read again', (tester) async {
      node.db = [_instance('gone', stoppedAt: 50, refundMu: '700')];
      await open(tester);
      await tester.fling(find.byKey(const Key('chats-list')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('chats-state-gone'))).data,
        startsWith(appL10n.chatsStateStopped),
      );
    });
  });

  group('long press', () {
    testWidgets('a running instance: Info and Stop, no Delete', (tester) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      await open(tester);
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-action-info')), findsOneWidget);
      expect(find.byKey(const Key('chats-action-stop')), findsOneWidget);
      expect(find.byKey(const Key('chats-action-delete')), findsNothing);
    });

    testWidgets('Rename keeps a local name, and an empty name shows the name of the start again', (
      tester,
    ) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      await open(tester);
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-rename')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.chatsRenameNoteOriginal('Echo chat')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('rename-field')), '  My   echo ');
      await tester.tap(find.byKey(const Key('rename-ok')));
      await tester.pumpAndSettle();
      expect(node.renamed, ['i1 My echo']);
      expect(tester.widget<Text>(find.byKey(const Key('chats-name-i1'))).data, 'My echo');
      // Only the database has it: no stop, no start, no call to the node.
      expect(node.stops, isEmpty);
      // Cancel changes nothing.
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-rename')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rename-cancel')));
      await tester.pumpAndSettle();
      expect(node.renamed, ['i1 My echo']);
      // Empty: the name of the skill again.
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-rename')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('rename-field')), '');
      await tester.tap(find.byKey(const Key('rename-ok')));
      await tester.pumpAndSettle();
      expect(node.renamed, ['i1 My echo', 'i1 ']);
      expect(tester.widget<Text>(find.byKey(const Key('chats-name-i1'))).data, 'Echo chat');
    });

    testWidgets('Rename with a title of the service: Save with no change keeps no name of the user', (
      tester,
    ) async {
      node.db = [withTitle(_instance('i1'), 'Trip to Lisbon')];
      node.answers['i1'] = _status('1');
      await open(tester);
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-rename')));
      await tester.pumpAndSettle();
      // The field has the title, and empty shows the title again.
      expect(tester.widget<TextField>(find.byKey(const Key('rename-field'))).controller!.text, 'Trip to Lisbon');
      expect(find.text(appL10n.chatsRenameNoteOriginal('Trip to Lisbon')), findsOneWidget);
      await tester.tap(find.byKey(const Key('rename-ok')));
      await tester.pumpAndSettle();
      // No name of the user: a later title of the service can still show.
      expect(node.renamed, isEmpty);
    });

    testWidgets('a stopped instance can be renamed from its info page', (tester) async {
      node.db = [_instance('i1', stoppedAt: 400, refundMu: '700')];
      await open(tester);
      await tester.tap(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('info-rename')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('rename-field')), 'Old echo');
      await tester.tap(find.byKey(const Key('rename-ok')));
      await tester.pumpAndSettle();
      expect(find.text('Old echo'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('chats-name-i1'))).data, 'Old echo');
    });

    testWidgets('Mute silences the chat, and the row shows it', (tester) async {
      addTearDown(() => chatPrefs.setMuted('i1', false));
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      await open(tester);
      expect(find.byKey(const Key('chats-muted-i1')), findsNothing);
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.chatMute), findsOneWidget);
      await tester.tap(find.byKey(const Key('chats-action-mute')));
      await tester.pumpAndSettle();
      expect(chatPrefs.isMuted('i1'), isTrue);
      expect(find.byKey(const Key('chats-muted-i1')), findsOneWidget);
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.chatUnmute), findsOneWidget);
    });

    testWidgets('the info page chooses the background of the chat', (tester) async {
      addTearDown(() => chatPrefs.setBackground('i1', 'none'));
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      await open(tester);
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-info')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('info-background')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('info-background-ocean')));
      await tester.pumpAndSettle();
      expect(chatPrefs.background('i1'), 'ocean');
    });

    testWidgets('Info opens the info page', (tester) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('321');
      await open(tester);
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-info')));
      await tester.pumpAndSettle();
      expect(tester.widget<SelectableText>(find.byKey(const Key('info-cost'))).data, '321 MU');
      expect(tester.widget<SelectableText>(find.byKey(const Key('info-service'))).data, _echoId);
      expect(tester.widget<SelectableText>(find.byKey(const Key('info-instance'))).data, 'i1');
    });

    testWidgets('Stop asks, stops, and the row stays as stopped until the user deletes it', (
      tester,
    ) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      notes.saw('i1', const [ChatMessage(seq: 1, role: 'assistant', text: 'bye')]);
      await open(tester);
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-stop')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stop-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('stop-ok')));
      await tester.pumpAndSettle();
      expect(node.stops, ['i1']);
      expect(
        tester.widget<Text>(find.byKey(const Key('chats-state-i1'))).data,
        startsWith(appL10n.chatsStateStopped),
      );
      expect(find.text('bye'), findsOneWidget);
      expect(node.db.single.stoppedAt, isNotNull);
      // A stopped row: Info and Delete. Delete asks first.
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-action-stop')), findsNothing);
      await tester.tap(find.byKey(const Key('chats-action-delete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-cancel')));
      await tester.pumpAndSettle();
      expect(node.forgotten, isEmpty);
      expect(find.byKey(const Key('chats-row-i1')), findsOneWidget);
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-ok')));
      await tester.pumpAndSettle();
      expect(node.forgotten, ['i1']);
      expect(find.byKey(const Key('chats-row-i1')), findsNothing);
    });

    testWidgets('Stop with no wallet stops nothing and says why', (tester) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      await open(tester, full: false);
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-stop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stop-ok')));
      await tester.pumpAndSettle();
      expect(node.stops, isEmpty);
      expect(find.text(appL10n.celautOpenFullWalletNeeded), findsOneWidget);
    });

    testWidgets('a row whose node does not answer has Info and Stop, and no way to delete it', (
      tester,
    ) async {
      node.db = [_instance('i1')];
      await open(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('chats-state-i1'))).data,
        startsWith(appL10n.chatsStateUnreachable),
      );
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-action-info')), findsOneWidget);
      expect(find.byKey(const Key('chats-action-stop')), findsOneWidget);
      expect(find.byKey(const Key('chats-action-delete')), findsNothing);
      expect(find.text(appL10n.chatsDelete), findsNothing);
      // Stop asks; the node does not answer: the user sees why, and the row stays.
      node.answers['i1'] =
          const CelautError(kind: CelautErrorKind.unreachable, message: 'no route');
      await tester.tap(find.byKey(const Key('chats-action-stop')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stop-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('stop-ok')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(node.stops, isEmpty);
      expect(node.forgotten, isEmpty);
      expect(node.db.single.stoppedAt, isNull);
      expect(
        tester.widget<Text>(find.byKey(const Key('chats-state-i1'))).data,
        startsWith(appL10n.chatsStateUnreachable),
      );
      // The info page has Stop, and no Delete.
      await tester.longPress(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-info')));
      await tester.pumpAndSettle();
      // The page also has Hibernate, so Stop can be below the window: scroll to it.
      await tester.scrollUntilVisible(
        find.byKey(const Key('info-stop')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(const Key('info-stop')), findsOneWidget);
      expect(find.byKey(const Key('info-delete')), findsNothing);
    });
  });

  group('the bottom bar', () {
    Future<void> show(WidgetTester tester, HomeTab tab) async {
      await tester.tap(find.byKey(Key('tab-${tab.name}')));
      await tester.pumpAndSettle();
    }

    testWidgets('each tab shows its page', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('home-tabs')), findsOneWidget);
      expect(find.byKey(const Key('chats-empty')), findsOneWidget);
      await show(tester, HomeTab.wallet);
      expect(find.text('the wallet'), findsOneWidget);
      expect(find.byKey(const Key('place-deposit')), findsOneWidget);
      await show(tester, HomeTab.compute);
      expect(find.byKey(const Key('compute-home-nodes')), findsOneWidget);
      expect(find.byKey(const Key('compute-home-run')), findsNothing);
      expect(find.byKey(const Key('place-otherInstances')), findsNothing);
      expect(find.byKey(const Key('compute-home-settings')), findsNothing);
      await show(tester, HomeTab.settings);
      expect(find.byKey(const Key('settings-tor')), findsOneWidget);
      await show(tester, HomeTab.chats);
      expect(find.byKey(const Key('chats-empty')), findsOneWidget);
      expect(tabs, ['wallet', 'compute', 'settings', 'chats']);
    });

    testWidgets('the pencil button is only on Chats', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('chats-new')), findsOneWidget);
      for (final tab in [HomeTab.wallet, HomeTab.compute, HomeTab.settings]) {
        await show(tester, tab);
        expect(find.byKey(const Key('chats-new')), findsNothing, reason: tab.name);
        expect(find.byType(FloatingActionButton), findsNothing, reason: tab.name);
      }
    });

    // Every page of the drawer of the first chat-first build has a place in a tab.
    for (final (tab, place) in [
      (HomeTab.wallet, HomePlace.deposit),
      (HomeTab.compute, HomePlace.nodes),
      (HomeTab.compute, HomePlace.services),
    ]) {
      testWidgets('${place.name} opens from ${tab.name} over the bar, and back is the tab', (
        tester,
      ) async {
        await open(tester);
        await show(tester, tab);
        await tester.ensureVisible(find.byKey(Key('place-${place.name}')));
        await tester.tap(find.byKey(Key('place-${place.name}')));
        await tester.pumpAndSettle();
        expect(find.text('page ${place.name}'), findsOneWidget);
        expect(find.byKey(const Key('home-tabs')), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byKey(Key('place-${place.name}')), findsOneWidget);
      });
    }

    testWidgets('Settings has the sections Ergo, Compute and General', (tester) async {
      await open(tester);
      await show(tester, HomeTab.settings);
      expect(find.byKey(const Key('settings-tor')), findsOneWidget);
      expect(find.byKey(const Key('settings-nodes')), findsOneWidget);
      // settings-nodes is a row of Compute.
      expect(find.byKey(const Key('settings-section-compute')), findsOneWidget);
      await tester.dragUntilVisible(
        find.byKey(const Key('settings-about')),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.byKey(const Key('settings-about')), findsOneWidget);
    });

    testWidgets('the Wallets line of Compute shows the Wallet tab', (tester) async {
      await open(tester);
      await show(tester, HomeTab.compute);
      await tester.ensureVisible(find.byKey(const Key('compute-home-wallets')));
      await tester.tap(find.byKey(const Key('compute-home-wallets')));
      await tester.pumpAndSettle();
      expect(find.text('the wallet'), findsOneWidget);
    });

    testWidgets('a tab keeps its state while another one shows', (tester) async {
      await open(tester);
      await show(tester, HomeTab.wallet);
      await tester.tap(find.byKey(const Key('wallet-count')));
      await tester.pump();
      expect(find.text('taps 1'), findsOneWidget);
      await show(tester, HomeTab.compute);
      expect(computeLoads, 1);
      await show(tester, HomeTab.chats);
      await show(tester, HomeTab.wallet);
      expect(find.text('taps 1'), findsOneWidget);
      // Compute shows the same page, and asks the nodes again.
      await show(tester, HomeTab.compute);
      expect(computeLoads, 2);
    });

    testWidgets('back on another tab goes to Chats', (tester) async {
      await open(tester);
      await show(tester, HomeTab.compute);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-new')), findsOneWidget);
      expect(tabs.last, 'chats');
    });

    testWidgets('a conversation opens over the bar', (tester) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      await open(tester);
      await tester.tap(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      expect(find.text('chat i1 Echo chat 4321 running'), findsOneWidget);
      expect(find.byKey(const Key('home-tabs')), findsNothing);
    });

    testWidgets('the tabs are in Spanish too', (tester) async {
      setAppLocale(const Locale('es'));
      addTearDown(() => setAppLocale(const Locale('en')));
      await open(tester);
      expect(find.text('Billetera'), findsOneWidget);
      expect(find.text('Cómputo'), findsOneWidget);
      await show(tester, HomeTab.compute);
      await tester.ensureVisible(find.byKey(const Key('place-services')));
      expect(find.text(appL10n.chatsServicesTitle), findsOneWidget);
    });
  });

  group('wide windows', () {
    const phoneOnItsSide = Size(844, 390);
    const tablet = Size(1280, 800);

    testWidgets('a phone on its side has the tabs on a rail, and a conversation over it', (tester) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      await open(tester, size: phoneOnItsSide);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byKey(const Key('tab-compute')));
      await tester.pumpAndSettle();
      expect(tabs, ['compute']);
      await tester.tap(find.byKey(const Key('tab-chats')));
      await tester.pumpAndSettle();
      // Too short for two panes: the conversation takes the whole window.
      expect(find.byKey(const Key('chats-pane-empty')), findsNothing);
      await tester.tap(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      expect(find.text('chat i1 Echo chat 4321 running'), findsOneWidget);
      expect(find.byKey(const Key('home-tabs')), findsNothing);
    });

    testWidgets('a tablet shows the conversation next to the list, and back closes it', (tester) async {
      node.db = [_instance('i1'), _instance('i2', name: 'Other', startedAt: 50)];
      node.answers['i1'] = _status('1');
      node.answers['i2'] = _status('2');
      await open(tester, size: tablet);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byKey(const Key('chats-pane-empty')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      expect(find.text('chat i1 Echo chat 4321 running'), findsOneWidget);
      // The list and the tabs stay in view, the row of the open conversation chosen.
      expect(find.byKey(const Key('home-tabs')), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('chats-row-i1'))).right,
          lessThan(tester.getRect(find.text('chat i1 Echo chat 4321 running')).left));
      final chosen = find.byWidgetPredicate((w) => w is Semantics && w.properties.selected == true);
      expect(find.ancestor(of: find.byKey(const Key('chats-row-i1')), matching: chosen), findsOneWidget);
      // Another row takes the place of the conversation.
      await tester.tap(find.byKey(const Key('chats-row-i2')));
      await tester.pumpAndSettle();
      expect(find.text('chat i1 Echo chat 4321 running'), findsNothing);
      expect(find.text('chat i2 Other 4321 running'), findsOneWidget);
      // Back closes the conversation, not the app.
      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popped, isTrue);
      expect(find.text('chat i2 Other 4321 running'), findsNothing);
      expect(find.byKey(const Key('chats-pane-empty')), findsOneWidget);
      expect(find.byKey(const Key('chats-row-i2')), findsOneWidget);
    });

    testWidgets('back on another tab goes to Chats, and keeps the conversation of the pane', (tester) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      await open(tester, size: tablet);
      await tester.tap(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-compute')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tabs.last, 'chats');
      expect(find.text('chat i1 Echo chat 4321 running'), findsOneWidget);
    });

    testWidgets('a tablet turned upright keeps the open conversation, over the list', (tester) async {
      node.db = [_instance('i1')];
      node.answers['i1'] = _status('1');
      await open(tester, size: tablet);
      await tester.tap(find.byKey(const Key('chats-row-i1')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpAndSettle();
      expect(find.text('chat i1 Echo chat 4321 running'), findsOneWidget);
      expect(find.byKey(const Key('home-tabs')), findsNothing);
      expect(node.tunnels, ['i1:8080', 'i1:8080']);
      // Back is the list.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-row-i1')), findsOneWidget);
    });
  });

  group('new conversation', () {
    Future<void> runEcho(WidgetTester tester, {bool confirm = true}) async {
      await tester.tap(find.byKey(const Key('chats-new')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.chatsNewTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('run-skill-skill-echo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-sheet-run')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('run-confirm')), findsOneWidget);
      await tester.tap(find.byKey(Key(confirm ? 'run-confirm-ok' : 'run-confirm-cancel')));
      await tester.pumpAndSettle();
    }

    testWidgets('the pencil, a skill, the confirmation, then the conversation that starts', (
      tester,
    ) async {
      await open(tester);
      await runEcho(tester);
      expect(launched, [_echoId]);
      expect(named, ['new-1 Echo chat']);
      expect(node.tunnels, ['new-1:8080']);
      expect(find.text('chat new-1 Echo chat 4321 starting'), findsOneWidget);
      expect(notes.isStarting('new-1'), isTrue);
      // Back from the conversation is the list, not the picker, with the new row.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-new')), findsOneWidget);
      expect(find.byKey(const Key('chats-row-new-1')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('chats-state-new-1'))).data,
        startsWith(appL10n.chatsStateStarting),
      );
    });

    testWidgets('Cancel in the confirmation starts nothing', (tester) async {
      await open(tester);
      await runEcho(tester, confirm: false);
      expect(launched, isEmpty);
      expect(node.tunnels, isEmpty);
      expect(find.text(appL10n.chatsNewTitle), findsOneWidget);
    });
  });

  group('instances without a chat slot (InstanceList with chats: false)', () {
    testWidgets('they list the instances without a chat slot, and a tap opens the info',
        (tester) async {
      node.db = [_instance('plain', chat: false, name: 'Solver'), _instance('chat')];
      node.answers['plain'] = _status('5');
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: false),
          home: Scaffold(
            body: InstanceList(
              chats: false,
              notes: notes,
              load: node.load,
              loadStatus: node.status,
              openTunnel: node.openTunnel,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-row-plain')), findsOneWidget);
      expect(find.byKey(const Key('chats-row-chat')), findsNothing);
      expect(find.text(appL10n.chatsNoInterface), findsOneWidget);
      await tester.tap(find.byKey(const Key('chats-row-plain')));
      await tester.pumpAndSettle();
      expect(node.tunnels, isEmpty);
      expect(
        tester.widget<SelectableText>(find.byKey(const Key('info-slot'))).data,
        appL10n.chatsInfoNoChatSlot,
      );
    });
  });

  group('the filter of stopped instances', () {
    setUp(() async {
      // The default of the app: no choice kept yet.
      SharedPreferences.setMockInitialValues({});
      filter = StoppedFilter();
      await filter.load();
    });

    testWidgets('hides the stopped instances by default, and a button shows them', (tester) async {
      expect(filter.value, isTrue);
      node.db = [
        _instance('run', startedAt: 300),
        _instance('old', stoppedAt: 400, refundMu: '700'),
      ];
      node.answers['run'] = _status('1');
      await open(tester);
      expect(find.byKey(const Key('chats-row-run')), findsOneWidget);
      expect(find.byKey(const Key('chats-row-old')), findsNothing);
      expect(find.text(appL10n.chatsShowStopped(1)), findsOneWidget);
      await tester.tap(find.byKey(const Key('chats-show-stopped')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-row-old')), findsOneWidget);
      // The choice is kept for the next start of the app.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StoppedFilter.key), isFalse);
      // A shown stopped instance can be deleted.
      await tester.longPress(find.byKey(const Key('chats-row-old')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-ok')));
      await tester.pumpAndSettle();
      expect(node.forgotten, ['old']);
      expect(find.byKey(const Key('chats-row-old')), findsNothing);
    });

    testWidgets('a stop hides the row, and Hide hides the shown ones again', (tester) async {
      node.db = [_instance('a', startedAt: 300), _instance('b', stoppedAt: 400)];
      node.answers['a'] = _status('1');
      await open(tester);
      await tester.longPress(find.byKey(const Key('chats-row-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chats-action-stop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stop-ok')));
      await tester.pumpAndSettle();
      expect(node.stops, ['a']);
      expect(find.byKey(const Key('chats-row-a')), findsNothing);
      // With no row left, the empty list still offers the stopped ones.
      expect(find.byKey(const Key('chats-empty')), findsOneWidget);
      expect(find.text(appL10n.chatsShowStopped(2)), findsOneWidget);
      await tester.tap(find.byKey(const Key('chats-show-stopped')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-row-a')), findsOneWidget);
      expect(find.byKey(const Key('chats-row-b')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chats-hide-stopped')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-row-a')), findsNothing);
      expect(find.byKey(const Key('chats-row-b')), findsNothing);
    });

    testWidgets('the list of them hides the stopped ones too', (tester) async {
      node.db = [
        _instance('plain', chat: false, startedAt: 300),
        _instance('plain-old', chat: false, stoppedAt: 400),
      ];
      node.answers['plain'] = _status('5');
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: false),
          home: Scaffold(
            body: InstanceList(
              chats: false,
              notes: notes,
              load: node.load,
              loadStatus: node.status,
              filter: filter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-row-plain')), findsOneWidget);
      expect(find.byKey(const Key('chats-row-plain-old')), findsNothing);
      await tester.tap(find.byKey(const Key('chats-show-stopped')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chats-row-plain-old')), findsOneWidget);
    });

    testWidgets('the button is in Spanish too', (tester) async {
      node.db = [_instance('old', stoppedAt: 400)];
      setAppLocale(const Locale('es'));
      addTearDown(() => setAppLocale(const Locale('en')));
      await tester.pumpWidget(
        MaterialApp(
          theme: argusTheme(watchful: false),
          home: Scaffold(
            body: InstanceList(chats: true, notes: notes, load: node.load, filter: filter),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mostrar 1 instancia detenida'), findsOneWidget);
    });
  });
}
