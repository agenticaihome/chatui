import 'package:argus_wallet/bridge/api/celaut_package.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/packages_usage_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PackagesStorageView _view({
  int services = 0,
  int without = 0,
  int library = 0,
  int downloads = 0,
  int incoming = 0,
}) => PackagesStorageView(
  services: services,
  withoutFilesystem: without,
  libraryBytes: BigInt.from(library),
  downloadsBytes: BigInt.from(downloads),
  incomingBytes: BigInt.from(incoming),
);

void main() {
  Future<void> open(WidgetTester tester, Future<PackagesStorageView?> Function() load) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // A new row each time: the state of an earlier one does not stay.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PackagesUsageRow(load: load))));
    await tester.pumpAndSettle();
  }

  testWidgets('says how many services there are and what they take', (tester) async {
    await open(tester, () async => _view(services: 3, library: 3 * 1024 * 1024 * 1024));
    expect(find.text(appL10n.celautStorageTitle), findsOneWidget);
    expect(find.text('3 services · 3.0 GiB'), findsOneWidget);
    // No stopped downloads, no copies, nothing kept without its filesystem: no more lines.
    expect(find.textContaining('Downloads that stopped'), findsNothing);
    expect(find.textContaining('Copies waiting'), findsNothing);
    expect(find.textContaining('without'), findsNothing);
  });

  testWidgets('with no service it says so, and with one it is singular', (tester) async {
    await open(tester, () async => _view());
    expect(find.text('No services · 0 B'), findsOneWidget);
    await open(tester, () async => _view(services: 1, library: 2048));
    expect(find.text('1 service · 2.0 KiB'), findsOneWidget);
  });

  testWidgets('adds a line for what is kept without the filesystem, the downloads and the copies', (tester) async {
    await open(tester, () async => _view(services: 4, without: 2, library: 5000, downloads: 1536, incoming: 100));
    expect(find.textContaining('4 services'), findsOneWidget);
    expect(find.textContaining('2 kept without their filesystem'), findsOneWidget);
    expect(find.textContaining('Downloads that stopped: 1.5 KiB'), findsOneWidget);
    expect(find.textContaining('Copies waiting to be loaded: 100 B'), findsOneWidget);
    await open(tester, () async => _view(services: 1, without: 1, library: 10));
    expect(find.textContaining('1 kept without its filesystem'), findsOneWidget);
  });

  testWidgets('a failed read says so and the refresh reads again', (tester) async {
    var calls = 0;
    await open(tester, () async {
      calls++;
      if (calls == 1) throw StateError('no core');
      return _view(services: 2, library: 1024);
    });
    expect(find.text(appL10n.celautStorageUnknown), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-packages-usage-refresh')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('2 services · 1.0 KiB'), findsOneWidget);
    expect(find.text(appL10n.celautStorageUnknown), findsNothing);
  });

  testWidgets('no private directory reads as unknown', (tester) async {
    await open(tester, () async => null);
    expect(find.text(appL10n.celautStorageUnknown), findsOneWidget);
  });
}
