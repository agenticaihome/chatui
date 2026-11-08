import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/bridge/api/celaut_support.dart';
import 'package:argus_wallet/bridge/frb_generated.dart';
import 'package:argus_wallet/ui/celaut/support_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _peer = 'aa' * 32;
final _node = NodeAddress(host: 'a.example', port: 1);

SupportMessageView _m(int seq, String body, {bool operator = false}) => SupportMessageView(
  sequence: BigInt.from(seq),
  ts: 1700000000 + seq,
  fromOperator: operator,
  body: body,
);

/// A node that keeps a thread. `supported: false` is a node with no support chat.
class _Fake implements SupportApi {
  _Fake({this.supported = true});

  final bool supported;
  final stored = <SupportMessageView>[];
  final asked = <int>[];
  final sent = <String>[];
  String refuse = '';
  CelautError? failure;

  @override
  Future<SupportThreadView> thread(NodeAddress node, int afterSequence) async {
    asked.add(afterSequence);
    if (failure != null) throw failure!;
    return SupportThreadView(
      supported: supported,
      messages: stored.where((m) => m.sequence.toInt() > afterSequence).toList(),
      latest: stored.isEmpty ? BigInt.zero : stored.last.sequence,
    );
  }

  @override
  Future<SupportSendView> send(NodeAddress node, String body) async {
    sent.add(body);
    if (refuse.isNotEmpty) return SupportSendView(supported: true, stored: false, reason: refuse);
    stored.add(_m(stored.length + 1, body));
    return SupportSendView(supported: true, stored: true, reason: '');
  }
}

void main() {
  setUpAll(() => RustLib.initMock(api: _NoApi()));

  Future<void> pump(WidgetTester tester, _Fake api) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SupportChatScreen(node: _node, peerId: _peer, api: api, pollInterval: const Duration(seconds: 30)),
      ),
    );
    await tester.pump();
  }

  testWidgets('an empty thread says so and has the input', (tester) async {
    await pump(tester, _Fake());
    expect(find.byKey(const Key('support-empty')), findsOneWidget);
    expect(find.byKey(const Key('support-input')), findsOneWidget);
  });

  testWidgets('shows the thread of the node with both sides', (tester) async {
    final api = _Fake()
      ..stored.addAll([_m(1, 'my instance stopped'), _m(2, 'we look at it', operator: true)]);
    await pump(tester, api);
    expect(find.text('my instance stopped'), findsOneWidget);
    expect(find.text('we look at it'), findsOneWidget);
    expect(api.asked, [0]);
  });

  testWidgets('a send gives the text trimmed, clears the input and asks only the new messages', (tester) async {
    final api = _Fake()..stored.add(_m(1, 'first'));
    await pump(tester, api);
    await tester.enterText(find.byKey(const Key('support-input')), '  second  ');
    await tester.tap(find.byKey(const Key('support-send')));
    await tester.pumpAndSettle();
    expect(api.sent, ['second']);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsOneWidget);
    // The second ask is after the message that the screen already had.
    expect(api.asked, [0, 1]);
    expect(tester.widget<TextField>(find.byKey(const Key('support-input'))).controller!.text, '');
  });

  testWidgets('an empty text is not sent', (tester) async {
    final api = _Fake();
    await pump(tester, api);
    await tester.enterText(find.byKey(const Key('support-input')), '   ');
    await tester.tap(find.byKey(const Key('support-send')));
    await tester.pump();
    expect(api.sent, isEmpty);
  });

  testWidgets('a message that the node refuses stays in the input with the reason', (tester) async {
    final api = _Fake()..refuse = 'Message is empty.';
    await pump(tester, api);
    await tester.enterText(find.byKey(const Key('support-input')), 'hello');
    await tester.tap(find.byKey(const Key('support-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-refused')), findsOneWidget);
    expect(find.textContaining('Message is empty.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('support-input'))).controller!.text, 'hello');
  });

  testWidgets('a node with no support chat says so and has no input', (tester) async {
    await pump(tester, _Fake(supported: false));
    expect(find.byKey(const Key('support-unsupported')), findsOneWidget);
    expect(find.byKey(const Key('support-input')), findsNothing);
  });

  testWidgets('the screen asks again after the poll interval', (tester) async {
    final api = _Fake();
    await pump(tester, api);
    api.stored.add(_m(1, 'an answer', operator: true));
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.text('an answer'), findsOneWidget);
  });
}

class _NoApi extends RustLibApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
