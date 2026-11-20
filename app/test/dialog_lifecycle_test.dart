import 'package:argus_wallet/bridge/frb_generated.dart';
import 'package:argus_wallet/format.dart';
import 'package:argus_wallet/services/address_label_service.dart';
import 'package:argus_wallet/services/contacts_service.dart';
import 'package:argus_wallet/services/wallet_service.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/contacts_screen.dart';
import 'package:argus_wallet/ui/receive_screen.dart';
import 'package:argus_wallet/ui/send_screen.dart';
import 'package:argus_wallet/ui/settings/security_settings_page.dart';
import 'package:argus_wallet/ui/settings/settings_shared.dart';
import 'package:argus_wallet/ui/settings/wallet_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/dialog_harness.dart';

// Every dialog outside the home screen that asks for text or a PIN, opened
// from where the app opens it, answered both ways, and pumped through its
// exit animation (see support/dialog_harness.dart). The home screen's own
// are in dialog_lifecycle_home_test.dart.

const _ergo = '9eatpGQdYNjTi5ZZLK7Bo7C3ms6oECPnxbQTRn6sDcBNLMYSCa8';
const _ergoOld = '9hY16vzHmmfyVBwKeFGHvb2bMFsG94A1u7To1QWtUokACyFVENQ';

void main() {
  final api = DialogApi();
  setUpAll(() => RustLib.initMock(api: api));

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'argus_contacts': '[]',
      'argus_address_labels': '[]',
    });
    await contactsService.load();
    await addressLabelService.load();
    api.wrappedUnder.clear();
  });

  tearDown(() async {
    if (walletService.isUnlocked) await walletService.lock();
  });

  /// The wallet unlocked, as Settings needs.
  Future<DialogKeystore> unlocked(WidgetTester tester) async {
    final keystore = DialogKeystore()..install(tester);
    await walletService.restoreWallet('', walletId: dialogWallet);
    return keystore;
  }

  group('Security', () {
    testWidgets('says the wallet opens with the phone, and has no PIN rows', (
      tester,
    ) async {
      tallView(tester);
      await unlocked(tester);
      await tester.pumpWidget(
        const MaterialApp(home: SecuritySettingsPage(walletId: dialogWallet)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unlock with your device'), findsOneWidget);
      expect(find.textContaining('no PIN of its own'), findsOneWidget);
      expect(find.text('Change PIN'), findsNothing);
    });
  });

  group('Receive', () {
    Widget receive() => const MaterialApp(
      home: WalletArgsScope(
        args: WalletRouteArgs(
          senderAddress: _ergo,
          receiveAddress: _ergo,
          changeAddress: _ergo,
          historyAddresses: [_ergo, _ergoOld],
        ),
        child: ReceiveScreen(),
      ),
    );

    testWidgets('Address label (a used address): Cancel, then Save', (
      tester,
    ) async {
      tallView(tester);
      await tester.pumpWidget(receive());
      await tester.pumpAndSettle();
      final row = find.text(shorten(_ergoOld, head: 12, tail: 10));

      await tester.longPress(row);
      await tester.pumpAndSettle();
      await tester.enterText(dialogField(), 'Cold storage');
      await answer(tester, 'Cancel');
      expect(addressLabelService.labelFor(_ergoOld), isNull);

      await tester.longPress(row);
      await tester.pumpAndSettle();
      await tester.enterText(dialogField(), 'Cold storage');
      await answer(tester, 'Save');
      expect(addressLabelService.labelFor(_ergoOld), 'Cold storage');
      expect(find.text('Cold storage'), findsOneWidget);
    });
  });

  testWidgets('Save to contacts (Send): Cancel, then Save', (tester) async {
    tallView(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: argusTheme(watchful: false),
        home: const WalletArgsScope(
          args: WalletRouteArgs(
            senderAddress: _ergoOld,
            receiveAddress: _ergoOld,
            changeAddress: _ergoOld,
            spendableNano: 5000000000,
          ),
          child: SendScreen(initialRecipient: _ergo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.text('Save to contacts');

    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.enterText(dialogField(), 'Alice');
    await answer(tester, 'Cancel');
    expect(contactsService.contacts, isEmpty);

    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.enterText(dialogField(), 'Alice');
    await answer(tester, 'Save');
    expect(contactsService.contacts.single.name, 'Alice');
    expect(contactsService.contacts.single.address, _ergo);
    expect(find.text('Contact saved'), findsOneWidget);
  });

  testWidgets('Pin address index (wallet settings): Cancel, then Pin', (
    tester,
  ) async {
    tallView(tester);
    await unlocked(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: WalletSettingsPage(walletId: dialogWallet),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.widgetWithText(SettingsRow, 'Primary address: index 0');

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.enterText(dialogField(), '3');
    await answer(tester, 'Cancel');
    expect(await walletService.getPinnedAddressIndex(walletId: dialogWallet), 0);

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.enterText(dialogField(), '3');
    await answer(tester, 'Pin');
    expect(await walletService.getPinnedAddressIndex(walletId: dialogWallet), 3);
    expect(find.text('Primary address: index #3'), findsOneWidget);
    expect(find.text('Pinned index 3 · addr3'), findsOneWidget);
  });

  testWidgets('the settings of the wallet have no name and no Rename', (tester) async {
    tallView(tester);
    await unlocked(tester);
    await tester.pumpWidget(const MaterialApp(home: WalletSettingsPage(walletId: dialogWallet)));
    await tester.pumpAndSettle();
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Name'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('Add contact and Edit contact: Cancel, then save each', (
    tester,
  ) async {
    tallView(tester);
    await tester.pumpWidget(const MaterialApp(home: ContactsScreen()));
    await tester.pumpAndSettle();

    Future<void> add() async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(dialogField('Name'), 'Bob');
      await tester.enterText(dialogField('Address'), _ergo);
    }

    await add();
    await answer(tester, 'Cancel');
    expect(contactsService.contacts, isEmpty);

    await add();
    await answer(tester, 'Add');
    expect(contactsService.contacts.single.name, 'Bob');

    Future<void> edit() async {
      await tester.tap(find.text(contactsService.contacts.single.name));
      await tester.pumpAndSettle();
      expect(find.text('Edit contact'), findsOneWidget);
      await tester.enterText(dialogField('Name'), 'Robert');
    }

    await edit();
    await answer(tester, 'Cancel');
    expect(contactsService.contacts.single.name, 'Bob');

    await edit();
    await answer(tester, 'Save');
    expect(contactsService.contacts.single.name, 'Robert');
    expect(find.text('Robert'), findsOneWidget);
  });
}
