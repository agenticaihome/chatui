import 'dart:io';

import 'package:argus_wallet/bridge/api/celaut.dart';
import 'package:argus_wallet/bridge/api/celaut_package.dart';
import 'package:argus_wallet/celaut/package_channel.dart';
import 'package:argus_wallet/celaut/package_library.dart';
import 'package:argus_wallet/celaut/service_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

final _id = 'ab' * 32;

/// A channel whose copy is a real file of the test, so that a delete can be seen.
class _Copier implements PackageChannel {
  _Copier(this.path);

  final String path;
  int copies = 0;
  int cancels = 0;

  @override
  int copied = 0;

  @override
  Future<ChosenFile?> pick() async => null;

  @override
  Future<PickedPackage> copy(ChosenFile file) async {
    copies++;
    File(path).writeAsBytesSync(List.filled(10, 1));
    copied = 10;
    return PickedPackage(path: path, bytes: 10, name: file.name);
  }

  @override
  void cancelCopy() => cancels++;

  @override
  Future<bool> isMetered() async => false;
}

LibraryPackageView _view({String? id, String name = 'echo', bool present = true}) => LibraryPackageView(
  serviceId: id ?? _id,
  name: name,
  path: '/data/packages/library/${id ?? _id}.bee',
  bytes: BigInt.from(4096),
  importedAt: 5,
  nodoExport: true,
  present: present,
);

void main() {
  late List<String> calls;
  var stored = <LibraryPackageView>[];
  String? dir = '/data/app';
  Object? importError;

  PackageLibrary make() => PackageLibrary(
    importPackage: (path, name, d) async {
      calls.add('import $path $name $d');
      if (importError != null) throw importError!;
      return _view(name: name);
    },
    list: () => stored,
    remove: (id) async => calls.add('remove $id'),
    privateDir: () async => dir,
    progress: () => TransferView(stage: TransferStage.checking, bytes: BigInt.from(4), total: BigInt.from(10)),
  );

  setUp(() {
    calls = [];
    stored = [];
    dir = '/data/app';
    importError = null;
  });

  test('a picked file is loaded into the private directory with the name of the file', () async {
    final loaded = await make().importPicked(
      const PickedPackage(path: '/cache/picked-1.bee', bytes: 10, name: 'echo.celaut.bee'),
    );
    expect(calls, ['import /cache/picked-1.bee echo.celaut.bee /data/app']);
    expect(loaded.serviceId, _id);
  });

  test('with no private directory the file is refused and nothing is loaded', () async {
    dir = null;
    await expectLater(
      make().importPicked(const PickedPackage(path: '/c.bee', bytes: 1, name: 'c')),
      throwsA(isA<PackageRefused>().having((e) => e.reason, 'reason', PackageRefusal.noDirectory)),
    );
    dir = '';
    await expectLater(
      make().importPicked(const PickedPackage(path: '/c.bee', bytes: 1, name: 'c')),
      throwsA(isA<PackageRefused>()),
    );
    expect(calls, isEmpty);
  });

  test('a file that is not a service package is an error of the core, for the screen', () async {
    importError = const CelautError(kind: CelautErrorKind.invalidInput, message: 'no Service part');
    await expectLater(
      make().importPicked(const PickedPackage(path: '/c.bee', bytes: 1, name: 'c')),
      throwsA(isA<CelautError>().having((e) => e.message, 'message', 'no Service part')),
    );
  });

  group('a chosen file', () {
    late Directory tmp;
    late _Copier copier;
    const chosen = ChosenFile(uri: 'content://files/echo.celaut.bee', name: 'echo.celaut.bee', bytes: 10);

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('pkg');
      copier = _Copier('${tmp.path}/picked-1.bee');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('is copied, then loaded from its copy', () async {
      final library = make();
      final loaded = await library.importChosen(chosen, copier);
      expect(copier.copies, 1);
      expect(calls, ['import ${copier.path} echo.celaut.bee /data/app']);
      expect(loaded.serviceId, _id);
      final now = library.importProgress();
      expect(now.phase, ImportPhase.checking);
      expect(now.bytes, 4);
      expect(now.total, 10);
    });

    test('that the core refuses: its copy is deleted', () async {
      importError = const CelautError(kind: CelautErrorKind.invalidInput, message: 'no Service part');
      await expectLater(make().importChosen(chosen, copier), throwsA(isA<CelautError>()));
      expect(File(copier.path).existsSync(), isFalse);
    });

    test('with no private directory, is not copied', () async {
      dir = null;
      await expectLater(make().importChosen(chosen, copier), throwsA(isA<PackageRefused>()));
      expect(copier.copies, 0);
    });
  });

  test('the progress of an import: the read is the first half, the check the second', () {
    const reading = ImportProgress(phase: ImportPhase.reading, bytes: 25, total: 100);
    expect(reading.fraction, 0.25);
    expect(reading.overall, 0.125);
    const checking = ImportProgress(phase: ImportPhase.checking, bytes: 50, total: 100);
    expect(checking.fraction, 0.5);
    expect(checking.overall, 0.75);
    const unknown = ImportProgress(phase: ImportPhase.reading, bytes: 25);
    expect(unknown.fraction, isNull);
    expect(unknown.overall, isNull);
    expect(const ImportProgress(phase: ImportPhase.checking, bytes: 0).overall, 0.5);
  });

  test('find gives a loaded service by id, in any case, only if its file is there', () {
    stored = [_view(), _view(id: 'cd' * 32, present: false)];
    final library = make();
    expect(library.find(_id)?.serviceId, _id);
    expect(library.find(_id.toUpperCase())?.serviceId, _id);
    expect(library.find('cd' * 32), isNull, reason: 'the file is gone');
    expect(library.find('ef' * 32), isNull);
    expect(library.list(), hasLength(2));
  });

  test('remove asks the core to delete the service', () async {
    await make().remove(_id);
    expect(calls, ['remove $_id']);
  });
}
