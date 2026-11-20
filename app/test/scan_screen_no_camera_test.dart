import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The scan screen of a device with no camera scan (the Linux app, issue #153): it reads
// the code from an image file. The decode itself runs in the real runner
// (integration_test/linux_platform_test.dart).
void main() {
  testWidgets('with no camera, the scan screen offers to read the code from an image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScanScreen(camera: false),
      ),
    );
    await tester.pump();
    final l = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l.scanNoCamera), findsOneWidget);
    expect(find.text(l.scanCameraUnavailable), findsNothing);
    expect(find.byKey(const ValueKey('scan-from-image')), findsOneWidget);
    expect(find.text(l.scanFromImage), findsOneWidget);
    expect(find.text(l.scanBack), findsOneWidget);
  });
}
