import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/packages_storage_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester, {required bool Function() read, required void Function(bool) write}) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PackagesStorageRow(read: read, write: write))),
    );
    await tester.pumpAndSettle();
  }

  bool isOn(WidgetTester tester) =>
      tester.widget<Switch>(find.byKey(const Key('settings-keep-no-filesystem'))).value;

  testWidgets('the setting starts as the core has it, off by default, and says what it does', (tester) async {
    await open(tester, read: () => false, write: (_) {});
    expect(isOn(tester), isFalse);
    expect(find.text(appL10n.celautKeepNoFilesystemTitle), findsOneWidget);
    expect(find.text(appL10n.celautKeepNoFilesystemSubtitle), findsOneWidget);
    expect(appL10n.celautKeepNoFilesystemSubtitle, contains('cannot'));
  });

  testWidgets('turning it on and off is written to the core', (tester) async {
    var stored = false;
    final writes = <bool>[];
    await open(tester, read: () => stored, write: (v) {
      writes.add(v);
      stored = v;
    });
    await tester.tap(find.byKey(const Key('settings-keep-no-filesystem')));
    await tester.pumpAndSettle();
    expect(isOn(tester), isTrue);
    await tester.tap(find.byKey(const Key('settings-keep-no-filesystem')));
    await tester.pumpAndSettle();
    expect(isOn(tester), isFalse);
    expect(writes, [true, false]);
  });

  testWidgets('a setting that was on shows on, and a failed write leaves the switch where it was', (tester) async {
    await open(tester, read: () => true, write: (_) => throw StateError('disk'));
    expect(isOn(tester), isTrue);
    await tester.tap(find.byKey(const Key('settings-keep-no-filesystem')));
    await tester.pumpAndSettle();
    expect(isOn(tester), isTrue);
  });
}
