import 'package:flutter/material.dart';

import '../bitcoin/bitcoin_settings.dart';
import '../celaut/auto_top_up.dart';
import '../celaut/celaut_strings.dart';
import '../celaut/compute_home_flag.dart';
import '../celaut/deposit_strings.dart';
import '../celaut/network_strings.dart';
import '../celaut/service_strings.dart';
import '../l10n/l10n.dart';
import '../services/contacts_service.dart';
import '../services/network_controller.dart';
import '../services/wallet_service.dart';
import '../theme/argus_theme.dart';
import '../theme/theme_controller.dart';
import 'bitcoin/bitcoin_settings_screen.dart';
import 'bitcoin/bitcoin_wallet_screen.dart';
import 'celaut/auto_top_up_screen.dart';
import 'celaut/network_screen.dart';
import 'celaut/node_connect_screen.dart';
import 'celaut/deposit_screen.dart';
import 'celaut/env_variables_screen.dart';
import 'celaut/balancer_screen.dart';
import 'celaut/known_nodes_screen.dart';
import 'celaut/service_screen.dart';
import 'home/home_scene.dart';
import 'layout.dart';
import 'settings/about_page.dart';
import 'settings/address_book_page.dart';
import 'settings/cards_settings_page.dart';
import 'settings/chat_settings_page.dart';
import 'settings/display_settings_page.dart';
import 'settings/network_settings_page.dart';
import 'settings/preview_settings_page.dart';
import 'settings/security_settings_page.dart';
import 'settings/settings_shared.dart';
import 'settings/update_notice.dart';
import 'settings/wallet_settings_page.dart';
import 'widgets/soft_card.dart';

/// The settings of the app, in three sections (Josemi, 2026-10-23):
///
/// - Ergo: the wallet, the Ergo network (nodes and explorer), the address book and the
///   remote previews;
/// - Compute: the Celaut nodes, the credit on them, the automatic top-up, Tor, the
///   environment variables, and the tools that check a node or run a service by its id;
/// - General: security and auto-lock, display, the first screen, and About.
///
/// The app holds one wallet, with no name. Creating and restoring it live on the
/// overview; removing it lives in its own settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.walletId,
    this.embedded = false,
    this.onWalletChanged,
    this.onWalletRemoved,
  });

  /// The seed wallet whose page hosts these settings. Null: the one wallet of the app,
  /// if there is one.
  final String? walletId;

  /// Hosted as a wallet page's tab: no app bar of its own.
  final bool embedded;

  /// The pinned address of the wallet changed.
  final VoidCallback? onWalletChanged;

  /// The wallet was removed; carries its id.
  final ValueChanged<String>? onWalletRemoved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<WalletInfo>> _walletsFuture = walletService.listWallets();

  Future<void> _open(Widget page) async {
    await Navigator.push(context, fadeRoute(page));
    if (!mounted) return;
    // setState takes a callback that returns nothing: an arrow here would return the
    // Future of the list, which setState refuses.
    setState(() {
      _walletsFuture = walletService.listWallets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.embedded ? null : AppBar(title: Text(context.l10n.commonSettings)),
      body: ReadableWidth(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            themeController,
            networkController,
            walletService.unlocked,
            contactsService,
          ]),
          builder: (context, _) {
            return FutureBuilder<List<WalletInfo>>(
              future: _walletsFuture,
              builder: (context, snapshot) {
                final wallets = snapshot.data ?? const <WalletInfo>[];
                // The wallet of the page, or else the one wallet of the app.
                WalletInfo? current;
                for (final w in wallets) {
                  if (w.walletId == (widget.walletId ?? w.walletId)) {
                    current = w;
                    break;
                  }
                }
                return ListView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    const UpdateNotice(),
                    if (current != null) ...[
                      _walletHeader(context, current),
                      const SizedBox(height: 24),
                    ],
                    _ergoGroup(current),
                    _bitcoinGroup(),
                    _computeGroup(),
                    _generalGroup(current),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
    return SceneBackdrop(child: scaffold);
  }

  Widget _ergoGroup(WalletInfo? current) {
    final t = context.l10n;
    return SettingsGroup(
      key: const Key('settings-section-ergo'),
      title: t.settingsErgoGroup,
      children: [
        if (current != null)
          SettingsRow(
            key: const Key('settings-wallet'),
            icon: Icons.account_balance_wallet_outlined,
            title: t.settingsWalletRowTitle,
            subtitle: t.settingsWalletRowSubtitle,
            onTap: () => _open(
              WalletSettingsPage(
                walletId: current.walletId,
                onChanged: widget.onWalletChanged,
                onRemoved: widget.onWalletRemoved,
              ),
            ),
          ),
        SettingsRow(
          key: const Key('settings-network'),
          icon: Icons.language_outlined,
          title: t.networkTitle,
          subtitle: networkController.statusLabel,
          onTap: () => _open(const NetworkSettingsPage()),
        ),
        SettingsRow(
          icon: Icons.contacts_outlined,
          title: t.addressBookTitle,
          subtitle: t.settingsContactsCount(contactsService.contacts.length),
          onTap: () => _open(const AddressBookPage()),
        ),
        SettingsRow(
          icon: Icons.image_outlined,
          title: t.settingsRemotePreviewsTitle,
          subtitle: t.settingsRemotePreviewsSubtitle,
          onTap: () => _open(const PreviewSettingsPage()),
        ),
      ],
    );
  }

  /// The Bitcoin wallet of the same words (issue #103), with the same rows as Ergo: the
  /// wallet, and its network and server. The address book is one for both.
  Widget _bitcoinGroup() {
    final t = context.l10n;
    return SettingsGroup(
      key: const Key('settings-section-bitcoin'),
      title: t.coinBitcoin,
      children: [
        SettingsRow(
          key: const Key('settings-bitcoin-wallet'),
          icon: Icons.currency_bitcoin,
          title: t.btcWalletButton,
          subtitle: t.btcWalletRowSubtitle,
          onTap: () => _open(const BitcoinWalletScreen()),
        ),
        SettingsRow(
          key: const Key('settings-bitcoin-network'),
          icon: Icons.language_outlined,
          title: t.btcSettingsTitle,
          subtitle: bitcoinSettings.loaded ? bitcoinSettings.network.name : t.btcSettingsRowSubtitle,
          onTap: () => _open(BitcoinSettingsScreen(settings: bitcoinSettings)),
        ),
      ],
    );
  }

  Widget _computeGroup() {
    final t = context.l10n;
    return SettingsGroup(
      key: const Key('settings-section-compute'),
      title: t.settingsComputeGroup,
      children: [
        SettingsRow(
          key: const Key('settings-nodes'),
          icon: Icons.hub_outlined,
          title: t.celautNodesTitle,
          subtitle: t.celautNodesRowSubtitle,
          onTap: () => _open(const KnownNodesScreen()),
        ),
        SettingsRow(
          key: const Key('settings-balancer'),
          icon: Icons.tune_outlined,
          title: t.balancerTitle,
          subtitle: t.balancerRowSubtitle,
          onTap: () => _open(const BalancerScreen()),
        ),
        SettingsRow(
          key: const Key('settings-deposit'),
          icon: Icons.savings_outlined,
          title: DepositStrings.rowTitle,
          subtitle: DepositStrings.rowSubtitle,
          onTap: () => _open(const DepositScreen()),
        ),
        ListenableBuilder(
          listenable: autoTopUp,
          builder: (context, _) => SettingsRow(
            key: const Key('settings-top-up'),
            icon: Icons.autorenew,
            title: t.celautTopUpTitle,
            subtitle: t.celautTopUpRow,
            onTap: () => _open(const AutoTopUpScreen()),
          ),
        ),
        SettingsRow(
          key: const Key('settings-tor'),
          icon: Icons.shield_outlined,
          title: NetworkStrings.rowTitle,
          subtitle: NetworkStrings.rowSubtitle,
          onTap: () => _open(const NetworkScreen()),
        ),
        SettingsRow(
          key: const Key('settings-env'),
          icon: Icons.key_outlined,
          title: t.celautEnvTitle,
          subtitle: t.celautEnvRowSubtitle,
          onTap: () => _open(const EnvVariablesScreen()),
        ),
        SettingsRow(
          key: const Key('settings-node-check'),
          icon: Icons.dns_outlined,
          title: CelautStrings.nodeRowTitle,
          subtitle: CelautStrings.nodeRowSubtitle,
          onTap: () => _open(const NodeConnectScreen()),
        ),
        SettingsRow(
          key: const Key('settings-service'),
          icon: Icons.play_circle_outline,
          title: ServiceStrings.rowTitle,
          subtitle: ServiceStrings.rowSubtitle,
          onTap: () => _open(const ServiceScreen()),
        ),
      ],
    );
  }

  Widget _generalGroup(WalletInfo? current) {
    final t = context.l10n;
    return SettingsGroup(
      key: const Key('settings-section-general'),
      title: t.settingsGeneralGroup,
      children: [
        SettingsRow(
          key: const Key('settings-security'),
          icon: Icons.lock_outline,
          title: t.securityTitle,
          subtitle: current != null ? t.settingsSecurityWalletSubtitle : t.settingsSecurityAppSubtitle,
          onTap: () => _open(
            current != null ? SecuritySettingsPage(walletId: current.walletId) : const SecuritySettingsPage(),
          ),
        ),
        SettingsRow(
          icon: Icons.palette_outlined,
          title: t.displayTitle,
          subtitle: '${_appearanceName()} · ${networkController.fiatCode.toUpperCase()}',
          onTap: () => _open(const DisplaySettingsPage()),
        ),
        SettingsRow(
          key: const Key('settings-chat'),
          icon: Icons.chat_bubble_outline,
          title: t.chatSettingsTitle,
          subtitle: t.chatSettingsRowSubtitle,
          onTap: () => _open(const ChatSettingsPage()),
        ),
        SettingsRow(
          key: const Key('settings-cards'),
          icon: Icons.style_outlined,
          title: t.cardsSettingsTitle,
          subtitle: t.cardsSettingsRowSubtitle,
          onTap: () => _open(const CardsSettingsPage()),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: computeHomeFlag,
          builder: (context, on, _) => SettingsRow(
            icon: Icons.forum_outlined,
            title: t.celautComputeHomeRowTitle,
            subtitle: t.celautComputeHomeRowSubtitle,
            trailing: Switch(
              key: const Key('settings-compute-home'),
              value: on,
              onChanged: computeHomeFlag.set,
            ),
          ),
        ),
        SettingsRow(
          key: const Key('settings-about'),
          icon: Icons.info_outline,
          title: t.settingsAboutRowTitle,
          subtitle: t.settingsAboutRowSubtitle,
          onTap: () => _open(const AboutPage()),
        ),
      ],
    );
  }

  static String _appearanceName() => switch (themeController.mode) {
        ArgusThemeMode.system => '${themeController.darkPalette.name} / ${themeController.lightPalette.name}',
        ArgusThemeMode.dark => themeController.darkPalette.name,
        ArgusThemeMode.light => themeController.lightPalette.name,
      };

  Widget _header(BuildContext context, {required IconData icon, required String name, required String detail}) {
    final colors = ArgusColors.of(context);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentOf(context).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentTextOf(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700, fontSize: 19),
                ),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(fontSize: 12.5, color: colors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletHeader(BuildContext context, WalletInfo current) {
    final unlocked = walletService.isUnlocked && walletService.activeWalletId == current.walletId;
    final t = context.l10n;
    return _header(
      context,
      icon: Icons.account_balance_wallet_outlined,
      name: t.commonWallet,
      detail: unlocked ? t.settingsUnlocked : t.settingsLocked,
    );
  }
}
