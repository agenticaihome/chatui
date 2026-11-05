import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:argus_wallet/ui/celaut/chat_floating.dart';

void main() {
  testWidgets('follows a child that changes its height by itself, as the keyboard that closes', (tester) async {
    final heights = <double>[];
    Future<void> pump(bool open) => tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.bottomCenter,
              child: MeasureHeight(
                onHeight: heights.add,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: SizedBox(height: open ? 300 : 50, width: 100),
                ),
              ),
            ),
          ),
        );
    await pump(true);
    await tester.pump();
    expect(heights.last, 300);
    await pump(false);
    await tester.pumpAndSettle();
    expect(heights.last, 50);
  });
}
