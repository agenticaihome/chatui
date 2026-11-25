import 'dart:io';

import 'package:argus_wallet/services/linux_app.dart';
import 'package:argus_wallet/services/update_service.dart';
import 'package:argus_wallet/ui/settings/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/update_fakes.dart';

/// The update notice of the Linux app (#156): the same opt-in check as on Android, and
/// for a newer release the link to its `.deb` for this architecture. No download or
/// install in the app.
void main() {
  ReleaseAsset asset(String name, int size) => ReleaseAsset(name: name, size: size, url: Uri.parse(assetUrl(name)));

  final apk = asset('superapp-1.0.0-beta.2-universal.apk', 101372707);
  final debAmd64 = asset('superapp-1.0.0-beta.2-linux-amd64.deb', 41234567);
  final debArm64 = asset('superapp-1.0.0-beta.2-linux-arm64.deb', 40123456);

  ReleaseInfo release(List<ReleaseAsset> assets) => ReleaseInfo(
        version: AppVersion.tryParse('1.0.0-beta.2')!,
        notes: 'What is new.',
        publishedAt: DateTime.utc(2026, 10, 20, 12),
        assets: assets,
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugLinuxAppOverride = null);

  group('pickDeb', () {
    test('takes the .deb of the architecture', () {
      final assets = [apk, debAmd64, debArm64];
      expect(pickDeb(assets, 'amd64'), same(debAmd64));
      expect(pickDeb(assets, 'arm64'), same(debArm64));
    });

    test('is null when the release has no .deb for it', () {
      expect(pickDeb([apk, debAmd64], 'arm64'), isNull);
      expect(pickDeb([apk], 'amd64'), isNull);
      expect(pickDeb([asset('other_1.0_amd64.deb', 10)], 'amd64'), isNull);
    });
  });

  test('the Linux app knows its architecture; flutter test is not the Linux app', () {
    expect(linuxDebArch, isNull);
    debugLinuxAppOverride = true;
    // The Abi of the test host: a Linux CI runner or the Alienware.
    if (Platform.isLinux) expect(linuxDebArch, anyOf('amd64', 'arm64'));
  });

  Future<UpdateService> openAbout(WidgetTester tester, {required String? arch, ReleaseInfo? available}) async {
    final platform = FakePlatform(null)..supported = false;
    final svc = UpdateService(platform: platform, current: AppVersion.tryParse('1.0.0-beta.1'), debArch: arch);
    await svc.ensureLoaded();
    svc.available = available;
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: AboutPage(updates: svc)));
    await tester.pumpAndSettle();
    return svc;
  }

  testWidgets('Linux: a newer release shows the link to its .deb and the apt command', (tester) async {
    debugLinuxAppOverride = true;
    final svc = await openAbout(tester, arch: 'arm64', available: release([apk, debAmd64, debArm64]));
    expect(svc.debForDevice, same(debArm64));
    expect(find.byKey(const Key('update-card')), findsOneWidget);
    expect(find.text('Download the .deb (arm64)'), findsOneWidget);
    expect(find.textContaining('superapp-1.0.0-beta.2-linux-arm64.deb · 38.3 MB. Your browser downloads it from GitHub.'), findsOneWidget);
    expect(find.text('sudo apt install ./superapp-1.0.0-beta.2-linux-arm64.deb'), findsOneWidget);
    expect(find.byKey(const Key('update-download')), findsNothing, reason: 'no in-app download');
    expect(find.byKey(const Key('update-open-releases')), findsNothing);
  });

  testWidgets('Linux: a release with no .deb for this machine points at the releases page', (tester) async {
    debugLinuxAppOverride = true;
    await openAbout(tester, arch: 'arm64', available: release([apk, debAmd64]));
    expect(find.byKey(const Key('update-download-deb')), findsNothing);
    expect(find.byKey(const Key('update-open-releases')), findsOneWidget);
  });

  testWidgets('Linux: About says what the check does there, and has no signing key row', (tester) async {
    debugLinuxAppOverride = true;
    await openAbout(tester, arch: 'amd64');
    expect(find.textContaining('On Linux, Celaut does not download or install an update'), findsOneWidget);
    expect(find.text('What changed in each alpha, and the latest .deb files.'), findsOneWidget);
    expect(find.text('Signing certificate'), findsNothing);
  });

  testWidgets('Android: no .deb link, and the Android texts', (tester) async {
    debugLinuxAppOverride = false;
    await openAbout(tester, arch: null, available: release([apk, debAmd64, debArm64]));
    expect(find.byKey(const Key('update-download-deb')), findsNothing);
    expect(find.textContaining('before Android is asked to install it'), findsOneWidget);
    expect(find.text('Signing certificate'), findsOneWidget);
  });
}
