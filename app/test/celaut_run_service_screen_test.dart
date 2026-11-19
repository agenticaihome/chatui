import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/run_service_screen.dart';
import 'package:argus_wallet/ui/celaut/run_service_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the screen has the title in its bar, and the section without its own title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RunServiceScreen(
          section: RunServiceSection(loadObjectives: () async => const [], showTitle: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AppBar), matching: find.text(appL10n.celautRunTitle)), findsOneWidget);
    expect(find.text(appL10n.celautRunTitle.toUpperCase()), findsNothing);
    expect(find.byKey(const Key('run-section')), findsOneWidget);
  });

  testWidgets('on the home screen the section shows its title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RunServiceSection(loadObjectives: () async => const [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(appL10n.celautRunTitle.toUpperCase()), findsOneWidget);
  });
}
