import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/conversation_keep_alive.dart';
import 'package:argus_wallet/ui/celaut/open_web.dart';

InstanceListView _web() => InstanceListView(
      instanceId: 'web-1',
      peerId: 'aa' * 32,
      address: 'node.example:53460',
      serviceId: '65' * 32,
      slots: Uint16List.fromList([80]),
      chatSlots: Uint16List(0),
      webSlots: Uint16List.fromList([80]),
      startedAt: 1,
      startChargeMu: '1000',
      name: 'Site',
      alias: '',
      title: '',
      refundMu: '',
    );

void main() {
  testWidgets('the app is held while the browser has the page, and not after', (tester) async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('test/holds');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final holds = ForegroundHolds(channel: channel, isAndroid: true);
    Uri? opened;
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        context = c;
        return const SizedBox();
      })),
    ));

    await openWebInBrowser(
      context,
      _web(),
      openTunnel: (id, slot) async => 4321,
      launch: (uri) async {
        opened = uri;
        return true;
      },
      holds: holds,
    );
    expect(opened, Uri.parse('http://127.0.0.1:4321/'));
    expect(holds.reasons, {KeepAliveReason.conversation});
    expect(calls.map((c) => c.method), contains('start'));

    await releaseBrowserHold();
    expect(holds.reasons, isEmpty);
    expect(calls.last.method, 'stop');
  });
}
