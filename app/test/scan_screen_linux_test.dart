import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/services/linux_app.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

// Issue #153: the camera plugin of flutter_zxing has no Linux side, so the Linux app reads
// the code from an image, as on macOS (scan_screen_macos_test.dart). The read itself
// (zxing on a real PNG) runs in the real runner (integration_test/linux_platform_test.dart).
void main() {
  tearDown(() => debugLinuxAppOverride = null);

  Future<Object?> open(WidgetTester tester, Future<Code?> Function() choose) async {
    Object? result = 'none';
    await tester.pumpWidget(MaterialApp(
      theme: argusTheme(watchful: false),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.push<Object?>(
              context,
              MaterialPageRoute(builder: (_) => ScanScreen(chooseImage: choose)),
            );
          },
          child: const Text('scan'),
        ),
      ),
    ));
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.scanFromImageNoteLinux), findsOneWidget);
    expect(find.text(appL10n.scanFromImageNote), findsNothing);
    expect(find.text(appL10n.scanCameraUnavailable), findsNothing);
    await tester.tap(find.byKey(const Key('scan-image-choose')));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('the Linux app reads the code of a chosen image', (tester) async {
    debugLinuxAppOverride = true;
    final result = await open(tester, () async => Code(text: ' celaut://node?addr=1.2.3.4:5 ', isValid: true));
    expect(result, 'celaut://node?addr=1.2.3.4:5');
  });

  testWidgets('an image with no code says so and stays', (tester) async {
    debugLinuxAppOverride = true;
    final result = await open(tester, () async => Code(isValid: false, error: 'not found'));
    expect(result, 'none');
    expect(find.byKey(const Key('scan-image-none')), findsOneWidget);
    expect(find.byKey(const Key('scan-image-choose')), findsOneWidget);
  });
}
