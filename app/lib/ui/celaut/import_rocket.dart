import 'dart:async';

import 'package:flutter/material.dart';

import '../../celaut/celaut_strings.dart';
import '../../celaut/package_library.dart';
import '../../l10n/l10n.dart';
import '../home/home_style.dart';
import 'raise_rocket.dart';

/// The user cancelled the import while the app checked the file.
class ImportCancelled implements Exception {
  const ImportCancelled();

  @override
  String toString() => 'ImportCancelled()';
}

/// Run [work] (the load of a service file) under a card with the rocket, the step of the
/// import (the read of the file, then the check of its blocks), its bytes so far, and
/// Cancel. The card shows before [work] starts, so that the user sees at once that the
/// import runs. The rocket lies on its pad and the pad raises it as the whole import goes
/// on ([RaiseStage]); when [work] ends well, it stands before the card goes. It does not
/// take off: that is the launch's. A failure of [work] is thrown again, as
/// [ImportCancelled] when the user pressed Cancel.
///
/// [progress] and [cancel] are those of [PackageLibrary] (`importProgress`,
/// `cancelImport`): they are injected so that tests need no Rust and no Android.
Future<T> runWithImportRocket<T>(
  BuildContext context, {
  required Future<T> Function() work,
  required ImportProgress Function() progress,
  required void Function() cancel,
  Duration poll = const Duration(milliseconds: 200),
}) async {
  final navigator = Navigator.of(context);
  final stage = GlobalKey<RaiseStageState>();
  var cancelled = false;
  final route = RawDialogRoute<void>(
    barrierDismissible: false,
    barrierColor: Colors.black54,
    pageBuilder: (context, animation, secondary) => PopScope(
      canPop: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _ImportCard(
            stage: stage,
            progress: progress,
            poll: poll,
            onCancel: () {
              cancelled = true;
              cancel();
            },
          ),
        ),
      ),
    ),
  );
  unawaited(navigator.push(route));
  try {
    final result = await work();
    await stage.currentState?.finish();
    return result;
  } catch (_) {
    if (cancelled) throw const ImportCancelled();
    rethrow;
  } finally {
    if (route.isActive) navigator.removeRoute(route);
  }
}

class _ImportCard extends StatefulWidget {
  const _ImportCard({
    required this.stage,
    required this.progress,
    required this.poll,
    required this.onCancel,
  });

  final GlobalKey<RaiseStageState> stage;
  final ImportProgress Function() progress;
  final Duration poll;
  final VoidCallback onCancel;

  @override
  State<_ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends State<_ImportCard> {
  Timer? _timer;
  ImportProgress? _view;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    // The first count shows at once, not one poll later; the rocket follows after the first
    // frame, when its stage is there.
    _view = widget.progress();
    _timer = Timer.periodic(widget.poll, (_) => _read());
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  void _read() {
    if (!mounted) return;
    final view = widget.progress();
    setState(() => _view = view);
    widget.stage.currentState?.setProgress(view.overall);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final view = _view;
    final done = view?.bytes ?? 0;
    final total = view?.total;
    final fraction = view?.fraction;
    final phase = view?.phase ?? ImportPhase.reading;
    final amount = fraction != null
        ? l.celautSendProgress(
            CelautStrings.bytes(done),
            CelautStrings.bytes(total!),
            (fraction * 100).floor().toString(),
          )
        : l.celautSendSoFar(CelautStrings.bytes(done));
    return Material(
      key: const Key('import-progress'),
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: RaiseStage(key: widget.stage)),
            const SizedBox(height: 12),
            Text(
              switch (phase) {
                ImportPhase.reading => l.celautImportReading,
                ImportPhase.checking => l.celautImportChecking,
                ImportPhase.downloading => l.celautLinkDownloading,
              },
              key: const Key('import-step'),
              style: t.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              switch (phase) {
                ImportPhase.reading => l.celautImportReadingNote,
                ImportPhase.checking => l.celautImportNote,
                ImportPhase.downloading => l.celautLinkDownloadingNote,
              },
              style: t.secondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              key: const Key('import-bar'),
              // A manifest gives no size: the bar goes by its parts.
              value: phase == ImportPhase.downloading ? view?.overall : fraction,
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              key: const Key('import-amount'),
              textAlign: TextAlign.center,
            ),
            if (view != null && view.chunks > 0)
              Text(
                l.celautLinkChunk(view.chunk, view.chunks),
                key: const Key('import-chunk'),
                style: t.secondary,
                textAlign: TextAlign.center,
              ),
            if (view != null && view.retries > 0)
              Text(
                l.celautLinkRetries(view.retries),
                key: const Key('import-retries'),
                style: t.secondary,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 4),
            TextButton(
              key: const Key('import-cancel'),
              onPressed: _cancelling
                  ? null
                  : () {
                      setState(() => _cancelling = true);
                      widget.onCancel();
                    },
              child: Text(l.celautSendCancel),
            ),
          ],
        ),
      ),
    );
  }
}
