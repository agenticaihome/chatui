import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bridge/api/celaut_package.dart';
import '../../celaut/celaut_strings.dart';
import '../../celaut/service_link.dart';
import '../../l10n/l10n.dart';
import '../home/home_style.dart';

/// What the user chose in the [ImportSheet].
sealed class ImportRequest {
  const ImportRequest();
}

/// Pick a `.celaut.bee` file on the phone.
class ImportFileRequest extends ImportRequest {
  const ImportFileRequest();
}

/// Download the service at [url] (issue #135).
class ImportLinkRequest extends ImportRequest {
  const ImportLinkRequest(this.url);

  final String url;
}

/// The import of a service (issue #135): a file on the phone, or a link to a `.celaut.bee`
/// file or to a manifest of its chunks, typed, pasted or read from a QR code. A download
/// that stopped shows on top, with Continue and Delete. The sheet closes with the
/// [ImportRequest]; the section runs it.
class ImportSheet extends StatefulWidget {
  const ImportSheet({
    super.key,
    required this.pending,
    required this.discard,
    required this.scan,
    this.initialLink,
  });

  /// The download that stopped, if any.
  final Future<PendingLinkView?> Function() pending;

  /// Delete the download that stopped.
  final Future<void> Function() discard;

  /// Read a QR code; null if the user went back.
  final Future<String?> Function(BuildContext context) scan;

  final String? initialLink;

  @override
  State<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<ImportSheet> {
  late final _link = TextEditingController(text: widget.initialLink ?? '');
  PendingLinkView? _pending;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_readPending());
  }

  Future<void> _readPending() async {
    PendingLinkView? pending;
    try {
      pending = await widget.pending();
    } catch (_) {
      pending = null;
    }
    if (mounted) setState(() => _pending = pending);
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  /// Put [raw] in the field: the link that it holds, or [raw] as it is (the check says why
  /// it is not a link).
  void _take(String raw) {
    final link = serviceLinkOf(raw) ?? raw.trim();
    setState(() {
      _link.text = link;
      _link.selection = TextSelection.collapsed(offset: link.length);
      _error = null;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      setState(() => _error = context.l10n.celautLinkClipboardEmpty);
      return;
    }
    _take(text);
  }

  Future<void> _scan() async {
    final raw = await widget.scan(context);
    if (!mounted || raw == null) return;
    _take(raw);
  }

  void _go() {
    final link = serviceLinkOf(_link.text);
    if (link == null) {
      setState(() => _error = context.l10n.celautLinkNotALink);
      return;
    }
    Navigator.of(context).pop(ImportLinkRequest(link));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final pending = _pending;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('import-sheet'),
        padding: EdgeInsets.fromLTRB(
          homeGutter,
          0,
          homeGutter,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.celautLinkSheetTitle, style: t.title),
            const SizedBox(height: 12),
            if (pending != null) ...[
              Container(
                key: const Key('import-pending'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.celautLinkPendingTitle, style: t.primary),
                    const SizedBox(height: 2),
                    Text(
                      l.celautLinkPendingBody(CelautStrings.bytes(pending.bytes.toInt())),
                      style: t.secondary,
                    ),
                    Text(
                      pending.url,
                      style: t.secondary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextButton(
                          key: const Key('import-pending-delete'),
                          onPressed: () async {
                            await widget.discard();
                            await _readPending();
                          },
                          child: Text(l.celautLinkPendingDelete),
                        ),
                        const Spacer(),
                        FilledButton(
                          key: const Key('import-pending-continue'),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                          onPressed: () => Navigator.of(context).pop(ImportLinkRequest(pending.url)),
                          child: Text(l.celautLinkPendingContinue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              key: const Key('import-choose-file'),
              onPressed: () => Navigator.of(context).pop(const ImportFileRequest()),
              icon: const Icon(Icons.upload_file_outlined, size: 20),
              label: Text(l.celautLinkChooseFile),
            ),
            const SizedBox(height: 20),
            Text(l.celautLinkFromLink, style: t.primary),
            const SizedBox(height: 2),
            Text(l.celautLinkFromLinkNote, style: t.secondary),
            const SizedBox(height: 8),
            TextField(
              key: const Key('import-link-field'),
              controller: _link,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _go(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: l.celautLinkHint,
                errorText: _error,
                errorMaxLines: 3,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('import-link-paste'),
                      tooltip: l.celautLinkPaste,
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste, size: 20),
                    ),
                    IconButton(
                      key: const Key('import-link-scan'),
                      tooltip: l.celautLinkScan,
                      onPressed: _scan,
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: _link,
              builder: (context, _) => FilledButton.icon(
                key: const Key('import-link-go'),
                onPressed: _link.text.trim().isEmpty ? null : _go,
                icon: const Icon(Icons.download_outlined, size: 20),
                label: Text(l.celautLinkDownload),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
