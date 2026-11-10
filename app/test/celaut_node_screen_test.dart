import 'dart:async';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/frb_generated.dart';
import 'package:argus_wallet/celaut/celaut_strings.dart';
import 'package:argus_wallet/ui/celaut/node_connect_screen.dart';
import 'package:argus_wallet/ui/settings_screen.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _peerId = 'ea4a6c63e29c520abef5507b132ec5f9954776aebebe7b92421eea691446d22c';

final _info = PeerInfoView(
  peerId: _peerId,
  ts: 1790000123,
  uris: [
    NodeUriView(
      ip: '203.0.113.7',
      port: 8090,
      expiryUnixTimestamp: 1790000600,
      transport: 'tcp',
      protocols: ['tls', 'http2', 'grpc', 'bee-rpc', 'celaut-gateway'],
    ),
    NodeUriView(
      ip: '2001:db8::7',
      port: 9000,
      expiryUnixTimestamp: 0,
      transport: 'tcp',
      protocols: [],
    ),
  ],
  rates: [
    KeyValueView(key: 'net_mu_per_gib', value: '2000000'),
    KeyValueView(key: 'tunnel_open_mu', value: '10000'),
  ],
  paymentContracts: [
    PaymentContractView(
      ledger: 'ergo, erg',
      muPerUnit: '1',
      details: [
        KeyValueView(key: 'script', value: '0008cd02abab'),
        KeyValueView(key: 'token_id', value: 'ERG'),
      ],
    ),
  ],
  resources: [
    NodeResourcesView(
      architecture: 'linux/amd64',
      cpuCores: 4,
      memLimitBytes: 8 * 1024 * 1024 * 1024,
      diskSpaceBytes: 125254500352,
      benchmark: [KeyValueView(key: 'int_ops_per_sec', value: '123456789')],
    ),
  ],
  reputationProofs: 2,
);

class NodeApi extends RustLibApi {
  final calls = <({String host, int port, String? expected})>[];
  Object? answer;

  /// When set, the call waits for it.
  Completer<void>? gate;

  @override
  Future<PeerInfoView> crateApiCelautCelautPeerInfo({
    required String host,
    required int port,
    String? expectedPeerId,
    String? storePath,
  }) async {
    calls.add((host: host, port: port, expected: expectedPeerId));
    await gate?.future;
    final a = answer;
    if (a is CelautError) throw a;
    return a! as PeerInfoView;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final api = NodeApi();
  setUpAll(() => RustLib.initMock(api: api));
  setUp(() {
    api.calls.clear();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(WidgetTester tester, {NodeConnectScreen screen = const NodeConnectScreen()}) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
  }

  /// The architectures and the benchmark are in a closed part.
  Future<void> openDetails(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('celaut-resources-details')));
    await tester.pumpAndSettle();
  }

  Future<void> connect(WidgetTester tester, String address, {String expected = ''}) async {
    await tester.enterText(find.byKey(const Key('celaut-address')), address);
    if (expected.isNotEmpty) {
      await tester.enterText(find.byKey(const Key('celaut-expected')), expected);
    }
    await tester.tap(find.byKey(const Key('celaut-connect')));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the peer id and the advertisement', (tester) async {
    api.answer = _info;
    await pump(tester);
    await connect(tester, 'node.example:8090');

    expect(api.calls.single, (host: 'node.example', port: 8090, expected: null));
    // The peer id in short form; the full id when the user asks for it.
    expect(tester.widget<Text>(find.byKey(const Key('celaut-peer-id-value'))).data, 'ea4a6c…d22c');
    expect(find.text(_peerId), findsNothing);
    await tester.tap(find.byKey(const Key('celaut-peer-id-full')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('celaut-peer-id-value'))).data, _peerId);
    expect(find.text('2026-09-21 14:15 UTC'), findsOneWidget); // ts 1790000123
    // Addresses.
    expect(find.text('203.0.113.7:8090'), findsOneWidget);
    expect(find.text('tcp · tls · http2 · grpc · bee-rpc · celaut-gateway'), findsOneWidget);
    expect(find.text('[2001:db8::7]:9000'), findsOneWidget);
    expect(find.text('no expiry given'), findsOneWidget);
    // Rates.
    expect(find.text('net_mu_per_gib'), findsOneWidget);
    expect(find.text('2000000'), findsOneWidget);
    expect(find.text('tunnel_open_mu'), findsOneWidget);
    // Payment contract.
    expect(find.text('ergo, erg'), findsOneWidget);
    expect(find.text('1 MU per base unit'), findsOneWidget);
    expect(find.text('script: 0008cd02abab'), findsOneWidget);
    expect(find.text('token_id: ERG'), findsOneWidget);
    // Resources: one summary line; the architectures and the benchmark behind "Details".
    expect(
      tester.widget<Text>(find.byKey(const Key('celaut-resources-summary'))).data,
      'CPU 4 cores · Memory 8.0 GiB · Disk 117 GiB',
    );
    expect(find.text('linux/amd64'), findsNothing);
    await openDetails(tester);
    expect(find.text('linux/amd64'), findsOneWidget);
    expect(find.text('CPU: 4 cores'), findsOneWidget);
    expect(find.text('Memory: 8.0 GiB'), findsOneWidget);
    expect(find.text('Disk: 117 GiB'), findsOneWidget);
    expect(find.text('Benchmark int_ops_per_sec: 123456789'), findsOneWidget);
    expect(find.byKey(const Key('celaut-error')), findsNothing);
  });

  testWidgets('sends the expected peer id, in lowercase', (tester) async {
    api.answer = _info;
    await pump(tester);
    await connect(tester, '[::1]:8090', expected: _peerId.toUpperCase());
    expect(api.calls.single, (host: '::1', port: 8090, expected: _peerId));
  });

  testWidgets('says what is empty in the advertisement', (tester) async {
    api.answer = PeerInfoView(
      peerId: _peerId,
      ts: 1,
      uris: [],
      rates: [],
      paymentContracts: [],
      resources: [],
      reputationProofs: 0,
    );
    await pump(tester);
    await connect(tester, 'node.example:9000');
    expect(find.text(CelautStrings.noUris), findsOneWidget);
    expect(find.text(CelautStrings.noRates), findsOneWidget);
    expect(find.text(CelautStrings.noContracts), findsOneWidget);
    expect(find.text(CelautStrings.noResources), findsOneWidget);
  });

  testWidgets('a value that the node does not give is unknown, not 0 or left out', (tester) async {
    api.answer = PeerInfoView(
      peerId: _peerId,
      ts: 1,
      uris: [],
      rates: [const KeyValueView(key: 'net_mu_per_gib', value: '')],
      paymentContracts: [],
      resources: [
        NodeResourcesView(
          architecture: 'linux/arm64',
          cpuCores: 2,
          benchmark: [const KeyValueView(key: 'int_ops_per_sec', value: '')],
        ),
      ],
      reputationProofs: 0,
    );
    await pump(tester);
    await connect(tester, 'node.example:9000');
    final unknown = appL10n.celautUnknown;
    // The summary says unknown, never 0.
    expect(
      tester.widget<Text>(find.byKey(const Key('celaut-resources-summary'))).data,
      '${CelautStrings.cpuLabel} ${CelautStrings.cores(2)} · ${CelautStrings.memoryLabel} $unknown · '
      '${CelautStrings.diskLabel} $unknown',
    );
    await openDetails(tester);
    expect(find.text('${CelautStrings.cpuLabel}: ${CelautStrings.cores(2)}'), findsOneWidget);
    expect(find.text('${CelautStrings.memoryLabel}: $unknown'), findsOneWidget);
    expect(find.text('${CelautStrings.diskLabel}: $unknown'), findsOneWidget);
    expect(find.text('${CelautStrings.benchmarkLabel} int_ops_per_sec: $unknown'), findsOneWidget);
    expect(find.text(unknown), findsOneWidget); // the rate
  });

  group('the client id (#123)', () {
    const client = '0123456789abcdef0123456789abcdef';

    testWidgets('shows in short form, with Copy and "Show full id"', (tester) async {
      api.answer = _info;
      final asked = <String>[];
      await pump(tester, screen: NodeConnectScreen(clientIdOf: (peer) {
        asked.add(peer);
        return client;
      }));
      await connect(tester, 'node.example:8090');
      expect(asked, [_peerId]);
      final value = find.byKey(const Key('celaut-client-id-value'));
      expect(tester.widget<Text>(value).data, '012345…cdef');
      expect(find.text(client), findsNothing);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.tap(find.byKey(const Key('celaut-client-id-copy')));
      await tester.pump();
      expect(copied, client);
      await tester.tap(find.byKey(const Key('celaut-client-id-full')));
      await tester.pump();
      expect(tester.widget<Text>(value).data, client);
    });

    testWidgets('with no client yet it says so, not an empty value', (tester) async {
      api.answer = _info;
      await pump(tester, screen: NodeConnectScreen(clientIdOf: (_) => null));
      await connect(tester, 'node.example:8090');
      expect(find.byKey(const Key('celaut-client-id')), findsNothing);
      expect(find.text(appL10n.celautClientIdNone), findsOneWidget);
    });

    testWidgets('a node that forgot it: no id, the message and "Make a new client"', (tester) async {
      api.answer = const CelautError(kind: CelautErrorKind.clientUnknown, message: 'requires a client_id');
      await pump(tester, screen: NodeConnectScreen(clientIdOf: (_) => client));
      await connect(tester, 'node.example:8090');
      expect(find.byKey(const Key('celaut-error')), findsOneWidget);
      expect(find.text(CelautStrings.errorText(CelautErrorKind.clientUnknown)), findsOneWidget);
      expect(find.byKey(const Key('celaut-client-unknown')), findsOneWidget);
      expect(find.byKey(const Key('celaut-client-id')), findsNothing);
      expect(find.textContaining('012345'), findsNothing);
    });

    testWidgets('from the node list it connects at once to the node', (tester) async {
      api.answer = _info;
      await pump(tester, screen: NodeConnectScreen(address: 'node.example:8090', expectedPeerId: _peerId, clientIdOf: (_) => client));
      await tester.pumpAndSettle();
      expect(api.calls.single, (host: 'node.example', port: 8090, expected: _peerId));
      expect(find.byKey(const Key('celaut-client-id')), findsOneWidget);
      // No form: it would show the full peer id.
      expect(find.byKey(const Key('celaut-expected')), findsNothing);
      expect(find.text(_peerId), findsNothing);
      expect(find.text('node.example:8090'), findsOneWidget);
      // "Check now" asks the node again.
      await tester.tap(find.byKey(const Key('celaut-connect')));
      await tester.pumpAndSettle();
      expect(api.calls, hasLength(2));
    });
  });

  testWidgets('an out-of-range time from a node does not break the screen', (tester) async {
    api.answer = PeerInfoView(
      peerId: _peerId,
      ts: 9223372036854775807,
      uris: [],
      rates: [],
      paymentContracts: [],
      resources: [],
      reputationProofs: 0,
    );
    await pump(tester);
    await connect(tester, 'node.example:9000');
    expect(find.text('9223372036854775807'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('errors in plain English', () {
    final cases = <CelautErrorKind, String>{
      CelautErrorKind.identityMismatch:
          'The identity of this node is not the one that was expected',
      CelautErrorKind.badCertificate: 'has no valid Celaut identity',
      CelautErrorKind.badSignature: 'The signature of the node advertisement is not valid',
      CelautErrorKind.staleTimestamp: 'older than one that the app accepted before',
      CelautErrorKind.timeout: 'The node did not answer in time',
      CelautErrorKind.unreachable: 'cannot connect to this address',
      CelautErrorKind.unsupportedScheme: 'does not support',
      CelautErrorKind.proofOfWork: 'asks for more work',
      CelautErrorKind.protocol: 'refused the request',
      CelautErrorKind.storage: 'cannot read or write',
      CelautErrorKind.invalidInput: 'address is not valid',
      CelautErrorKind.limitReached: 'would pass the limit',
      CelautErrorKind.wallet: 'The wallet cannot make this transaction',
      CelautErrorKind.clientUnknown: 'does not know the client of this app',
      CelautErrorKind.nodeClosed: 'The node is closed now',
      CelautErrorKind.noRoom: 'not enough free resources',
      CelautErrorKind.serviceMissing: 'does not have this service',
      CelautErrorKind.policyRefused: 'policy of the node',
      CelautErrorKind.unsupportedArchitecture: 'processor architecture',
      CelautErrorKind.rateLimited: 'limits the calls',
      CelautErrorKind.recursionLimit: 'went round or too deep',
      CelautErrorKind.insufficientCredit: 'Your credit on the node',
      CelautErrorKind.launchFailed: 'tried to start the service',
      CelautErrorKind.transferFailed: 'The transfer of the service stopped',
      CelautErrorKind.noDescendants: 'does not support descendants',
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key.name} shows its text and the detail', (tester) async {
        api.answer = CelautError(kind: entry.key, message: 'technical reason ${entry.key.name}');
        await pump(tester);
        await connect(tester, 'node.example:9000');
        expect(find.byKey(const Key('celaut-error')), findsOneWidget);
        expect(find.text(CelautStrings.errorTitle), findsOneWidget);
        expect(find.textContaining(entry.value), findsOneWidget);
        expect(find.text('Detail: technical reason ${entry.key.name}'), findsOneWidget);
        expect(find.byKey(const Key('celaut-peer-id')), findsNothing);
      });
    }

    test('every kind has a text', () {
      for (final kind in CelautErrorKind.values) {
        expect(CelautStrings.errorText(kind), isNotEmpty);
        expect(cases.containsKey(kind), isTrue, reason: '${kind.name} has no test above');
      }
    });
  });

  testWidgets('a new result replaces an old error, and an error replaces a result', (tester) async {
    await pump(tester);
    api.answer = CelautError(kind: CelautErrorKind.timeout, message: 'late');
    await connect(tester, 'node.example:9000');
    expect(find.byKey(const Key('celaut-error')), findsOneWidget);
    api.answer = _info;
    await connect(tester, 'node.example:9000');
    expect(find.byKey(const Key('celaut-error')), findsNothing);
    expect(find.byKey(const Key('celaut-peer-id')), findsOneWidget);
    api.answer = CelautError(kind: CelautErrorKind.badSignature, message: 'x');
    await connect(tester, 'node.example:9000');
    expect(find.byKey(const Key('celaut-peer-id')), findsNothing);
    expect(find.byKey(const Key('celaut-error')), findsOneWidget);
  });

  testWidgets('bad input is shown at the field, and the node is not called', (tester) async {
    api.answer = _info;
    await pump(tester);
    await connect(tester, '');
    expect(find.text(CelautStrings.addressEmpty), findsOneWidget);
    await connect(tester, 'node.example');
    expect(find.text(CelautStrings.addressInvalid), findsOneWidget);
    await connect(tester, 'node.example:99999');
    expect(find.text(CelautStrings.portInvalid), findsOneWidget);
    await connect(tester, 'node.example:80', expected: 'abc');
    expect(find.text(CelautStrings.expectedInvalid), findsOneWidget);
    expect(api.calls, isEmpty);
  });

  testWidgets('the button is off while the call runs', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('celaut-address')), 'node.example:80');
    api.answer = _info;
    final gate = api.gate = Completer<void>();
    addTearDown(() => api.gate = null);
    await tester.tap(find.byKey(const Key('celaut-connect')));
    await tester.pump();
    expect(find.text(CelautStrings.connecting), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('celaut-connect'))).onPressed, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text(CelautStrings.connect), findsOneWidget);
  });

  testWidgets('Settings has a Compute row that opens the screen', (tester) async {
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
    expect(find.text('COMPUTE'), findsOneWidget);
    await tester.tap(find.text(CelautStrings.nodeRowTitle));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('celaut-connect')), findsOneWidget);
  });
}
