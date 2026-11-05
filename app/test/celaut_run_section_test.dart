import 'dart:async';
import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_catalog.dart';
import 'package:argus_wallet/bridge/api/celaut_env.dart';
import 'package:argus_wallet/bridge/api/celaut_service_info.dart';
import 'package:argus_wallet/bridge/api/celaut_package.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/celaut_strings.dart';
import 'package:argus_wallet/celaut/env_store.dart';
import 'package:argus_wallet/celaut/launcher.dart';
import 'package:argus_wallet/celaut/package_channel.dart';
import 'package:argus_wallet/celaut/package_library.dart';
import 'package:argus_wallet/celaut/payers.dart';
import 'package:argus_wallet/celaut/service_strings.dart';
import 'package:argus_wallet/celaut/service_transfer.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/celaut/launch_failure_sheet.dart';
import 'package:argus_wallet/ui/celaut/run_service_section.dart';
import 'package:argus_wallet/ui/celaut/service_info_screen.dart';
import 'package:argus_wallet/ui/celaut/skill_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a service says about itself, with the parts that these tests use.
ServiceInfoView _info({
  List<DeclaredVariableView> env = const [],
  List<NetworkView> networks = const [],
  ChatSupportView chat = ChatSupportView.supported,
  bool truncated = false,
}) => ServiceInfoView(
  prose: 'A service',
  architecture: const ['linux/amd64'],
  filesystemBytes: BigInt.from(1024),
  entryPath: const [],
  configPath: const [],
  nodeProtocols: const [],
  environment: env,
  slots: const [],
  networks: networks,
  workloads: const [],
  workloadsSkipped: 0,
  partsSkipped: 0,
  apiSkipped: false,
  chat: chat,
  chatPort: chat == ChatSupportView.supported ? 8080 : null,
  truncated: truncated,
);

final _best = 'aa' * 32;
final _other = 'bb' * 32;

const _sat = SkillView(
  boxId: 'skill-sat',
  name: 'Boolean SAT Solver',
  prose: 'Decides if a formula can be satisfied.',
  tags: ['logic'],
  domain: 'algorithms',
  height: 0,
  serviceIds: [],
  publisherReputation: 0,
);
const _summary = SkillView(boxId: 'skill-md', name: 'Markdown Summarization', prose: '', tags: ['summary'], domain: 'nlp', height: 0, serviceIds: [], publisherReputation: 0);

/// A service id of a skill of [_catalog].
String _serviceOf(String skill, int i) => '$skill-$i'.padRight(64, '0');

SkillView _storeSkill(String id, String name, String domain, int height, int services, double reputation) => SkillView(
  boxId: id,
  name: name,
  prose: 'About $name.',
  tags: const [],
  domain: domain,
  height: height,
  serviceIds: [for (var i = 0; i < services; i++) _serviceOf(id, i)],
  publisherReputation: reputation,
);

/// The catalog of mainnet on 2026-11-05: heights, declared services and the reputation of
/// the publisher (nanoERG) as the explorer gave them.
final _catalog = [
  _storeSkill('satisfiability', 'Boolean Satisfiability Problem Solver', 'SAT', 1811888, 1, 32e6),
  _storeSkill('markdown', 'Markdown Summarization', 'nlp', 1816212, 2, 96e6),
  _storeSkill('address', 'Ergo Address Validation', 'blockchain', 1816214, 2, 96e6),
  _storeSkill('satsolver', 'Boolean SAT Solver', 'algorithms', 1816301, 2, 96e6),
  _storeSkill('audit', 'ErgoScript Contract Audit', 'blockchain-security', 1816382, 1, 96e6),
  _storeSkill('market', 'market-strategy', 'finance', 1844990, 4, 96e6),
  _storeSkill('reserves', 'proof-of-reserves', 'finance', 1846051, 3, 96e6),
];

List<SkillServiceView> _ranked() => [
  SkillServiceView(serviceId: _best, score: 0.8455, direct: true),
  SkillServiceView(serviceId: _other, score: 0.7, direct: true),
];

QuoteView _quote({String credit = '', String cost = '1000000'}) => QuoteView(
  address: const NodeAddress(host: '127.0.0.1', port: 18460),
  peerId: 'aa' * 32,
  costMu: cost,
  initMaintenanceMu: '1',
  maxMaintenanceMu: '1',
  maintenanceSecondsLoop: 10,
  variance: 0,
  comparedNanoErg: '1',
  clientBalanceMu: credit,
);

InstanceView _instance({List<int> chat = const []}) => InstanceView(
  instanceId: 'inst-1',
  peerId: 'aa' * 32,
  slots: Uint16List.fromList([8080]),
  chatSlots: Uint16List.fromList(chat),
  webSlots: Uint16List(0),
  clientBalanceMu: '5',
);

class _Wallets implements FullWallets {
  _Wallets({this.full = true, this.open = true, this.unlocks = true});

  final bool full;
  bool open;
  final bool unlocks;

  @override
  Future<List<PayerWallet>> payers() async =>
      full ? [PayerWallet(walletId: 'w1', name: 'Main', balanceNano: 1, open: open)] : const [];

  @override
  Future<bool> unlock(BuildContext context, PayerWallet wallet) async {
    if (unlocks) open = true;
    return unlocks;
  }
}

/// The service files loaded into the app, in memory.
class _Lib {
  final calls = <String>[];
  var stored = <LibraryPackageView>[];
  Object? importError;

  /// An import that waits for the test: the rocket shows meanwhile.
  Completer<void>? importGate;

  /// What the check of the file read so far, of 4000 bytes.
  var checked = 0;
  var cancels = 0;

  /// The service that an imported file holds.
  String imports = _best;

  LibraryPackageView view({String? id, String name = 'echo', bool present = true}) =>
      LibraryPackageView(
        serviceId: id ?? _best,
        name: name,
        path: '/data/packages/library/${id ?? _best}.bee',
        bytes: BigInt.from(4096),
        importedAt: 1,
        nodoExport: true,
        present: present,
      );

  PackageLibrary get library => PackageLibrary(
    importPackage: (path, name, dir) async {
      calls.add('import $path $name');
      if (importGate != null) await importGate!.future;
      if (importError != null) throw importError!;
      final v = view(id: imports, name: name.replaceAll('.celaut.bee', ''));
      stored = [...stored.where((p) => p.serviceId != v.serviceId), v];
      return v;
    },
    list: () => stored,
    remove: (id) async {
      calls.add('remove $id');
      stored = [for (final p in stored) if (p.serviceId != id) p];
    },
    privateDir: () async => '/data',
    progress: () => TransferView(
      stage: TransferStage.checking,
      bytes: BigInt.from(checked),
      total: BigInt.from(4000),
    ),
    cancel: () {
      cancels++;
      importError = const CelautError(kind: CelautErrorKind.transferFailed, message: 'cancelled');
      importGate?.complete();
    },
  );
}

class _Packages implements PackageChannel {
  bool metered = false;
  PickedPackage? picked;
  int picks = 0;

  @override
  Future<bool> isMetered() async => metered;

  @override
  Future<PickedPackage?> pick() async {
    picks++;
    return picked;
  }
}

void main() {
  late List<String> launched;
  late List<(String, int)> tunnels;
  late int changed;
  late int deposits;
  late LaunchOutcome Function() outcome;
  Object? launchError;
  // A launch that waits for the test: the rocket shows meanwhile.
  Completer<void>? launchGate;
  List<EnvChoice>? envChosen;
  Object? skillsError;
  var skills = <SkillView>[_sat, _summary];

  Future<void> open(
    WidgetTester tester, {
    FullWallets? wallets,
    QuoteView? preview,
    List<SkillServiceView>? services,
    ServiceTransfer? transfer,
    PackageChannel? packages,
    _Lib? lib,
    ThemeData? theme,
    bool askEnvironment = false,
    ServiceInfoLoader? inspect,
    EnvStore? envStore,
    Set<String> Function()? trustedNodes,
    List<RanService> ran = const [],
    Size size = const Size(390, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: RunServiceSection(
              wallets: wallets ?? _Wallets(),
              onChanged: () => changed++,
              newClient: (node) async =>
                  NewClientView(peerId: 'aa' * 32, freeCreditMu: '4500000', earlierClients: 1),
              loadSkills: () async {
                if (skillsError != null) throw skillsError!;
                return skills;
              },
              loadServices: (id) async => services ?? _ranked(),
              previewQuote: (id) async => preview,
              launch: ({required serviceIdHex, initialMu, minSurvival, keepAlive = false, budgetMu, environment}) async {
                launched.add(
                  '$serviceIdHex $initialMu${minSurvival == null ? '' : ' ${minSurvival.inMinutes} min'}'
                  '${keepAlive ? ' keep ${budgetMu ?? 'no limit'}' : ''}',
                );
                if (launchGate != null) await launchGate!.future;
                if (launchError != null) throw launchError!;
                if (askEnvironment) {
                  final quotes = QuotesView(quotes: [_quote()], failures: const []);
                  final chosen = await environment!(quotes);
                  if (chosen == null) throw const LaunchCancelled();
                  envChosen = chosen;
                }
                return outcome();
              },
              inspect: inspect,
              envStore: envStore,
              trustedNodes: trustedNodes ?? () => const {},
              openTunnel: (id, slot) async {
                tunnels.add((id, slot));
                return 4321;
              },
              chatBuilder: (id, port) => Scaffold(body: Text('chat $id $port')),
              openDeposit: () => deposits++,
              transfer: transfer,
              packages: packages,
              library: (lib ?? _Lib()).library,
              runHistory: () => ran,
            ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    // The confirmation keeps the last least time in the preferences.
    SharedPreferences.setMockInitialValues({});
    launched = [];
    tunnels = [];
    changed = 0;
    deposits = 0;
    launchError = null;
    launchGate = null;
    envChosen = null;
    skillsError = null;
    skills = [_sat, _summary];
    outcome = () => LaunchOutcome(quote: _quote(), instance: _instance(), skipped: const []);
  });

  /// The files on this phone: a sheet from the small action at the top.
  Future<void> showFiles(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('run-phone')));
    await tester.pumpAndSettle();
  }

  Future<void> run(WidgetTester tester, {String? serviceId}) async {
    await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
    await tester.pumpAndSettle();
    if (serviceId != null) {
      // The services beyond the best are folded until the user asks for them.
      if (find.byKey(Key('skill-service-$serviceId')).evaluate().isEmpty) {
        await tester.tap(find.byKey(const Key('skill-sheet-more')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(Key('skill-service-$serviceId')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('skill-sheet-run')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run-confirm-ok')));
    await tester.pumpAndSettle();
  }

  testWidgets('the skills are cards with a Run button; the files on this phone are behind a small action', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('run-mode')), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('run-skill-skill-sat')), matching: find.byType(SkillMark)), findsOneWidget);
    expect(find.byKey(const Key('run-skill-run-skill-sat')), findsOneWidget);
    // No file list on the page: it is in the sheet of the action at the top.
    expect(find.byKey(const Key('run-on-phone')), findsNothing);
    await showFiles(tester);
    expect(find.byKey(const Key('run-on-phone')), findsOneWidget);
    // Import is a small text button, not a filled one.
    expect(find.descendant(of: find.byKey(const Key('pkg-import')), matching: find.byType(Icon)), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('pkg-import'))), isA<TextButton>());
    expect(find.byKey(const Key('pkg-empty')), findsOneWidget);
  });

  testWidgets('Run on a card opens the services of its skill, the best chosen', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('run-skill-run-skill-md')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('skill-sheet-name'))).data, _summary.name);
    expect(find.byKey(const Key('skill-service-best')), findsOneWidget);
  });

  group('the store', () {
    setUp(() => skills = _catalog);

    Rect rectOf(WidgetTester tester, String key) => tester.getRect(find.byKey(Key(key)));

    testWidgets('has its sections, each from its own data, in this order', (tester) async {
      await open(tester, ran: [(serviceId: _serviceOf('market', 0), name: 'other name')]);
      List<String> row(String id) => [
        for (final e in find.descendant(of: find.byKey(Key('store-$id')), matching: find.byType(SkillTile)).evaluate())
          (e.widget as SkillTile).skill.boxId,
      ];
      final featured = [
        for (final e in find.byType(SkillFeatureCard).evaluate()) (e.widget as SkillFeatureCard).skill.boxId,
      ];
      expect(featured, ['market', 'satsolver', 'address', 'markdown', 'audit']);
      expect(row('suggested'), ['reserves']);
      expect(row('new'), ['reserves', 'market', 'audit', 'satsolver', 'address', 'markdown', 'satisfiability']);
      expect(row('popular'), ['market', 'reserves', 'satsolver', 'address', 'markdown', 'audit', 'satisfiability']);
      final tops = [
        for (final key in ['store-featured', 'store-suggested', 'store-new', 'store-popular', 'store-categories', 'store-all'])
          rectOf(tester, key).top,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      // Every skill is in the list at the end, and every field has a tile.
      for (final s in _catalog) {
        expect(find.byKey(Key('run-skill-${s.boxId}')), findsOneWidget);
        expect(find.byKey(Key('run-field-${s.domain.toLowerCase()}')), findsOneWidget);
      }
      expect(find.text(appL10n.celautStoreServices(4)), findsWidgets);
    });

    testWidgets('a section with no data is not shown', (tester) async {
      skills = [
        for (final s in _catalog)
          SkillView(
            boxId: s.boxId,
            name: s.name,
            prose: s.prose,
            tags: s.tags,
            domain: s.domain,
            height: 0,
            serviceIds: const [],
            publisherReputation: 0,
          ),
      ];
      await open(tester);
      for (final id in ['featured', 'suggested', 'new', 'popular']) {
        expect(find.byKey(Key('store-$id')), findsNothing, reason: id);
      }
      expect(find.byKey(const Key('store-categories')), findsOneWidget);
      expect(find.byKey(Key('run-skill-${_catalog.first.boxId}')), findsOneWidget);
    });

    testWidgets('no suggestion with no history', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('store-suggested')), findsNothing);
      expect(find.byKey(const Key('store-featured')), findsOneWidget);
    });

    testWidgets('a search or a field shows its skills only, with no section', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('run-search')), 'reserves');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store-featured')), findsNothing);
      expect(find.byKey(const Key('store-all')), findsNothing);
      expect(find.byKey(const Key('run-skill-reserves')), findsOneWidget);
      expect(find.byKey(const Key('run-skill-market')), findsNothing);
      await tester.enterText(find.byKey(const Key('run-search')), '');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store-featured')), findsOneWidget);
      // The tile of a field chooses its chip.
      await tester.ensureVisible(find.byKey(const Key('run-field-blockchain')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-field-blockchain')));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('run-category-blockchain'))).selected, isTrue);
      expect(find.byKey(const Key('store-featured')), findsNothing);
      expect(find.byKey(const Key('run-skill-address')), findsOneWidget);
      expect(find.byKey(const Key('run-skill-audit')), findsNothing);
      // The list starts again from its top.
      expect(rectOf(tester, 'run-skill-address').top, lessThan(rectOf(tester, 'run-top').bottom + 20));
    });

    testWidgets('Run on a featured card or a tile opens the services of its skill', (tester) async {
      await open(tester, ran: [(serviceId: _serviceOf('market', 0), name: '')]);
      await tester.tap(find.byKey(const Key('store-featured-run-market')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('skill-sheet-name'))).data, 'market-strategy');
      Navigator.of(tester.element(find.byKey(const Key('skill-sheet')))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('store-suggested-run-reserves')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('skill-sheet-name'))).data, 'proof-of-reserves');
    });

    for (final scale in [1.0, 1.3]) {
      for (final palette in [argusTheme(watchful: true), argusTheme(watchful: false)]) {
        testWidgets('on a small phone (360 x 640, font x$scale, ${palette.brightness.name}): featured and '
            'suggested show with no scroll, and the actions of this phone stay at the top', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await open(
            tester,
            size: const Size(360, 640),
            theme: palette,
            ran: [(serviceId: _serviceOf('market', 0), name: '')],
          );
          expect(tester.takeException(), isNull);
          final import = rectOf(tester, 'run-import');
          final phone = rectOf(tester, 'run-phone');
          expect(import.top, lessThan(80));
          expect(phone.top, import.top);
          // Small: an icon, no text.
          expect(import.height, lessThanOrEqualTo(48));
          expect(find.descendant(of: find.byKey(const Key('run-import')), matching: find.byType(Text)), findsNothing);
          expect(tester.widget<Tooltip>(find.ancestor(of: find.byKey(const Key('run-phone')), matching: find.byType(Tooltip)).first).message,
              appL10n.celautRunPhoneServices);
          // Featured and the start of the suggestions are on the screen.
          expect(rectOf(tester, 'store-featured-market').bottom, lessThan(640));
          expect(rectOf(tester, 'store-suggested-reserves').top, lessThan(640 - 40));
          // Scroll far: the actions do not move.
          await tester.drag(find.byKey(const Key('run-list')), const Offset(0, -1500));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('store-featured')).hitTestable(), findsNothing);
          expect(rectOf(tester, 'run-import'), import);
          expect(rectOf(tester, 'run-phone'), phone);
          await tester.tap(find.byKey(const Key('run-phone')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('phone-sheet')), findsOneWidget);
        });
      }
    }

    testWidgets('on a wide screen the actions have their text, and the cards are in two columns', (tester) async {
      await open(tester, size: const Size(1000, 900));
      expect(tester.takeException(), isNull);
      expect(find.descendant(of: find.byKey(const Key('run-import')), matching: find.text(appL10n.celautRunImport)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('run-phone')), matching: find.text(appL10n.celautRunOnPhone)), findsOneWidget);
      expect(rectOf(tester, 'run-import').top, lessThan(80));
      // Three fields in a row of tiles: the most used first, then by name.
      final fields = [for (final f in ['finance', 'algorithms', 'blockchain']) rectOf(tester, 'run-field-$f')];
      expect(fields.map((r) => r.top).toSet(), hasLength(1));
      expect(rectOf(tester, 'run-field-blockchain-security').top, greaterThan(fields.first.bottom));
      // The list builds what is near the screen only: scroll to the cards.
      await tester.scrollUntilVisible(
        find.byKey(Key('run-skill-${_catalog[1].boxId}')),
        200,
        scrollable: find.descendant(of: find.byKey(const Key('run-list')), matching: find.byType(Scrollable)).first,
      );
      await tester.pumpAndSettle();
      final first = rectOf(tester, 'run-skill-${_catalog[0].boxId}');
      final second = rectOf(tester, 'run-skill-${_catalog[1].boxId}');
      expect(second.top, first.top);
      expect(second.left, greaterThan(first.right));
      expect(second.height, first.height);
    });
  });

  testWidgets('the fields of the skills are chips, and a chip shows the skills of its field', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('run-category-all')), findsOneWidget);
    expect(find.byKey(const Key('run-category-algorithms')), findsOneWidget);
    expect(find.byKey(const Key('run-category-nlp')), findsOneWidget);
    await tester.tap(find.byKey(const Key('run-category-nlp')));
    await tester.pump();
    expect(find.byKey(const Key('run-skill-skill-sat')), findsNothing);
    expect(find.byKey(const Key('run-skill-skill-md')), findsOneWidget);
    await tester.tap(find.byKey(const Key('run-category-all')));
    await tester.pump();
    expect(find.byKey(const Key('run-skill-skill-sat')), findsOneWidget);
    expect(find.byKey(const Key('run-skill-skill-md')), findsOneWidget);
  });

  testWidgets('with no field in the catalog, there are no chips', (tester) async {
    skills = [for (var i = 0; i < 3; i++) SkillView(boxId: 'skill-$i', name: 'Skill $i', prose: '', tags: const [], domain: '', height: 0, serviceIds: const [], publisherReputation: 0)];
    await open(tester);
    expect(find.byKey(const Key('run-categories')), findsNothing);
    expect(find.byKey(const Key('run-skill-skill-2')), findsOneWidget);
  });

  testWidgets('the search finds a skill by a tag or by its field too', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('run-search')), 'summary');
    await tester.pump();
    expect(find.byKey(const Key('run-skill-skill-sat')), findsNothing);
    expect(find.byKey(const Key('run-skill-skill-md')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('run-search')), 'ALGORITHMS');
    await tester.pump();
    expect(find.byKey(const Key('run-skill-skill-sat')), findsOneWidget);
    expect(find.byKey(const Key('run-skill-skill-md')), findsNothing);
  });

  testWidgets('On this phone: the saved services run from there, and import is a small action', (
    tester,
  ) async {
    final lib = _Lib();
    lib.stored = [lib.view(), lib.view(id: _other, name: 'summary')];
    await open(tester, lib: lib);
    await showFiles(tester);
    // Saved services are listed, each with its Run, and the import is one small button.
    expect(find.byKey(Key('pkg-run-$_best')), findsOneWidget);
    expect(find.byKey(Key('pkg-run-$_other')), findsOneWidget);
    expect(find.byKey(const Key('pkg-import')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('phone-sheet')), matching: find.byType(FilledButton)), findsNothing);
    expect(find.byKey(const Key('pkg-empty')), findsNothing);
  });

  testWidgets('it lists the skills and the search narrows them', (tester) async {
    await open(tester);
    expect(find.text('RUN A SERVICE'), findsOneWidget);
    expect(find.text('Boolean SAT Solver'), findsOneWidget);
    expect(find.text('Markdown Summarization'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('run-search')), 'markdown');
    await tester.pump();
    expect(find.text('Boolean SAT Solver'), findsNothing);
    expect(find.text('Markdown Summarization'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('run-search')), 'zzz');
    await tester.pump();
    expect(find.byKey(const Key('run-empty')), findsOneWidget);
  });

  testWidgets('every skill of the catalog is listed, not only the first ones', (tester) async {
    skills = [
      for (var i = 0; i < 9; i++) SkillView(boxId: 'skill-$i', name: 'Skill $i', prose: '', tags: const [], domain: '', height: 0, serviceIds: const [], publisherReputation: 0),
    ];
    await open(tester);
    for (var i = 0; i < 9; i++) {
      expect(find.byKey(Key('run-skill-skill-$i')), findsOneWidget);
    }
  });

  testWidgets('a failure to read the catalog shows a retry that reads it again', (tester) async {
    skillsError = StateError('no bridge');
    await open(tester);
    expect(find.byKey(const Key('run-error')), findsOneWidget);
    skillsError = null;
    await tester.tap(find.byKey(const Key('run-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('run-error')), findsNothing);
    expect(find.text('Boolean SAT Solver'), findsOneWidget);
  });

  testWidgets('a skill opens its services, the best first and chosen, with the best node', (tester) async {
    await open(tester, preview: _quote());
    await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('skill-sheet')), findsOneWidget);
    expect(find.byKey(const Key('skill-service-best')), findsOneWidget);
    // Only the best shows at first; the others are one tap away.
    expect(find.byKey(Key('skill-service-$_best')), findsOneWidget);
    expect(find.byKey(Key('skill-service-$_other')), findsNothing);
    expect(find.text('${_best.substring(0, 8)}…'), findsOneWidget);
    expect(find.text(_best), findsNothing);
    await tester.tap(find.byKey(const Key('skill-sheet-more')));
    await tester.pumpAndSettle();
    final best = tester.getTopLeft(find.byKey(Key('skill-service-$_best')));
    final other = tester.getTopLeft(find.byKey(Key('skill-service-$_other')));
    expect(best.dy, lessThan(other.dy));
    expect(find.byKey(const Key('skill-service-chosen')), findsOneWidget);
    expect(find.textContaining('127.0.0.1:18460'), findsOneWidget);
    expect(find.textContaining('1,000,000 MU'), findsOneWidget);
  });

  testWidgets('a skill with no service says so, and has no Run button', (tester) async {
    await open(tester, services: const []);
    await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('skill-sheet-empty')), findsOneWidget);
    expect(find.byKey(const Key('skill-sheet-run')), findsNothing);
  });

  testWidgets('Run starts the best service with the default balance', (tester) async {
    await open(tester);
    await run(tester);
    expect(launched, ['$_best 1000000']);
  });

  testWidgets('Run asks first, with the best node and its start cost', (tester) async {
    await open(tester, preview: _quote());
    await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-sheet-run')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('run-confirm')), findsOneWidget);
    expect(find.text(appL10n.celautRunConfirmTitle('Boolean SAT Solver')), findsOneWidget);
    expect(find.text(appL10n.celautRunConfirmBody), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('run-confirm-quote'))).data,
      appL10n.celautRunPreview('127.0.0.1:18460', '1,000,000 MU'),
    );
    expect(launched, isEmpty, reason: 'nothing starts before the user confirms');
    await tester.tap(find.byKey(const Key('run-confirm-ok')));
    await tester.pumpAndSettle();
    expect(launched, ['$_best 1000000']);
  });

  testWidgets('the confirmation asks for the least time, and the launch uses it', (tester) async {
    // 100 MU each 60 s on the best node, and a quote of 1,000,300 MU with the default
    // balance of 1,000,000 MU: a build of 300 MU.
    final best = QuoteView(
      address: const NodeAddress(host: '127.0.0.1', port: 18460),
      peerId: 'aa' * 32,
      costMu: '1000300',
      initMaintenanceMu: '100',
      maxMaintenanceMu: '100',
      maintenanceSecondsLoop: 60,
      variance: 0,
      comparedNanoErg: '1',
      clientBalanceMu: '',
    );
    await open(tester, preview: best);
    await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-sheet-run')));
    await tester.pumpAndSettle();
    // Empty: the default balance, and how long it lasts on that node.
    expect(
      tester.widget<Text>(find.byKey(const Key('run-confirm-survival'))).data,
      appL10n.celautRunDefaultBalanceLasts('1,000,000 MU', '6 d 22 h'),
    );
    await tester.enterText(find.byKey(const Key('run-confirm-minutes')), '90');
    await tester.pump();
    // 90 periods and one more, of 100 MU, plus the build.
    expect(
      tester.widget<Text>(find.byKey(const Key('run-confirm-survival'))).data,
      appL10n.celautRunSurvivalEstimate('9,400 MU', '9,100 MU', '1 h 30 min'),
    );
    // More than 30 days cannot run.
    await tester.enterText(find.byKey(const Key('run-confirm-minutes')), '50000');
    await tester.pump();
    expect(find.text(appL10n.celautRunSurvivalWrong), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('run-confirm-ok'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('run-confirm-minutes')), '90');
    await tester.pump();
    await tester.tap(find.byKey(const Key('run-confirm-ok')));
    await tester.pumpAndSettle();
    expect(launched, ['$_best 1000000 90 min']);
    // The next confirmation starts with the same time.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('celaut_min_survival_minutes_v1'), 90);
  });

  group('the mode until I stop it', () {
    // 100 MU each 60 s, a client credit of 10,000 MU on the best node.
    final best = QuoteView(
      address: const NodeAddress(host: '127.0.0.1', port: 18460),
      peerId: 'aa' * 32,
      costMu: '1000300',
      initMaintenanceMu: '100',
      maxMaintenanceMu: '100',
      maintenanceSecondsLoop: 60,
      variance: 0,
      comparedNanoErg: '1',
      clientBalanceMu: '10000',
    );

    Future<void> confirm(WidgetTester tester) async {
      await open(tester, preview: best);
      await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-sheet-run')));
      await tester.pumpAndSettle();
    }

    testWidgets('starts in the mode by time, with no warning', (tester) async {
      await confirm(tester);
      expect(find.byKey(const Key('run-confirm-minutes')), findsOneWidget);
      expect(find.byKey(const Key('run-confirm-warning')), findsNothing);
      expect(find.byKey(const Key('run-confirm-limit')), findsNothing);
    });

    testWidgets('warns about the credit, shows the price and the credit, and has a limit', (tester) async {
      await confirm(tester);
      await tester.tap(find.text(appL10n.celautRunModeKeep));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('run-confirm-warning')), findsOneWidget);
      expect(find.text(appL10n.celautKeepWarning), findsOneWidget);
      expect(find.byKey(const Key('run-confirm-minutes')), findsNothing);
      // 6,000 MU an hour; 10,000 MU last 1 h 39 min (99 periods) there. A few hours: a warning.
      expect(
        tester.widget<Text>(find.byKey(const Key('run-confirm-keep'))).data,
        '${appL10n.celautKeepRate('6,000 MU', '10,000 MU', '1 h 39 min')}\n${appL10n.celautKeepLowCredit}',
      );
      expect(find.text(appL10n.celautRunButtonKeep), findsOneWidget);
      // A zero limit is wrong.
      await tester.enterText(find.byKey(const Key('run-confirm-limit')), '0');
      await tester.pump();
      expect(find.text(appL10n.celautKeepLimitWrong), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('run-confirm-ok'))).onPressed, isNull);
    });

    testWidgets('runs with no limit, or with the limit that was typed, and keeps no time', (tester) async {
      await confirm(tester);
      await tester.tap(find.text(appL10n.celautRunModeKeep));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-confirm-ok')));
      await tester.pumpAndSettle();
      expect(launched, ['$_best 1000000 keep no limit']);
      expect((await SharedPreferences.getInstance()).getInt('celaut_min_survival_minutes_v1'), isNull);
    });

    testWidgets('the limit goes to the launch', (tester) async {
      await confirm(tester);
      await tester.tap(find.text(appL10n.celautRunModeKeep));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('run-confirm-limit')), '250000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('run-confirm-ok')));
      await tester.pumpAndSettle();
      expect(launched, ['$_best 1000000 keep 250000']);
    });
  });

  group('the rocket of a launch', () {
    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-sheet-run')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-confirm-ok')));
      // The launch waits: the rocket hovers, so the frames never settle.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('it shows while the app launches, then lifts off and goes', (tester) async {
      launchGate = Completer<void>();
      await open(tester);
      await confirm(tester);
      expect(find.byKey(const Key('launch-rocket')), findsOneWidget);
      expect(find.text(appL10n.celautRunLaunching('Boolean SAT Solver')), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'it moves');
      launchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('launch-rocket')), findsNothing);
      expect(launched, hasLength(1));
    });

    testWidgets('it lists the steps, and stays while the service is read', (tester) async {
      final read = Completer<ServiceInfoView>();
      await open(tester, askEnvironment: true, inspect: (id, node) => read.future);
      await confirm(tester);
      // The quotes are in: the app reads the service. The rocket stays, with its steps.
      expect(find.byKey(const Key('launch-rocket')), findsOneWidget);
      expect(find.byKey(const Key('launch-steps')), findsOneWidget);
      expect(find.text(appL10n.celautRunStepNodes), findsOneWidget);
      expect(find.text(appL10n.celautRunStepReading), findsOneWidget);
      expect(find.text(appL10n.celautRunStepStarting), findsOneWidget);
      // One step goes on (a spinner), one is done (a check), one waits.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      // The service declares nothing: the start follows with no question, and the rocket
      // went on to the last step.
      read.complete(_info());
      // A few frames: the start is instant here, and the lift-off takes 450 ms.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const Key('env-step')), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('launch-rocket')), findsNothing);
    });

    testWidgets('a failed launch takes it away before the sheet of the failure', (tester) async {
      launchGate = Completer<void>();
      launchError = const LaunchFailure(LaunchFailureKind.noQuotes);
      await open(tester);
      await confirm(tester);
      expect(find.byKey(const Key('launch-rocket')), findsOneWidget);
      launchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('launch-rocket')), findsNothing);
    });

    testWidgets('with animations off in Android, it stands still', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      launchGate = Completer<void>();
      await open(tester);
      await confirm(tester);
      expect(find.byKey(const Key('launch-rocket')), findsOneWidget);
      // Nothing moves: no frame waits.
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('launch-rocket')), findsOneWidget);
      launchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('launch-rocket')), findsNothing);
    });
  });

  testWidgets('Cancel in the confirmation starts nothing', (tester) async {
    await open(tester, preview: _quote());
    await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-sheet-run')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('run-confirm')), findsNothing);
    expect(launched, isEmpty);
    expect(find.byKey(const Key('run-progress')), findsNothing);
  });

  testWidgets('with no price yet, the confirmation says so and Run still asks the nodes', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-sheet-run')));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.celautRunConfirmNoQuote), findsOneWidget);
    await tester.tap(find.byKey(const Key('run-confirm-ok')));
    await tester.pumpAndSettle();
    expect(launched, hasLength(1));
  });

  testWidgets('Run starts the service that the user chose', (tester) async {
    await open(tester);
    await run(tester, serviceId: _other);
    expect(launched, ['$_other 1000000']);
  });

  testWidgets('a service with a chat slot opens the conversation', (tester) async {
    outcome = () => LaunchOutcome(quote: _quote(), instance: _instance(chat: [8080, 9090]), skipped: const []);
    await open(tester);
    await run(tester);
    expect(tunnels, [('inst-1', 8080)]);
    expect(find.text('chat inst-1 4321'), findsOneWidget);
    expect(changed, greaterThan(0));
  });

  testWidgets('a service with no chat slot stays on the home with a message and a reload', (tester) async {
    await open(tester);
    await run(tester);
    expect(tunnels, isEmpty);
    expect(find.textContaining('chat inst-1'), findsNothing);
    expect(find.textContaining('Started on 127.0.0.1:18460'), findsOneWidget);
    expect(find.textContaining('1,000,000 MU'), findsOneWidget);
    expect(changed, 1);
  });

  testWidgets('with no full wallet the sheet says so and Run is off', (tester) async {
    await open(tester, wallets: _Wallets(full: false));
    await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('skill-sheet-no-wallet')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('skill-sheet-run'))).onPressed, isNull);
  });

  testWidgets('a locked wallet that is not opened stops the launch', (tester) async {
    await open(tester, wallets: _Wallets(open: false, unlocks: false));
    await run(tester);
    expect(launched, isEmpty);
    expect(find.text(appL10n.celautOpenFullWalletNeeded), findsOneWidget);
  });

  testWidgets('a locked wallet that is opened lets the launch go on', (tester) async {
    await open(tester, wallets: _Wallets(open: false));
    await run(tester);
    expect(launched, hasLength(1));
  });

  testWidgets('when no node starts it, a sheet says why for each node, with the text under Details', (tester) async {
    launchError = LaunchFailure(
      LaunchFailureKind.allFailed,
      quoteFailures: [
        QuoteFailureView(
          address: const NodeAddress(host: 'q.example', port: 9),
          kind: CelautErrorKind.serviceMissing,
          message: 'This node does not have the service ab',
        ),
      ],
      skipped: [
        LaunchSkip(
          _quote(),
          const CelautError(kind: CelautErrorKind.nodeClosed, message: 'This node is not accepting new work.'),
        ),
      ],
      leftOut: const [LeftOutNode(address: 'd.example:4', peerId: 'd', kind: CelautErrorKind.timeout)],
    );
    await open(tester);
    await run(tester);
    expect(find.byKey(const Key('launch-failure')), findsOneWidget);
    expect(find.text(appL10n.celautRunFailedAll), findsOneWidget);
    expect(find.text('q.example:9'), findsOneWidget);
    expect(find.text(appL10n.celautErrorServiceMissing), findsOneWidget);
    expect(find.text('127.0.0.1:18460'), findsOneWidget);
    expect(find.text(appL10n.celautErrorNodeClosed), findsOneWidget);
    expect(find.text(appL10n.celautRunLeftOut), findsOneWidget);
    expect(find.text(appL10n.celautErrorTimeout), findsOneWidget);
    // The text of the node is folded.
    expect(find.text('This node is not accepting new work.'), findsNothing);
    await tester.tap(find.byKey(const Key('launch-details-127.0.0.1:18460')));
    await tester.pumpAndSettle();
    expect(find.text('This node is not accepting new work.'), findsOneWidget);
    expect(find.byKey(const Key('launch-failure-deposit')), findsNothing);
    await tester.tap(find.byKey(const Key('launch-failure-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('launch-failure')), findsNothing);
  });

  testWidgets('a credit problem shows the numbers and a button to the deposit screen', (tester) async {
    launchError = LaunchFailure(
      LaunchFailureKind.allFailed,
      skipped: [
        LaunchSkip(
          _quote(credit: '2500', cost: '1000000'),
          const CelautError(kind: CelautErrorKind.insufficientCredit, message: 'credit 2500 MU, price 1000000 MU'),
        ),
      ],
    );
    await open(tester);
    await run(tester);
    expect(find.text(appL10n.celautRunNeedsCredit('2,500 MU', '1,000,000 MU')), findsOneWidget);
    await tester.tap(find.byKey(const Key('launch-failure-deposit')));
    await tester.pumpAndSettle();
    expect(deposits, 1);
    expect(find.byKey(const Key('launch-failure')), findsNothing);
  });

  testWidgets('a node that forgot the client id gives the choice, never a new client by itself', (tester) async {
    launchError = LaunchFailure(
      LaunchFailureKind.allFailed,
      skipped: [
        LaunchSkip(
          _quote(),
          const CelautError(kind: CelautErrorKind.clientUnknown, message: 'forgot'),
        ),
      ],
    );
    await open(tester);
    await run(tester);
    await tester.tap(find.byKey(const Key('launch-failure-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('client-unknown-dialog')), findsOneWidget);
  });

  group('the service files that the user loaded', () {
    late _Packages packages;
    late _Lib lib;

    setUp(() {
      packages = _Packages();
      lib = _Lib();
    });

    testWidgets('with none loaded, the section says how to load one', (tester) async {
      await open(tester, packages: packages, lib: lib);
    await showFiles(tester);
      expect(find.byKey(const Key('pkg-empty')), findsOneWidget);
      expect(find.text(appL10n.celautPkgEmpty), findsOneWidget);
      expect(find.byKey(const Key('pkg-import')), findsOneWidget);
    });

    testWidgets('a file is picked, loaded into the app and listed', (tester) async {
      packages.picked = const PickedPackage(path: '/cache/picked.bee', bytes: 10, name: 'echo.celaut.bee');
      await open(tester, packages: packages, lib: lib);
    await showFiles(tester);
      await tester.tap(find.byKey(const Key('pkg-import')));
      await tester.pumpAndSettle();
      expect(lib.calls, ['import /cache/picked.bee echo.celaut.bee']);
      expect(find.text(appL10n.celautPkgLoaded('echo')), findsOneWidget);
      expect(find.byKey(Key('pkg-$_best')), findsOneWidget);
      expect(find.text('echo'), findsOneWidget);
      expect(find.byKey(const Key('pkg-empty')), findsNothing);
      // Nothing was sent or launched: loading a file only keeps it.
      expect(launched, isEmpty);
    });

    testWidgets('while the file is checked, the rocket shows the bytes read', (tester) async {
      packages.picked = const PickedPackage(path: '/cache/picked.bee', bytes: 10, name: 'echo.celaut.bee');
      lib.importGate = Completer<void>();
      await open(tester, packages: packages, lib: lib);
    await showFiles(tester);
      await tester.tap(find.byKey(const Key('pkg-import')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('import-progress')), findsOneWidget);
      // The rocket of an import is raised on its pad, not the one that hovers to launch.
      expect(find.byKey(const Key('raise-rocket')), findsOneWidget);
      expect(find.byKey(const Key('launch-rocket')), findsNothing);
      expect(find.text(appL10n.celautImportChecking), findsOneWidget);
      lib.checked = 1000;
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(appL10n.celautSendProgress(CelautStrings.bytes(1000), CelautStrings.bytes(4000), '25')), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(find.byKey(const Key('import-bar')));
      expect(bar.value, 0.25);
      // The check ends: the rocket stands upright, and the card goes.
      lib.importGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-progress')), findsNothing);
      expect(find.text(appL10n.celautPkgLoaded('echo')), findsOneWidget);
    });

    testWidgets('Cancel stops the check, says nothing and loads nothing', (tester) async {
      packages.picked = const PickedPackage(path: '/cache/picked.bee', bytes: 10, name: 'echo.celaut.bee');
      lib.importGate = Completer<void>();
      await open(tester, packages: packages, lib: lib);
    await showFiles(tester);
      await tester.tap(find.byKey(const Key('pkg-import')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('import-cancel')));
      await tester.pumpAndSettle();
      expect(lib.cancels, 1);
      expect(find.byKey(const Key('import-progress')), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const Key('pkg-empty')), findsOneWidget);
    });

    testWidgets('closing the picker loads nothing', (tester) async {
      await open(tester, packages: packages, lib: lib);
    await showFiles(tester);
      await tester.tap(find.byKey(const Key('pkg-import')));
      await tester.pumpAndSettle();
      expect(packages.picks, 1);
      expect(lib.calls, isEmpty);
      expect(find.byKey(const Key('pkg-empty')), findsOneWidget);
    });

    testWidgets('a file that is not a service package is refused with the reason', (tester) async {
      packages.picked = const PickedPackage(path: '/cache/junk.bee', bytes: 10, name: 'junk.bee');
      lib.importError = const CelautError(
        kind: CelautErrorKind.invalidInput,
        message: 'the file does not say which service it is',
      );
      await open(tester, packages: packages, lib: lib);
    await showFiles(tester);
      await tester.tap(find.byKey(const Key('pkg-import')));
      await tester.pumpAndSettle();
      expect(
        find.text('${appL10n.celautPkgBadFile('the file does not say which service it is')}\n${appL10n.celautPkgRedownload}'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('pkg-empty')), findsOneWidget);
    });

    testWidgets('any other error of the load also says to download the file again', (tester) async {
      packages.picked = const PickedPackage(path: '/cache/a.bee', bytes: 10, name: 'a.bee');
      lib.importError = const CelautError(kind: CelautErrorKind.storage, message: 'disk');
      await open(tester, packages: packages, lib: lib);
      await showFiles(tester);
      await tester.tap(find.byKey(const Key('pkg-import')));
      await tester.pumpAndSettle();
      expect(find.textContaining(appL10n.celautPkgRedownload), findsOneWidget);
    });

    testWidgets('Run launches the loaded service by its id', (tester) async {
      lib.stored = [lib.view()];
      await open(tester, packages: packages, lib: lib);
    await showFiles(tester);
      await tester.tap(find.byKey(Key('pkg-run-$_best')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.celautRunConfirmTitle('echo')), findsOneWidget);
      await tester.tap(find.byKey(const Key('run-confirm-ok')));
      await tester.pumpAndSettle();
      expect(launched, ['$_best ${ServiceStrings.initialDefault}']);
      expect(changed, greaterThan(0));
    });

    testWidgets('with the theme of the app, a loaded service and the confirmation lay out', (tester) async {
      lib.stored = [lib.view(name: 'echo')];
      await open(tester, packages: packages, lib: lib, theme: argusTheme(watchful: false), preview: _quote());
    await showFiles(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(Key('pkg-run-$_best'))).width, lessThan(300));
      await tester.tap(find.byKey(Key('pkg-run-$_best')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('run-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('run-confirm-ok')));
      await tester.pumpAndSettle();
      expect(launched, hasLength(1));
    });

    testWidgets('a service whose file is gone cannot run and says so', (tester) async {
      lib.stored = [lib.view(present: false)];
      await open(tester, packages: packages, lib: lib);
    await showFiles(tester);
      expect(find.text(appL10n.celautPkgMissing), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(Key('pkg-run-$_best'))).onPressed, isNull);
      expect(launched, isEmpty);
    });

    testWidgets('Remove asks first, then deletes it; Cancel keeps it', (tester) async {
      lib.stored = [lib.view(name: 'echo')];
      await open(tester, packages: packages, lib: lib);
    await showFiles(tester);
      await tester.tap(find.byKey(Key('pkg-remove-$_best')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.celautPkgRemoveBody('echo')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pkg-remove-cancel')));
      await tester.pumpAndSettle();
      expect(lib.calls, isEmpty);
      expect(find.byKey(Key('pkg-$_best')), findsOneWidget);

      await tester.tap(find.byKey(Key('pkg-remove-$_best')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pkg-remove-confirm')));
      await tester.pumpAndSettle();
      expect(lib.calls, ['remove $_best']);
      expect(find.byKey(Key('pkg-$_best')), findsNothing);
      expect(find.byKey(const Key('pkg-empty')), findsOneWidget);
    });

    testWidgets('the loaded services are shown by name with their size and a short id', (tester) async {
      lib.stored = [lib.view(name: 'echo'), lib.view(id: _other, name: 'translate')];
      await open(tester, packages: packages, lib: lib);
      await showFiles(tester);
      expect(find.text('echo'), findsOneWidget);
      expect(find.text('translate'), findsOneWidget);
      expect(find.textContaining('4.0 KiB · ${_best.substring(0, 8)}'), findsOneWidget);
    });
  });

  group('a service that a node does not have', () {
    late List<String> transfers;
    late _Packages packages;
    late TransferView progress;
    Object? sendError;
    Completer<void>? hold;

    ServiceTransfer transfer() => ServiceTransfer(
      fetch: (source, id, dir) async {
        transfers.add('fetch ${source.host}');
        return PackageView(
          path: '/data/packages/$id.bee',
          bytes: BigInt.from(10),
          serviceId: id,
          hasService: true,
          nodoExport: false,
        );
      },
      send: (node, id, initialMu, path) async {
        transfers.add('send ${node.host} $path');
        await hold?.future;
        if (sendError != null) throw sendError!;
        return _quote();
      },
      progress: () => progress,
      cancel: () => transfers.add('cancel'),
      privateDir: () async => '/data',
    );

    LaunchFailure missingOn({bool holder = true}) => LaunchFailure(
      LaunchFailureKind.noQuotes,
      quoteFailures: [
        QuoteFailureView(
          address: const NodeAddress(host: 'q.example', port: 9),
          kind: CelautErrorKind.serviceMissing,
          message: 'This node does not have the service',
        ),
        if (holder)
          QuoteFailureView(
            address: const NodeAddress(host: 'h.example', port: 7),
            kind: CelautErrorKind.noRoom,
            message: 'This node cannot run the service right now',
          ),
      ],
    );

    setUp(() {
      transfers = [];
      packages = _Packages();
      progress = TransferView(stage: TransferStage.idle, bytes: BigInt.zero);
      sendError = null;
      hold = null;
    });

    testWidgets('it is sent from a node that has it, then the launch runs again', (tester) async {
      launchError = missingOn();
      packages.metered = true;
      await open(tester, transfer: transfer(), packages: packages);
      await run(tester);
      expect(find.byKey(const Key('launch-missing')), findsOneWidget);
      expect(find.text(appL10n.celautSendFromNode('h.example:7', 'q.example:9')), findsOneWidget);
      await tester.tap(find.byKey(const Key('launch-send-service')));
      await tester.pumpAndSettle();
      // On mobile data the confirmation warns.
      expect(find.byKey(const Key('send-confirm')), findsOneWidget);
      expect(find.byKey(const Key('send-metered')), findsOneWidget);
      launchError = null;
      await tester.tap(find.byKey(const Key('send-confirm-ok')));
      await tester.pumpAndSettle();
      expect(transfers, ['fetch h.example', 'send q.example /data/packages/$_best.bee']);
      expect(find.text(appL10n.celautSendDone), findsOneWidget);
      expect(launched, hasLength(2), reason: 'the launch runs again');
      expect(find.byKey(const Key('run-confirm')), findsNothing, reason: 'it does not ask a second time');
      expect(packages.picks, 0);
    });

    testWidgets('no node has it: a .celaut.bee file is picked, loaded into the app and sent', (tester) async {
      launchError = missingOn(holder: false);
      packages.picked = const PickedPackage(path: '/cache/picked.bee', bytes: 10, name: 'echo.celaut.bee');
      final lib = _Lib();
      await open(tester, transfer: transfer(), packages: packages, lib: lib);
      await run(tester);
      expect(find.text(appL10n.celautSendNoHolder), findsOneWidget);
      expect(find.text(appL10n.celautSendFromFile('q.example:9')), findsOneWidget);
      await tester.tap(find.byKey(const Key('launch-send-service')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('send-metered')), findsNothing);
      launchError = null;
      await tester.tap(find.byKey(const Key('send-confirm-ok')));
      await tester.pumpAndSettle();
      expect(packages.picks, 1);
      // The file is loaded into the library first, and the service is sent from there.
      expect(lib.calls, ['import /cache/picked.bee echo.celaut.bee']);
      expect(transfers, ['send q.example /data/packages/library/$_best.bee']);
      expect(launched, hasLength(2));
      // And it stays in the app, listed with the services of the user.
      await showFiles(tester);
      expect(find.byKey(Key('pkg-$_best')), findsOneWidget);
    });

    testWidgets('a cancelled confirmation or pick sends nothing', (tester) async {
      launchError = missingOn(holder: false);
      await open(tester, transfer: transfer(), packages: packages);
      await run(tester);
      await tester.tap(find.byKey(const Key('launch-send-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-confirm-cancel')));
      await tester.pumpAndSettle();
      expect(packages.picks, 0);

      await run(tester);
      await tester.tap(find.byKey(const Key('launch-send-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-confirm-ok')));
      await tester.pumpAndSettle();
      expect(packages.picks, 1, reason: 'the user closed the picker');
      expect(transfers, isEmpty);
      expect(launched, hasLength(2), reason: 'two launches, no third one');
    });

    testWidgets('a failed transfer says why, and the launch does not run again', (tester) async {
      launchError = missingOn();
      sendError = const CelautError(kind: CelautErrorKind.transferFailed, message: 'the file is cut');
      await open(tester, transfer: transfer(), packages: packages);
      await run(tester);
      await tester.tap(find.byKey(const Key('launch-send-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-confirm-ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('send-failed')), findsOneWidget);
      expect(find.text(appL10n.celautErrorTransferFailed), findsOneWidget);
      expect(find.text('the file is cut'), findsOneWidget);
      expect(launched, hasLength(1));
    });

    testWidgets('the node can store it and refuse the quote: its reason is shown', (tester) async {
      launchError = missingOn();
      sendError = const CelautError(kind: CelautErrorKind.unsupportedArchitecture, message: 'riscv64');
      await open(tester, transfer: transfer(), packages: packages);
      await run(tester);
      await tester.tap(find.byKey(const Key('launch-send-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-confirm-ok')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.celautErrorUnsupportedArchitecture), findsOneWidget);
    });

    testWidgets('a file of another service is loaded but not sent, and the reason is shown', (tester) async {
      launchError = missingOn(holder: false);
      packages.picked = const PickedPackage(path: '/cache/other.bee', bytes: 10, name: 'other');
      final lib = _Lib()..imports = _other;
      await open(tester, transfer: transfer(), packages: packages, lib: lib);
      await run(tester);
      await tester.tap(find.byKey(const Key('launch-send-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-confirm-ok')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.celautSendOtherService), findsOneWidget);
      expect(transfers, isEmpty);
      // The dialog with the reason is open: the library itself says that the file stays.
      expect(lib.stored.map((p) => p.serviceId), [_other], reason: 'it stays in the library');
    });

    testWidgets('a service that the user loaded is sent from the library, with no file to pick', (tester) async {
      launchError = missingOn();
      final lib = _Lib()..stored = [_Lib().view()];
      await open(tester, transfer: transfer(), packages: packages, lib: lib);
      await run(tester);
      expect(find.text(appL10n.celautSendFromLibrary('q.example:9')), findsOneWidget);
      expect(find.text(appL10n.celautSendNoHolder), findsNothing);
      await tester.tap(find.byKey(const Key('launch-send-service')));
      await tester.pumpAndSettle();
      launchError = null;
      await tester.tap(find.byKey(const Key('send-confirm-ok')));
      await tester.pumpAndSettle();
      expect(packages.picks, 0);
      expect(transfers, ['send q.example /data/packages/library/$_best.bee'], reason: 'no fetch from a node');
      expect(launched, hasLength(2));
    });

    testWidgets('the progress shows the bytes and the percent, and Cancel stops the transfer', (tester) async {
      launchError = missingOn();
      hold = Completer<void>();
      progress = TransferView(
        stage: TransferStage.sending,
        bytes: BigInt.from(512 * 1024),
        total: BigInt.from(1024 * 1024),
      );
      await open(tester, transfer: transfer(), packages: packages);
      await run(tester);
      await tester.tap(find.byKey(const Key('launch-send-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('send-confirm-ok')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('send-progress')), findsOneWidget);
      expect(find.text(appL10n.celautSendSending), findsOneWidget);
      expect(find.textContaining('50%'), findsOneWidget);
      await tester.tap(find.byKey(const Key('send-cancel')));
      await tester.pump();
      expect(transfers.last, 'cancel');
      sendError = const CelautError(kind: CelautErrorKind.transferFailed, message: 'the transfer was cancelled');
      hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('send-progress')), findsNothing);
      expect(find.byKey(const Key('send-failed')), findsOneWidget);
    });
  });

  testWidgets('the failure sheet says that there is no node when the list is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LaunchFailureSheet(failure: LaunchFailure(LaunchFailureKind.noNodes))),
      ),
    );
    expect(find.text(appL10n.celautRunFailedNoNodes), findsOneWidget);
    expect(find.byKey(const Key('launch-failure-deposit')), findsNothing);
  });

  testWidgets('a Celaut error of the quotes is a message, not a crash', (tester) async {
    launchError = const CelautError(kind: CelautErrorKind.unreachable, message: 'x');
    await open(tester);
    await run(tester);
    expect(find.text(appL10n.celautErrorUnreachable), findsOneWidget);
    expect(find.byKey(const Key('run-progress')), findsNothing);
  });

  group('environment variables', () {
    final store = EnvStore(
      names: () => [EnvNameView(name: 'OPENAI_KEY', changedAt: 1, sensitive: true)],
      get: (n) => 'secret',
      set: (n, v, s) {},
      delete: (n) {},
    );
    const declared = [
      DeclaredVariableView(name: 'API_KEY', tags: ['text'], prose: 'The key of the API'),
      DeclaredVariableView(name: 'MODE', tags: [], prose: ''),
    ];

    testWidgets('a service that declares nothing starts with no question', (tester) async {
      await open(tester, askEnvironment: true, inspect: (id, node) async => _info(), envStore: store);
      await run(tester);
      expect(find.byKey(const Key('env-step')), findsNothing);
      expect(envChosen, isEmpty);
      expect(launched, hasLength(1));
    });

    testWidgets('the declared variables are asked one by one and go to the start', (tester) async {
      final asked = <(String, int)>[];
      await open(
        tester,
        askEnvironment: true,
        inspect: (id, node) async {
          asked.add((id, node!.port));
          return _info(env: declared);
        },
        envStore: store,
      );
      await run(tester);
      // The declaration is read from the node of the best quote.
      expect(asked, [(_best, 18460)]);
      expect(find.text('Variable 1 of 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('env-ask-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-pick-OPENAI_KEY')));
      await tester.pumpAndSettle();
      expect(find.text('Variable 2 of 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('env-ask-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      expect(envChosen!.map((c) => (c.name, c.container, c.text)), [('API_KEY', 'OPENAI_KEY', null)]);
      expect(find.byKey(const Key('env-step')), findsNothing);
    });

    const egress = [
      NetworkView(tags: ['api.example.com'], prose: '', formal: '', protocolStack: []),
    ];

    testWidgets('a sensitive value for a service with egress: red review, Deny cancels the launch', (tester) async {
      await open(
        tester,
        askEnvironment: true,
        inspect: (id, node) async => _info(env: declared, networks: egress),
        envStore: store,
      );
      await run(tester);
      await tester.tap(find.byKey(const Key('env-ask-pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-pick-OPENAI_KEY')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-ask-skip')));
      await tester.pumpAndSettle();
      // One review: the exit and the node of the quote, which is not trusted.
      expect(find.byKey(const Key('env-warning-egress')), findsOneWidget);
      expect(find.textContaining('api.example.com'), findsOneWidget);
      expect(find.textContaining('127.0.0.1:18460'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('env-deny'))).autofocus, isTrue);
      await tester.tap(find.byKey(const Key('env-deny')));
      await tester.pumpAndSettle();
      expect(envChosen, isNull, reason: 'nothing goes to a node');
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('a value that is not sensitive on a trusted node starts with no warning', (tester) async {
      await open(
        tester,
        askEnvironment: true,
        inspect: (id, node) async => _info(env: declared, networks: egress),
        envStore: store,
        trustedNodes: () => {_best},
      );
      await run(tester);
      await tester.tap(find.byKey(const Key('env-ask-type')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('env-typed')), 'fast');
      await tester.tap(find.byKey(const Key('env-typed-use')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-ask-skip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('env-warning-egress')), findsNothing);
      expect(find.byKey(const Key('env-warning')), findsNothing);
      expect(find.byKey(const Key('env-deny')), findsNothing);
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      expect(envChosen!.map((c) => (c.name, c.text)), [('API_KEY', 'fast')]);
    });

    testWidgets('Done on the keyboard uses the typed value, as its button', (tester) async {
      await open(
        tester,
        askEnvironment: true,
        inspect: (id, node) async => _info(env: declared, networks: egress),
        envStore: store,
        trustedNodes: () => {_best},
      );
      await run(tester);
      await tester.tap(find.byKey(const Key('env-ask-type')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byKey(const Key('env-typed')));
      expect(field.textInputAction, TextInputAction.done);
      await tester.enterText(find.byKey(const Key('env-typed')), 'fast');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-ask-skip')));
      await tester.pumpAndSettle();
      // The review comes before the start, as after the button.
      expect(envChosen, isNull);
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      expect(envChosen!.map((c) => (c.name, c.text)), [('API_KEY', 'fast')]);
    });

    testWidgets('cancelling the question cancels the launch without a failure sheet', (tester) async {
      await open(tester, askEnvironment: true, inspect: (id, node) async => _info(env: declared), envStore: store);
      await run(tester);
      await tester.tap(find.byKey(const Key('env-cancel')));
      await tester.pumpAndSettle();
      expect(envChosen, isNull);
      expect(changed, 0);
      expect(find.byKey(const Key('env-step')), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    /// Run, and stop at the dialog: the progress bar of the section animates for as long as
    /// it is open, so the test cannot wait for it to settle.
    Future<void> runUntilDialog(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-sheet-run')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-confirm-ok')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a declaration that cannot be read offers to run with no variables', (tester) async {
      Future<ServiceInfoView> broken(String id, NodeAddress? node) async =>
          throw const CelautError(kind: CelautErrorKind.protocol, message: 'too large');
      await open(tester, askEnvironment: true, inspect: broken, envStore: store);
      await runUntilDialog(tester);
      expect(find.byKey(const Key('env-unreadable')), findsOneWidget);
      await tester.tap(find.byKey(const Key('env-run-without')));
      await tester.pumpAndSettle();
      expect(envChosen, isEmpty);
      expect(changed, 1);
    });

    testWidgets('a declaration that cannot be read can be cancelled', (tester) async {
      Future<ServiceInfoView> broken(String id, NodeAddress? node) async =>
          throw const CelautError(kind: CelautErrorKind.protocol, message: 'too large');
      await open(tester, askEnvironment: true, inspect: broken, envStore: store);
      await runUntilDialog(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(envChosen, isNull);
      expect(changed, 0);
    });

    testWidgets('an interface that Chatui does not support gets an alert before the start', (tester) async {
      await open(
        tester,
        askEnvironment: true,
        inspect: (id, node) async => _info(chat: ChatSupportView.unsupported),
        envStore: store,
      );
      await runUntilDialog(tester);
      expect(find.byKey(const Key('chat-unsupported')), findsOneWidget);
      expect(find.text(appL10n.celautChatUnsupportedTitle), findsOneWidget);
      // Nothing has started yet, and Cancel ends the launch for good.
      await tester.tap(find.byKey(const Key('chat-unsupported-cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(envChosen, isNull);
      expect(changed, 0);
    });

    testWidgets('the alert can be run anyway, and then the variables are asked', (tester) async {
      await open(
        tester,
        askEnvironment: true,
        inspect: (id, node) async => _info(
          chat: ChatSupportView.unsupported,
          env: const [DeclaredVariableView(name: 'MODE', tags: [], prose: '')],
        ),
        envStore: store,
      );
      await runUntilDialog(tester);
      await tester.tap(find.byKey(const Key('chat-unsupported-run')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Variable 1 of 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('env-ask-skip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('env-run')));
      await tester.pumpAndSettle();
      expect(envChosen, isEmpty);
      expect(changed, 1);
    });

    testWidgets('the alert opens the details of the service without reading it again', (tester) async {
      var reads = 0;
      await open(
        tester,
        askEnvironment: true,
        inspect: (id, node) async {
          reads++;
          return _info(chat: ChatSupportView.unsupported);
        },
        envStore: store,
      );
      await runUntilDialog(tester);
      await tester.tap(find.byKey(const Key('chat-unsupported-details')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('service-info-chat-unsupported')), findsOneWidget);
      expect(reads, 1);
    });

    testWidgets('a service that was too large to read is not called unsupported', (tester) async {
      await open(
        tester,
        askEnvironment: true,
        inspect: (id, node) async => _info(chat: ChatSupportView.unknown, truncated: true),
        envStore: store,
      );
      await runUntilDialog(tester);
      expect(find.byKey(const Key('chat-unsupported')), findsNothing);
      expect(find.byKey(const Key('env-unreadable')), findsOneWidget);
      await tester.tap(find.byKey(const Key('env-run-without')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(envChosen, isEmpty);
    });

    testWidgets('an interface too large to decode is not called unsupported either', (tester) async {
      await open(
        tester,
        askEnvironment: true,
        inspect: (id, node) async => _info(chat: ChatSupportView.unknown),
        envStore: store,
      );
      await runUntilDialog(tester);
      expect(find.byKey(const Key('chat-unsupported')), findsNothing);
      expect(find.byKey(const Key('env-unreadable')), findsOneWidget);
    });

    testWidgets('a supported interface starts with no alert', (tester) async {
      await open(tester, askEnvironment: true, inspect: (id, node) async => _info(), envStore: store);
      await run(tester);
      expect(find.byKey(const Key('chat-unsupported')), findsNothing);
      expect(envChosen, isEmpty);
    });

    testWidgets('the confirmation has a button for the details of the service', (tester) async {
      await open(tester, preview: _quote(), inspect: (id, node) async => _info());
      await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-sheet-run')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-confirm-details')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('service-info-chat-supported')), findsOneWidget);
      expect(launched, isEmpty);
    });

    testWidgets('on a small phone, Cancel and Run share one row', (tester) async {
      await open(tester, preview: _quote(), theme: argusTheme(watchful: false));
      // 360 x 640 dp. (The glyphs of the test font are squares, wider than those of the
      // app, so the larger text sizes are checked on a device.)
      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-skill-skill-sat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skill-sheet-run')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cancel = tester.getRect(find.byKey(const Key('run-confirm-cancel')));
      final run = tester.getRect(find.byKey(const Key('run-confirm-ok')));
      expect(run.center.dy, moreOrLessEquals(cancel.center.dy, epsilon: 1));
      expect(run.left, greaterThan(cancel.right));
      // The details are in the content, above the actions.
      final content = find.descendant(of: find.byKey(const Key('run-confirm')), matching: find.byType(SingleChildScrollView));
      expect(find.descendant(of: content, matching: find.byKey(const Key('run-confirm-details'))), findsOneWidget);
    });
  });
}
