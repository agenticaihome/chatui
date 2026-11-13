
import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_home.dart';
import 'package:argus_wallet/bridge/api/celaut_invite.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/bridge/frb_generated.dart';
import 'package:argus_wallet/celaut/celaut_link.dart';
import 'package:argus_wallet/celaut/celaut_strings.dart';
import 'package:argus_wallet/celaut/host_port.dart';
import 'package:argus_wallet/celaut/invite_scan.dart';
import 'package:argus_wallet/format.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/known_nodes_screen.dart';
import 'package:argus_wallet/ui/celaut/node_connect_screen.dart';
import 'package:argus_wallet/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _a = 'aa' * 32;
final _b = 'bb' * 32;

/// The node list as the database keeps it: a removed node keeps its record and its
/// deposits, and comes back with them.
class _Db implements KnownNodes {
  final records = <String, ({List<String> addresses, int deposited, bool listed})>{
    'aa' * 32: (addresses: ['a.example:1'], deposited: 10000000, listed: true),
  };
  final byAddress = {'a.example:1': 'aa' * 32, 'b.example:2': 'bb' * 32};
  final errors = <CelautError>[];
  final adds = <String>[];

  /// The nodes that the user marked as fully trusted.
  final trusted = <String>{};

  @override
  void setTrusted(String peerId, bool value) => value ? trusted.add(peerId) : trusted.remove(peerId);

  /// The priority (reputation) that the user set, by node. A node with none has 50.
  final priorities = <String, int>{};

  @override
  void setPriority(String peerId, int priority) => priorities[peerId] = priority;

  /// The answers of `connectInvite`, in order, and the bytes that it was given.
  final invites = <InviteConnectView>[];
  final invited = <Uint8List>[];

  /// The invitations that were read for the confirmation, and the errors of the reader.
  final read = <Uint8List>[];
  final readErrors = <CelautError>[];

  @override
  InviteReadView readInvite(Uint8List invite) {
    read.add(invite);
    if (readErrors.isNotEmpty) throw readErrors.removeAt(0);
    final key = invite.sublist(2, 34).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return InviteReadView(
      peerId: key,
      addresses: const [
        InviteAddrView(address: 'b.example:2'),
        InviteAddrView(address: 'x.onion:3', skipped: InviteAttemptKind.onionNeedsProxy),
      ],
      listed: records[key]?.listed ?? false,
    );
  }

  @override
  Future<InviteConnectView> connectInvite(Uint8List invite) async {
    invited.add(invite);
    if (errors.isNotEmpty) throw errors.removeAt(0);
    final view = invites.removeAt(0);
    final node = view.node;
    if (node != null) {
      records[node.peerId] = (
        addresses: node.addresses,
        deposited: records[node.peerId]?.deposited ?? 0,
        listed: true,
      );
    }
    return view;
  }

  KnownNodeView _view(String peer) => KnownNodeView(
    peerId: peer,
    addresses: records[peer]!.addresses,
    depositedNanoErg: BigInt.from(records[peer]!.deposited),
    trusted: trusted.contains(peer),
    // A node of full trust counts as 100 for the balancer, as the Rust side says.
    priority: trusted.contains(peer) ? 100 : priorities[peer] ?? 50,
    setPriority: priorities[peer] ?? 50,
  );

  @override
  List<KnownNodeView> list() => [
    for (final e in records.entries)
      if (e.value.listed) _view(e.key),
  ];

  @override
  Future<KnownNodeView> add(NodeAddress node) async {
    final address = '${node.host}:${node.port}';
    adds.add(address);
    if (errors.isNotEmpty) throw errors.removeAt(0);
    final peer = byAddress[address]!;
    final old = records[peer];
    records[peer] = (
      addresses: old?.addresses ?? [address],
      deposited: old?.deposited ?? 0,
      listed: true,
    );
    return _view(peer);
  }

  @override
  void remove(String peerId) {
    final old = records[peerId]!;
    records[peerId] = (addresses: old.addresses, deposited: old.deposited, listed: false);
  }
}

class _Api extends RustLibApi {
  @override
  List<KnownNodeView> crateApiCelautHomeCelautKnownNodes() => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => RustLib.initMock(api: _Api()));

  Future<_Db> pump(
    WidgetTester tester, {
    List<String>? made,
    List<String?>? scans,
    List<ScannedCode?>? codes,
    bool camera = false,
    _Db? with_,
    Uint8List? invite,
    HostPort? address,
  }) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = with_ ?? _Db();
    await tester.pumpWidget(
      MaterialApp(
        home: KnownNodesScreen(
          nodes: db,
          newClient: (node) async {
            made?.add('${node.host}:${node.port}');
            return NewClientView(peerId: _b, earlierClients: 1);
          },
          invite: invite,
          address: address,
          // The QR codes that the scanner reads, in order; null is "back". With
          // `camera`, the app's scanner opens (the test has no camera).
          scan: camera
              ? null
              : (_) async {
                  if (codes != null) return codes.removeAt(0);
                  final text = scans!.removeAt(0);
                  return text == null ? null : ScannedCode.text(text);
                },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('add a node by its address and remove it; its deposits stay', (tester) async {
    final db = await pump(tester);
    expect(find.byKey(Key('nodes-row-$_a')), findsOneWidget);
    expect(find.text(appL10n.celautNodesDeposited(formatErg(10000000))), findsOneWidget);

    await tester.enterText(find.byKey(const Key('nodes-address')), 'b.example:2');
    await tester.tap(find.byKey(const Key('nodes-add')));
    await tester.pumpAndSettle();
    expect(db.adds, ['b.example:2']);
    expect(find.byKey(Key('nodes-row-$_b')), findsOneWidget);
    expect(find.text(appL10n.celautNodesAdded), findsOneWidget);

    await tester.tap(find.byKey(Key('nodes-remove-$_a')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('nodes-row-$_a')), findsNothing);
    expect(find.text(appL10n.celautNodesRemoved), findsOneWidget);
    // The record and its deposits stay in the database.
    expect(db.records[_a]!.deposited, 10000000);

    // Adding it again restores them.
    await tester.enterText(find.byKey(const Key('nodes-address')), 'a.example:1');
    await tester.tap(find.byKey(const Key('nodes-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('nodes-row-$_a')), findsOneWidget);
    expect(find.text(appL10n.celautNodesDeposited(formatErg(10000000))), findsOneWidget);
  });

  testWidgets('a node has a Details action to its detail; the list never shows the client id (#123)', (tester) async {
    await pump(tester);
    expect(find.text(appL10n.celautClientIdLabel), findsNothing);
    await tester.tap(find.byKey(Key('nodes-detail-$_a')));
    await tester.pumpAndSettle();
    final detail = tester.widget<NodeConnectScreen>(find.byType(NodeConnectScreen));
    expect(detail.address, 'a.example:1');
    expect(detail.expectedPeerId, _a);
  });

  testWidgets('a bad address calls nothing', (tester) async {
    final db = await pump(tester);
    await tester.enterText(find.byKey(const Key('nodes-address')), 'no port');
    await tester.tap(find.byKey(const Key('nodes-add')));
    await tester.pumpAndSettle();
    expect(db.adds, isEmpty);
  });

  testWidgets('a node is not trusted until the user marks it, and the mark can be taken back', (tester) async {
    final db = await pump(tester);
    final mark = find.byKey(Key('nodes-trusted-$_a'));
    expect(tester.widget<SwitchListTile>(mark).value, isFalse);
    expect(find.text(appL10n.celautNodesTrusted), findsOneWidget);
    await tester.tap(mark);
    await tester.pumpAndSettle();
    expect(db.trusted, {_a});
    expect(tester.widget<SwitchListTile>(mark).value, isTrue);
    await tester.tap(mark);
    await tester.pumpAndSettle();
    expect(db.trusted, isEmpty);
    expect(tester.widget<SwitchListTile>(mark).value, isFalse);
  });

  testWidgets('the priority of a node is a slider that starts at neutral, and full trust makes it 100', (tester) async {
    final db = await pump(tester);
    final slider = find.byKey(Key('nodes-priority-$_a'));
    expect(tester.widget<Slider>(slider).value, 50);
    expect(find.text(appL10n.celautNodesPriority(50)), findsOneWidget);
    // Drag to the right end: the slider gives its maximum, 100.
    await tester.drag(slider, const Offset(800, 0));
    await tester.pumpAndSettle();
    expect(db.priorities[_a], 100);
    expect(find.text(appL10n.celautNodesPriority(100)), findsOneWidget);
    db.priorities[_a] = 30;
    // Full trust: the slider shows 100 and cannot be moved; taking it back returns to 30.
    await tester.tap(find.byKey(Key('nodes-trusted-$_a')));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value, 100);
    expect(tester.widget<Slider>(slider).onChanged, isNull);
    expect(find.text(appL10n.celautNodesPriorityFullTrust), findsOneWidget);
    await tester.tap(find.byKey(Key('nodes-trusted-$_a')));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value, 30);
    expect(tester.widget<Slider>(slider).onChanged, isNotNull);
  });

  testWidgets('add a node by a QR code: the same check as a typed address', (tester) async {
    final db = await pump(tester, scans: ['celaut://node?addr=b.example:2', '[::1]:9']);
    await tester.tap(find.byKey(const Key('nodes-scan')));
    await tester.pumpAndSettle();
    expect(db.adds, ['b.example:2']);
    expect(find.byKey(Key('nodes-row-$_b')), findsOneWidget);
    expect(find.text(appL10n.celautNodesAdded), findsOneWidget);
    expect(find.byKey(const Key('nodes-error')), findsNothing);

    // A bare address goes to the node check too; this one does not answer.
    db.errors.add(const CelautError(kind: CelautErrorKind.unreachable, message: 'refused'));
    await tester.tap(find.byKey(const Key('nodes-scan')));
    await tester.pumpAndSettle();
    expect(db.adds, ['b.example:2', '::1:9']);
  });

  testWidgets('a QR code that is not a node address shows the error and stores nothing', (
    tester,
  ) async {
    final db = await pump(
      tester,
      scans: ['ergopay://example.org/pay', 'celaut://node?addr=b.example:0'],
    );
    await tester.enterText(find.byKey(const Key('nodes-address')), 'typed');
    await tester.tap(find.byKey(const Key('nodes-scan')));
    await tester.pumpAndSettle();
    expect(db.adds, isEmpty);
    expect(find.text(appL10n.celautAddressInvalid), findsOneWidget);
    // The typed text stays; the scanned text does not go into the field.
    expect(find.text('typed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nodes-scan')));
    await tester.pumpAndSettle();
    expect(db.adds, isEmpty);
    expect(find.text(appL10n.celautPortInvalid), findsOneWidget);
    expect(find.byKey(Key('nodes-row-$_b')), findsNothing);
    expect(db.records.keys, [_a]);
  });

  testWidgets('a scanned node that fails the check shows the error of a typed address', (
    tester,
  ) async {
    const refused = CelautError(kind: CelautErrorKind.unreachable, message: 'refused');
    final db = await pump(tester, scans: ['celaut://node?addr=b.example:2']);
    db.errors.add(refused);
    await tester.enterText(find.byKey(const Key('nodes-address')), 'b.example:2');
    await tester.tap(find.byKey(const Key('nodes-add')));
    await tester.pumpAndSettle();
    final typed = tester.widget<Text>(find.byKey(const Key('nodes-error'))).data;

    await tester.enterText(find.byKey(const Key('nodes-address')), '');
    db.errors.add(refused);
    await tester.tap(find.byKey(const Key('nodes-scan')));
    await tester.pumpAndSettle();
    expect(db.adds, ['b.example:2', 'b.example:2']);
    expect(tester.widget<Text>(find.byKey(const Key('nodes-error'))).data, typed);
    expect(find.byKey(Key('nodes-row-$_b')), findsNothing);
    expect(db.records.keys, [_a]);
  });

  testWidgets('back from the scanner changes nothing; the address field still works', (
    tester,
  ) async {
    final db = await pump(tester, scans: [null]);
    await tester.tap(find.byKey(const Key('nodes-scan')));
    await tester.pumpAndSettle();
    expect(db.adds, isEmpty);
    expect(find.byKey(const Key('nodes-error')), findsNothing);

    await tester.enterText(find.byKey(const Key('nodes-address')), 'b.example:2');
    await tester.tap(find.byKey(const Key('nodes-add')));
    await tester.pumpAndSettle();
    expect(db.adds, ['b.example:2']);
    expect(find.byKey(Key('nodes-row-$_b')), findsOneWidget);
  });

  testWidgets('no camera (or no permission): a message, then the address field works', (
    tester,
  ) async {
    // The camera plugin as on a phone where the user refused the camera permission.
    const channel = MethodChannel('plugins.flutter.io/camera');
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'availableCameras') {
        return [
          {'name': '0', 'lensFacing': 'back', 'sensorOrientation': 90},
        ];
      }
      throw PlatformException(code: 'CameraAccessDenied', message: 'denied');
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
    final db = await pump(tester, camera: true);
    // Nothing asks for the camera before the scanner opens.
    expect(calls, isEmpty);
    await tester.tap(find.byKey(const Key('nodes-scan')));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.scanCameraUnavailable), findsOneWidget);
    await tester.tap(find.text(appL10n.scanBack));
    await tester.pumpAndSettle();
    expect(db.adds, isEmpty);

    await tester.enterText(find.byKey(const Key('nodes-address')), 'b.example:2');
    await tester.tap(find.byKey(const Key('nodes-add')));
    await tester.pumpAndSettle();
    expect(db.adds, ['b.example:2']);
  });

  testWidgets('a node that forgot the client: a new client, then the add', (tester) async {
    final made = <String>[];
    final db = await pump(tester, made: made);
    db.errors.add(
      const CelautError(
        kind: CelautErrorKind.clientUnknown,
        message: 'This RPC requires a client_id minted by GenerateClient first.',
      ),
    );
    await tester.enterText(find.byKey(const Key('nodes-address')), 'b.example:2');
    await tester.tap(find.byKey(const Key('nodes-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('client-unknown-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('client-unknown-new')));
    await tester.pumpAndSettle();
    expect(made, ['b.example:2']);
    expect(db.adds, ['b.example:2', 'b.example:2']);
    expect(find.byKey(Key('nodes-row-$_b')), findsOneWidget);
  });

  testWidgets('Settings opens the node list and comes back without an error', (tester) async {
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
    await tester.tap(find.byKey(const Key('settings-nodes')));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.celautNodesEmpty), findsOneWidget);
    // Back to Settings: `_open` refreshes the wallets with setState. Its callback must
    // not return a Future (that was an assertion error before).
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('settings-nodes')), findsOneWidget);
  });

  group('a peer invitation', () {
    /// The bytes of an invitation as nodo writes them: field 1, the 32-byte key, first.
    Uint8List invite([int fill = 0xbb]) => Uint8List.fromList([0x0a, 0x20, ...List.filled(32, fill), 0x12, 0x00]);

    KnownNodeView nodeB(String address) =>
        KnownNodeView(peerId: _b, addresses: [address], depositedNanoErg: BigInt.zero, trusted: false, priority: 50, setPriority: 50);

    InviteAttemptView attempt(
      String address,
      InviteAttemptKind kind, {
      CelautErrorKind? error,
      String message = '',
    }) => InviteAttemptView(address: address, kind: kind, error: error, message: message);

    testWidgets('it connects by the address that worked and lists the node', (tester) async {
      final db = _Db();
      db.invites.add(
        InviteConnectView(
          peerId: _b,
          node: nodeB('b.example:2'),
          attempts: [
            attempt('203.0.113.7:1', InviteAttemptKind.failed, error: CelautErrorKind.timeout),
            attempt('b.example:2', InviteAttemptKind.connected),
          ],
        ),
      );
      final bytes = invite();
      await pump(tester, with_: db, codes: [ScannedCode(bytes: bytes)]);
      await tester.tap(find.byKey(const Key('nodes-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('node-invite-add')));
      await tester.pumpAndSettle();
      expect(db.invited, [bytes]);
      expect(db.adds, isEmpty, reason: 'it is not a typed address');
      expect(find.byKey(Key('nodes-row-$_b')), findsOneWidget);
      expect(find.text(appL10n.celautInviteConnected('b.example:2')), findsOneWidget);
      expect(find.byKey(const Key('nodes-invite-failed')), findsNothing);
      expect(find.byKey(const Key('nodes-error')), findsNothing);
    });

    testWidgets('when no address works, each one says why', (tester) async {
      final db = _Db();
      db.invites.add(
        InviteConnectView(
          peerId: _b,
          attempts: [
            attempt('203.0.113.7:1', InviteAttemptKind.failed, error: CelautErrorKind.identityMismatch),
            attempt('x.onion:2', InviteAttemptKind.onionNeedsProxy),
            attempt('[fd00::1]:3', InviteAttemptKind.privateOverTor),
          ],
        ),
      );
      await pump(tester, with_: db, codes: [ScannedCode(bytes: invite())]);
      await tester.tap(find.byKey(const Key('nodes-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('node-invite-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nodes-invite-failed')), findsOneWidget);
      expect(find.text(appL10n.celautInviteFailedTitle), findsOneWidget);
      expect(find.text('203.0.113.7:1'), findsOneWidget);
      expect(find.text(CelautStrings.errorText(CelautErrorKind.identityMismatch)), findsOneWidget);
      expect(find.text(appL10n.celautInviteOnionNeedsProxy), findsOneWidget);
      expect(find.text(appL10n.celautInvitePrivateOverTor), findsOneWidget);
      expect(find.byKey(Key('nodes-row-$_b')), findsNothing);
      expect(db.records.keys, [_a]);
    });

    testWidgets('an invitation with no address that the app knows says so', (tester) async {
      final db = _Db()..invites.add(InviteConnectView(peerId: _b, attempts: const []));
      await pump(tester, with_: db, codes: [ScannedCode(bytes: invite())]);
      await tester.tap(find.byKey(const Key('nodes-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('node-invite-add')));
      await tester.pumpAndSettle();
      expect(find.text(appL10n.celautInviteNoAddress), findsOneWidget);
    });

    testWidgets('bytes that Rust does not read as an invitation are a bad address', (tester) async {
      final db = _Db()..readErrors.add(const CelautError(kind: CelautErrorKind.invalidInput, message: 'Not a peer invitation'));
      await pump(tester, with_: db, codes: [ScannedCode(bytes: invite())]);
      await tester.tap(find.byKey(const Key('nodes-scan')));
      await tester.pumpAndSettle();
      expect(db.read, hasLength(1));
      expect(find.byKey(const Key('node-invite-confirm')), findsNothing);
      expect(db.invited, isEmpty);
      expect(find.text(appL10n.celautAddressInvalid), findsOneWidget);
      expect(db.records.keys, [_a]);
    });

    testWidgets('a code of text is never sent to the invitation reader', (tester) async {
      final db = _Db();
      final text = 'ergopay://example.org/pay';
      await pump(
        tester,
        with_: db,
        codes: [ScannedCode(text: text, bytes: Uint8List.fromList(text.codeUnits))],
      );
      await tester.tap(find.byKey(const Key('nodes-scan')));
      await tester.pumpAndSettle();
      expect(db.invited, isEmpty);
      expect(find.text(appL10n.celautAddressInvalid), findsOneWidget);
    });

    testWidgets('bytes that begin as an invitation but are too short are not one', (tester) async {
      expect(looksLikeInvite(Uint8List.fromList([0x0a, 0x20, 1, 2, 3])), isFalse);
      expect(looksLikeInvite(null), isFalse);
      expect(looksLikeInvite(invite()), isTrue);
      expect(looksLikeInvite(Uint8List.fromList([0x0a, 0x1f, ...List.filled(40, 1)])), isFalse);
    });

    testWidgets('a node that forgot the client id asks the user, and a new client connects again', (
      tester,
    ) async {
      final made = <String>[];
      final db = _Db();
      db.invites
        ..add(
          InviteConnectView(
            peerId: _b,
            attempts: [
              attempt(
                'b.example:2',
                InviteAttemptKind.failed,
                error: CelautErrorKind.clientUnknown,
                message: 'unknown client',
              ),
            ],
          ),
        )
        ..add(
          InviteConnectView(
            peerId: _b,
            node: nodeB('b.example:2'),
            attempts: [attempt('b.example:2', InviteAttemptKind.connected)],
          ),
        );
      await pump(tester, with_: db, made: made, codes: [ScannedCode(bytes: invite())]);
      await tester.tap(find.byKey(const Key('nodes-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('node-invite-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('client-unknown-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('client-unknown-new')));
      await tester.pumpAndSettle();
      expect(made, ['b.example:2']);
      expect(db.invited, hasLength(2));
      expect(find.byKey(Key('nodes-row-$_b')), findsOneWidget);
      expect(find.byKey(const Key('nodes-invite-failed')), findsNothing);
    });
    testWidgets('the confirmation shows the key and the addresses, and Cancel connects nothing', (tester) async {
      final db = _Db();
      final bytes = invite();
      await pump(tester, with_: db, codes: [ScannedCode(bytes: bytes)]);
      await tester.tap(find.byKey(const Key('nodes-scan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('node-invite-confirm')), findsOneWidget);
      expect(find.text(appL10n.celautLinkConfirmTitle), findsOneWidget);
      expect(find.text('bbbbbb…bbbb'), findsOneWidget, reason: 'the key in short form');
      expect(find.text('b.example:2'), findsOneWidget);
      expect(find.text('x.onion:3'), findsOneWidget);
      expect(find.text(appL10n.celautLinkConfirmSkipped), findsOneWidget);
      expect(find.byKey(const Key('node-invite-listed')), findsNothing);
      await tester.tap(find.byKey(const Key('node-invite-cancel')));
      await tester.pumpAndSettle();
      expect(db.read, [bytes]);
      expect(db.invited, isEmpty);
      expect(db.records.keys, [_a]);
    });

    testWidgets('the confirmation says when the node is already in the list', (tester) async {
      final db = _Db();
      await pump(tester, with_: db, codes: [ScannedCode(bytes: invite(0xaa))]);
      await tester.tap(find.byKey(const Key('nodes-scan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('node-invite-listed')), findsOneWidget);
    });

    testWidgets('a QR code with the text of a celaut:// invitation link is an invitation', (tester) async {
      final db = _Db();
      db.invites.add(
        InviteConnectView(
          peerId: _b,
          node: nodeB('b.example:2'),
          attempts: [attempt('b.example:2', InviteAttemptKind.connected)],
        ),
      );
      final bytes = invite();
      await pump(tester, with_: db, scans: [celautInviteLink(bytes)]);
      await tester.tap(find.byKey(const Key('nodes-scan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('node-invite-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('node-invite-add')));
      await tester.pumpAndSettle();
      expect(db.invited, [bytes]);
      expect(find.byKey(Key('nodes-row-$_b')), findsOneWidget);
    });

    testWidgets('a damaged invitation link in a QR code is a bad address', (tester) async {
      final db = _Db();
      await pump(tester, with_: db, scans: ['celaut://node?invite=AAAA']);
      await tester.tap(find.byKey(const Key('nodes-scan')));
      await tester.pumpAndSettle();
      expect(db.read, isEmpty);
      expect(find.text(appL10n.celautAddressInvalid), findsOneWidget);
    });

    testWidgets('opened with an invitation that the user confirmed, it connects at once', (tester) async {
      final db = _Db();
      db.invites.add(
        InviteConnectView(
          peerId: _b,
          node: nodeB('b.example:2'),
          attempts: [attempt('b.example:2', InviteAttemptKind.connected)],
        ),
      );
      final bytes = invite();
      await pump(tester, with_: db, invite: bytes);
      expect(find.byKey(const Key('node-invite-confirm')), findsNothing, reason: 'the link asked already');
      expect(db.invited, [bytes]);
      expect(find.byKey(Key('nodes-row-$_b')), findsOneWidget);
      expect(find.text(appL10n.celautInviteConnected('b.example:2')), findsOneWidget);
    });

    testWidgets('opened with an address that the user confirmed, it adds it at once', (tester) async {
      final db = await pump(tester, address: const HostPort('b.example', 2));
      expect(db.adds, ['b.example:2']);
      expect(find.byKey(Key('nodes-row-$_b')), findsOneWidget);
    });
  });
}
