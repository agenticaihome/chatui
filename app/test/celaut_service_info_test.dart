import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_env.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/bridge/api/celaut_service_info.dart';
import 'package:argus_wallet/celaut/celaut_strings.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/instance_info_screen.dart';
import 'package:argus_wallet/ui/celaut/instance_actions.dart';
import 'package:argus_wallet/ui/celaut/service_info_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProtocolView _p(List<String> tags, [String prose = '']) => ProtocolView(tags: tags, prose: prose);

SysresourcesView _res({double? cores, int? mem, int? disk, List<NamedValueView> bench = const []}) =>
    SysresourcesView(
      cpuCores: cores,
      memBytes: mem == null ? null : BigInt.from(mem),
      diskBytes: disk == null ? null : BigInt.from(disk),
      benchmark: bench,
    );

/// A service with every part, and a chat port.
ServiceInfoView _full({ChatSupportView chat = ChatSupportView.supported, bool chatSlot = true}) => ServiceInfoView(
  prose: 'An echo service for the tests',
  architecture: const ['linux/arm64'],
  filesystemBytes: BigInt.from(536 * 1024 * 1024),
  entryPath: const ['usr', 'bin', 'echo'],
  resourcesAtInit: _res(
    cores: 1.5,
    mem: 256 * 1024 * 1024,
    disk: 1024 * 1024 * 1024,
    bench: const [NamedValueView(key: 'int_ops_per_sec', value: '1000000')],
  ),
  resourcesAtMost: _res(mem: 512 * 1024 * 1024),
  configPath: const ['__config__'],
  nodeProtocols: [_p(['grpc'])],
  environment: const [
    DeclaredVariableView(name: 'API_KEY', tags: ['text'], prose: 'The key of the API'),
    DeclaredVariableView(name: 'MODE', tags: ['text'], prose: ''),
  ],
  slots: [
    ApiSlotView(
      port: 8080,
      transport: const ['tcp'],
      protocolStack: [_p(['http2']), _p(['grpc']), _p(['chat'], 'A chat service')],
      muPerCall: const [NamedValueView(key: 'send', value: '5')],
      chat: chatSlot,
    ),
    const ApiSlotView(port: 53, transport: ['udp'], protocolStack: [], muPerCall: [], chat: false),
  ],
  networks: [
    NetworkView(tags: const ['api.example.org'], prose: 'The API', formal: 'pow.chain=ergo', protocolStack: [_p(['https'])]),
    const NetworkView(tags: ['*'], prose: '', formal: '', protocolStack: []),
  ],
  workloads: [WorkloadView(scenario: 0, count: 3, resources: _res(cores: 2), hasDependency: true)],
  workloadsSkipped: 2,
  partsSkipped: 0,
  apiSkipped: false,
  chat: chat,
  chatPort: chat == ChatSupportView.supported ? 8080 : null,
  truncated: false,
);

ServiceInfoView _empty() => ServiceInfoView(
  prose: '',
  architecture: const [],
  filesystemBytes: BigInt.zero,
  entryPath: const [],
  configPath: const [],
  nodeProtocols: const [],
  environment: const [],
  slots: const [],
  networks: const [],
  workloads: const [],
  workloadsSkipped: 0,
  partsSkipped: 0,
  apiSkipped: false,
  chat: ChatSupportView.unsupported,
  truncated: false,
);

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Future<void> _pump(WidgetTester tester, ServiceInfoView info) async {
  tester.view.physicalSize = const Size(390, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(ServiceInfoScreen(serviceIdHex: 'ab' * 32, info: info)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('it shows every part of a service', (tester) async {
    await _pump(tester, _full());
    final l = appL10n;
    expect(find.text('An echo service for the tests'), findsOneWidget);
    expect(find.text('linux/arm64'), findsOneWidget);
    expect(find.text('/usr/bin/echo'), findsOneWidget);
    expect(find.text('/__config__'), findsOneWidget);
    expect(find.text('536 MiB'), findsOneWidget);
    // Resources at the start and at most.
    expect(find.text(l.serviceInfoAtStart), findsOneWidget);
    expect(find.text(l.serviceInfoAtMost), findsOneWidget);
    expect(find.text(CelautStrings.cores(1.5)), findsOneWidget);
    expect(find.text('int_ops_per_sec: 1000000'), findsOneWidget);
    // The interface, with the chat port marked and the stack from bottom to top.
    expect(find.text(l.serviceInfoSlot(1)), findsOneWidget);
    expect(find.byKey(const Key('service-info-chat-8080')), findsOneWidget);
    expect(find.byKey(const Key('service-info-chat-53')), findsNothing);
    expect(find.text('tcp → http2 → grpc → chat'), findsOneWidget);
    expect(find.text('A chat service'), findsOneWidget);
    expect(find.text('${l.serviceInfoPricePerCall}: send = 5'), findsOneWidget);
    // The networks that the service declares.
    expect(find.text('api.example.org'), findsOneWidget);
    expect(find.text('The API'), findsOneWidget);
    expect(find.text('pow.chain=ergo'), findsOneWidget);
    expect(find.text(l.serviceInfoPeersSpeak('https')), findsOneWidget);
    expect(find.text(l.serviceInfoAnyAddress), findsOneWidget);
    // The environment variables.
    expect(find.text('API_KEY'), findsOneWidget);
    expect(find.text('The key of the API'), findsOneWidget);
    expect(find.text('MODE'), findsOneWidget);
    // The rest.
    expect(find.text('grpc'), findsOneWidget);
    expect(find.text('${l.serviceInfoWorkload(3)} · ${l.serviceInfoWorkloadService} · ${CelautStrings.cores(2)}'), findsOneWidget);
    expect(find.text(l.serviceInfoWorkloadsSkipped(2)), findsOneWidget);
  });

  testWidgets('the banner says that the interface works as a conversation', (tester) async {
    await _pump(tester, _full());
    expect(find.text(appL10n.serviceInfoChatSupported), findsOneWidget);
    expect(find.byKey(const Key('service-info-chat-unsupported')), findsNothing);
  });

  testWidgets('an interface that Chatui does not support says so', (tester) async {
    await _pump(tester, _full(chat: ChatSupportView.unsupported, chatSlot: false));
    expect(find.text(appL10n.serviceInfoChatUnsupported), findsOneWidget);
    expect(find.byKey(const Key('service-info-chat-supported')), findsNothing);
    expect(find.byKey(const Key('service-info-chat-8080')), findsNothing);
  });

  testWidgets('a service with nothing says what is missing, in each section', (tester) async {
    await _pump(tester, _empty());
    final l = appL10n;
    expect(find.text(l.serviceInfoNoProse), findsOneWidget);
    expect(find.text(l.serviceInfoNoResources), findsOneWidget);
    expect(find.text(l.serviceInfoNoInterface), findsOneWidget);
    expect(find.text(l.serviceInfoNoNetworks), findsOneWidget);
    expect(find.text(l.serviceInfoNoEnvironment), findsOneWidget);
    expect(find.byKey(const Key('service-info-more')), findsNothing);
  });

  testWidgets('a service that was too large to read shows only what came first, and no "none"', (tester) async {
    final info = ServiceInfoView(
      prose: 'Big',
      architecture: const ['linux/arm64'],
      filesystemBytes: BigInt.zero,
      entryPath: const [],
      configPath: const [],
      nodeProtocols: const [],
      environment: const [],
      slots: const [],
      networks: const [],
      workloads: const [],
      workloadsSkipped: 0,
  partsSkipped: 0,
  apiSkipped: false,
      chat: ChatSupportView.unknown,
      truncated: true,
    );
    await _pump(tester, info);
    final l = appL10n;
    expect(find.text(l.serviceInfoChatUnknown), findsOneWidget);
    expect(find.byKey(const Key('service-info-truncated')), findsOneWidget);
    expect(find.text('Big'), findsOneWidget);
    // What is after the filesystem is unknown: no "declares no variables", no "no port".
    for (final key in ['interface', 'networks', 'environment', 'resources']) {
      expect(find.byKey(Key('service-info-$key')), findsNothing, reason: key);
    }
    expect(find.text(l.serviceInfoNoNetworks), findsNothing);
  });

  testWidgets('an interface that was too large to decode is not shown as "no port"', (tester) async {
    final full = _full(chat: ChatSupportView.unknown, chatSlot: false);
    final info = ServiceInfoView(
      prose: full.prose,
      architecture: full.architecture,
      filesystemBytes: full.filesystemBytes,
      entryPath: full.entryPath,
      configPath: full.configPath,
      nodeProtocols: full.nodeProtocols,
      environment: full.environment,
      slots: const [],
      networks: full.networks,
      workloads: const [],
      workloadsSkipped: 0,
      partsSkipped: 1,
      apiSkipped: true,
      chat: ChatSupportView.unknown,
      truncated: false,
    );
    await _pump(tester, info);
    final l = appL10n;
    expect(find.text(l.serviceInfoChatUnknown), findsOneWidget);
    expect(find.text(l.serviceInfoNoInterface), findsNothing);
    expect(find.byKey(const Key('service-info-interface')), findsNothing);
    expect(find.text(l.serviceInfoPartsSkipped(1)), findsOneWidget);
    // The parts that were read are still shown.
    expect(find.byKey(const Key('service-info-networks')), findsOneWidget);
    expect(find.byKey(const Key('service-info-environment')), findsOneWidget);
  });

  testWidgets('it reads the service with the loader, and a failure can be retried', (tester) async {
    final calls = <(String, NodeAddress?)>[];
    var fail = true;
    const node = NodeAddress(host: 'n.example', port: 7);
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        ServiceInfoScreen(
          serviceIdHex: 'cd' * 32,
          node: node,
          name: 'Echo',
          load: (id, n) async {
            calls.add((id, n));
            if (fail) throw const CelautError(kind: CelautErrorKind.unreachable, message: 'down');
            return _full();
          },
        ),
      ),
    );
    expect(find.byKey(const Key('service-info-loading')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Echo'), findsOneWidget);
    expect(find.text(CelautStrings.errorText(CelautErrorKind.unreachable)), findsOneWidget);
    fail = false;
    await tester.tap(find.byKey(const Key('service-info-retry')));
    await tester.pumpAndSettle();
    expect(calls, [('cd' * 32, node), ('cd' * 32, node)]);
    expect(find.text('An echo service for the tests'), findsOneWidget);
  });

  testWidgets('info that the caller read is not read again', (tester) async {
    var reads = 0;
    tester.view.physicalSize = const Size(390, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        ServiceInfoScreen(
          serviceIdHex: 'ab' * 32,
          info: _full(),
          load: (id, n) async {
            reads++;
            return _empty();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.text('An echo service for the tests'), findsOneWidget);
  });

  testWidgets('the info page of an instance opens the details of its service from its node', (tester) async {
    final seen = <(String, NodeAddress?)>[];
    final instance = InstanceListView(
      instanceId: 'i1',
      peerId: 'aa' * 32,
      address: 'node.example:53460',
      serviceId: 'ef' * 32,
      slots: Uint16List.fromList([8080]),
      chatSlots: Uint16List.fromList([8080]),
      webSlots: Uint16List(0),
      startedAt: 1,
      startChargeMu: '1000',
      name: 'Echo',
      alias: '',
      title: '',
      refundMu: '',
    );
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        InstanceInfoScreen(
          instance: instance,
          state: InstanceState.running,
          loadInfo: (id, node) async {
            seen.add((id, node));
            return _full();
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('info-service-details')));
    await tester.pumpAndSettle();
    expect(seen, [('ef' * 32, const NodeAddress(host: 'node.example', port: 53460))]);
    expect(find.byKey(const Key('service-info-chat-supported')), findsOneWidget);
  });

  group('the title of the app', () {
    testWidgets('is Chatui, in lower case except the C, with "ui" in the other colour', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [ArgusColors(muted: Colors.grey, cardBorder: Colors.grey, inset: Colors.grey, chip: Colors.grey)]),
          home: const Scaffold(body: CelautWordmark()),
        ),
      );
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      final root = rich.text as TextSpan;
      expect(root.toPlainText(), 'Chatui');
      // The text of each span, with its own style: the first is the accent, the last "ui".
      final spans = <TextSpan>[];
      root.visitChildren((span) {
        if (span is TextSpan && span.text != null) spans.add(span);
        return true;
      });
      expect(spans.map((s) => s.text), ['Chat', 'ui']);
      final ui = spans.last;
      expect(ui.text, equals(ui.text!.toLowerCase()));
      // Another colour than the rest of the title.
      expect(ui.style!.color, isNot(root.style!.color));
      expect(CelautWordmark.name, 'Chatui');
    });
  });
}
