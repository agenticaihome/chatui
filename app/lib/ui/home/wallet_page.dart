import 'package:flutter/material.dart';

import '../../format.dart';
import '../../theme/argus_theme.dart';
import '../../theme/argus_tones.dart';
import '../layout.dart';
import 'home_format.dart';
import 'home_glass.dart';
import 'home_hero.dart';
import 'home_models.dart';
import 'home_rows.dart';
import 'home_scene.dart';
import 'home_style.dart';
import 'home_widgets.dart';
import 'wallet_actions.dart';
import 'wallet_tools_sheet.dart';
import '../../l10n/l10n.dart';

/// One open wallet's frame: the way back to every wallet, its name and
/// state, the tab it is on, and its tabs.
///
/// The back chevron returns to the overview, which is where wallets are
/// switched. The header carries the scanner. On the Wallet tab the header is [immersive]: it lies over
/// the scene the page opens on, clear until the page scrolls under it.
class WalletPageScreen extends StatelessWidget {
  const WalletPageScreen({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.actions = const [],
    this.navBar,
    this.subtitle,
    this.subtitleLive = false,
    this.immersive = true,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? navBar;

  /// Under the title: the wallet's state, e.g. "Unlocked", with a green dot
  /// when [subtitleLive].
  final String? subtitle;
  final bool subtitleLive;

  /// The page lies on the scene, its header clear until the page scrolls
  /// under it. Off for the tabs that are lists of their own.
  final bool immersive;

  /// The wallet's medallion, where every immersive page sets it: beside the
  /// balance, the first thing under the header.
  static const medallionSize = 112.0;
  static const medallionInset = homeGutter - 14;

  @override
  Widget build(BuildContext context) {
    final page = Theme.of(context).scaffoldBackgroundColor;
    final t = HomeText.of(context);
    final live = mossFor(context);
    final toolbar = subtitle == null ? kToolbarHeight : 66.0;
    final scaffold = Scaffold(
      backgroundColor: immersive ? Colors.transparent : null,
      appBar: AppBar(
        backgroundColor: immersive ? sceneBarColor(page) : null,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: toolbar,
        leading: IconButton(
          key: const Key('wallet-back'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          tooltip: context.l10n.homeAllWallets,
          onPressed: onBack,
        ),
        titleSpacing: 0,
        title: subtitle == null
            ? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (subtitleLive) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: live,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: live.withValues(alpha: 0.5), blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        subtitle!,
                        style: t.secondary.copyWith(fontFamily: bodyFont, fontSize: 14, color: subtitleLive ? live : t.muted),
                      ),
                    ],
                  ),
                ],
              ),
        actions: [...actions, const SizedBox(width: 4)],
      ),
      body: ReadableWidth(
        child: body,
      ),
      bottomNavigationBar: navBar,
    );
    if (!immersive) return scaffold;
    final media = MediaQuery.of(context);
    final top = media.padding.top + toolbar;
    return ColoredBox(
      color: page,
      // The light follows the medallion, which keeps to a column on a wide window.
      child: LayoutBuilder(
        builder: (context, box) => HomeScene(
          light: SceneLight.medallion,
          lightAt: Offset(
            AppLayout.readableSide(box.maxWidth) + medallionInset + medallionSize / 2,
            top + medallionSize / 2 - 4,
          ),
          height: top + 560,
          child: scaffold,
        ),
      ),
    );
  }
}

/// The tabs under a wallet's actions.
enum WalletPageTab { assets, activity, addresses, utxos }

/// The Wallet tab's scrolling body.
///
/// Top to bottom: the scene, with the balance set straight onto it beside
/// the wallet's medallion, the address it is shown as and what sits on its
/// other addresses on pills of glass, and the round actions; a line on how
/// current it is, and on anything that needs a look (fragmented boxes, a
/// pin that cannot be derived); then tabs. Assets shows the holdings
/// worth a glance and the last three transactions; Activity, Addresses and
/// UTXOs each lead on to their tool. Tools live in Discover, settings in
/// Settings.
class WalletPageView extends StatelessWidget {
  const WalletPageView({
    super.key,
    required this.data,
    this.onToggleHidden,
    this.onAction,
    this.onTool,
    this.onAsset,
    this.onAllAssets,
    this.onActivity,
    this.onAllActivity,
    this.onStatus,
    this.onTidyUp,
    this.onOtherAddresses,
    this.onReceive,
    this.onPinIssue,
    this.onRetry,
    this.onCopyAddress,
    this.onRefresh,
  });

  final WalletPageData data;
  final VoidCallback? onToggleHidden;

  /// Send or Receive. More opens its sheet
  /// here and reports the pick through [onTool].
  final ValueChanged<WalletAction>? onAction;
  final ValueChanged<WalletTool>? onTool;
  final ValueChanged<String>? onAsset;
  final VoidCallback? onAllAssets;
  final ValueChanged<String>? onActivity;
  final VoidCallback? onAllActivity;

  /// The status line: the UTXO tools.
  final VoidCallback? onStatus;

  /// "N UTXOs · Fragmented": the suggested cleanup.
  final VoidCallback? onTidyUp;
  final VoidCallback? onOtherAddresses;

  /// The empty-activity line's link; defaults to the Receive action.
  final VoidCallback? onReceive;
  final VoidCallback? onPinIssue;

  /// No node answers: look again.
  final VoidCallback? onRetry;

  /// The address of the wallet, copied.
  final VoidCallback? onCopyAddress;

  /// Pull to refresh.
  final Future<void> Function()? onRefresh;

  /// Holdings and transactions shown before "View all".
  static const assetLimit = 6;
  static const activityLimit = 3;

  Future<void> _more(BuildContext context) async {
    final tool = await showWalletToolsSheet(context, tools: data.tools);
    if (tool != null) onTool?.call(tool);
  }

  void _act(BuildContext context, WalletAction a) => a == WalletAction.more ? _more(context) : onAction?.call(a);

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      key: const Key('wallet-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // The page settles in from the top: the scene, its lines, then the
        // tabs.
        HomeEntrance(child: _top(context)),
        HomeEntrance(
          order: 1,
          child: Column(
            children: [
              const HomeRule(),
              ..._statusLines(context),
            ],
          ),
        ),
        const SizedBox(height: 4),
        HomeEntrance(
          order: 2,
          child: _WalletTabs(
            tabs: [
              WalletPageTab.assets,
              WalletPageTab.activity,
              WalletPageTab.addresses,
              WalletPageTab.utxos,
            ],
            content: (tab) => switch (tab) {
              WalletPageTab.assets => [..._assets(context), const SizedBox(height: 16), ..._activity(context)],
              WalletPageTab.activity => _activity(context, all: true),
              WalletPageTab.addresses => _addresses(context),
              WalletPageTab.utxos => _utxos(context),
            },
          ),
        ),
      ],
    );
    final refresh = onRefresh;
    return refresh == null ? list : RefreshIndicator(onRefresh: refresh, child: list);
  }

  /// The balance beside the medallion, the address pills and the actions,
  /// on the scene the page's frame paints.
  Widget _top(BuildContext context) {
    final wallet = data.wallet;
    final hidden = data.hidden;
    final other = wallet.otherAddresses;
    final address = wallet.address;
    final t = HomeText.of(context);
    const medallion = WalletPageScreen.medallionSize;
    return Padding(
      padding: const EdgeInsets.fromLTRB(homeGutter, 18, homeGutter, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              HomeBalance(
                label: context.l10n.homeBalanceLabel,
                figureKey: const Key('wallet-balance'),
                pendingKey: const Key('wallet-balance-pending'),
                nanoErg: wallet.nanoErg,
                loading: wallet.loading,
                currency: data.currency,
                fiatValue: wallet.fiatValue,
                unpricedCount: data.unpricedCount,
                pricesNote: data.pricesNote,
                pending: wallet.pending,
                hidden: hidden,
                onToggleHidden: onToggleHidden,
                onUnpriced: onAllAssets,
                figureReserve: medallion - 18,
                showLabel: false,
                unpricedPill: false,
              ),
              PositionedDirectional(
                top: -18,
                end: -(homeGutter - WalletPageScreen.medallionInset),
                child: const WalletMedallion(size: medallion),
              ),
            ],
          ),
          // The address the wallet is shown as, which is not always where
          // all of its money sits.
          if (address != null) ...[
            const SizedBox(height: 18),
            IdentityPill(address: address, pinnedIndex: wallet.pinnedIndex, onCopy: onCopyAddress),
          ],
          if (other != null) ...[
            const SizedBox(height: 10),
            GlassPill(
              inkKey: const Key('funds-elsewhere'),
              onTap: onOtherAddresses,
              hint: context.l10n.homeOtherAddressesHint,
              semanticLabel: spoken(otherAddressLine(other, hidden: hidden)),
              leading: Icon(Icons.subdirectory_arrow_right, size: 20, color: t.muted),
              child: Text(otherAddressLine(other, hidden: hidden), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
          const SizedBox(height: 20),
          HomeActionCircles(
            actions: data.actions,
            onAction: (a) => _act(context, a),
          ),
        ],
      ),
    );
  }

  /// How current the figures are, and anything about the wallet that needs
  /// a look, one line each.
  List<Widget> _statusLines(BuildContext context) {
    final t = HomeText.of(context);
    final hidden = data.hidden;
    final utxos = data.utxoCount;
    // Hidden balances keep the advice but not the count, which says how
    // much the wallet has been used.
    final utxoText = utxos == null || hidden ? context.l10n.homeUtxos : context.l10n.homeUtxoCount(groupThousands('$utxos'));
    final lines = <Widget>[];
    // Each part of a status line wraps as a whole: "Updated just" over
    // "now" reads as two statements.
    String whole(String part) => part.replaceAll(' ', nbsp);
    if (data.status case final status?) {
      final (word, dot, problem) = syncLook(context, status);
      final parts = [
        if (status.blockHeight != null) context.l10n.homeBlock(formatWithCommas(status.blockHeight!)),
        // While fragmented the count leads its own line below.
        if (utxos != null && !hidden && !data.fragmented) utxoText,
        if (status.age != null) whole(status.age!),
      ];
      lines.add(HomeLineRow(
        inkKey: const Key('wallet-status'),
        onTap: onStatus,
        hint: onStatus == null ? null : context.l10n.homeUtxoTools,
        semanticLabel: spoken([word, ...parts].join(', ')),
        markWidth: 14,
        chevron: false,
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dot,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.5), blurRadius: 6)],
          ),
        ),
        text: TextSpan(
          children: [
            TextSpan(text: word, style: TextStyle(color: problem ? rustFor(context) : t.ink, fontWeight: FontWeight.w700)),
            for (final p in parts) TextSpan(text: '  ·  $p'),
          ],
        ),
      ));
    }
    if (data.offline) {
      lines.add(HomeLineRow(
        inkKey: const Key('wallet-offline'),
        onTap: onRetry,
        action: onRetry == null ? null : context.l10n.commonRetry,
        semanticLabel: '${context.l10n.homeNoReachableNodes}${onRetry == null ? '' : '. ${context.l10n.commonRetry}'}',
        leading: Icon(Icons.wifi_off_outlined, size: 16, color: rustFor(context)),
        text: TextSpan(text: context.l10n.homeNoReachableNodes, style: TextStyle(color: rustFor(context))),
      ));
    }
    if (data.fragmented && utxos != null) {
      lines.add(HomeLineRow(
        inkKey: const Key('utxo-fragmented'),
        onTap: onTidyUp,
        semanticLabel: context.l10n.homeSpokenFragmented(spoken(utxoText)),
        leading: Icon(Icons.grain, size: 18, color: rustFor(context)),
        action: context.l10n.homeTidyUp,
        text: TextSpan(
          children: [
            TextSpan(text: utxoText, style: TextStyle(color: t.ink)),
            TextSpan(text: ' · ${context.l10n.homeFragmented}', style: TextStyle(color: rustFor(context), fontWeight: FontWeight.w700)),
          ],
        ),
      ));
    }
    if (data.pinIssue case final issue?) {
      lines.add(HomeLineRow(
        inkKey: const Key('wallet-pin-issue'),
        onTap: onPinIssue,
        semanticLabel: issue,
        leading: Icon(Icons.push_pin_outlined, size: 16, color: rustFor(context)),
        text: TextSpan(text: issue, style: TextStyle(color: rustFor(context))),
      ));
    }
    return lines;
  }

  List<Widget> _assets(BuildContext context) {
    final hidden = data.hidden;
    final shown = data.assets.take(assetLimit).toList();
    return [
      const SizedBox(height: 14),
      if (shown.isNotEmpty)
        GlassCard(
          key: const Key('wallet-assets'),
          dividers: true,
          children: [
            for (final a in shown)
              HomeAssetRow(
                asset: a,
                currency: data.currency,
                hidden: hidden,
                onTap: onAsset == null ? null : () => onAsset!(a.id),
              ),
          ],
        ),
      // A count says how much is held as surely as an amount does.
      if (data.assetCount > shown.length && onAllAssets != null)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: homeGutter - 6),
            child: HomeLink(
              text: hidden ? context.l10n.homeAllAssets : context.l10n.homeAllAssetsCount(groupThousands('${data.assetCount}')),
              onPressed: onAllAssets,
              linkKey: const Key('wallet-all-assets'),
              quiet: true,
            ),
          ),
        ),
    ];
  }

  /// The latest transactions, or with [all] every one the page has, each
  /// row titled and figured as the activity model says.
  List<Widget> _activity(BuildContext context, {bool all = false}) {
    final t = HomeText.of(context);
    final receive = onReceive ?? (onAction == null ? null : () => onAction!(WalletAction.receive));
    final emptyAction = receive == null
        ? null
        : data.activityEmptyAction == WalletPageData.showMyAddress
            ? context.l10n.homeShowMyAddress
            : data.activityEmptyAction;
    final empty = data.activityEmpty ?? context.l10n.homeNoActivity;
    final shown = all ? data.activity : data.activity.take(activityLimit).toList();
    return [
      if (all)
        const SizedBox(height: 14)
      else
        HomeHeading(
          title: context.l10n.homeRecentActivity,
          action: data.activity.isEmpty || onAllActivity == null ? null : context.l10n.homeViewAll,
          actionKey: const Key('wallet-all-activity'),
          onAction: onAllActivity,
        ),
      GlassCard(
        key: const Key('wallet-activity'),
        dividers: true,
        children: [
          if (shown.isNotEmpty)
            for (final tx in shown)
              HomeActivityRow(item: tx, hidden: data.hidden, onTap: onActivity == null ? null : () => onActivity!(tx.id))
          else if (data.activityLoading)
            HomeLineRow(
              inkKey: const Key('wallet-activity-loading'),
              semanticLabel: context.l10n.homeReadingActivity,
              leading: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              text: TextSpan(text: context.l10n.homeReadingActivityEllipsis),
            )
          else if (data.activityError case final error?)
            HomeLineRow(
              inkKey: const Key('wallet-activity-error'),
              semanticLabel: error,
              leading: Icon(Icons.cloud_off_outlined, size: 18, color: rustFor(context)),
              text: TextSpan(text: error, style: TextStyle(color: rustFor(context))),
            )
          else
            HomeLineRow(
              inkKey: const Key('wallet-no-activity'),
              onTap: emptyAction == null ? null : receive,
              semanticLabel: [empty, ?emptyAction].join('. '),
              leading: Icon(Icons.inbox_outlined, size: 18, color: t.muted),
              action: emptyAction,
              text: TextSpan(text: empty),
            ),
        ],
      ),
      if (all && data.activity.isNotEmpty && onAllActivity != null)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: homeGutter - 6),
            child: HomeLink(text: context.l10n.homeFullHistory, onPressed: onAllActivity, quiet: true),
          ),
        ),
    ];
  }

  /// Where the wallet's funds sit: the address it is shown as, its other
  /// addresses and the way to every one.
  List<Widget> _addresses(BuildContext context) {
    final t = HomeText.of(context);
    final wallet = data.wallet;
    final address = wallet.address;
    final other = wallet.otherAddresses;
    return [
      const SizedBox(height: 14),
      GlassCard(
        dividers: true,
        dividerIndent: glassGutter,
        children: [
          if (address != null)
            HomeLineRow(
              semanticLabel: spoken(wallet.pinnedIndex != null
                  ? context.l10n.homeSpokenPinnedAddress('${wallet.pinnedIndex}', shorten(address, head: 8, tail: 6))
                  : shorten(address, head: 8, tail: 6)),
              leading: Icon(Icons.person_outline, size: 18, color: HomeTones.of(context).accent),
              text: TextSpan(
                children: [
                  if (wallet.pinnedIndex != null) TextSpan(text: '#${wallet.pinnedIndex}   ', style: TextStyle(color: t.ink)),
                  TextSpan(text: shorten(address, head: 10, tail: 8)),
                ],
              ),
            ),
          if (other != null)
            HomeLineRow(
              onTap: onOtherAddresses,
              semanticLabel: spoken(otherAddressLine(other, hidden: data.hidden)),
              leading: Icon(Icons.subdirectory_arrow_right, size: 18, color: t.muted),
              text: TextSpan(text: otherAddressLine(other, hidden: data.hidden)),
            ),
          if (onTool != null)
            HomeLineRow(
              inkKey: const Key('wallet-every-address'),
              onTap: () => onTool!(WalletTool.addresses),
              semanticLabel: context.l10n.homeEveryAddress,
              leading: Icon(Icons.account_tree_outlined, size: 18, color: t.muted),
              text: TextSpan(text: context.l10n.homeEveryAddress, style: TextStyle(color: t.ink)),
            ),
          // Nothing known yet: the tab says so rather than showing an empty pane.
          if (address == null && other == null && onTool == null)
            HomeLineRow(
              inkKey: const Key('wallet-no-addresses'),
              semanticLabel: context.l10n.homeNoAddresses,
              leading: Icon(Icons.account_tree_outlined, size: 18, color: t.muted),
              text: TextSpan(
                text: context.l10n.homeNoAddressesDot,
              ),
            ),
        ],
      ),
    ];
  }

  /// The wallet's boxes: how many, whether they are fragmented, and the
  /// way to the UTXO tools.
  List<Widget> _utxos(BuildContext context) {
    final t = HomeText.of(context);
    final utxos = data.utxoCount;
    final count = utxos == null || data.hidden ? context.l10n.homeUtxos : context.l10n.homeUtxoCount(groupThousands('$utxos'));
    return [
      const SizedBox(height: 14),
      GlassCard(
        dividers: true,
        dividerIndent: glassGutter,
        children: [
          HomeLineRow(
            semanticLabel: spoken(data.fragmented ? context.l10n.homeSpokenCountFragmented(count) : count),
            leading: Icon(Icons.grain, size: 18, color: data.fragmented ? rustFor(context) : t.muted),
            text: TextSpan(
              children: [
                TextSpan(text: count, style: TextStyle(color: t.ink)),
                if (data.fragmented)
                  TextSpan(text: ' · ${context.l10n.homeFragmented}', style: TextStyle(color: rustFor(context))),
              ],
            ),
            action: data.fragmented && onTidyUp != null ? context.l10n.homeTidyUp : null,
            onTap: data.fragmented ? onTidyUp : null,
          ),
          HomeLineRow(
            inkKey: const Key('wallet-utxo-tools'),
            onTap: onTool == null ? onStatus : () => onTool!(WalletTool.utxos),
            semanticLabel: context.l10n.homeUtxoTools,
            leading: Icon(Icons.tune, size: 18, color: t.muted),
            text: TextSpan(text: context.l10n.homeUtxoTools, style: TextStyle(color: t.ink)),
          ),
        ],
      ),
    ];
  }
}

/// The wallet page's tabs: names in a row, the current one in ink over a
/// line of the accent, the rest quiet, with what the current tab holds
/// beneath.
class _WalletTabs extends StatefulWidget {
  const _WalletTabs({required this.tabs, required this.content});

  final List<WalletPageTab> tabs;
  final List<Widget> Function(WalletPageTab tab) content;

  @override
  State<_WalletTabs> createState() => _WalletTabsState();
}

class _WalletTabsState extends State<_WalletTabs> {
  WalletPageTab _tab = WalletPageTab.assets;

  static String _name(WalletPageTab tab) => switch (tab) {
        WalletPageTab.assets => appL10n.homeAssets,
        WalletPageTab.activity => appL10n.navActivity,
        WalletPageTab.addresses => appL10n.commonAddresses,
        WalletPageTab.utxos => appL10n.homeUtxos,
      };

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final accent = ArgusColors.of(context).accent;
    final tab = widget.tabs.contains(_tab) ? _tab : widget.tabs.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: homeGutter - 8),
          child: Row(
            children: [
              for (final each in widget.tabs)
                Expanded(
                  child: Semantics(
                    selected: each == tab,
                    child: InkWell(
                      key: Key('wallet-page-tab-${each.name}'),
                      onTap: () => setState(() => _tab = each),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 50),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                _name(each),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.primary.copyWith(fontSize: 14.5, color: each == tab ? t.ink : t.muted),
                              ),
                            ),
                            Container(
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: each == tab ? accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(1),
                                boxShadow: [
                                  if (each == tab) BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 6),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const HomeRule(indent: homeGutter - 8, endIndent: homeGutter - 8),
        ...widget.content(tab),
      ],
    );
  }
}
