import 'dart:io';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_package.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:argus_wallet/celaut/launcher.dart';
import 'package:argus_wallet/celaut/package_channel.dart';
import 'package:argus_wallet/celaut/service_transfer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = NodeAddress(host: 'a.example', port: 1);
const _b = NodeAddress(host: 'b.example', port: 2);
const _c = NodeAddress(host: 'c.example', port: 3);
const _d = NodeAddress(host: 'd.example', port: 4);
final _id = 'ab' * 32;

QuoteFailureView _failure(NodeAddress a, CelautErrorKind kind) =>
    QuoteFailureView(address: a, kind: kind, message: kind.name);

QuoteView _quote(NodeAddress a) => QuoteView(
  address: a,
  peerId: 'p',
  costMu: '10',
  initMaintenanceMu: '1',
  maxMaintenanceMu: '1',
  maintenanceSecondsLoop: 10,
  variance: 0,
  comparedNanoErg: '1',
  clientBalanceMu: '100',
  childrenInitialCostMu: '',
);

LaunchSkip _skip(NodeAddress a, CelautErrorKind kind) =>
    LaunchSkip(_quote(a), CelautError(kind: kind, message: kind.name));

PackageView _package({String? id, bool hasService = true}) => PackageView(
  path: '/cache/packages/x.bee',
  bytes: BigInt.from(1000),
  serviceId: id,
  hasService: hasService,
  nodoExport: false,
);

void main() {
  group('the offer of a failed launch', () {
    test('a service that the user loaded into the app is sent from the library', () {
      final failure = LaunchFailure(
        LaunchFailureKind.noQuotes,
        quoteFailures: [
          _failure(_a, CelautErrorKind.serviceMissing),
          _failure(_b, CelautErrorKind.nodeClosed),
        ],
      );
      // Even when another node has it, the file of the library is the first choice: it
      // needs no download.
      final offer = transferOfferOf(failure, libraryPath: '/library/ab.bee')!;
      expect(offer.source, TransferSource.library);
      expect(offer.libraryPath, '/library/ab.bee');
      expect(offer.from, isNull);
      expect(offer.to, _a);
      // No node lacks it: nothing to send, with or without the library.
      final fine = LaunchFailure(
        LaunchFailureKind.noQuotes,
        quoteFailures: [_failure(_b, CelautErrorKind.nodeClosed)],
      );
      expect(transferOfferOf(fine, libraryPath: '/library/ab.bee'), isNull);
    });

    test('a node that has it and a node that does not: send from one to the other', () {
      final offer = transferOfferOf(
        LaunchFailure(
          LaunchFailureKind.noQuotes,
          quoteFailures: [
            _failure(_a, CelautErrorKind.serviceMissing),
            _failure(_b, CelautErrorKind.nodeClosed),
          ],
        ),
      )!;
      expect(offer.source, TransferSource.node);
      expect(offer.from, _b);
      expect(offer.to, _a);
      expect(offer.missing, [_a]);
    });

    test('a node that quoted has the service, whatever stopped its start', () {
      final offer = transferOfferOf(
        LaunchFailure(
          LaunchFailureKind.allFailed,
          quoteFailures: [_failure(_a, CelautErrorKind.serviceMissing)],
          skipped: [_skip(_c, CelautErrorKind.protocol)],
        ),
      )!;
      expect(offer.from, _c);
    });

    test('nodes that do not answer say nothing: the service comes from a file', () {
      final offer = transferOfferOf(
        LaunchFailure(
          LaunchFailureKind.noQuotes,
          quoteFailures: [
            _failure(_a, CelautErrorKind.serviceMissing),
            _failure(_b, CelautErrorKind.unreachable),
            _failure(_c, CelautErrorKind.timeout),
            _failure(_d, CelautErrorKind.identityMismatch),
          ],
        ),
      )!;
      expect(offer.source, TransferSource.file);
      expect(offer.from, isNull);
      expect(offer.to, _a);
    });

    test('every reason that nodo gives only for a service that it has makes a holder', () {
      for (final kind in [
        CelautErrorKind.nodeClosed,
        CelautErrorKind.noRoom,
        CelautErrorKind.insufficientCredit,
        CelautErrorKind.rateLimited,
        CelautErrorKind.launchFailed,
        CelautErrorKind.policyRefused,
        CelautErrorKind.unsupportedArchitecture,
      ]) {
        final offer = transferOfferOf(
          LaunchFailure(
            LaunchFailureKind.noQuotes,
            quoteFailures: [_failure(_a, CelautErrorKind.serviceMissing), _failure(_b, kind)],
          ),
        )!;
        expect(offer.from, _b, reason: kind.name);
      }
    });

    test('the nodes that lack it, in order and once, from failures and skips', () {
      final offer = transferOfferOf(
        LaunchFailure(
          LaunchFailureKind.allFailed,
          quoteFailures: [
            _failure(_b, CelautErrorKind.serviceMissing),
            _failure(_b, CelautErrorKind.serviceMissing),
          ],
          skipped: [_skip(_a, CelautErrorKind.serviceMissing)],
        ),
      )!;
      expect(offer.missing, [_b, _a]);
      expect(offer.to, _b);
      expect(offer.source, TransferSource.file);
    });

    test('no node lacks the service: no offer', () {
      expect(
        transferOfferOf(
          LaunchFailure(
            LaunchFailureKind.allFailed,
            quoteFailures: [_failure(_a, CelautErrorKind.noRoom)],
            skipped: [_skip(_b, CelautErrorKind.insufficientCredit)],
          ),
        ),
        isNull,
      );
      expect(transferOfferOf(const LaunchFailure(LaunchFailureKind.noNodes)), isNull);
    });
  });

  group('the transfer', () {
    late List<String> calls;
    String? dir = '/data/app';

    ServiceTransfer make() => ServiceTransfer(
      fetch: (source, id, d) async {
        calls.add('fetch ${source.host} $id $d');
        return _package(id: id);
      },
      send: (node, id, initialMu, path) async {
        calls.add('send ${node.host} $id $initialMu $path');
        return _quote(node);
      },
      progress: () => TransferView(stage: TransferStage.idle, bytes: BigInt.zero),
      cancel: () => calls.add('cancel'),
      privateDir: () async => dir,
    );

    setUp(() {
      calls = [];
      dir = '/data/app';
    });

    test('from a node: get it into the private directory, then send that file', () async {
      final offer = TransferOffer(source: TransferSource.node, from: _b, to: _a, missing: const [_a]);
      final quote = await make().fromNode(offer, _id, '7');
      expect(quote.address, _a);
      expect(calls, [
        'fetch b.example $_id /data/app',
        'send a.example $_id 7 /cache/packages/x.bee',
      ]);
    });

    test('from a node, with no private directory: refused, nothing moves', () async {
      dir = null;
      final offer = TransferOffer(source: TransferSource.node, from: _b, to: _a, missing: const [_a]);
      await expectLater(
        make().fromNode(offer, _id, null),
        throwsA(isA<PackageRefused>().having((e) => e.reason, 'reason', PackageRefusal.noDirectory)),
      );
      expect(calls, isEmpty);
    });

    test('from the library: the file is sent as it is, and it stays', () async {
      final quote = await make().fromLibrary(_a, _id, '5', '/library/x.bee');
      expect(quote.address, _a);
      expect(calls, ['send a.example $_id 5 /library/x.bee']);
    });

    test('an error of the node goes to the caller', () async {
      final transfer = ServiceTransfer(
        send: (node, id, initialMu, path) async =>
            throw const CelautError(kind: CelautErrorKind.transferFailed, message: 'cut'),
        progress: () => TransferView(stage: TransferStage.idle, bytes: BigInt.zero),
        cancel: () {},
      );
      await expectLater(
        transfer.fromLibrary(_a, _id, null, '/p.bee'),
        throwsA(isA<CelautError>().having((e) => e.kind, 'kind', CelautErrorKind.transferFailed)),
      );
    });
  });

  group('the copy of the service', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('celaut-transfer-'));
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    File copy(String name) => File('${dir.path}/$name')..writeAsBytesSync([1, 2, 3]);

    ServiceTransfer make(File file, {required bool sendWorks}) => ServiceTransfer(
      fetch: (source, id, d) async => PackageView(
        path: file.path,
        bytes: BigInt.from(3),
        serviceId: id,
        hasService: true,
        nodoExport: false,
      ),
      send: (node, id, initialMu, path) async {
        expect(File(path).existsSync(), isTrue, reason: 'the file is there while it is sent');
        if (!sendWorks) {
          throw const CelautError(kind: CelautErrorKind.transferFailed, message: 'cut');
        }
        return _quote(node);
      },
      progress: () => TransferView(stage: TransferStage.idle, bytes: BigInt.zero),
      cancel: () {},
      privateDir: () async => dir.path,
    );

    for (final works in [true, false]) {
      test('a service from a node is deleted after the send (send works: $works)', () async {
        final file = copy('fetched.bee');
        final offer = TransferOffer(source: TransferSource.node, from: _b, to: _a, missing: const [_a]);
        final run = make(file, sendWorks: works).fromNode(offer, _id, null);
        if (works) {
          await run;
        } else {
          await expectLater(run, throwsA(isA<CelautError>()));
        }
        expect(file.existsSync(), isFalse);
      });

      test('a file of the library is kept after the send (send works: $works)', () async {
        final file = copy('library.bee');
        final run = make(file, sendWorks: works).fromLibrary(_a, _id, null, file.path);
        if (works) {
          await run;
        } else {
          await expectLater(run, throwsA(isA<CelautError>()));
        }
        expect(file.existsSync(), isTrue, reason: 'the user loaded it to keep it');
      });
    }
  });

  group('the Android channel', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<String> methods;

    void answer(Object? Function(MethodCall call) reply) {
      messenger.setMockMethodCallHandler(AndroidPackageChannel.channel, (call) async {
        methods.add(call.method);
        return reply(call);
      });
    }

    setUp(() => methods = []);
    tearDown(() => messenger.setMockMethodCallHandler(AndroidPackageChannel.channel, null));

    test('a chosen file and the metered network', () async {
      answer((call) => call.method == 'isMetered'
          ? true
          : {'uri': 'content://downloads/1', 'bytes': 2048, 'name': 'echo.celaut.bee'});
      const channel = AndroidPackageChannel(android: true);
      final chosen = await channel.pick();
      expect(chosen!.uri, 'content://downloads/1');
      expect(chosen.bytes, 2048);
      expect(chosen.name, 'echo.celaut.bee');
      expect(await channel.isMetered(), isTrue);
      expect(methods, ['pickPackage', 'isMetered']);
    });

    test('a provider that does not say the size gives no size', () async {
      answer((_) => {'uri': 'content://x/2', 'bytes': -1, 'name': 'echo.celaut.bee'});
      final chosen = await const AndroidPackageChannel(android: true).pick();
      expect(chosen!.bytes, isNull);
    });

    test('the copy gives the file in the cache, and counts its bytes', () async {
      Object? args;
      answer((call) {
        args = call.arguments;
        return {'path': '/cache/packages/picked-1.bee', 'bytes': 2048};
      });
      const channel = AndroidPackageChannel(android: true);
      const chosen = ChosenFile(uri: 'content://downloads/1', name: 'echo.celaut.bee', bytes: 2048);
      final copy = await channel.copy(chosen);
      expect(copy.path, '/cache/packages/picked-1.bee');
      expect(copy.bytes, 2048);
      expect(copy.name, 'echo.celaut.bee');
      expect(args, {'uri': 'content://downloads/1'});
      // The Android side tells the bytes while it copies.
      await messenger.handlePlatformMessage(
        AndroidPackageChannel.channel.name,
        AndroidPackageChannel.channel.codec.encodeMethodCall(const MethodCall('copied', 1024)),
        (_) {},
      );
      expect(channel.copied, 1024);
      channel.cancelCopy();
      await Future<void>.delayed(Duration.zero);
      expect(methods, ['copyPackage', 'cancelCopy']);
    });

    test('a cancelled copy and a copy that fails are told apart', () async {
      const channel = AndroidPackageChannel(android: true);
      const chosen = ChosenFile(uri: 'content://downloads/1', name: 'echo.celaut.bee');
      answer((_) => throw PlatformException(code: 'cancelled'));
      await expectLater(channel.copy(chosen), throwsA(isA<CopyCancelled>()));
      answer((_) => throw PlatformException(code: 'copy_failed', message: 'Permission denied'));
      await expectLater(
        channel.copy(chosen),
        throwsA(isA<CopyFailed>().having((e) => e.message, 'message', 'Permission denied')),
      );
    });

    test('a cancelled pick, an error, or no channel give no file and never throw', () async {
      const channel = AndroidPackageChannel(android: true);
      answer((_) => null);
      expect(await channel.pick(), isNull);
      answer((_) => throw PlatformException(code: 'copy_failed'));
      expect(await channel.pick(), isNull);
      expect(await channel.isMetered(), isFalse);
      messenger.setMockMethodCallHandler(AndroidPackageChannel.channel, null);
      expect(await channel.pick(), isNull);
      expect(await channel.isMetered(), isFalse);
    });

    test('off Android it does nothing', () async {
      answer((_) => true);
      const channel = AndroidPackageChannel(android: false);
      expect(await channel.pick(), isNull);
      expect(await channel.isMetered(), isFalse);
      expect(methods, isEmpty);
    });
  });
}
