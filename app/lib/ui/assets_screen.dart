import 'package:flutter/material.dart';
import '../format.dart';
import '../l10n/l10n.dart';
import '../services/network_controller.dart';
import '../services/privacy_service.dart';
import '../services/token_metadata.dart';
import '../services/token_pricer.dart';
import '../services/verified_tokens.dart';
import '../services/wallet_service.dart';
import '../services/wallet_sync_controller.dart';
import '../theme/argus_theme.dart';
import 'layout.dart';
import 'send_screen.dart';
import 'token_avatar.dart';
import 'widgets/asset_tile.dart';
import 'widgets/pending_balance_line.dart';
import 'widgets/token_detail_sheet.dart';

/// A text-first, lazy view of holdings. Opening it never hydrates metadata.
class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key, required this.args});
  final WalletRouteArgs args;
  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  bool _collectibles = false;
  bool _grid = true;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    privacyService.addListener(_privacyChanged);
  }

  void _privacyChanged() {
    if (privacyService.hideBalances && _search.text.isNotEmpty) _clearSearch();
  }

  @override
  void dispose() {
    privacyService.removeListener(_privacyChanged);
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  void _open(TokenBalance token) => showTokenDetailSheet(
    context,
    token: token,
    explorerUrl: networkController.explorerToken(token.id),
    onSend: (t) => Navigator.push(
      context,
      fadeRoute(
        SendScreen(initialAssetId: t.id),
        settings: RouteSettings(arguments: widget.args),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.assetsTitle),
      actions: [
        if (_collectibles)
          IconButton(
            tooltip: _grid ? context.l10n.assetsShowList : context.l10n.assetsShowGrid,
            icon: Icon(_grid ? Icons.view_list_outlined : Icons.grid_view),
            onPressed: () => setState(() => _grid = !_grid),
          ),
        IconButton(
          tooltip: context.l10n.assetsClearCache,
          icon: const Icon(Icons.delete_outline),
          onPressed: walletService.clearCollectibleData,
        ),
      ],
    ),
    body: ReadableWidth(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          networkController,
          privacyService,
          tokenPricer,
          walletSyncController,
          walletService.metadataChanges,
        ]),
        builder: (context, _) {
          final live = walletSyncController;
          final hidden = privacyService.hideBalances;
          final holdings = live.tokens
              .map(walletService.displayMetadata)
              .toList();
          final rows = holdings
              .where(
                (t) =>
                    (!_collectibles || t.isCollectible) &&
                    (t.label.toLowerCase().contains(_query) ||
                        t.id.toLowerCase().contains(_query)),
              )
              .toList();
          final unknown = holdings
              .where((t) => t.metadataState != MetadataState.complete)
              .length;
          final collectibleCount = holdings.where((t) => t.isCollectible).length;
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (textScale > 1.4)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(context.l10n.assetsAll),
                            selected: !_collectibles,
                            onSelected: (_) =>
                                setState(() => _collectibles = false),
                          ),
                          ChoiceChip(
                            label: Text(context.l10n.assetsCollectibles),
                            selected: _collectibles,
                            onSelected: (_) =>
                                setState(() => _collectibles = true),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(value: false, label: Text(context.l10n.assetsAll)),
                            ButtonSegment(
                              value: true,
                              label: Text(context.l10n.assetsCollectibles),
                            ),
                          ],
                          selected: {_collectibles},
                          onSelectionChanged: (s) =>
                              setState(() => _collectibles = s.single),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        labelText: context.l10n.assetsSearchLabel,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: context.l10n.assetsClearSearch,
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close, size: 18),
                              ),
                      ),
                      enabled: !hidden,
                      onChanged: (q) =>
                          setState(() => _query = q.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 10),
                    if (!hidden)
                      Text(
                        _collectibles
                            ? context.l10n.assetsCollectibleCount(collectibleCount)
                            : unknown > 0
                            ? context.l10n.assetsTokenIdCountIncomplete('${holdings.length}', '$unknown')
                            : context.l10n.assetsTokenIdCount('${holdings.length}'),
                        style: TextStyle(color: ArgusColors.of(context).muted),
                      ),
                    if (live.publicSnapshotOnly)
                      Text(context.l10n.assetsPublicOnly),
                    if (live.balanceNano == null)
                      Text(context.l10n.assetsNotLoaded),
                    if (live.lastSyncedAt != null)
                      Text(
                        context.l10n.assetsLastSynced(formatSyncAge(live.lastSyncedAt)),
                      ),
                    PendingBalanceLine(pending: live.pending, hidden: hidden),
                  ],
                ),
              ),
              Expanded(
                child: hidden
                    ? Center(child: Text(context.l10n.assetsHidden))
                    : rows.isEmpty && (_collectibles || _query.isNotEmpty)
                    ? _EmptyAssets(
                        searching: _query.isNotEmpty,
                        unknown: unknown,
                        onClearSearch: _clearSearch,
                      )
                    : _collectibles && _grid
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260 * textScale,
                          mainAxisExtent:
                              270 +
                              (textScale - 1).clamp(0, double.infinity) * 110,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: rows.length,
                        itemBuilder: (context, index) => _CollectibleCard(
                          token: rows[index],
                          onTap: () => _open(rows[index]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        itemCount:
                            rows.length +
                            (!_collectibles && _query.isEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          final hasErg = !_collectibles && _query.isEmpty;
                          if (index == 0 && hasErg)
                            return AssetTile.erg(
                              balanceNano: live.balanceNano,
                              fiatText: networkController.fiatText(live.balanceNano),
                            );
                          final token = rows[index - (hasErg ? 1 : 0)];
                          return AssetTile.token(
                            token,
                            onTap: () => _open(token),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _EmptyAssets extends StatelessWidget {
  const _EmptyAssets({
    required this.searching,
    required this.unknown,
    required this.onClearSearch,
  });
  final bool searching;
  final int unknown;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.collections_outlined,
              size: 36,
              color: ArgusColors.of(context).muted,
            ),
            const SizedBox(height: 12),
            Text(
              searching
                  ? context.l10n.assetsNoMatch
                  : context.l10n.assetsNoCollectibles,
              textAlign: TextAlign.center,
            ),
            if (searching)
              TextButton(
                onPressed: onClearSearch,
                child: Text(context.l10n.assetsClearSearch),
              )
            else if (unknown > 0) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.assetsIncompleteHint,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Collectible browsing remains local and text-first. Artwork is requested
/// only through the explicit consent action in the individual details sheet.
class _CollectibleCard extends StatelessWidget {
  const _CollectibleCard({required this.token, required this.onTap});
  final TokenBalance token;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ArgusColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.inset,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: TokenAvatar(
                      tokenId: token.id,
                      label: tokenTicker(token),
                      radius: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      token.label,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (cautionedToken(token.id) != null) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: context.l10n.tokenCautionFlagged,
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: rust,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                token.classification,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.assetsHeld(holdingAmountText(token)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: colors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
