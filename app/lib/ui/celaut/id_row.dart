import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';

/// An id in short form: the first 6 and the last 4 characters (issue #123).
String shortId(String id) => id.length <= 12 ? id : '${id.substring(0, 6)}…${id.substring(id.length - 4)}';

/// A row for a long id (a client id, a peer id): its label, the id in short form, "Copy"
/// (the full id) and "Show full id". The full id shows only when the user asks for it, and
/// the row never logs it. The keys start with [keyPrefix]: `<prefix>-value`,
/// `<prefix>-copy`, `<prefix>-full`.
class IdRow extends StatefulWidget {
  const IdRow({
    super.key,
    required this.label,
    required this.id,
    required this.keyPrefix,
    this.copiedText,
  });

  final String label;
  final String id;
  final String keyPrefix;

  /// The message after Copy; a general one if null.
  final String? copiedText;

  @override
  State<IdRow> createState() => _IdRowState();
}

class _IdRowState extends State<IdRow> {
  bool _full = false;

  Future<void> _copy() async {
    final l = context.l10n;
    await Clipboard.setData(ClipboardData(text: widget.id));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(widget.copiedText ?? l.celautIdCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = ArgusColors.of(context).muted;
    final p = widget.keyPrefix;
    final small = TextButton.styleFrom(
      minimumSize: const Size(48, 40),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(fontSize: 12.5, color: muted)),
        const SizedBox(height: 2),
        Text(
          _full ? widget.id : shortId(widget.id),
          key: Key('$p-value'),
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
        ),
        Wrap(
          spacing: 4,
          children: [
            TextButton(key: Key('$p-copy'), style: small, onPressed: _copy, child: Text(l.commonCopy)),
            TextButton(
              key: Key('$p-full'),
              style: small,
              onPressed: () => setState(() => _full = !_full),
              child: Text(_full ? l.celautIdShowShort : l.celautIdShowFull),
            ),
          ],
        ),
      ],
    );
  }
}
