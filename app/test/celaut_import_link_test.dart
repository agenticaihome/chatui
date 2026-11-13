// Import a service from a link (issue #135): the import sheet (a file, or a link typed,
// pasted or scanned), the http:// warning, the card of the download (bytes, chunk N of M,
// retries), cancel, errors, the download that stopped, and links that other apps open.

import 'dart:async';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_package.dart';
import 'package:argus_wallet/celaut/celaut_strings.dart';
import 'package:argus_wallet/celaut/incoming_package.dart';
import 'package:argus_wallet/celaut/package_channel.dart';
import 'package:argus_wallet/celaut/package_library.dart';
import 'package:argus_wallet/celaut/service_link.dart';
import 'package:argus_wallet/l10n/l10n.dart';
import 'package:argus_wallet/ui/celaut/run_service_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _id = 'ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12ab12';

/// The library in memory, with a download that the test drives.
class _Lib {
  final calls = <String>[];
  var stored = <LibraryPackageView>[];
  Object? linkError;
  Completer<void>? gate;
  var progress = TransferView(stage: TransferStage.idle, bytes: BigInt.zero, chunk: 0, chunks: 0, retries: 0);
  PendingLinkView? pending;
  var cancels = 0;

  PackageLibrary get library => PackageLibrary(
    importPackage: (path, name, dir) async => throw UnimplementedError(),
    list: () => stored,
    remove: (id) async {},
    privateDir: () async => '/data',
    progress: () => progress,
    cancel: () {
      cancels++;
      linkError = const CelautError(kind: CelautErrorKind.transferFailed, message: 'the transfer was cancelled');
      if (gate?.isCompleted == false) gate!.complete();
    },
    checkLink: (url) {
      final lower = url.trim().toLowerCase();
      if (!lower.startsWith('https://') && !lower.startsWith('http://')) {
        throw const CelautError(kind: CelautErrorKind.invalidInput, message: 'only https:// and http:// links are accepted');
      }
      return LinkView(url: url.trim(), insecure: lower.startsWith('http://'), name: 'echo');
    },
    importLink: (url, dir, allowHttp, maxBytes) async {
      calls.add('link $url http=$allowHttp max=$maxBytes');
      if (gate != null) await gate!.future;
      final error = linkError;
      if (error != null) throw error;
      final v = LibraryPackageView(
        serviceId: _id,
        name: 'echo',
        path: '/data/packages/library/$_id.bee',
        bytes: BigInt.from(4096),
        importedAt: 1,
        nodoExport: true,
        present: true,
      );
      stored = [v];
      return v;
    },
    pendingLink: (dir) => pending,
    discardLink: (dir) async {
      calls.add('discard');
      pending = null;
    },
  );
}

class _Packages implements PackageChannel {
  int picks = 0;

  @override
  int copied = 0;

  @override
  Future<bool> isMetered() async => false;

  @override
  Future<ChosenFile?> pick() async {
    picks++;
    return null;
  }

  @override
  Future<PickedPackage> copy(ChosenFile file) async => throw UnimplementedError();

  @override
  void cancelCopy() {}
}

void main() {
  late _Lib lib;
  late _Packages packages;
  String? scanned;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    lib = _Lib();
    packages = _Packages();
    scanned = null;
  });

  Future<void> open(WidgetTester tester, {ChosenFile? importFile, IncomingPackages? incoming}) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunServiceSection(
            loadSkills: () async => const [],
            packages: packages,
            library: lib.library,
            importFile: importFile,
            incoming: incoming ?? IncomingPackages(),
            scan: (context) async => scanned,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('run-import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('import-sheet')), findsOneWidget);
  }

  Future<void> download(WidgetTester tester, String link) async {
    await tester.enterText(find.byKey(const Key('import-link-field')), link);
    await tester.pump();
    await tester.tap(find.byKey(const Key('import-link-go')));
  }

  group('the import sheet', () {
    testWidgets('Import offers a file or a link; a file goes to the picker', (tester) async {
      await open(tester);
      await openSheet(tester);
      expect(find.text(appL10n.celautLinkSheetTitle), findsOneWidget);
      // No link: Download is off.
      expect(tester.widget<FilledButton>(find.byKey(const Key('import-link-go'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('import-choose-file')));
      await tester.pumpAndSettle();
      expect(packages.picks, 1);
      expect(lib.calls, isEmpty);
    });

    testWidgets('a typed link downloads under the card, then the service is loaded', (tester) async {
      lib.gate = Completer<void>();
      lib.progress = TransferView(
        stage: TransferStage.downloading,
        bytes: BigInt.from(3 * 1024 * 1024),
        total: BigInt.from(12 * 1024 * 1024),
        chunk: 0,
        chunks: 0,
        retries: 0,
      );
      await open(tester);
      await openSheet(tester);
      await download(tester, '  https://example.org/echo.celaut.bee ');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('import-progress')), findsOneWidget);
      expect(find.text(appL10n.celautLinkDownloading), findsOneWidget);
      expect(find.textContaining('25'), findsOneWidget);
      expect(find.byKey(const Key('import-chunk')), findsNothing);
      lib.gate!.complete();
      await tester.pumpAndSettle();
      expect(lib.calls, ['link https://example.org/echo.celaut.bee http=false max=$maxLinkBytes']);
      expect(find.text(appL10n.celautPkgLoaded('echo')), findsOneWidget);
      expect(find.byKey(const Key('import-progress')), findsNothing);
    });

    testWidgets('a manifest shows the part, and the retries', (tester) async {
      lib.gate = Completer<void>();
      lib.progress = TransferView(
        stage: TransferStage.downloading,
        bytes: BigInt.from(1024),
        chunk: 3,
        chunks: 8,
        retries: 2,
      );
      await open(tester);
      await openSheet(tester);
      await download(tester, 'https://example.org/echo.txt');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(appL10n.celautLinkChunk(3, 8)), findsOneWidget);
      expect(find.text(appL10n.celautLinkRetries(2)), findsOneWidget);
      lib.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('Paste takes the link out of the clipboard text', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return {'text': 'Try this service: https://example.org/a.celaut.bee.'};
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('import-link-paste')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(const Key('import-link-field'))).controller!.text,
        'https://example.org/a.celaut.bee',
      );
    });

    testWidgets('a QR code with the deep link fills in the link', (tester) async {
      scanned = importDeepLink('https://example.org/a b.celaut.bee');
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('import-link-scan')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(const Key('import-link-field'))).controller!.text,
        'https://example.org/a b.celaut.bee',
      );
    });

    testWidgets('a text that is not a link is refused in the sheet', (tester) async {
      await open(tester);
      await openSheet(tester);
      await download(tester, 'ftp://example.org/x');
      await tester.pumpAndSettle();
      expect(find.text(appL10n.celautLinkNotALink), findsOneWidget);
      expect(lib.calls, isEmpty);
    });

    testWidgets('the files sheet has the import from a link too', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('run-phone')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pkg-import-link')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-sheet')), findsOneWidget);
    });
  });

  group('http:// and errors', () {
    testWidgets('an http:// link asks first, and goes only with a yes', (tester) async {
      await open(tester);
      await openSheet(tester);
      await download(tester, 'http://example.org/echo.celaut.bee');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('link-http-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('link-http-cancel')));
      await tester.pumpAndSettle();
      expect(lib.calls, isEmpty);

      await openSheet(tester);
      await download(tester, 'http://example.org/echo.celaut.bee');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('link-http-confirm')));
      await tester.pumpAndSettle();
      expect(lib.calls, ['link http://example.org/echo.celaut.bee http=true max=$maxLinkBytes']);
    });

    testWidgets('Cancel on the card stops the download', (tester) async {
      lib.gate = Completer<void>();
      lib.progress = TransferView(stage: TransferStage.downloading, bytes: BigInt.from(10), chunk: 0, chunks: 0, retries: 0);
      await open(tester);
      await openSheet(tester);
      await download(tester, 'https://example.org/echo.celaut.bee');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('import-cancel')));
      await tester.pumpAndSettle();
      expect(lib.cancels, 1);
      expect(find.text(appL10n.celautLinkCancelled), findsOneWidget);
      expect(lib.stored, isEmpty);
    });

    testWidgets('a download that stopped says so, and Continue goes on with the same link', (tester) async {
      lib.linkError = const CelautError(kind: CelautErrorKind.unreachable, message: 'connection reset');
      await open(tester);
      await openSheet(tester);
      await download(tester, 'https://example.org/echo.celaut.bee');
      await tester.pumpAndSettle();
      expect(find.text(appL10n.celautLinkStopped('connection reset')), findsOneWidget);
      lib.linkError = null;
      await tester.tap(find.byKey(const Key('link-retry')));
      await tester.pumpAndSettle();
      expect(lib.calls.length, 2);
      expect(lib.calls.last, startsWith('link https://example.org/echo.celaut.bee '));
      expect(find.text(appL10n.celautPkgLoaded('echo')), findsOneWidget);
    });

    testWidgets('a file that fails the check, and a file over the limit, are refused', (tester) async {
      lib.linkError = const CelautError(kind: CelautErrorKind.invalidInput, message: 'the Service hashes to 00');
      await open(tester);
      await openSheet(tester);
      await download(tester, 'https://example.org/bad.celaut.bee');
      await tester.pumpAndSettle();
      expect(find.text(appL10n.celautLinkBadFile('the Service hashes to 00')), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(RunServiceSection))).clearSnackBars();
      await tester.pumpAndSettle();

      lib.linkError = CelautError(kind: CelautErrorKind.limitReached, message: '$maxLinkBytes');
      await openSheet(tester);
      await download(tester, 'https://example.org/huge.celaut.bee');
      await tester.pumpAndSettle();
      expect(find.text(appL10n.celautLinkTooLarge(CelautStrings.bytes(maxLinkBytes))), findsOneWidget);
      expect(lib.stored, isEmpty);
    });
  });

  group('a download that stopped', () {
    testWidgets('the sheet offers to continue it or to delete it', (tester) async {
      lib.pending = PendingLinkView(url: 'https://example.org/big.celaut.bee', bytes: BigInt.from(5 * 1024 * 1024));
      await open(tester);
      await openSheet(tester);
      expect(find.byKey(const Key('import-pending')), findsOneWidget);
      expect(find.text('https://example.org/big.celaut.bee'), findsOneWidget);
      await tester.tap(find.byKey(const Key('import-pending-continue')));
      await tester.pumpAndSettle();
      expect(lib.calls.first, startsWith('link https://example.org/big.celaut.bee '));
    });

    testWidgets('Delete removes it', (tester) async {
      lib.pending = PendingLinkView(url: 'https://example.org/big.celaut.bee', bytes: BigInt.from(1024));
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const Key('import-pending-delete')));
      await tester.pumpAndSettle();
      expect(lib.calls, ['discard']);
      expect(find.byKey(const Key('import-pending')), findsNothing);
    });
  });

  group('links that other apps open', () {
    testWidgets('a link from another app starts the download at once', (tester) async {
      final incoming = IncomingPackages();
      await open(
        tester,
        importFile: const ChosenFile.link('https://example.org/echo.celaut.bee'),
        incoming: incoming,
      );
      await tester.pumpAndSettle();
      expect(lib.calls, ['link https://example.org/echo.celaut.bee http=false max=$maxLinkBytes']);
      expect(incoming.busy.value, isFalse);
    });

    test('the Android side gives a link as {link}', () {
      final file = chosenFileOf({'link': 'chatui://import?url=https%3A%2F%2Fh%2Fx.celaut.bee'});
      expect(file!.isLink, isTrue);
      expect(file.uri, 'https://h/x.celaut.bee');
      expect(chosenFileOf({'link': 'not a link'}), isNull);
      final plain = chosenFileOf({'uri': 'content://x/1', 'name': 'a.celaut.bee', 'bytes': 3});
      expect(plain!.isLink, isFalse);
    });
  });

  group('serviceLinkOf', () {
    test('finds the link in what came', () {
      expect(serviceLinkOf(' https://h/a.celaut.bee '), 'https://h/a.celaut.bee');
      expect(serviceLinkOf('HTTP://h/a'), 'HTTP://h/a');
      expect(serviceLinkOf('Look: https://h/a.celaut.bee.'), 'https://h/a.celaut.bee');
      expect(serviceLinkOf('(https://h/a)'), 'https://h/a');
      expect(serviceLinkOf(importDeepLink('https://h/a?b=1&c=2#ff')), 'https://h/a?b=1&c=2#ff');
      expect(serviceLinkOf('chatui://other?url=https://h/a'), isNull);
      expect(serviceLinkOf('chatui://import?url=ftp://h/a'), isNull);
      expect(serviceLinkOf('ergopay:abc'), isNull);
      expect(serviceLinkOf(''), isNull);
      expect(serviceLinkOf('no link here'), isNull);
    });
  });

  group('the progress of a download', () {
    test('a file with a size goes by bytes; a manifest by chunks', () {
      const sized = ImportProgress(phase: ImportPhase.downloading, bytes: 25, total: 100);
      expect(sized.overall, 0.25);
      const list = ImportProgress(phase: ImportPhase.downloading, bytes: 25, chunk: 3, chunks: 5);
      expect(list.overall, closeTo(0.4, 1e-9));
      const unknown = ImportProgress(phase: ImportPhase.downloading, bytes: 25);
      expect(unknown.overall, isNull);
    });
  });
}
