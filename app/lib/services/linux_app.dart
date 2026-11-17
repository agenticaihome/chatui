import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../l10n/l10n.dart';

/// True in the Linux app (app/linux, issue #153). False in `flutter test`, which runs on a
/// Linux host too but has no runner behind the platform channels.
final bool isLinuxApp =
    !kIsWeb && Platform.isLinux && !Platform.environment.containsKey('FLUTTER_TEST');

/// Shares files ([ShareParams.files]). share_plus shares no file on Linux, so there the
/// user saves each file with the file chooser of the desktop.
Future<void> shareFiles(ShareParams params) async {
  if (!isLinuxApp) {
    await SharePlus.instance.share(params);
    return;
  }
  final files = params.files ?? const [];
  for (var i = 0; i < files.length; i++) {
    final overrides = params.fileNameOverrides;
    final name = overrides != null && i < overrides.length ? overrides[i] : files[i].name;
    await FilePicker.platform.saveFile(
      dialogTitle: appL10n.commonSave,
      fileName: name,
      bytes: await files[i].readAsBytes(),
    );
  }
}
