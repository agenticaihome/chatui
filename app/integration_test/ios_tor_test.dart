// Tor (Arti, the `celaut-tor` crate) inside the app on iOS (docs/ios.md, "Tor"): the client
// bootstraps with its state in the private directory of the app, then a connection goes
// through its SOCKS5 proxy to a web server and to an onion service. It needs the Internet;
// in CI it is not a gate (the Tor network can be slow or blocked from a runner), and its
// log says how long each step took.
//
//   cd app && flutter test integration_test/ios_tor_test.dart -d <simulator or iPhone id>

import 'dart:async';
import 'dart:io';

import 'package:argus_wallet/bridge/api/celaut_network.dart';
import 'package:argus_wallet/bridge/frb_generated.dart';
import 'package:argus_wallet/services/secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The onion service of www.torproject.org.
const _torProjectOnion = '2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Arti bootstraps and connects on iOS', (tester) async {
    await RustLib.init();
    final db = await SecureStorageService.celautDbPath();
    expect(db, isNotNull);
    final dir = File(db!).parent.path;

    final watch = Stopwatch()..start();
    await celautSetNetwork(choice: NetworkChoice.embedded, dataDir: dir);
    var status = celautNetworkStatus();
    var shown = '';
    while (status.state == NetworkState.starting && watch.elapsed < const Duration(minutes: 5)) {
      final now = '${status.state.name} ${status.percent}%';
      if (now != shown) debugPrint('ARTI ${watch.elapsed.inSeconds}s $now');
      shown = now;
      await Future<void>.delayed(const Duration(seconds: 1));
      status = celautNetworkStatus();
    }
    debugPrint('ARTI_BOOTSTRAP ${status.state.name} after ${watch.elapsedMilliseconds} ms ${status.error}');
    expect(status.state, NetworkState.ready, reason: status.error);

    final proxy = celautNetworkProxy();
    expect(proxy.kind, NetworkProxyKind.socks);

    watch.reset();
    final clear = await _headThroughSocks(proxy, 'www.torproject.org', 80);
    debugPrint('ARTI_EXIT "$clear" in ${watch.elapsedMilliseconds} ms');
    expect(clear, startsWith('HTTP/1.'));

    watch.reset();
    try {
      final onion = await _headThroughSocks(proxy, _torProjectOnion, 80);
      debugPrint('ARTI_ONION "$onion" in ${watch.elapsedMilliseconds} ms');
    } on Object catch (e) {
      debugPrint('ARTI_ONION failed after ${watch.elapsedMilliseconds} ms: $e');
    }
    await celautSetNetwork(choice: NetworkChoice.off, dataDir: dir);
  });
}

/// The status line of `HEAD /` on [host]:[port], through the SOCKS5 proxy of [proxy]
/// (RFC 1928, with the user name and password of RFC 1929 when it has them).
Future<String> _headThroughSocks(NetworkProxyView proxy, String host, int port) async {
  final socket = await Socket.connect(proxy.host, proxy.port, timeout: const Duration(seconds: 30));
  final conn = _Reader(socket);
  try {
    final auth = proxy.user.isNotEmpty;
    socket.add([5, 1, auth ? 2 : 0]);
    final method = await conn.read(2);
    if (method[0] != 5 || method[1] != (auth ? 2 : 0)) throw StateError('SOCKS method $method');
    if (auth) {
      final user = proxy.user.codeUnits;
      final pass = proxy.password.codeUnits;
      socket.add([1, user.length, ...user, pass.length, ...pass]);
      final ok = await conn.read(2);
      if (ok[1] != 0) throw StateError('SOCKS authentication $ok');
    }
    final name = host.codeUnits;
    socket.add([5, 1, 0, 3, name.length, ...name, port >> 8, port & 0xff]);
    final reply = await conn.read(4);
    if (reply[1] != 0) throw StateError('SOCKS reply ${reply[1]}');
    final addr = switch (reply[3]) { 1 => 4, 4 => 16, _ => (await conn.read(1))[0] };
    await conn.read(addr + 2);
    socket.add('HEAD / HTTP/1.0\r\nHost: $host\r\nConnection: close\r\n\r\n'.codeUnits);
    final answer = await conn.readAll();
    return answer.split('\r\n').first;
  } finally {
    socket.destroy();
  }
}

class _Reader {
  _Reader(Socket socket) {
    socket.listen(
      (data) {
        _buffer.addAll(data);
        _wake();
      },
      onError: (Object e) {
        _error = e;
        _wake();
      },
      onDone: () {
        _done = true;
        _wake();
      },
    );
  }

  static const _timeout = Duration(minutes: 2);
  final _buffer = <int>[];
  Object? _error;
  bool _done = false;
  Completer<void>? _waiting;

  void _wake() {
    _waiting?.complete();
    _waiting = null;
  }

  Future<void> _more() {
    if (_error != null) throw _error!;
    if (_done) throw StateError('closed after ${_buffer.length} bytes');
    return (_waiting = Completer<void>()).future.timeout(_timeout);
  }

  Future<List<int>> read(int n) async {
    while (_buffer.length < n) {
      await _more();
    }
    final out = _buffer.sublist(0, n);
    _buffer.removeRange(0, n);
    return out;
  }

  Future<String> readAll() async {
    while (!_done && _error == null) {
      await (_waiting = Completer<void>()).future.timeout(_timeout);
    }
    return String.fromCharCodes(_buffer);
  }
}
