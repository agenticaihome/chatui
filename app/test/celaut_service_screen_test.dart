import 'dart:io';
import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_env.dart';
import 'package:argus_wallet/bridge/api/celaut_catalog.dart';
import 'package:argus_wallet/bridge/api/celaut_health.dart';
import 'package:argus_wallet/bridge/api/celaut_home.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/bridge/frb_generated.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/celaut/service_strings.dart';
import 'package:argus_wallet/celaut/tunnel_http.dart';
import 'package:argus_wallet/ui/celaut/service_screen.dart';
import 'package:argus_wallet/ui/settings_screen.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _service = '9b0e4e45d3b078451984895891402a24b24a7f4112522592d7b3e2326aecb4c4';
final _cheap = 'aa' * 32;
final _dear = 'bb' * 32;

QuoteView _quote(String peer, int port, String cost, String? compared) => QuoteView(
  address: NodeAddress(host: '127.0.0.1', port: port),
  peerId: peer,
  costMu: cost,
  initMaintenanceMu: '11990',
  maxMaintenanceMu: '11990',
  maintenanceSecondsLoop: 10,
  variance: 0,
  comparedNanoErg: compared,
  clientBalanceMu: '',
);

class ServiceApi extends RustLibApi {
  final quoteCalls = <({List<NodeAddress> nodes, String service, String? initial})>[];
  final startCalls = <({NodeAddress node, String service, String? initial})>[];
  final stops = <String>[];
  int tunnelPort = 0;
  var chatSlots = <int>[3030];
  var knownNodes = <KnownNodeView>[];
  final failStartOn = <int>{};
  Object? quoteAnswer;
  var instances = <InstanceListView>[];

  @override
  List<InstanceListView> crateApiCelautServiceCelautInstances() => instances;

  @override
  List<KnownNodeView> crateApiCelautHomeCelautKnownNodes() => knownNodes;

  @override
  List<NodeHealthView> crateApiCelautHealthCelautNodesHealth() => const [];

  @override
  Future<QuotesView> crateApiCelautServiceCelautQuoteService({
    required List<NodeAddress> nodes,
    required String serviceIdHex,
    String? initialMu,
  }) async {
    quoteCalls.add((nodes: nodes, service: serviceIdHex, initial: initialMu));
    final a = quoteAnswer;
    if (a is CelautError) throw a;
    return a! as QuotesView;
  }

  @override
  Future<InstanceView> crateApiCelautServiceCelautStartService({
    required NodeAddress node,
    required String serviceIdHex,
    String? initialMu,
    required List<EnvChoice> environment,
  }) async {
    startCalls.add((node: node, service: serviceIdHex, initial: initialMu));
    if (failStartOn.contains(node.port)) {
      throw const CelautError(kind: CelautErrorKind.unreachable, message: 'node down');
    }
    return InstanceView(
      instanceId: 'inst-1',
      peerId: _cheap,
      slots: Uint16List.fromList([3030]),
      chatSlots: Uint16List.fromList(chatSlots),
      webSlots: Uint16List(0),
      clientBalanceMu: '3500000',
    );
  }

  @override
  Future<int> crateApiCelautServiceCelautOpenTunnel({
    required String instanceId,
    required int slot,
  }) async => tunnelPort;

  @override
  Future<InstanceStatusView> crateApiCelautServiceCelautInstanceStatus({
    required String instanceId,
  }) async => InstanceStatusView(
    instanceBalanceMu: '976400',
    costSoFarMu: '23600',
    streamsOpened: BigInt.one,
    lastTunnelError: null,
  );

  @override
  Future<StopView> crateApiCelautServiceCelautStopService({required String instanceId}) async {
    stops.add(instanceId);
    return StopView(refundMu: '976399', clientBalanceMu: '4476399');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final api = ServiceApi();
  setUpAll(() => RustLib.initMock(api: api));
  setUp(() {
    api.quoteCalls.clear();
    api.startCalls.clear();
    api.stops.clear();
    api.instances = [];
    api.knownNodes = [];
    api.failStartOn.clear();
    api.quoteAnswer = QuotesView(
      quotes: [_quote(_cheap, 18460, '1000000', '5316400'), _quote(_dear, 18461, '9000000', null)],
      failures: [
        QuoteFailureView(
          address: const NodeAddress(host: 'down.example', port: 9000),
          kind: CelautErrorKind.unreachable,
          message: 'connection refused',
        ),
      ],
    );
  });

  Future<_Wallets> pump(
    WidgetTester tester, {
    TunnelHttp? http,
    bool fullWallet = true,
    bool open = true,
    bool consent = true,
    Future<List<SkillView>> Function()? loadSkills,
    Future<List<SkillServiceView>> Function(String)? loadSkillServices,
  }) async {
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wallets = _Wallets(full: fullWallet, open: open, consent: consent);
    await tester.pumpWidget(
      MaterialApp(
        home: ServiceScreen(
          http: http,
          wallets: wallets,
          loadSkills: loadSkills,
          loadSkillServices: loadSkillServices,
        ),
      ),
    );
    await tester.pump();
    return wallets;
  }

  Future<void> fill(
    WidgetTester tester, {
    String nodes = '127.0.0.1:18460\n127.0.0.1:18461',
  }) async {
    await tester.enterText(find.byKey(const Key('service-nodes')), nodes);
    await tester.enterText(find.byKey(const Key('service-id')), _service.toUpperCase());
  }

  testWidgets('quotes every node, best first, and shows the failures', (tester) async {
    await pump(tester);
    await fill(tester, nodes: '127.0.0.1:18460\n\n[::1]:18461\ndown.example:9000');
    await tester.tap(find.byKey(const Key('service-quote')));
    await tester.pumpAndSettle();

    final call = api.quoteCalls.single;
    expect(call.nodes.map((n) => '${n.host}:${n.port}'), [
      '127.0.0.1:18460',
      '::1:18461',
      'down.example:9000',
    ]);
    expect(call.service, _service);
    expect(call.initial, ServiceStrings.initialDefault);
    final cheap = tester.getTopLeft(find.byKey(Key('service-quote-$_cheap')));
    final dear = tester.getTopLeft(find.byKey(Key('service-quote-$_dear')));
    expect(cheap.dy, lessThan(dear.dy));
    expect(find.text(ServiceStrings.cost('1,000,000 MU')), findsOneWidget);
    expect(find.text(ServiceStrings.compared('5316400')), findsOneWidget);
    expect(find.text(ServiceStrings.compared(null)), findsOneWidget);
    expect(find.text(ServiceStrings.failuresTitle.toUpperCase()), findsOneWidget);
    expect(find.text('Detail: connection refused'), findsOneWidget);
  });

  testWidgets('bad input is shown at the fields and no node is called', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('service-quote')));
    await tester.pumpAndSettle();
    expect(find.text(ServiceStrings.nodesEmpty), findsOneWidget);
    expect(find.text(ServiceStrings.serviceInvalid), findsOneWidget);

    await tester.enterText(find.byKey(const Key('service-nodes')), 'node.example');
    await tester.enterText(find.byKey(const Key('service-id')), _service);
    await tester.enterText(find.byKey(const Key('service-initial')), '1.5');
    await tester.tap(find.byKey(const Key('service-quote')));
    await tester.pumpAndSettle();
    expect(find.text(ServiceStrings.nodeInvalid('node.example')), findsOneWidget);
    expect(find.text(ServiceStrings.initialInvalid), findsOneWidget);
    expect(api.quoteCalls, isEmpty);
  });

  testWidgets('an empty start balance asks for the default of the node', (tester) async {
    await pump(tester);
    await fill(tester);
    await tester.enterText(find.byKey(const Key('service-initial')), '');
    await tester.tap(find.byKey(const Key('service-quote')));
    await tester.pumpAndSettle();
    expect(api.quoteCalls.single.initial, isNull);
  });

  testWidgets('start, call through the local port, and stop', (tester) async {
    // The local port of the tunnel: here a local HTTP server that counts connections.
    final connections = <int>{};
    final server = (await tester.runAsync(() => HttpServer.bind(InternetAddress.loopbackIPv4, 0)))!;
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      connections.add(request.connectionInfo!.remotePort);
      request.response.write('bold-pasteur');
      await request.response.close();
    });
    api.tunnelPort = server.port;
    // testWidgets answers every HttpClient with 400: this one must reach the socket.
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    final http = TunnelHttp();
    HttpOverrides.global = saved;
    addTearDown(http.close);

    await pump(tester, http: http);
    await fill(tester);
    await tester.tap(find.byKey(const Key('service-quote')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('service-start-$_cheap')));
    await tester.pumpAndSettle();

    final start = api.startCalls.single;
    expect(start.node, const NodeAddress(host: '127.0.0.1', port: 18460));
    expect(start.service, _service);
    // The quote (build plus balance) is what the start sends.
    expect(start.initial, '1000000');
    expect(find.byKey(const Key('service-instance')), findsOneWidget);
    expect(find.text(ServiceStrings.clientBalance('3,500,000 MU')), findsOneWidget);
    // One instance at a time: the start buttons are off.
    expect(
      tester.widget<OutlinedButton>(find.byKey(Key('service-start-$_dear'))).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('service-open-3030')));
    await tester.pumpAndSettle();
    expect(find.text(ServiceStrings.localPort(server.port)), findsOneWidget);
    expect(find.byKey(const Key('service-chat-3030')), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('service-call-3030')));
        // Let the real socket answer.
        for (var j = 0; j < 50 && find.byKey(const Key('service-answer')).evaluate().isEmpty; j++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
    }
    expect(find.text('HTTP 200\nbold-pasteur'), findsOneWidget);
    expect(connections, hasLength(1), reason: 'the calls must share one connection');
    expect(find.text(ServiceStrings.instanceBalance('976,400 MU')), findsOneWidget);
    expect(find.text(ServiceStrings.costSoFar('23,600 MU')), findsOneWidget);
    expect(find.text(ServiceStrings.streams(BigInt.one)), findsOneWidget);

    await tester.tap(find.byKey(const Key('service-stop')));
    await tester.pumpAndSettle();
    expect(api.stops, ['inst-1']);
    expect(find.text(ServiceStrings.stopped('976,399 MU', '4,476,399 MU')), findsOneWidget);
    expect(find.byKey(const Key('service-instance')), findsNothing);
  });

  testWidgets('launch starts the service on the best quote, with no choice by the user', (tester) async {
    await pump(tester);
    await fill(tester);
    await tester.tap(find.byKey(const Key('service-launch')));
    await tester.pumpAndSettle();

    expect(api.quoteCalls.single.nodes, hasLength(2));
    final start = api.startCalls.single;
    expect(start.node, const NodeAddress(host: '127.0.0.1', port: 18460));
    expect(find.byKey(const Key('service-launched')), findsOneWidget);
    expect(find.text(ServiceStrings.launched('127.0.0.1:18460', '1,000,000 MU')), findsOneWidget);
    expect(find.byKey(const Key('service-instance')), findsOneWidget);
    expect(find.byKey(const Key('service-launch-failed')), findsNothing);
  });

  testWidgets('launch with no typed nodes asks the known nodes', (tester) async {
    api.knownNodes = [
      KnownNodeView(
        peerId: _cheap,
        addresses: ['127.0.0.1:18460', 'old.example:1'],
        depositedNanoErg: BigInt.zero,
        trusted: false, priority: 50, setPriority: 50,
      ),
    ];
    await pump(tester);
    await fill(tester, nodes: '');
    await tester.tap(find.byKey(const Key('service-launch')));
    await tester.pumpAndSettle();

    expect(api.quoteCalls.single.nodes, [const NodeAddress(host: '127.0.0.1', port: 18460)]);
    expect(api.startCalls, hasLength(1));
    expect(find.byKey(const Key('service-launched')), findsOneWidget);
  });

  testWidgets('launch with no typed and no known nodes asks nothing', (tester) async {
    await pump(tester);
    await fill(tester, nodes: '');
    await tester.tap(find.byKey(const Key('service-launch')));
    await tester.pumpAndSettle();

    expect(find.text(ServiceStrings.nodesEmpty), findsOneWidget);
    expect(api.quoteCalls, isEmpty);
    expect(api.startCalls, isEmpty);
  });

  testWidgets('launch skips a better node that fails and uses the next one', (tester) async {
    api.failStartOn.add(18460);
    await pump(tester);
    await fill(tester);
    await tester.tap(find.byKey(const Key('service-launch')));
    await tester.pumpAndSettle();

    expect(api.startCalls.map((c) => c.node.port), [18460, 18461]);
    expect(find.text(ServiceStrings.launched('127.0.0.1:18461', '9,000,000 MU')), findsOneWidget);
    expect(find.text(ServiceStrings.skippedTitle), findsOneWidget);
    expect(find.byKey(const Key('service-instance')), findsOneWidget);
  });

  testWidgets('launch shows why nothing started when every node fails', (tester) async {
    api.failStartOn.addAll([18460, 18461]);
    await pump(tester);
    await fill(tester);
    await tester.tap(find.byKey(const Key('service-launch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('service-launch-failed')), findsOneWidget);
    expect(find.text(ServiceStrings.launchAllFailed), findsOneWidget);
    expect(find.byKey(const Key('service-instance')), findsNothing);
  });

  testWidgets('launch is off with no full wallet and while an instance runs', (tester) async {
    await pump(tester, fullWallet: false);
    expect(tester.widget<FilledButton>(find.byKey(const Key('service-launch'))).onPressed, isNull);
  });

  testWidgets('a picked skill fills the service id, and launch uses it', (tester) async {
    final picked = 'ab' * 32;
    await pump(
      tester,
      loadSkills: () async => [
        const SkillView(boxId: 'skill-1', name: 'A skill', prose: 'Does a thing.', tags: []),
      ],
      loadSkillServices: (id) async => [
        SkillServiceView(serviceId: picked, score: 0.9, direct: true),
        SkillServiceView(serviceId: 'cd' * 32, score: 0.4, direct: false),
      ],
    );
    // A wrong id in the field gets an error at first.
    await tester.enterText(find.byKey(const Key('service-id')), 'not an id');
    await tester.enterText(find.byKey(const Key('service-nodes')), '127.0.0.1:18460');
    await tester.tap(find.byKey(const Key('service-launch')));
    await tester.pumpAndSettle();
    expect(find.text(ServiceStrings.serviceInvalid), findsOneWidget);

    await tester.tap(find.byKey(const Key('service-pick-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker-skill-skill-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker-use')));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byKey(const Key('service-id'))).controller!.text, picked);
    expect(find.text(ServiceStrings.serviceInvalid), findsNothing);
    await tester.tap(find.byKey(const Key('service-launch')));
    await tester.pumpAndSettle();
    expect(api.startCalls.single.service, picked);
  });

  testWidgets('going back from the picker leaves the service id as it was', (tester) async {
    await pump(
      tester,
      loadSkills: () async => const [],
      loadSkillServices: (_) async => const [],
    );
    await tester.enterText(find.byKey(const Key('service-id')), 'ab' * 32);
    await tester.tap(find.byKey(const Key('service-pick-skill')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-id')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('service-id'))).controller!.text, 'ab' * 32);
  });

  testWidgets('the chat button is only on a slot that follows the chat convention', (tester) async {
    api.tunnelPort = 1;
    api.chatSlots = [];
    await pump(tester);
    await fill(tester);
    await tester.tap(find.byKey(const Key('service-quote')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('service-start-$_cheap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('service-open-3030')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-call-3030')), findsOneWidget);
    expect(find.byKey(const Key('service-chat-3030')), findsNothing);
  });

  testWidgets('with no full wallet, start and stop are off with the same message', (tester) async {
    api.instances = [
      InstanceListView(
        instanceId: 'old-1',
        peerId: _cheap,
        address: '127.0.0.1:18460',
        serviceId: _service,
        slots: Uint16List.fromList([3030]),
        chatSlots: Uint16List(0),
        webSlots: Uint16List(0),
        startedAt: 1,
        startChargeMu: '',
        refundMu: '',
        name: '',
        alias: '',
        title: '',
      ),
    ];
    await pump(tester, fullWallet: false);
    expect(find.byKey(const Key('service-no-full-wallet')), findsOneWidget);
    expect(find.text(appL10n.celautNoFullWallet), findsOneWidget);
    // Quotes are read only: they still work.
    await fill(tester);
    await tester.tap(find.byKey(const Key('service-quote')));
    await tester.pumpAndSettle();
    expect(api.quoteCalls, hasLength(1));
    expect(
      tester.widget<OutlinedButton>(find.byKey(Key('service-start-$_cheap'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('service-app-stop-old-1'))).onPressed,
      isNull,
    );
    expect(api.startCalls, isEmpty);
    expect(api.stops, isEmpty);
  });

  testWidgets('start and stop need an open full wallet: the app asks to open one', (
    tester,
  ) async {
    api.instances = [
      InstanceListView(
        instanceId: 'old-1',
        peerId: _cheap,
        address: '127.0.0.1:18460',
        serviceId: _service,
        slots: Uint16List.fromList([3030]),
        chatSlots: Uint16List(0),
        webSlots: Uint16List(0),
        startedAt: 1,
        startChargeMu: '1000000',
        refundMu: '',
        name: '',
        alias: '',
        title: '',
      ),
    ];
    // The full wallet is locked and the user does not give the PIN: nothing stops.
    final refused = await pump(tester, open: false, consent: false);
    expect(find.byKey(const Key('service-wallet-locked')), findsOneWidget);
    expect(find.text(appL10n.celautOpenFullWalletNeeded), findsOneWidget);
    await tester.tap(find.byKey(const Key('service-app-stop-old-1')));
    await tester.pumpAndSettle();
    expect(refused.unlocked, ['w1']);
    expect(api.stops, isEmpty);
    await fill(tester);
    await tester.tap(find.byKey(const Key('service-quote')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('service-start-$_cheap')));
    await tester.pumpAndSettle();
    expect(refused.unlocked, ['w1', 'w1']);
    expect(api.startCalls, isEmpty);
  });

  testWidgets('a locked full wallet opens with its PIN, then the stop runs', (tester) async {
    api.instances = [
      InstanceListView(
        instanceId: 'old-1',
        peerId: _cheap,
        address: '127.0.0.1:18460',
        serviceId: _service,
        slots: Uint16List.fromList([3030]),
        chatSlots: Uint16List(0),
        webSlots: Uint16List(0),
        startedAt: 1,
        startChargeMu: '1000000',
        refundMu: '',
        name: '',
        alias: '',
        title: '',
      ),
    ];
    final wallets = await pump(tester, open: false);
    await tester.tap(find.byKey(const Key('service-app-stop-old-1')));
    await tester.pumpAndSettle();
    expect(wallets.unlocked, ['w1']);
    expect(api.stops, ['old-1']);
    // The wallet is open now: the message is gone.
    expect(find.byKey(const Key('service-wallet-locked')), findsNothing);
  });

  testWidgets('an instance of an earlier run is listed and can be stopped', (tester) async {
    api.instances = [
      InstanceListView(
        instanceId: 'old-1',
        peerId: _cheap,
        address: '127.0.0.1:18460',
        serviceId: _service,
        slots: Uint16List.fromList([3030]),
        chatSlots: Uint16List(0),
        webSlots: Uint16List(0),
        startedAt: 1,
        startChargeMu: '1000000',
        refundMu: '',
        name: '',
        alias: '',
        title: '',
      ),
    ];
    await pump(tester);
    expect(find.byKey(const Key('service-no-full-wallet')), findsNothing);
    expect(find.byKey(const Key('service-app-instance-old-1')), findsOneWidget);
    api.instances = [];
    await tester.tap(find.byKey(const Key('service-app-stop-old-1')));
    await tester.pumpAndSettle();
    expect(api.stops, ['old-1']);
    expect(find.byKey(const Key('service-app-instance-old-1')), findsNothing);
    expect(find.text(ServiceStrings.stopped('976,399 MU', '4,476,399 MU')), findsOneWidget);
  });

  testWidgets('an error of the call is shown in plain English', (tester) async {
    api.quoteAnswer = CelautError(kind: CelautErrorKind.invalidInput, message: 'bad id');
    await pump(tester);
    await fill(tester);
    await tester.tap(find.byKey(const Key('service-quote')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-error')), findsOneWidget);
    expect(find.text('Detail: bad id'), findsOneWidget);
  });

  testWidgets('Settings has a Compute row that opens the screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('com.argus.wallet/secure_storage');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'listWalletIds' ? <String>[] : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ServiceStrings.rowTitle));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-quote')), findsOneWidget);
  });
}

class _Wallets implements FullWallets {
  _Wallets({required this.full, required this.open, required this.consent});

  final bool full;
  bool open;
  final bool consent;
  final unlocked = <String>[];

  @override
  Future<List<PayerWallet>> payers() async => full
      ? [PayerWallet(walletId: 'w1', name: 'Main', balanceNano: 1, open: open)]
      : const [];

  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async {
    unlocked.add(wallet.walletId);
    if (consent) open = true;
    return consent;
  }
}
