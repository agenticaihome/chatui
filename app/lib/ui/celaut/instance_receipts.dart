import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../bridge/api/celaut_receipts.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import '../home/home_style.dart';

/// The receipts of an instance (`docs/celaut/receipts.md`), or null if the app cannot
/// read them.
ReceiptsView? readReceipts(String instanceId) {
  try {
    return celautInstanceReceipts(instanceId: instanceId);
  } catch (_) {
    return null;
  }
}

/// Share the receipts of an instance as a JSON Lines file, the file that
/// `nodo receipt verify` reads. False if there is no receipt to export.
Future<bool> shareReceipts(String instanceId) async {
  final text = celautExportReceipts(instanceId: instanceId);
  if (text.isEmpty) return false;
  final short = instanceId.length > 8 ? instanceId.substring(0, 8) : instanceId;
  final name = 'receipts-$short.jsonl';
  await SharePlus.instance.share(ShareParams(
    files: [
      XFile.fromData(Uint8List.fromList(utf8.encode(text)), mimeType: 'text/plain', name: name),
    ],
    // Without it, the file of the data gets a random name.
    fileNameOverrides: [name],
  ));
  return true;
}

String receiptFaultText(AppLocalizations l, ReceiptFaultKind kind) => switch (kind) {
      ReceiptFaultKind.sent => l.chatsReceiptsFaultSent,
      ReceiptFaultKind.received => l.chatsReceiptsFaultReceived,
      ReceiptFaultKind.envs => l.chatsReceiptsFaultEnvs,
      ReceiptFaultKind.service => l.chatsReceiptsFaultService,
      ReceiptFaultKind.amount => l.chatsReceiptsFaultAmount,
      ReceiptFaultKind.invalid => l.chatsReceiptsFaultInvalid,
      ReceiptFaultKind.omitted => l.chatsReceiptsFaultOmitted,
    };

/// The close of the tunnels: ✓, "none (cancelled)" (this phone ended the tunnel),
/// "none" (it ended with no close, not by this phone) or "open", with a count for each
/// when the instance had more than one tunnel. No close is not shown as a fault.
String receiptsCloseText(AppLocalizations l, ReceiptsView v) {
  if (v.streams == BigInt.zero) return l.chatsReceiptsNoTunnel;
  final open = v.streams - v.closed - v.cancelled - v.noClose;
  final many = v.streams > BigInt.one;
  String part(String word, BigInt n) => many ? '$word $n' : word;
  return [
    if (v.closed > BigInt.zero) part('✓', v.closed),
    if (v.cancelled > BigInt.zero) part(l.chatsReceiptsCancelled, v.cancelled),
    if (v.noClose > BigInt.zero) part(l.chatsReceiptsNone, v.noClose),
    if (open > BigInt.zero) part(l.chatsReceiptsOpen, open),
  ].join(' · ');
}

/// The Receipts part of the info page of an instance: the start receipt, the count of
/// the checkpoints, the close of the tunnels, every fault in red, and Export.
class InstanceReceiptsSection extends StatelessWidget {
  const InstanceReceiptsSection({super.key, required this.view, this.onExport});

  final ReceiptsView view;

  /// Export the receipts. Null hides Export (the receipts of a descendant).
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = HomeText.of(context);
    final red = rustFor(context);
    final v = view;
    final rows = <(String, String, Key, bool)>[
      (
        l.chatsReceiptsStart,
        switch (v.start) {
          StartReceiptState.valid => '✓',
          StartReceiptState.invalid => '✗',
          StartReceiptState.none => l.chatsReceiptsNone,
        },
        const Key('info-receipts-start'),
        v.start == StartReceiptState.invalid,
      ),
      (l.chatsReceiptsCheckpoints, '${v.checkpoints}', const Key('info-receipts-checkpoints'), false),
      (l.chatsReceiptsClose, receiptsCloseText(l, v), const Key('info-receipts-close'), false),
      if (v.droppedStreams > BigInt.zero)
        (l.chatsReceiptsDropped, '${v.droppedStreams}', const Key('info-receipts-dropped'), false),
    ];
    return Column(
      key: const Key('info-receipts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.chatsReceiptsTitle.toUpperCase(), style: t.label),
        const SizedBox(height: 4),
        for (final (label, value, key, bad) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(label, style: t.secondary)),
                Text(value, key: key, style: bad ? t.primary.copyWith(color: red) : t.primary),
              ],
            ),
          ),
        for (final (i, f) in v.faults.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receiptFaultText(l, f.kind),
                  key: Key('info-receipts-fault-$i'),
                  style: t.primary.copyWith(color: red),
                ),
                if (f.detail.isNotEmpty) Text(f.detail, style: t.secondary.copyWith(color: red)),
              ],
            ),
          ),
        if (onExport != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('info-receipts-export'),
            onPressed: onExport,
            icon: const Icon(Icons.ios_share),
            label: Text(l.chatsReceiptsExport),
          ),
          const SizedBox(height: 8),
          Text(l.chatsReceiptsNote, style: t.secondary),
        ],
      ],
    );
  }
}
