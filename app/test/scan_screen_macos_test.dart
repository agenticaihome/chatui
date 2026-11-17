import 'dart:typed_data';

import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

// Issue #154: the camera plugin has no macOS implementation, so on a Mac the scan reads an
// image that the user chooses. The read itself (zxing on a real PNG) runs in the macOS
// integration test (integration_test/macos_smoke_test.dart).
void main() {
  Future<Object?> open(WidgetTester tester, Future<Code?> Function() choose, {bool binary = false}) async {
    Object? result = 'none';
    await tester.pumpWidget(MaterialApp(
      theme: argusTheme(watchful: false),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.push<Object?>(
              context,
              MaterialPageRoute(builder: (_) => ScanScreen(binary: binary, chooseImage: choose)),
            );
          },
          child: const Text('scan'),
        ),
      ),
    ));
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.scanFromImageNote), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-image-choose')));
    await tester.pumpAndSettle();
    return result;
  }

  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  testWidgets('the code of the chosen image is the result', (tester) async {
    final result = await open(tester, () async => Code(text: ' celaut://node?addr=1.2.3.4:5 ', isValid: true));
    expect(result, 'celaut://node?addr=1.2.3.4:5');
  }, variant: mac);

  testWidgets('a binary scan gives the bytes', (tester) async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final result = await open(tester, () async => Code(text: 'x', rawBytes: bytes, isValid: true), binary: true);
    expect((result as dynamic).bytes, bytes);
  }, variant: mac);

  testWidgets('an image with no code says so and stays', (tester) async {
    final result = await open(tester, () async => Code(isValid: false, error: 'not found'));
    expect(result, 'none');
    expect(find.byKey(const Key('scan-image-none')), findsOneWidget);
    expect(find.byKey(const Key('scan-image-choose')), findsOneWidget);
  }, variant: mac);

  testWidgets('no image chosen: nothing happens', (tester) async {
    final result = await open(tester, () async => null);
    expect(result, 'none');
    expect(find.byKey(const Key('scan-image-none')), findsNothing);
  }, variant: mac);
}
