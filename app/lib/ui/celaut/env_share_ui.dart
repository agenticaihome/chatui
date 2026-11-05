import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../celaut/env_share.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../scan_screen.dart';

/// Show the QR code that shares the variable [name] (`docs/celaut/env-share.md`).
Future<void> showEnvShare(
  BuildContext context, {
  required String name,
  required String value,
  required bool sensitive,
}) {
  final share = EnvShare(name: name, value: value, sensitive: sensitive);
  final l = context.l10n;
  final colors = ArgusColors.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('env-share'),
      title: Text(l.celautEnvShareTitle(name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!share.fits)
              Padding(
                key: const Key('env-share-toobig'),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l.celautEnvShareTooBig),
              )
            else
              Center(
                // A fixed size: QrImageView uses a LayoutBuilder, which an AlertDialog cannot
                // measure without one.
                child: Container(
                  key: const Key('env-share-qr'),
                  width: 260,
                  height: 260,
                  color: Colors.white,
                  padding: const EdgeInsets.all(10),
                  child: QrImageView(
                    data: share.encode(),
                    // The text of the code is the value: it must not reach a screen reader.
                    semanticsLabel: l.celautEnvShareTitle(name),
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              sensitive ? l.celautEnvShareWarnSensitive : l.celautEnvShareWarn,
              key: const Key('env-share-warning'),
              style: TextStyle(fontSize: 12.5, color: colors.muted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('env-share-done'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonDone),
        ),
      ],
    ),
  );
}

/// Scan a QR code of a shared variable. Null if the user closed the camera, or if the code
/// is not a variable (the user is told).
Future<EnvShare?> scanEnvShare(BuildContext context) async {
  final raw = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));
  if (raw == null || !context.mounted) return null;
  final share = EnvShare.tryParse(raw);
  if (share == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.celautEnvScanNotVariable)));
  }
  return share;
}
