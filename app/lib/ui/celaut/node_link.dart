
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../bridge/api/celaut.dart';
import '../../bridge/api/celaut_invite.dart';
import '../../celaut/celaut_link.dart';
import '../../celaut/host_port.dart';
import '../../l10n/l10n.dart';
import '../../theme/argus_theme.dart';
import 'id_row.dart';
import 'known_nodes_screen.dart';

/// The confirmation of a peer invitation, before the app connects (`docs/celaut/invite.md`):
/// the key of the node, its addresses in the order that the app tries them, and the ones
/// that the current route skips. True if the user chose Add.
Future<bool> confirmNodeInvite(BuildContext context, InviteReadView view) async {
  final l = context.l10n;
  final muted = ArgusColors.of(context).muted;
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('node-invite-confirm'),
      title: Text(l.celautLinkConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.celautLinkConfirmInvite),
            const SizedBox(height: 12),
            IdRow(label: l.celautLinkConfirmKey, id: view.peerId, keyPrefix: 'node-invite-key'),
            if (view.listed) ...[
              const SizedBox(height: 8),
              Text(l.celautLinkConfirmListed, key: const Key('node-invite-listed')),
            ],
            const SizedBox(height: 12),
            if (view.addresses.isEmpty)
              Text(l.celautInviteNoAddress, key: const Key('node-invite-no-address'))
            else ...[
              Text(l.celautLinkConfirmAddresses, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final a in view.addresses) ...[
                Text(a.address, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 13)),
                if (a.skipped != null)
                  Text(l.celautLinkConfirmSkipped, style: TextStyle(fontSize: 12.5, color: muted)),
                const SizedBox(height: 4),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('node-invite-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('node-invite-add'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.celautNodesAdd),
        ),
      ],
    ),
  );
  return sure == true;
}

/// The confirmation of a node address that a link gives. True if the user chose Add.
Future<bool> confirmNodeAddress(BuildContext context, HostPort address) async {
  final l = context.l10n;
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('node-address-confirm'),
      title: Text(l.celautLinkConfirmTitle),
      content: Text(l.celautLinkConfirmAddress(address.toString())),
      actions: [
        TextButton(
          key: const Key('node-invite-cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('node-invite-add'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.celautNodesAdd),
        ),
      ],
    ),
  );
  return sure == true;
}

/// Says why a link was not opened.
Future<void> showCelautLinkRefused(BuildContext context, CelautLinkError error) {
  final l = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('celaut-link-refused'),
      title: Text(l.celautLinkRefusedTitle),
      content: Text(switch (error) {
        CelautLinkError.tooLong => l.celautLinkTooLong,
        CelautLinkError.invalid => l.celautLinkInvalid,
        CelautLinkError.damaged => l.celautLinkDamaged,
        CelautLinkError.unknownKind => l.celautLinkUnknownKind,
      }),
      actions: [
        TextButton(
          key: const Key('celaut-link-refused-close'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonClose),
        ),
      ],
    ),
  );
}

/// The node list that opens after the user confirms a link. Tests give their own.
typedef NodeLinkScreen = Widget Function({Uint8List? invite, HostPort? address});

/// Open a `celaut://node` link (issue #138): read it, ask the user, then open the node list,
/// which connects to the node and adds it as it does for a scanned code. A link that the
/// app does not read, or an invitation that Rust refuses, shows why and changes nothing.
///
/// [read] reads an invitation without connecting (`celaut_read_invite`); tests give their
/// own, as for [screen].
Future<void> openNodeLink(
  BuildContext context,
  String link, {
  InviteReadView Function(Uint8List invite)? read,
  NodeLinkScreen? screen,
}) async {
  final nodes = screen ?? ({invite, address}) => KnownNodesScreen(invite: invite, address: address);
  switch (parseCelautLink(link)) {
    case CelautLinkRefused(:final error):
      await showCelautLinkRefused(context, error);
    case CelautAddressLink(:final address):
      if (!await confirmNodeAddress(context, address) || !context.mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => nodes(address: address)));
    case CelautInviteLink(:final bytes):
      final InviteReadView view;
      try {
        view = (read ?? (b) => celautReadInvite(invite: b))(bytes);
      } on CelautError {
        // The bytes looked like an invitation but are not one by the rules of nodo.
        await showCelautLinkRefused(context, CelautLinkError.damaged);
        return;
      }
      if (!await confirmNodeInvite(context, view) || !context.mounted) return;
      await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => nodes(invite: bytes)));
  }
}

/// The Share action of the node detail (answer 4 on PR #145): the `celaut://node?invite=`
/// link of the node [peerId], as a QR code that a phone camera opens, as text with Copy, and
/// with the share sheet of the system. The invitation has the key of the node and the
/// addresses where the app reached it (`celaut_node_invite`). If the app has no address that
/// another device could use, the dialog says so.
///
/// [invite] makes the invitation and [share] opens the share sheet; tests give their own.
Future<void> showNodeShare(
  BuildContext context,
  String peerId, {
  Uint8List Function(String peerId)? invite,
  Future<void> Function(String link)? share,
}) {
  final l = context.l10n;
  String? link;
  try {
    link = celautInviteLink((invite ?? (id) => celautNodeInvite(peerId: id))(peerId));
  } on CelautError {
    link = null;
  }
  if (link == null) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('node-share-none'),
        title: Text(l.celautNodeShareTitle),
        content: Text(l.celautNodeShareNone),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonClose)),
        ],
      ),
    );
  }
  final text = link;
  final muted = ArgusColors.of(context).muted;
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      key: const Key('node-share'),
      title: Text(l.celautNodeShareTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              // A fixed size: QrImageView uses a LayoutBuilder, which an AlertDialog cannot
              // measure without one.
              child: Container(
                key: const Key('node-share-qr'),
                width: 260,
                height: 260,
                color: Colors.white,
                padding: const EdgeInsets.all(10),
                child: QrImageView(
                  data: text,
                  semanticsLabel: l.celautNodeShareTitle,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              text,
              key: const Key('node-share-link'),
              style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(l.celautNodeShareNote, style: TextStyle(fontSize: 12.5, color: muted)),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('node-share-copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (!dialog.mounted || !context.mounted) return;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l.celautNodeShareCopied)));
          },
          child: Text(l.commonCopy),
        ),
        TextButton(
          key: const Key('node-share-send'),
          onPressed: () async {
            if (share != null) {
              await share(text);
            } else {
              await SharePlus.instance.share(ShareParams(text: text));
            }
          },
          child: Text(l.celautNodeShareLink),
        ),
        FilledButton(
          key: const Key('node-share-done'),
          onPressed: () => Navigator.pop(dialog),
          child: Text(l.commonDone),
        ),
      ],
    ),
  );
}
