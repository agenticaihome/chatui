import 'layout.dart';
import 'widgets/tx_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../format.dart';
import '../l10n/l10n.dart';
import '../services/network_controller.dart';
import '../services/token_issuance.dart';
import '../services/wallet_service.dart';
import '../theme/argus_theme.dart';
import 'confirm_transaction_sheet.dart';
import 'widgets/error_sheet.dart';
import 'widgets/soft_card.dart';

/// Issue a token or NFT, or burn tokens: two things a wallet does rarely
/// and one of them cannot be undone, so they live apart from Send.
class TokenToolsScreen extends StatefulWidget {
  const TokenToolsScreen({super.key});

  @override
  State<TokenToolsScreen> createState() => _TokenToolsScreenState();
}

class _TokenToolsScreenState extends State<TokenToolsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.commonTokens),
          bottom: TabBar(tabs: [Tab(text: context.l10n.tokenIssue), Tab(text: context.l10n.tokenBurn)]),
        ),
        body: ReadableWidth(
          child: const TabBarView(children: [_IssueTab(), _BurnTab()]),
        ),
      ),
    );
  }
}

// ── Issue ───────────────────────────────────────────────────────────────

class _IssueTab extends StatefulWidget {
  const _IssueTab();

  @override
  State<_IssueTab> createState() => _IssueTabState();
}

class _IssueTabState extends State<_IssueTab>
    with TxReceiptOwner, AutomaticKeepAliveClientMixin {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _decimals = TextEditingController(text: '0');
  final _hash = TextEditingController();
  final _url = TextEditingController();
  bool _nft = false;
  String _kind = 'picture';
  bool _working = false;
  String? _issuedId;
  String? _issuedTxId;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final c in [_name, _description, _amount, _decimals, _hash, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _decimalsValue => _nft ? 0 : (int.tryParse(_decimals.text.trim()) ?? -1);

  String? get _error => issuanceError(
        name: _name.text,
        amountText: _nft ? '1' : _amount.text,
        decimals: _decimalsValue,
        nft: _nft,
        contentHashHex: _hash.text,
        url: _url.text,
      );

  Future<void> _issue() async {
    if (_working) return;
    final problem = _error;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final args = WalletRouteArgs.of(context);
    final amount = _nft ? BigInt.one : parseIssuanceAmount(_amount.text, _decimalsValue)!;
    setState(() => _working = true);
    try {
      final prepared = await walletService.prepareMint(
        senderAddress: args.senderAddress,
        spendAddresses: args.historyAddresses,
        changeAddress: args.changeAddress,
        name: _name.text.trim(),
        description: _description.text.trim(),
        decimals: _decimalsValue,
        amount: amount,
        nftKind: _nft ? _kind : null,
        nftContentHashHex: _nft && _hash.text.trim().isNotEmpty ? _hash.text.trim().toLowerCase() : null,
        nftUrl: _nft ? _url.text.trim() : null,
        nodeUrl: networkController.activeUrl,
      );
      if (!mounted) return;
      final tokenId = prepared['token_id'] as String;
      final ok = await showConfirmTransactionSheet(
        context,
        title: _nft ? context.l10n.tokenIssueNftTitle : context.l10n.tokenIssueTokenTitle,
        confirmLabel: context.l10n.tokenIssue,
        detail: context.l10n.tokenIssueDetail,
        rows: [
          ConfirmTxRow(context.l10n.commonName, _name.text.trim(), bold: true),
          ConfirmTxRow(context.l10n.tokenSupply, _nft ? '1 (NFT)' : context.l10n.tokenSupplyDecimals(_decimalsValue, formatTokenAmountGrouped(amount.toInt(), _decimalsValue))),
          if (_description.text.trim().isNotEmpty) ConfirmTxRow(context.l10n.tokenDescription, _description.text.trim()),
          if (_nft) ConfirmTxRow(context.l10n.tokenKind, _kind),
          if (_nft && _url.text.trim().isNotEmpty) ConfirmTxRow(context.l10n.tokenLink, _url.text.trim()),
          ConfirmTxRow(context.l10n.tokenIdRow, shorten(tokenId, head: 10, tail: 8)),
          ConfirmTxRow(context.l10n.tokenBoxValue, formatErg((prepared['box_value'] as num).toInt())),
          ConfirmTxRow(context.l10n.commonMinerFee, formatErg((prepared['miner_fee'] as num).toInt())),
        ],
        preparationId: (prepared['preparation_id'] as num).toInt(),
      );
      if (!ok || !mounted) return;
      final txId = await walletService.sendErg(
        preparationId: (prepared['preparation_id'] as num).toInt(),
      );
      if (mounted)
        setState(() {
          _issuedId = tokenId;
          _issuedTxId = txId;
        });
      showTxResultSheet(
        receiptContext,
        txId: txId,
        headline: appL10n.tokenIssuanceSubmitted,
        note: appL10n.tokenIssuanceNote,
      );
    } catch (e) {
      if (mounted) showTxFailureSheet(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final muted = ArgusColors.of(context).muted;
    final issued = _issuedId;
    if (issued != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: accentTextOf(context),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.tokenNamedIssuanceSubmitted(_name.text.trim()),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tokenIssuedExplainer,
              style: TextStyle(color: muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(context.l10n.tokenIdLabel, textAlign: TextAlign.center),
            SoftCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(child: SelectableText(issued, style: monoStyle(context, size: 11))),
                  IconButton(
                    tooltip: context.l10n.tokenCopyId,
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: issued));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.tokenIdCopied)));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => showTxResultSheet(
                receiptContext,
                txId: _issuedTxId!,
                headline: context.l10n.tokenIssuanceSubmitted,
                note: context.l10n.tokenIssuanceNote,
              ),
              child: Text(context.l10n.tokenViewReceipt),
            ),
            Text(context.l10n.tokenTransactionId),
            SelectableText(_issuedTxId!, style: monoStyle(context, size: 11)),
            OutlinedButton(
              onPressed: () => setState(() {
                _issuedId = null;
                _issuedTxId = null;
                for (final c in [_name, _description, _amount, _hash, _url]) {
                  c.clear();
                }
              }),
              child: Text(context.l10n.tokenIssueAnother),
            ),
          ],
        ),
      );
    }
    final problem = _error;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          context.l10n.tokenIssueIntro,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('NFT'),
          subtitle: Text(context.l10n.nftSubtitle),
          value: _nft,
          onChanged: (v) => setState(() {
            _nft = v;
            if (v) {
              _amount.text = '1';
              _decimals.text = '0';
            }
          }),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('issue-name'),
          controller: _name,
          decoration: InputDecoration(labelText: context.l10n.commonName),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('issue-description'),
          controller: _description,
          decoration: InputDecoration(labelText: context.l10n.tokenDescriptionOptional),
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (!_nft)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  key: const Key('issue-amount'),
                  controller: _amount,
                  decoration: InputDecoration(labelText: context.l10n.tokenSupply, helperText: context.l10n.tokenSupplyHelper),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  key: const Key('issue-decimals'),
                  controller: _decimals,
                  decoration: InputDecoration(labelText: context.l10n.tokenDecimals, helperText: context.l10n.tokenDecimalsHelper),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        if (_nft) ...[
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: InputDecoration(labelText: context.l10n.tokenKind),
            items: [
              DropdownMenuItem(value: 'picture', child: Text(context.l10n.nftKindPicture)),
              DropdownMenuItem(value: 'audio', child: Text(context.l10n.nftKindAudio)),
              DropdownMenuItem(value: 'video', child: Text(context.l10n.nftKindVideo)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? 'picture'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('issue-hash'),
            controller: _hash,
            decoration: InputDecoration(labelText: context.l10n.nftHashLabel, helperText: context.l10n.nftHashHelper),
            style: monoStyle(context, size: 12),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('issue-url'),
            controller: _url,
            decoration: InputDecoration(labelText: context.l10n.nftLinkLabel, helperText: context.l10n.nftLinkHelper),
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 8),
        if (problem != null && _name.text.isNotEmpty)
          Text(problem, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
        const SizedBox(height: 16),
        Text(context.l10n.tokenIssueCost, style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('issue-continue'),
          onPressed: _working || problem != null ? null : _issue,
          child: Text(_working ? context.l10n.tokenPreparing : context.l10n.tokenIssue),
        ),
      ],
    );
  }
}

// ── Burn ────────────────────────────────────────────────────────────────

class _BurnTab extends StatefulWidget {
  const _BurnTab();

  @override
  State<_BurnTab> createState() => _BurnTabState();
}

class _BurnTabState extends State<_BurnTab>
    with TxReceiptOwner, AutomaticKeepAliveClientMixin {
  /// Token id to the amount field, for the tokens picked to burn.
  final Map<String, TextEditingController> _picked = {};
  final _confirmWord = TextEditingController();
  bool _working = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final c in _picked.values) {
      c.dispose();
    }
    _confirmWord.dispose();
    super.dispose();
  }

  /// Amounts in base units per token, or the first problem.
  (Map<String, int>?, String?) _burns(List<TokenBalance> held) {
    final out = <String, int>{};
    for (final e in _picked.entries) {
      final t = held.where((t) => t.id == e.key).firstOrNull;
      if (t == null) continue;
      final int? n;
      if ((t.amount == 1 && t.decimals == 0)) {
        n = 1;
      } else {
        n = parseDecimalToBase(e.value.text, t.decimals);
      }
      if (n == null || n <= 0) return (null, context.l10n.tokenBurnEnterAmount(t.label));
      if (n > t.amount) return (null, context.l10n.tokenBurnYouHold(formatTokenAmount(t.amount, t.decimals), t.label));
      out[e.key] = n;
    }
    if (out.isEmpty) return (null, context.l10n.tokenBurnPick);
    return (out, null);
  }

  Future<void> _burn(List<TokenBalance> held) async {
    if (_working) return;
    final (burns, problem) = _burns(held);
    if (burns == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem!)));
      return;
    }
    if (_confirmWord.text.trim() != burnConfirmWord) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.tokenBurnTypeToGoOn(burnConfirmWord))));
      return;
    }
    final args = WalletRouteArgs.of(context);
    setState(() => _working = true);
    try {
      final prepared = await walletService.prepareBurn(
        senderAddress: args.senderAddress,
        spendAddresses: args.historyAddresses,
        changeAddress: args.changeAddress,
        burns: burns,
        nodeUrl: networkController.activeUrl,
      );
      if (!mounted) return;
      String label(String id, int n) {
        final t = held.firstWhere((t) => t.id == id);
        return '${formatTokenAmountGrouped(n, t.decimals)} ${t.label}';
      }
      final ok = await showConfirmTransactionSheet(
        context,
        title: context.l10n.tokenBurnTitle,
        confirmLabel: context.l10n.tokenBurnForGood,
        detail: context.l10n.tokenBurnDetail,
        rows: [
          for (final b in (prepared['burned'] as List).cast<Map>())
            ConfirmTxRow(context.l10n.tokenBurn, label(b['token_id'] as String, (b['amount'] as num).toInt()), bold: true),
          ConfirmTxRow(context.l10n.commonMinerFee, formatErg((prepared['miner_fee'] as num).toInt())),
          ConfirmTxRow(context.l10n.tokenBurnBackToYou, formatErg((prepared['change_nano_erg'] as num).toInt())),
        ],
        preparationId: (prepared['preparation_id'] as num).toInt(),
      );
      if (!ok || !mounted) return;
      final txId = await walletService.sendErg(preparationId: (prepared['preparation_id'] as num).toInt());
      if (mounted)
        setState(() {
          for (final c in _picked.values) {
            c.dispose();
          }
          _picked.clear();
          _confirmWord.clear();
        });
      showTxResultSheet(
        receiptContext,
        txId: txId,
        headline: appL10n.tokenBurnSubmitted,
      );
    } catch (e) {
      if (mounted) showTxFailureSheet(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final muted = ArgusColors.of(context).muted;
    final held = WalletRouteArgs.of(context).tokens.where((t) => t.amount > 0).toList();
    final (burns, problem) = _burns(held);
    final ready = burns != null && _confirmWord.text.trim() == burnConfirmWord;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        SoftCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_fire_department_outlined, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.tokenBurnWarning,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (held.isEmpty)
          Text(context.l10n.tokenBurnNoTokens, style: TextStyle(color: muted))
        else ...[
          Text(context.l10n.tokenBurnInWallet, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final t in held)
            CheckboxListTile(
              key: ValueKey('burn-${t.id}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(t.label),
              subtitle: Text(context.l10n.tokenBurnHeldRow(formatTokenAmountGrouped(t.amount, t.decimals), shorten(t.id, head: 8, tail: 6)),
                  style: TextStyle(color: muted, fontSize: 12)),
              value: _picked.containsKey(t.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _picked[t.id] = TextEditingController(text: (t.amount == 1 && t.decimals == 0) ? '1' : '');
                } else {
                  _picked.remove(t.id)?.dispose();
                }
              }),
            ),
          for (final t in held)
            if (_picked[t.id] case final ctl?)
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 12),
                child: TextField(
                  key: ValueKey('burn-amount-${t.id}'),
                  controller: ctl,
                  enabled: !(t.amount == 1 && t.decimals == 0),
                  decoration: InputDecoration(
                    labelText: (t.amount == 1 && t.decimals == 0) ? context.l10n.tokenBurnOneUnit(t.label) : context.l10n.tokenBurnAmountLabel(t.label),
                    helperText: (t.amount == 1 && t.decimals == 0) ? null : context.l10n.tokenBurnOf(formatTokenAmount(t.amount, t.decimals)),
                    suffixIcon: (t.amount == 1 && t.decimals == 0)
                        ? null
                        : TextButton(
                            onPressed: () => setState(() => ctl.text = formatTokenAmount(t.amount, t.decimals)),
                            child: Text(context.l10n.tokenBurnAll),
                          ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
          if (problem != null && _picked.isNotEmpty)
            Text(problem, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            key: const Key('burn-confirm-word'),
            controller: _confirmWord,
            decoration: InputDecoration(labelText: context.l10n.tokenBurnTypeToConfirm(burnConfirmWord)),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('burn-continue'),
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError),
            onPressed: _working || !ready ? null : () => _burn(held),
            child: Text(_working ? context.l10n.tokenPreparing : context.l10n.tokenBurn),
          ),
        ],
      ],
    );
  }
}
