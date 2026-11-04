import 'package:argus_wallet/theme/argus_theme.dart';
import 'package:argus_wallet/ui/home/home_scene.dart';
import 'package:argus_wallet/ui/settings/settings_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page with the scene of the overview, as the overview and the Compute tab have it.
Widget _page({required double height, double radius = 80}) => MaterialApp(
      theme: argusTheme(watchful: true),
      home: HomeScene(
        light: SceneLight.eclipse,
        lightAt: const Offset(96, 130),
        lightRadius: radius,
        height: height,
        child: const Scaffold(backgroundColor: Colors.transparent, body: Text('page')),
      ),
    );

void main() {
  setUp(SceneImagePainter.clearImages);
  tearDown(SceneImagePainter.clearImages);

  testWidgets('the scene is drawn from one image, made once for its size and look', (tester) async {
    await tester.pumpWidget(_page(height: 520));
    expect(find.byKey(const Key('home-scene')), findsOneWidget);
    expect(SceneImagePainter.imageCount, 1);

    // A page over it and back, as a route transition does: the same image.
    await tester.pumpWidget(const MaterialApp(home: Text('other')));
    await tester.pumpWidget(_page(height: 520));
    expect(SceneImagePainter.imageCount, 1);

    // Another size or another light has its own image.
    await tester.pumpWidget(_page(height: 560));
    expect(SceneImagePainter.imageCount, 2);
    await tester.pumpWidget(_page(height: 560, radius: 70));
    expect(SceneImagePainter.imageCount, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a few images are kept, no more', (tester) async {
    for (var h = 400.0; h < 480; h += 10) {
      await tester.pumpWidget(_page(height: h));
    }
    expect(SceneImagePainter.imageCount, 5);
    expect(tester.takeException(), isNull);
  });

  for (final watchful in [true, false]) {
    testWidgets('the other pages share one scene, under a clear bar (watchful: $watchful)', (tester) async {
      Widget app(Widget page) => MaterialApp(theme: argusTheme(watchful: watchful), home: page);
      await tester.pumpWidget(
        app(
          SettingsPage(
            title: 'Nodes',
            children: [for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('row $i'))],
          ),
        ),
      );
      expect(find.byKey(const Key('home-scene')), findsOneWidget);
      expect(SceneImagePainter.imageCount, 1);

      // The bar is clear over the scene, and takes the page's colour under the list.
      final page = argusTheme(watchful: watchful).scaffoldBackgroundColor;
      Color bar() {
        final material = tester.widget<Material>(
          find.descendant(of: find.byType(AppBar), matching: find.byType(Material)).first,
        );
        return material.color!;
      }

      expect(bar().a, 0);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(bar(), page.withValues(alpha: 0.94));

      // Another page on the scene: the same image.
      await tester.pumpWidget(
        app(
          const SceneBackdrop(
            child: Scaffold(backgroundColor: Colors.transparent, body: Text('info')),
          ),
        ),
      );
      expect(find.byKey(const Key('home-scene')), findsOneWidget);
      expect(SceneImagePainter.imageCount, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
