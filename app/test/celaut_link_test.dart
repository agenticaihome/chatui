import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_invite.dart';
import 'package:argus_wallet/celaut/celaut_link.dart';
import 'package:argus_wallet/celaut/host_port.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/node_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// An invitation as nodo writes it: field 1 with the 32-byte key, then one `ip4` address
/// (192.0.2.1:53460). 49 bytes, as `invite.md` says.
final _invite = Uint8List.fromList([
  0x0a, 0x20, ...List.filled(32, 0x5a), //
  0x12, 0x0d, 0x0a, 0x03, ...ascii.encode('ip4'), 0x1a, 0x06, 192, 0, 2, 1, 0xd0, 0xd4,
]);

final _peer = '5a' * 32;

void main() {
  group('parseCelautLink', () {
    test('an invitation link gives the bytes back, with or without padding', () {
      final link = celautInviteLink(_invite);
      expect(link, startsWith('celaut://node?invite='));
      expect(link.substring('celaut://node?invite='.length), isNot(contains('=')));
      final read = parseCelautLink(link);
      expect(read, isA<CelautInviteLink>());
      expect((read as CelautInviteLink).bytes, _invite);

      // A padded form, a percent-encoded padding, a slash, upper case, spaces around it and
      // another parameter (for a later version) all read the same.
      final padded = base64Url.encode(_invite);
      expect(padded, endsWith('='), reason: 'the test needs a padded form');
      for (final l in [
        'celaut://node?invite=$padded',
        'celaut://node?invite=${padded.replaceAll('=', '%3D')}',
        'celaut://node/?invite=$padded',
        'CELAUT://NODE?invite=$padded',
        '  celaut://node?v=2&invite=$padded  ',
      ]) {
        final r = parseCelautLink(l);
        expect(r, isA<CelautInviteLink>(), reason: l);
        expect((r as CelautInviteLink).bytes, _invite, reason: l);
      }
    });

    test('an address link is a node address, as in a QR code', () {
      final r = parseCelautLink('celaut://node?addr=203.0.113.7:53460');
      expect(r, isA<CelautAddressLink>());
      expect((r as CelautAddressLink).address, const HostPort('203.0.113.7', 53460));
      final v6 = parseCelautLink('celaut://node?addr=%5B2001:db8::1%5D:9');
      expect((v6 as CelautAddressLink).address, const HostPort('2001:db8::1', 9));
    });

    test('a link that is too long is refused before it is read', () {
      final huge = 'celaut://node?invite=${'A' * (1 << 20)}';
      final r = parseCelautLink(huge);
      expect((r as CelautLinkRefused).error, CelautLinkError.tooLong);
      // Just over the limit of the link, with an otherwise fine invitation.
      final over = '${celautInviteLink(_invite)}&pad=${'x' * maxCelautLinkLength}';
      expect((parseCelautLink(over) as CelautLinkRefused).error, CelautLinkError.tooLong);
    });

    test('an invitation over the size that nodo allows is refused', () {
      // 1001 bytes: valid base64 that fits in the link but not in an invitation.
      final big = Uint8List.fromList([0x0a, 0x20, ...List.filled(999, 1)]);
      expect(base64Url.encode(big).length, lessThanOrEqualTo(maxInviteChars));
      expect(
        (parseCelautLink(celautInviteLink(big)) as CelautLinkRefused).error,
        CelautLinkError.tooLong,
      );
      final chars = 'celaut://node?invite=${'A' * (maxInviteChars + 4)}';
      expect((parseCelautLink(chars) as CelautLinkRefused).error, CelautLinkError.tooLong);
      // 1000 bytes are fine for the size check (the reader of Rust decides the rest).
      final most = Uint8List.fromList([0x0a, 0x20, ...List.filled(998, 1)]);
      expect(parseCelautLink(celautInviteLink(most)), isA<CelautInviteLink>());
    });

    test('malformed links are refused with the right reason', () {
      CelautLinkError? why(String l) => switch (parseCelautLink(l)) {
            CelautLinkRefused(:final error) => error,
            _ => null,
          };
      final b64 = celautInviteLink(_invite).substring('celaut://node?invite='.length);
      expect(why('celaut://node?invite='), CelautLinkError.invalid, reason: 'empty');
      expect(why('celaut://node?invite'), CelautLinkError.invalid, reason: 'no value');
      expect(why('celaut://node?invite=$b64&invite=$b64'), CelautLinkError.invalid, reason: 'twice');
      expect(why('celaut://node?invite=${base64.encode(List.filled(60, 0xfb))}'), CelautLinkError.invalid,
          reason: 'standard base64 (+ and /) is not URL-safe');
      expect(why('celaut://node?invite=$b64!'), CelautLinkError.invalid);
      expect(why('celaut://node?invite=A'), CelautLinkError.invalid, reason: 'a length that base64 never has');
      expect(why('celaut://node?invite=A==='), CelautLinkError.invalid, reason: 'three padding characters');
      expect(why('celaut://node?invite=%zz'), CelautLinkError.invalid, reason: 'bad percent encoding');
      expect(why('celaut://node?invite=$b64#x'), CelautLinkError.invalid, reason: 'fragment');
      expect(why('celaut://service?invite=$b64'), CelautLinkError.invalid, reason: 'another host');
      expect(why('celaut://nodes?invite=$b64'), CelautLinkError.invalid);
      expect(why('celaut:node?invite=$b64'), CelautLinkError.invalid);
      expect(why('celaut://node'), CelautLinkError.invalid);
      expect(why('celaut://node?addr=nope'), CelautLinkError.invalid);
      expect(why('ergopay://example.org'), CelautLinkError.invalid);
      expect(why(''), CelautLinkError.invalid);
      // Base64 that decodes, but not to an invitation.
      expect(why('celaut://node?invite=AAAA'), CelautLinkError.damaged);
      expect(why(celautInviteLink(List.filled(40, 7))), CelautLinkError.damaged);
    });

    test('random input never throws', () {
      final rnd = Random(138);
      const alphabet = 'ABCabc019-_=%&?#/:+ é\u{1F600}';
      for (var i = 0; i < 3000; i++) {
        final n = rnd.nextInt(80);
        final junk = String.fromCharCodes(
          List.generate(n, (_) => alphabet.codeUnitAt(rnd.nextInt(alphabet.length))),
        );
        for (final l in ['celaut://node?invite=$junk', 'celaut://node?$junk', 'celaut:$junk']) {
          expect(() => parseCelautLink(l), returnsNormally, reason: l);
        }
      }
    });

    test('isCelautLink takes only the celaut scheme', () {
      expect(isCelautLink('celaut://node?invite=x'), isTrue);
      expect(isCelautLink(' CELAUT://node'), isTrue);
      expect(isCelautLink('ergopay://x'), isFalse);
      expect(isCelautLink('argus://chat/x'), isFalse);
    });
  });

  group('openCelautLink', () {
    InviteReadView view({bool listed = false}) => InviteReadView(
          peerId: _peer,
          addresses: const [
            InviteAddrView(address: '192.0.2.1:53460'),
            InviteAddrView(address: '10.0.0.2:1', skipped: InviteAttemptKind.privateOverTor),
          ],
          listed: listed,
        );

    /// What the node list was opened with, if it was.
    final opened = <({Uint8List? invite, HostPort? address})>[];

    Future<void> open(
      WidgetTester tester,
      String link, {
      InviteReadView Function(Uint8List)? read,
    }) async {
      opened.clear();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open'),
                onPressed: () => openCelautLink(
                  context,
                  link,
                  read: read ?? (_) => view(),
                  screen: ({invite, address}) {
                    opened.add((invite: invite, address: address));
                    return const Scaffold(body: Text('node list'));
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('an invitation asks first, and Add opens the node list with it', (tester) async {
      final asked = <Uint8List>[];
      await open(tester, celautInviteLink(_invite), read: (b) {
        asked.add(b);
        return view();
      });
      expect(asked, [_invite]);
      expect(find.byKey(const Key('node-invite-confirm')), findsOneWidget);
      expect(find.text(appL10n.celautLinkConfirmInvite), findsOneWidget);
      expect(find.text('5a5a5a…5a5a'), findsOneWidget);
      expect(find.text('192.0.2.1:53460'), findsOneWidget);
      expect(find.text('10.0.0.2:1'), findsOneWidget);
      expect(find.text(appL10n.celautLinkConfirmSkipped), findsOneWidget);
      expect(opened, isEmpty, reason: 'nothing before the user chooses');
      await tester.tap(find.byKey(const Key('node-invite-add')));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));
      expect(opened.single.invite, _invite);
      expect(find.text('node list'), findsOneWidget);
    });

    testWidgets('Cancel opens nothing', (tester) async {
      await open(tester, celautInviteLink(_invite), read: (_) => view(listed: true));
      expect(find.byKey(const Key('node-invite-listed')), findsOneWidget);
      await tester.tap(find.byKey(const Key('node-invite-cancel')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.byKey(const Key('node-invite-confirm')), findsNothing);
    });

    testWidgets('an address link asks first, then opens the node list with it', (tester) async {
      await open(tester, 'celaut://node?addr=203.0.113.7:53460');
      expect(find.byKey(const Key('node-address-confirm')), findsOneWidget);
      expect(find.text(appL10n.celautLinkConfirmAddress('203.0.113.7:53460')), findsOneWidget);
      await tester.tap(find.byKey(const Key('node-invite-add')));
      await tester.pumpAndSettle();
      expect(opened.single.address, const HostPort('203.0.113.7', 53460));
      expect(opened.single.invite, isNull);
    });

    testWidgets('a link that is too long says so and reads nothing', (tester) async {
      var reads = 0;
      await open(tester, 'celaut://node?invite=${'A' * 5000}', read: (_) {
        reads++;
        return view();
      });
      expect(find.byKey(const Key('celaut-link-refused')), findsOneWidget);
      expect(find.text(appL10n.celautLinkTooLong), findsOneWidget);
      expect(reads, 0);
      await tester.tap(find.byKey(const Key('celaut-link-refused-close')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
    });

    testWidgets('a malformed link says so', (tester) async {
      await open(tester, 'celaut://node?invite=no+t/base64');
      expect(find.text(appL10n.celautLinkInvalid), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('an invitation that Rust refuses is damaged', (tester) async {
      await open(
        tester,
        celautInviteLink(_invite),
        read: (_) => throw const CelautError(kind: CelautErrorKind.invalidInput, message: 'Not a peer invitation'),
      );
      expect(find.text(appL10n.celautLinkDamaged), findsOneWidget);
      expect(find.byKey(const Key('node-invite-confirm')), findsNothing);
      expect(opened, isEmpty);
    });
  });
}
