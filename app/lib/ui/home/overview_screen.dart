import 'package:flutter/material.dart';

import '../../theme/argus_theme.dart';
import '../layout.dart';
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

/// The launch screen: the wallet of the app under its balance, or, with no
/// wallet, the welcome that creates or restores one.
///
/// It is the level above an open wallet, so it has no tab bar: its header
/// carries the app's settings (there is no other way to reach them before
/// a wallet is open, and a careful user sets their own node before the
/// first restore). Opening a wallet is the only step that asks the phone to unlock
/// or fingerprint.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.data,
    this.onOpenWallet,
    this.onAdd,
    this.onSettings,
    this.onToggleHidden,
    this.onNetwork,
    this.networkAction,
    this.onLearnMore,
    this.onRefresh,
    this.footnote,
    this.notice,
    this.noticeIsError = false,
    this.onAction,
    this.extra,
  });

  final OverviewData data;
  final ValueChanged<WalletRef>? onOpenWallet;

  /// A row under the wallet, such as "Deposit to a node" in the Wallet tab of the home
  /// screen. The welcome does not show it.
  final Widget? extra;

  /// Create or restore, on the welcome: the app has no wallet yet.
  final ValueChanged<AddWalletChoice>? onAdd;
  final VoidCallback? onSettings;
  final VoidCallback? onToggleHidden;
  final VoidCallback? onNetwork;

  /// The network line's link, e.g. "Retry" when no node answers.
  final String? networkAction;
  final VoidCallback? onLearnMore;

  /// Pull to refresh.
  final Future<void> Function()? onRefresh;

  /// A quiet note under the list: how locked wallets are kept current.
  final String? footnote;

  /// A parked link waiting for an unlock, or a startup error.
  final String? notice;
  final bool noticeIsError;

  /// Send, Receive and More from the overview; without it the row is
  /// not shown.
  final ValueChanged<WalletAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final page = Theme.of(context).scaffoldBackgroundColor;
    final t = HomeText.of(context);
    final scaffold = Scaffold(
      // The header lies on the scene, clear until the list scrolls under it.
      backgroundColor: data.isEmpty ? null : Colors.transparent,
      appBar: AppBar(
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder) ? page.withValues(alpha: 0.94) : page.withValues(alpha: 0),
        ),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        titleSpacing: homeGutter,
        title: Semantics(
          header: true,
          label: CelautWordmark.name,
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CellMark(size: 40),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CelautWordmark(size: 24),
                    Text(
                      context.l10n.overviewTagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.secondary.copyWith(fontSize: 14, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('overview-settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.l10n.commonSettings,
            onPressed: onSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ReadableWidth(
        child: OverviewView(
          data: data,
          onOpenWallet: onOpenWallet,
          onAdd: onAdd,
          onToggleHidden: onToggleHidden,
          onNetwork: onNetwork,
          networkAction: networkAction,
          onLearnMore: onLearnMore,
          onRefresh: onRefresh,
          footnote: footnote,
          notice: notice,
          noticeIsError: noticeIsError,
          onAction: onAction,
          extra: extra,
        ),
      ),
    );
    if (data.isEmpty) return scaffold;
    final top = MediaQuery.paddingOf(context).top + 72;
    return ColoredBox(
      color: page,
      // The light follows the content, which keeps to a column on a wide window.
      child: LayoutBuilder(
        builder: (context, box) => HomeScene(
          light: SceneLight.eclipse,
          lightAt: Offset(AppLayout.readableSide(box.maxWidth) + 96, top + 66),
          lightRadius: 80,
          height: top + 520,
          child: scaffold,
        ),
      ),
    );
  }
}

/// The overview's scrolling body, for hosting under another app bar: the
/// total on the raised panel with the ERG price under a hairline, the
/// network line, then the wallet.
class OverviewView extends StatelessWidget {
  const OverviewView({
    super.key,
    required this.data,
    this.onOpenWallet,
    this.onAdd,
    this.onToggleHidden,
    this.onNetwork,
    this.networkAction,
    this.onLearnMore,
    this.onRefresh,
    this.footnote,
    this.notice,
    this.noticeIsError = false,
    this.onAction,
    this.extra,
  });

  final OverviewData data;
  final ValueChanged<WalletRef>? onOpenWallet;
  final ValueChanged<AddWalletChoice>? onAdd;
  final VoidCallback? onToggleHidden;
  final VoidCallback? onNetwork;
  final String? networkAction;
  final VoidCallback? onLearnMore;
  final Future<void> Function()? onRefresh;
  final String? footnote;
  final String? notice;
  final bool noticeIsError;
  final ValueChanged<WalletAction>? onAction;

  /// A row under the wallet ([OverviewScreen.extra]).
  final Widget? extra;

  Widget _row(WalletSummary w) => OverviewWalletRow(
        wallet: w,
        currency: data.currency,
        hidden: data.hidden,
        onTap: onOpenWallet == null ? null : () => onOpenWallet!(w.ref),
      );

  /// The wallet, on a glass card of its own.
  Widget _card(WalletSummary w) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(children: [_row(w)]),
      );

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final message = notice == null ? null : OverviewNotice(message: notice!, error: noticeIsError);
    if (data.isEmpty) {
      return _Welcome(notice: message, onAdd: onAdd, onLearnMore: onLearnMore);
    }
    final price = data.price;
    final list = ListView(
      key: const Key('overview-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24 + bottom),
      children: [
        // The page settles in from the top: the scene, then each list.
        // On the scene the screen paints behind the list.
        HomeEntrance(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(homeGutter, 8, homeGutter, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: message),
                HomeBalance(
                  label: context.l10n.overviewTotalBalance,
                  figureKey: const Key('overview-total'),
                  pendingKey: const Key('overview-total-pending'),
                  nanoErg: data.totalNano,
                  loading: data.loading,
                  notLoaded: data.notLoaded,
                  currency: data.currency,
                  fiatValue: data.totalFiat,
                  unpricedCount: data.unpricedCount,
                  pricesNote: data.pricesNote,
                  pending: data.pending,
                  hidden: data.hidden,
                  onToggleHidden: onToggleHidden,
                  figureReserve: 40,
                ),
                if (onAction != null && data.wallets.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  HomeActionCircles(
                    keyPrefix: 'overview-action',
                    gridMore: true,
                    actions: const [WalletAction.send, WalletAction.receive, WalletAction.more],
                    onAction: onAction!,
                  ),
                ],
                const SizedBox(height: 18),
                homeNetworkPill(context, data.network, onTap: onNetwork, action: networkAction),
                if (price != null) ...[
                  const SizedBox(height: 10),
                  _PriceCard(price: price, currency: data.currency),
                ],
              ],
            ),
          ),
        ),
        if (data.wallets.isNotEmpty)
          HomeEntrance(
            order: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                _card(data.wallets.first),
              ],
            ),
          ),
        ?extra,
        if (footnote != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(homeGutter, 16, homeGutter, 0),
            child: Text(footnote!, style: t.secondary),
          ),
        const SizedBox(height: 12),
        PrototypeNote(onLearnMore: onLearnMore),
      ],
    );
    final refresh = onRefresh;
    return refresh == null ? list : RefreshIndicator(onRefresh: refresh, child: list);
  }
}

/// The ERG price on a glass card of its own, under the network pill.
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.price, required this.currency});

  final ErgPriceView price;
  final FiatCurrency currency;

  @override
  Widget build(BuildContext context) {
    final spec = ArgusColors.sceneOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(glassRadius),
        border: Border.all(color: spec.glassBorder),
        color: spec.glassFill,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 16, 10),
        child: ErgPriceStrip(price: price, currency: currency),
      ),
    );
  }
}

/// A message the overview must show above everything else: a parked link
/// waiting for an unlock, or an error from startup.
class OverviewNotice extends StatelessWidget {
  const OverviewNotice({super.key, required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    final color = error ? rustFor(context) : t.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: homeGutter, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: homeMarkSize,
            child: Icon(error ? Icons.error_outline : Icons.info_outline, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: SelectableText(message, style: t.secondary.copyWith(color: color))),
        ],
      ),
    );
  }
}

/// What Argus is, said once: an unaudited prototype.
Future<void> showPrototypeNotice(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.overviewPrototypeTitle),
        content: Text(
          context.l10n.overviewPrototypeBody,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.overviewGotIt)),
        ],
      ),
    );

/// The prototype warning, kept but moved from the top of every screen to
/// the foot of the launch screen: always findable, never in the way.
class PrototypeNote extends StatelessWidget {
  const PrototypeNote({super.key, this.onLearnMore, this.inset = true});

  /// Defaults to [showPrototypeNotice].
  final VoidCallback? onLearnMore;

  /// Keep to the page's gutters; off where the parent already does.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    // At large text the link moves under the words instead of squeezing
    // them into a column a few words wide.
    final stacked = homeLargeText(context);
    final text = Text(context.l10n.overviewPrototypeNote, style: t.secondary);
    final link = TextButton(
      key: const Key('overview-learn-more'),
      onPressed: onLearnMore ?? () => showPrototypeNotice(context),
      style: TextButton.styleFrom(
        foregroundColor: HomeTones.of(context).accent,
        minimumSize: const Size(48, 48),
        padding: stacked ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10),
        alignment: AlignmentDirectional.centerStart,
        textStyle: t.link,
      ),
      child: Text(context.l10n.overviewLearnMore),
    );
    final shield = SizedBox(
      width: homeMarkSize,
      child: Center(child: Icon(Icons.shield_outlined, size: 16, color: t.muted)),
    );
    return Padding(
      padding: inset ? const EdgeInsetsDirectional.only(start: homeGutter, end: homeGutter - 10) : EdgeInsets.zero,
      child: stacked
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: shield),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, link])),
              ],
            )
          : Row(children: [shield, const SizedBox(width: 12), Expanded(child: text), link]),
    );
  }
}

/// First launch, or every wallet removed: no wallets yet, so the ways in
/// are the page.
class _Welcome extends StatelessWidget {
  const _Welcome({this.notice, this.onAdd, this.onLearnMore});

  final Widget? notice;
  final ValueChanged<AddWalletChoice>? onAdd;
  final VoidCallback? onLearnMore;

  @override
  Widget build(BuildContext context) {
    final t = HomeText.of(context);
    VoidCallback? add(AddWalletChoice c) => onAdd == null ? null : () => onAdd!(c);
    return ListView(
      key: const Key('overview-welcome'),
      // The header already carries the mark; the page opens on the words.
      padding: EdgeInsets.fromLTRB(homeGutter, notice == null ? 40 : 8, homeGutter, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        if (notice != null) ...[notice!, const SizedBox(height: 24)],
        Semantics(
          header: true,
          child: Text(context.l10n.overviewWelcomeTitle, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.overviewWelcomeBody,
          style: t.secondary.copyWith(fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          key: Key(AddWalletChoice.create.keyName),
          onPressed: add(AddWalletChoice.create),
          icon: const Icon(Icons.add, size: 20),
          label: Text(context.l10n.overviewCreateWallet),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: Key(AddWalletChoice.restore.keyName),
          onPressed: add(AddWalletChoice.restore),
          icon: const Icon(Icons.settings_backup_restore, size: 20),
          label: Text(context.l10n.overviewRestoreWallet),
        ),
        const SizedBox(height: 36),
        PrototypeNote(onLearnMore: onLearnMore, inset: false),
      ],
    );
  }
}
