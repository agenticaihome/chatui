import 'package:file_picker/file_picker.dart';
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
/// Without a camera (the Linux app: the camera plugin of flutter_zxing has no Linux
/// side), or when the camera fails, the user reads the code from an image file.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.binary = false, bool? camera}) : _camera = camera;

  final bool binary;

  /// Stands in for the platform check in tests: false is a device with no camera scan.
  final bool? _camera;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _done = false;
  late bool _cameraFailed = !(widget._camera ?? !isLinuxApp);
  bool _reading = false;
  String? _imageError;

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

  /// The user picks an image (a screenshot, a photo) and zxing reads the code in it.
  Future<void> _readImage() async {
    if (_reading) return;
    setState(() {
      _reading = true;
      _imageError = null;
    });
    final noCode = context.l10n.scanImageNoCode;
    final title = context.l10n.scanFromImage;
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.image, dialogTitle: title);
      final path = picked?.files.single.path;
      if (path == null || !mounted) return;
      final code = await zx.readBarcodeImagePathString(
        path,
        // The image of a screen can be large: a dense code needs its pixels.
        DecodeParams(format: Format.qrCode, tryHarder: true, tryInverted: true, maxSize: 2048),
      );
      if (!mounted) return;
      _onScan(code);
      if (!_done) setState(() => _imageError = noCode);
    } on Object {
      if (mounted) setState(() => _imageError = noCode);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  // A phone without a flash also reports an error here; the camera still works.
  void _onControllerCreated(CameraController? controller, Exception? error) {
    if (error == null || !mounted) return;
    if (error.toString().contains('setFlashModeFailed')) return;
    setState(() => _cameraFailed = true);
  }

  @override
  Widget build(BuildContext context) {
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
                      widget._camera ?? !isLinuxApp
                          ? context.l10n.scanCameraUnavailable
                          : context.l10n.scanNoCamera,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const ValueKey('scan-from-image'),
                      onPressed: _reading ? null : _readImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(context.l10n.scanFromImage),
                    ),
                    if (_imageError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _imageError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
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
