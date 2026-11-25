import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../celaut/invite_scan.dart';
import '../l10n/l10n.dart';
import '../services/linux_app.dart';
import '../services/session_lock.dart';

/// Reads one QR code and closes with it. By default the result is the trimmed text
/// (`String`). With [binary] it is a [ScannedCode] with the text and the bytes, for the
/// peer invitation of a node, which is binary (`docs/celaut/invite.md`).
///
/// On macOS the `camera` plugin has no implementation (issue #154), and on Linux the camera
/// plugin of flutter_zxing has no Linux side (issue #153): the user chooses an image of the
/// code (a screenshot), and zxing reads it ([readQrImage]).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.binary = false, this.chooseImage});

  final bool binary;

  /// Stands in for the file picker and the read of the image in tests; null if the user
  /// chose no image.
  final Future<Code?> Function()? chooseImage;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _done = false;
  bool _cameraFailed = false;

  @override
  void initState() {
    super.initState();
    sessionLock.suppress();
  }

  @override
  void dispose() {
    sessionLock.release();
    super.dispose();
  }

  void _onScan(Code code) {
    if (_done || !mounted || !code.isValid) return;
    if (widget.binary) {
      final bytes = code.rawBytes;
      if (bytes == null || bytes.isEmpty) return;
      _done = true;
      Navigator.pop(context, ScannedCode(text: code.text?.trim(), bytes: bytes));
      return;
    }
    final raw = code.text?.trim();
    if (raw == null || raw.isEmpty) return;
    _done = true;
    Navigator.pop(context, raw);
  }

  // A phone without a flash also reports an error here; the camera still works.
  void _onControllerCreated(CameraController? controller, Exception? error) {
    if (error == null || !mounted) return;
    if (error.toString().contains('setFlashModeFailed')) return;
    setState(() => _cameraFailed = true);
  }

  Future<void> _fromImage() async {
    final code = await (widget.chooseImage ?? () => _chooseAndRead(context.l10n.scanChooseImage))();
    if (code == null || !mounted) return;
    final before = _done;
    _onScan(code);
    if (!before && !_done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(key: const Key('scan-image-none'), content: Text(context.l10n.scanNoCodeInImage)),
      );
    }
  }

  // The title names the file chooser of the Linux desktop.
  static Future<Code?> _chooseAndRead(String title) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, dialogTitle: title);
    final path = picked?.files.single.path;
    if (path == null) return null;
    return readQrImage(path);
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.macOS || isLinuxApp) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.scanTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(isLinuxApp ? context.l10n.scanFromImageNoteLinux : context.l10n.scanFromImageNote, key: const Key('scan-image-note'), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('scan-image-choose'),
                  onPressed: _fromImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(context.l10n.scanChooseImage),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.scanTitle)),
      body: _cameraFailed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.scanCameraUnavailable,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.scanBack),
                    ),
                  ],
                ),
              ),
            )
          : ReaderWidget(
              codeFormat: Format.qrCode,
              onScan: _onScan,
              onControllerCreated: _onControllerCreated,
              showGallery: false,
              showToggleCamera: false,
              // Light modules on a dark ground (a QR in a dark terminal) need the inverted try.
              tryInverted: true,
              tryHarder: true,
              // The whole frame: the default scans only the centre square of half the short
              // side, which cuts a large code and gives a dense one few pixels per module.
              cropPercent: 0,
              // A failed frame must not make the next ones wait a second.
              scanDelay: const Duration(milliseconds: 100),
              scanDelaySuccess: Duration.zero,
              resolution: ResolutionPreset.veryHigh,
            ),
    );
  }
}

/// Read a QR code in the image file at [path] (PNG, JPEG…), as the camera scan does: the
/// whole image, also inverted (light modules on a dark ground).
Future<Code> readQrImage(String path) => zx.readBarcodeImagePathString(
      path,
      DecodeParams(format: Format.qrCode, tryHarder: true, tryInverted: true, maxSize: 2048),
    );
