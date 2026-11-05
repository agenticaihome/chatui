import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../bitcoin/btc_format.dart';
import '../format.dart';
import '../l10n/l10n.dart';
import '../services/contacts_service.dart';
import '../services/wallet_service.dart';
import '../theme/argus_theme.dart';
import 'layout.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.accepts});

  /// In select mode, only the addresses that this accepts (the Bitcoin wallet gives its
  /// network's check). Null: the Ergo addresses, as before there were Bitcoin contacts.
  final bool Function(String address)? accepts;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool get _selectMode =>
      ModalRoute.of(context)?.settings.arguments == true;

  /// The user's other wallets as destinations: each one's address. Only in
  /// select mode.
  List<WalletContact> _ownWallets = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOwnWallets());
  }

  Future<void> _loadOwnWallets() async {
    if (!mounted || !_selectMode) return;
    try {
      final wallets = await walletService.listWallets();
      final active = walletService.activeWalletId;
      final out = <WalletContact>[];
      for (final w in wallets) {
        if (w.walletId == active) continue;
        final addr = w.pinnedAddress ?? w.address0;
        if (addr != null && addr.isNotEmpty) {
          out.add(WalletContact(id: 'wallet:${w.walletId}', name: appL10n.commonWallet, address: addr));
        }
      }
      if (mounted) setState(() => _ownWallets = out);
    } catch (_) {
      // The picker still offers saved contacts.
    }
  }

  void _addOrEdit([WalletContact? existing]) {
    showDialog<void>(
      context: context,
      builder: (_) => _ContactDialog(existing: existing),
    );
  }

  Future<void> _exportContacts() async {
    final contacts = contactsService.contacts;
    if (contacts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.contactsNoneToExport)),
      );
      return;
    }
    final json = '[${contacts.map((c) => jsonEncode({'name': c.name, 'address': c.address})).join(',')}]';
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(
          Uint8List.fromList(utf8.encode(json)),
          mimeType: 'application/json',
          name: 'argus_contacts.json',
        )],
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.contactsExportFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: contactsService,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_selectMode ? context.l10n.contactsSelectTitle : context.l10n.commonContacts),
            actions: _selectMode
                ? null
                : [
                    if (contactsService.contacts.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.file_download),
                        tooltip: context.l10n.contactsExportTooltip,
                        onPressed: _exportContacts,
                      ),
                  ],
          ),
          floatingActionButton: _selectMode
              ? null
              : FloatingActionButton(
                  onPressed: () => _addOrEdit(),
                  child: const Icon(Icons.person_add),
                ),
          body: ReadableWidth(
            child: _contactList(),
          ),
        );
      },
    );
  }

  Widget _contactList() {
    final accepts = widget.accepts ?? looksLikeRecipient;
    final contacts = _selectMode
        ? contactsService.contacts.where((c) => accepts(c.address)).toList()
        : contactsService.contacts;
    final ownWallets = _ownWallets.where((c) => accepts(c.address)).toList();
    if (contacts.isEmpty && ownWallets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            _selectMode
                ? context.l10n.contactsEmptySelect
                : context.l10n.contactsEmpty,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // In select mode the user's other wallets come first, then contacts.
    final rows = <Object>[
      if (ownWallets.isNotEmpty) context.l10n.contactsYourWallets,
      ...ownWallets,
      if (ownWallets.isNotEmpty && contacts.isNotEmpty) context.l10n.commonContacts,
      ...contacts,
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: rows.length,
      separatorBuilder: (_, i) => rows[i] is String || rows[i + 1] is String ? const SizedBox.shrink() : const Hairline(),
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is String) {
          return Padding(
            padding: EdgeInsets.fromLTRB(0, i == 0 ? 4 : 20, 0, 8),
            child: SectionLabel(row),
          );
        }
        final c = row as WalletContact;
        final own = c.id.startsWith('wallet');
        return InkWell(
          onTap: () {
            if (_selectMode) {
              Navigator.pop(context, c);
            } else {
              _addOrEdit(c);
            }
          },
          onLongPress: _selectMode ? null : () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(ctx.l10n.contactsDeleteTitle),
                content: Text(c.name),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.contactsDelete)),
                ],
              ),
            );
            if (ok == true) await contactsService.remove(c.id);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                if (own) ...[
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: ArgusColors.of(context).muted,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(shorten(c.address, head: 10, tail: 10), style: monoStyle(context, size: 11)),
                    ],
                  ),
                ),
                if (!_selectMode)
                  const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Adds or edits a contact. Owns its fields' controllers, so they outlive
/// the dialog's exit animation and go with its State.
class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.existing});

  final WalletContact? existing;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _address = TextEditingController(text: widget.existing?.address ?? '');

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final existing = widget.existing;
    final name = _name.text.trim();
    final addr = _address.text.trim();
    if (name.isEmpty || addr.isEmpty) return;
    // The address book has the addresses of both wallets, Ergo and Bitcoin (issue #103).
    if (!looksLikeRecipient(addr) && !looksLikeBitcoinAddress(addr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.contactsInvalidAddress)),
      );
      return;
    }
    if (existing == null) {
      await contactsService.add(name, addr);
    } else {
      await contactsService.update(existing.id, name: name, address: addr);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AlertDialog(
      title: Text(existing == null ? context.l10n.contactsAddTitle : context.l10n.contactsEditTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: context.l10n.commonName),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: InputDecoration(labelText: context.l10n.commonAddress),
            style: monoStyle(context, size: 12),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
        FilledButton(
          onPressed: _save,
          child: Text(existing == null ? context.l10n.contactsAdd : context.l10n.commonSave),
        ),
      ],
    );
  }
}
