import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_network.dart';
import 'package:argus_wallet/celaut/network_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _off = NetworkStatusView(
  choice: NetworkChoice.off,
  state: NetworkState.off,
  percent: 0,
  error: '',
);

void main() {
  late List<({NetworkChoice choice, String? socks, String dir})> pushed;
  Object? pushError;
  String? dir;

  NetworkRoute make() => NetworkRoute(
    push: (choice, socks, dataDir) async {
      pushed.add((choice: choice, socks: socks, dir: dataDir));
      if (pushError != null) throw pushError!;
    },
    readStatus: () => _off,
    privateDir: () async => dir,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pushed = [];
    pushError = null;
    dir = '/data/user/0/org.celaut.superapp/files';
  });

  test('the default is off, with the address of Orbot', () async {
    final route = make();
    await route.load();
    expect(route.mode, NetworkMode.off);
    expect(route.socksAddress, '127.0.0.1:9050');
  });

  test('apply gives the stored choice to the core, and the private directory', () async {
    SharedPreferences.setMockInitialValues({
      NetworkRoute.modeKey: 'embedded',
      NetworkRoute.socksKey: '10.0.0.2:1080',
    });
    final route = make();
    await route.apply();
    expect(route.mode, NetworkMode.embedded);
    expect(pushed.single, (choice: NetworkChoice.embedded, socks: null, dir: dir!));
  });

  test('apply with a stored socks choice gives the address', () async {
    SharedPreferences.setMockInitialValues({
      NetworkRoute.modeKey: 'socks',
      NetworkRoute.socksKey: '127.0.0.1:9150',
    });
    await make().apply();
    expect(pushed.single.choice, NetworkChoice.socks);
    expect(pushed.single.socks, '127.0.0.1:9150');
  });

  test('an unknown stored mode is off', () async {
    SharedPreferences.setMockInitialValues({NetworkRoute.modeKey: 'something'});
    final route = make();
    await route.apply();
    expect(route.mode, NetworkMode.off);
    expect(pushed.single.choice, NetworkChoice.off);
  });

  test('apply does not throw when the core refuses: the core has blocked the route', () async {
    SharedPreferences.setMockInitialValues({NetworkRoute.modeKey: 'embedded'});
    pushError = const CelautError(kind: CelautErrorKind.invalidInput, message: 'no directory');
    dir = null;
    await make().apply();
    // With no private directory, the core gets an empty one and refuses it.
    expect(pushed.single.dir, '');
  });

  test('choose keeps the choice, then gives it to the core', () async {
    final route = make();
    await route.choose(NetworkMode.socks, socksAddress: ' 127.0.0.1:9050 ');
    expect(route.mode, NetworkMode.socks);
    expect(route.socksAddress, '127.0.0.1:9050');
    expect(pushed.single, (choice: NetworkChoice.socks, socks: '127.0.0.1:9050', dir: dir!));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(NetworkRoute.modeKey), 'socks');
    expect(prefs.getString(NetworkRoute.socksKey), '127.0.0.1:9050');
    // A new object reads the same choice.
    final again = make();
    await again.load();
    expect(again.mode, NetworkMode.socks);
  });

  test('choose keeps the choice even when the core refuses it, and throws the error', () async {
    const error = CelautError(kind: CelautErrorKind.invalidInput, message: 'bad address');
    pushError = error;
    final route = make();
    await expectLater(route.choose(NetworkMode.socks, socksAddress: 'x'), throwsA(error));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(NetworkRoute.modeKey), 'socks');
  });

  test('turning Tor off gives off to the core', () async {
    final route = make();
    await route.choose(NetworkMode.embedded);
    await route.choose(NetworkMode.off);
    expect(pushed.map((p) => p.choice), [NetworkChoice.embedded, NetworkChoice.off]);
    expect(pushed.last.socks, isNull);
  });

  test('listeners hear a change', () async {
    final route = make();
    var calls = 0;
    route.addListener(() => calls++);
    await route.choose(NetworkMode.embedded);
    expect(calls, greaterThan(0));
  });
}
