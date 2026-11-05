import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge/argus_error.dart';
import '../celaut/compute_home_flag.dart';
import '../celaut/incoming_package.dart';
import '../format.dart';
import '../l10n/l10n.dart';
import '../services/address_label_service.dart';
import '../services/deep_link_controller.dart';
import '../services/ergopay_service.dart';
import '../services/incoming_payment_watcher.dart';
import '../services/network_controller.dart';
import '../services/notification_service.dart';
import '../services/pin_migration.dart';
import '../services/token_pricer.dart';
import '../services/privacy_service.dart';
import '../services/public_wallet_sync.dart';
import '../services/secure_storage.dart';
import '../services/session_lock.dart';
import '../services/single_wallet.dart';
import '../services/wallet_service.dart';
import '../services/wallet_sync_controller.dart';
import '../theme/argus_theme.dart';
import '../theme/theme_controller.dart';
import 'assets_screen.dart';
import '../celaut/wallet_money.dart';
import 'bitcoin/bitcoin_wallet_screen.dart';
import 'celaut/deposit_screen.dart';
import 'celaut/home_tabs.dart';
import 'create_wallet_screen.dart';
import 'ergopay_screen.dart';
import 'home/erg_price_feed.dart';
import 'home/home_data.dart' show isPendingTx;
import 'home/home_models.dart';
import 'home/overview_model.dart';
import 'home/unlock_gate.dart';
import 'home/wallet_ledger.dart';
import 'home/wallet_summary.dart';
import 'home/wallet_nav_bar.dart';
import 'home/wallet_page.dart';
import 'restore_wallet_screen.dart';
import 'scan_screen.dart';
import 'send_screen.dart';
import 'settings/network_settings_page.dart';
import 'settings_screen.dart';
import 'transaction_detail_screen.dart';
import 'transactions_screen.dart';
import 'wallets_overview_screen.dart';
import 'widgets/discover_sheet.dart';
import 'widgets/entry_dialogs.dart';
import 'widgets/error_sheet.dart';
import 'widgets/token_detail_sheet.dart';
import 'widgets/wallet_view_boundary.dart';

/// The app's home: the tabs of the bottom bar ([HomeTabs]), whose Wallet
/// tab is the overview of the wallet, and the page of the wallet when it is
/// open.
///
/// The app opens on the Chats tab, with no unlock and no prompt. With the
/// setting "Chats home" off it opens on the overview
/// ([WalletsOverviewScreen]). Tapping a wallet opens its page in place, over
/// the bar; back
/// returns to the overview, which is how the user switches wallets. A seed
/// wallet asks for its key once, when it is opened. A cancelled prompt of
/// the phone leaves its locked page ([UnlockGate]) with Unlock, and nothing asks again by
/// itself. The app holds one wallet and no
/// watched wallets ([enforceSingleWallet]).
///
/// An unlocked seed wallet's page has four tabs: Wallet ([WalletLedger]),
/// Activity, Discover (the tools that act on its coins) and Settings.
///
/// This state also owns what must run whichever page shows: the poll of
/// the unlocked wallet, the overview's public refresh, the ERG price
/// history the home screens chart, deep links and incoming-payment
/// notifications.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.initializeWalletService,
    this.computeHome,
    this.enforceSingleWallet,
  });

  final Future<void> Function()? initializeWalletService;

  /// Removes what an earlier version left beyond the one wallet. Null: the
  /// app's [enforceSingleWallet]; tests give their own.
  final Future<void> Function()? enforceSingleWallet;

  /// Whether the launch level is the list of conversations. Null: the setting decides
  /// (on by default). Tests of the wallets list give false.
  final bool? computeHome;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  final _sync = walletSyncController;
  final _overview = WalletsOverviewModel();
  final _price = ErgPriceFeed();

  /// The wallet whose page is showing; null shows the overview.
  WalletRef? _open;

  /// Shown on the overview: a startup error, or why a parked link waits.
  String? _notice;
  bool _noticeIsError = false;

  /// The seed wallet being unlocked or unlocked: the one the gate and the
  /// ledger belong to. Null until a seed wallet is opened.
  String? _walletId;
  bool _walletUnlocked = false;

  /// Unlock methods of [_methodsFor]; stale until it equals [_walletId].
  String? _methodsFor;
  bool _hasSeed = false;
  bool _hasPin = false;
  bool _canBiometric = false;
  bool _unlockBusy = false;

  /// Why the open wallet is still locked, for the gate.
  String? _gateStatus;
  bool _gateStatusIsError = false;
  final _pinCtrl = TextEditingController();

  /// Wallet page tabs: 0 wallet, 1 activity, 2 discover, 3 settings. Tabs
  /// are built on first visit so unlocking doesn't fan out into every
  /// screen's network calls at once.
  int _tab = 0;
  final Set<int> _visitedTabs = {0};
  static const _tabOrder = [WalletTab.wallet, WalletTab.activity, WalletTab.discover, WalletTab.settings];

  /// Poll for mempool changes (pending activity, balance, spendable UTXOs)
  /// while a wallet is unlocked. A tick is a light refresh on the known
  /// addresses; discovery also runs when its freshness interval expires.
  /// Manual refresh forces discovery; the probe timer remains separate.
  /// Paused while backgrounded; a tick is skipped if the previous refresh is
  /// still in flight. The same timer drives the overview's own refresh,
  /// locked or not, on its five-minute floor.
  Timer? _pollTimer;
  Timer? _probeTimer;
  bool _pollBackgrounded = false;

  /// The timer ticks every [_fastPollInterval]; a tick polls when something
  /// is unconfirmed, or when [_pollInterval] has passed since the last poll.
  static const _pollInterval = Duration(seconds: 20);
  static const _fastPollInterval = Duration(seconds: 5);
  static const _probeInterval = Duration(minutes: 2);
  DateTime _lastPollAt = DateTime.now();

  /// Polling keeps going this long after the app leaves the foreground so an
  /// incoming payment can still be announced; Android may stop it sooner.
  static const _backgroundPollWindow = Duration(minutes: 10);
  DateTime? _backgroundedAt;
  final _incoming = IncomingPaymentWatcher();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    walletService.unlocked.addListener(_syncLock);
    _overview.attach();
    _price.attach();
    _sync.addListener(_onSyncChanged);
    deepLinkController.addListener(_onDeepLink);
    incomingPackages.addListener(_openIncomingPackage);
    computeHomeFlag.addListener(_onComputeHomeChanged);
    computeHomeFlag.load();
    walletService.currentWalletId.addListener(_onActiveWalletChanged);
    _pollTimer = Timer.periodic(_fastPollInterval, (_) => _pollTick());
    _probeTimer = Timer.periodic(_probeInterval, (_) => _probeTick());
    _init();
  }

  /// The tab of the home screen (`docs/celaut/ui-chat-first.md`), kept while the
  /// page of the wallet covers the tabs.
  HomeTab _homeTab = HomeTab.chats;

  void _onComputeHomeChanged() {
    if (mounted) setState(() {});
  }

  /// A Celaut screen can open another full wallet (a deposit asks for the PIN or
  /// fingerprint of the paying wallet and opens it). The page of the wallet that was
  /// open then shows its gate again; the sync stays with the new open wallet.
  void _onActiveWalletChanged() {
    if (!mounted) return;
    final active = walletService.activeWalletId;
    if (_walletUnlocked && _walletId != null && active != _walletId) {
      setState(() {
        _walletUnlocked = false;
        _incoming.reset();
      });
    }
  }

  @override
  void dispose() {
    computeHomeFlag.removeListener(_onComputeHomeChanged);
    walletService.currentWalletId.removeListener(_onActiveWalletChanged);
    _pollTimer?.cancel();
    _probeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    walletService.unlocked.removeListener(_syncLock);
    _sync.removeListener(_onSyncChanged);
    deepLinkController.removeListener(_onDeepLink);
    incomingPackages.removeListener(_openIncomingPackage);
    _overview.dispose();
    _price.dispose();
    _pinCtrl.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) => ergoThemeActive.value = false);
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await (widget.initializeWalletService ?? walletService.init)();
      await networkController.load();
      networkController.probe();
      await (widget.enforceSingleWallet ?? enforceSingleWallet)();
      await _overview.loadWallets();
    } on ArgusException catch (e) {
      _notice = '${e.code}: ${e.message}';
      _noticeIsError = true;
    } catch (e) {
      _notice = context.l10n.dashboardStartupError('$e');
      _noticeIsError = true;
    }
    // No unlock and no biometric prompt here: the app opens on the overview,
    // and a wallet asks for its key when the user opens it.
    if (!mounted) return;
    setState(() => _loading = false);
    unawaited(_overview.refreshOnLaunch());
    // A file that the user opened in a file manager launched the app: its import starts
    // when the home screen is there.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openIncomingPackage());
  }

  // ── Listeners ─────────────────────────────────────────────────────────

  void _onSyncChanged() {
    if (mounted) setState(() {});
    _openPendingDeepLink();
    _announceIncoming();
  }

  void _syncLock() {
    if (!mounted) return;
    setState(() {
      if (!walletService.unlocked.value && _walletUnlocked) _resetLocked();
    });
  }

  /// Announces payments that appeared since the last refresh. Only fires
  /// while the app is not in front, so the home screen itself stays quiet.
  void _announceIncoming() {
    if (!_walletUnlocked) return;
    final fresh = _incoming.observe(_sync.displayActivity);
    if (fresh.isEmpty || !_pollBackgrounded) return;
    for (final tx in fresh) {
      notificationService.incomingPayment(
        nanoErg: (tx['value_nano_erg'] as num?)?.toInt() ?? 0,
        walletName: context.l10n.commonWallet,
        pending: ((tx['height'] as num?)?.toInt() ?? 0) == 0,
      );
    }
  }

  // ── Files opened in a file manager ────────────────────────────────────

  /// Import the `.celaut.bee` file that the user opened in a file manager, on the page
  /// Services over the list of chats. It waits while the app starts and while another
  /// import runs ([IncomingPackages]). The page of a wallet closes first.
  void _openIncomingPackage() {
    if (!mounted || _loading || incomingPackages.pending == null) return;
    if (!(widget.computeHome ?? computeHomeFlag.value)) return;
    if (_open != null) {
      _closeWallet();
      WidgetsBinding.instance.addPostFrameCallback((_) => _openIncomingPackage());
      return;
    }
    final home = _homeKey.currentState;
    if (home == null) return;
    final file = incomingPackages.take();
    if (file != null) unawaited(home.importFile(file));
  }

  // ── Deep links ────────────────────────────────────────────────────────

  void _onDeepLink() {
    if (!_openPendingDeepLink() && mounted) {
      // Parked until a wallet unlocks; tell the user why nothing happened.
      final link = deepLinkController.pending;
      if (!_walletUnlocked && link != null && argusChatInstance(link) == null) {
        setState(() {
          _notice = isErgoPayLink(link)
              ? context.l10n.dashboardUnlockForErgoPay
              : context.l10n.dashboardUnlockForNotification;
          _noticeIsError = false;
        });
      }
    }
  }

  bool _ergoPayOpen = false;

  /// Opens a parked link once a wallet is unlocked and has an address.
  /// Returns false when it had to stay parked.
  bool _openPendingDeepLink() {
    if (!mounted || _ergoPayOpen) return false;
    final link = deepLinkController.pending;
    if (link == null) return false;
    // A chat does not need a wallet: the notice of an answer opens it at once, when the
    // home screen is there.
    final chat = argusChatInstance(link);
    if (chat != null) {
      final home = _homeKey.currentState;
      if (home == null) return false;
      deepLinkController.take();
      Navigator.of(context).popUntil((r) => r.isFirst);
      unawaited(home.openChat(chat));
      return true;
    }
    final walletId = _walletId;
    if (walletId == null ||
        !_walletUnlocked ||
        !walletService.isUnlocked ||
        _sync.receiveAddress == null) {
      return false;
    }
    deepLinkController.take();
    if (_notice != null && !_noticeIsError) setState(() => _notice = null);
    if (isErgoPayLink(link)) {
      _openErgoPay(link);
      return true;
    }
    final route = argusLinkRoute(link);
    if (route == null) return true;
    // A notification tap lands on the screen it names, over the unlocked
    // wallet's page and nothing else.
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (_open != WalletRef.seed(walletId)) _showSeedPage(walletId);
    if (route == '/transactions') {
      _selectTab(1);
    } else {
      _go(route);
    }
    return true;
  }

  Future<void> _openErgoPay(String link) async {
    _ergoPayOpen = true;
    try {
      final txId = await Navigator.push<String?>(
        context,
        fadeRoute(ErgoPayScreen(link: link), settings: RouteSettings(arguments: _args())),
      );
      if (txId != null && mounted) _sync.refresh(discover: false);
    } finally {
      _ergoPayOpen = false;
    }
  }

  /// Home scan: ErgoPay links open the signing flow; `ergo:` payment URIs
  /// open Send prefilled.
  Future<void> _scan() async {
    if (!_guardUnlocked()) return;
    final raw = await Navigator.push<String>(context, fadeRoute(const ScanScreen()));
    if (!mounted || raw == null) return;
    if (isErgoPayLink(raw)) {
      _openErgoPay(raw);
      return;
    }
    final pay = parseErgoUri(raw);
    if (pay == null) {
      _snack(context.l10n.dashboardScanNotErgo);
      return;
    }
    Navigator.push(
      context,
      fadeRoute(
        SendScreen(initialRecipient: pay.address, initialAmountErg: pay.amountErg),
        settings: RouteSettings(arguments: _args()),
      ),
    );
  }

  // ── Polling and lifecycle ─────────────────────────────────────────────

  void _pollTick() {
    if (!mounted) return;
    if (_pollBackgrounded) {
      final since = _backgroundedAt;
      if (since == null || DateTime.now().difference(since) > _backgroundPollWindow) {
        return;
      }
    } else {
      // The locked wallet, on its five-minute floor. This needs no unlock:
      // the overview shows it before one.
      unawaited(_overview.refreshIfDue());
    }
    if (!_walletUnlocked || _sync.busy) return;
    final now = DateTime.now();
    if (!shouldPoll(
      now: now,
      lastPollAt: _lastPollAt,
      hasPending: _sync.hasPending,
      pollInterval: _pollInterval,
      fastPollInterval: _fastPollInterval,
    )) {
      return;
    }
    _lastPollAt = now;
    // Routine poll: refresh without flipping the strip to "Syncing…".
    _sync.refresh(discover: false, quiet: true);
  }

  void _probeTick() {
    if (!mounted || _pollBackgrounded) return;
    networkController.probe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    publicWalletSync.setForeground(state == AppLifecycleState.resumed);
    // Pause mempool polling while backgrounded; resume on return.
    final backgrounded =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (backgrounded && !_pollBackgrounded) _backgroundedAt = DateTime.now();
    _pollBackgrounded = backgrounded;
    if (state != AppLifecycleState.resumed) return;
    _backgroundedAt = null;
    // Whatever happened while away shows now, not at the next tick.
    if (_walletUnlocked && !_sync.busy) {
      _lastPollAt = DateTime.now();
      unawaited(_sync.refresh(discover: false, quiet: true));
    }
    // Deliberately no unlock here. A biometric sheet pauses and resumes the
    // activity itself, so prompting on resume reopened the sheet the moment
    // the user cancelled it, over and over (1.0.0-beta.1). After an
    // auto-lock the wallet's page shows its gate; unlocking is the user's
    // tap.
  }

  // ── Opening and closing wallets ───────────────────────────────────────

  Future<void> _openWallet(WalletRef ref) => _openSeed(ref.id);

  /// Shows [walletId]'s page without touching its lock state.
  void _showSeedPage(String walletId) {
    setState(() {
      if (_open != WalletRef.seed(walletId)) {
        _tab = 0;
        _visitedTabs
          ..clear()
          ..add(0);
      }
      _open = WalletRef.seed(walletId);
      _gateStatus = null;
    });
  }

  /// Opens a seed wallet: straight in when it is the unlocked one, else its
  /// gate, with biometrics asked once when they are set up.
  Future<void> _openSeed(String walletId) async {
    _pinCtrl.clear();
    _showSeedPage(walletId);
    if (walletService.isUnlocked && walletService.activeWalletId == walletId) {
      if (_walletId == walletId && _walletUnlocked) return;
      _walletId = walletId;
      await sessionLock.run(() async {
        await _refreshUnlockMethods();
        await _afterUnlock();
      });
      return;
    }
    await _switchWallet(walletId);
  }

  /// Makes [walletId] the wallet to unlock, and asks for biometrics once
  /// when they are set up. A cancel leaves the gate with Unlock and Use
  /// PIN; nothing asks again by itself.
  ///
  /// A wallet unlocked before stays unlocked until this one's key is in
  /// hand ([_lockOtherWallet]): backing out of the gate returns to the
  /// overview with it still open. Its view and services are left as they
  /// are; it just stops being polled while it is not the selected wallet.
  Future<void> _switchWallet(String walletId) async {
    try {
      _walletId = walletId;
      setState(() {
        _walletUnlocked = false;
        _incoming.reset();
        _tab = 0;
        _visitedTabs
          ..clear()
          ..add(0);
      });
      await _refreshUnlockMethods();
      if (!mounted || _walletId != walletId) return;
      setState(() {});
      if (_open == WalletRef.seed(walletId) && _canBiometric) {
        await _unlockBiometric();
      }
    } on ArgusException catch (e) {
      if (!mounted) return;
      showErrorSheet(context, code: e.code, message: e.message);
    } catch (e) {
      if (!mounted) return;
      _snack(context.l10n.dashboardOpenFailed('$e'));
    }
  }

  /// Back to the overview. An unlocked wallet stays unlocked, so opening it
  /// again asks for nothing; the session lock still locks it in the
  /// background.
  void _closeWallet() {
    if (_open == null) return;
    setState(() {
      _open = null;
      _tab = 0;
      _visitedTabs
        ..clear()
        ..add(0);
      _gateStatus = null;
    });
    _pinCtrl.clear();
    unawaited(_overview.loadWallets());
  }

  /// System back on a wallet page: first to its Wallet tab, then out.
  void _back() {
    if (_tab != 0) {
      _selectTab(0);
    } else {
      _closeWallet();
    }
  }

  /// Renamed or re-pinned in its settings: the page title and the address
  /// it is shown as come from the wallet list.
  Future<void> _onWalletEdited() async {
    await _overview.loadWallets();
    if (mounted) setState(() {});
  }

  Future<void> _onWalletRemoved(String walletId) async {
    if (!mounted) return;
    final name = context.l10n.commonWallet;
    if (_open?.id == walletId) _closeWallet();
    if (_walletId == walletId) {
      setState(() {
        _resetLocked();
        _walletId = null;
        _methodsFor = null;
      });
    }
    await _overview.loadWallets();
    _snack(context.l10n.dashboardWalletRemoved(name));
  }

  Future<void> _openCreate() =>
      _adopt(Navigator.push<String?>(context, fadeRoute(const CreateWalletScreen())));

  Future<void> _openRestore() =>
      _adopt(Navigator.push<String?>(context, fadeRoute(const RestoreWalletScreen())));

  /// A created or restored wallet comes back unlocked: open it without a
  /// second prompt.
  Future<void> _adopt(Future<String?> pushed) async {
    final walletId = await pushed;
    if (walletId == null || !mounted) return;
    _walletId = walletId;
    _showSeedPage(walletId);
    await sessionLock.run(() async {
      await _overview.loadWallets();
      await _refreshUnlockMethods();
      await _afterUnlock();
    });
  }

  // ── Unlocking ─────────────────────────────────────────────────────────

  void _resetLocked() {
    _walletUnlocked = false;
    _incoming.reset();
    _tab = 0;
    _visitedTabs
      ..clear()
      ..add(0);
    _sync.deactivate();
  }

  Future<void> _refreshUnlockMethods() async {
    final id = _walletId;
    if (id == null) {
      _hasSeed = false;
      _hasPin = false;
      _canBiometric = false;
      _methodsFor = null;
      return;
    }
    final hasSeed = await SecureStorageService.hasEncryptedSeed(walletId: id);
    final hasPin = await SecureStorageService.hasPinWrap(walletId: id);
    final canBiometric = await SecureStorageService.hasWrapKey(walletId: id);
    if (_walletId != id) return;
    _hasSeed = hasSeed;
    _hasPin = hasPin;
    _canBiometric = canBiometric;
    _methodsFor = id;
  }

  UnlockMethod get _unlockMethod {
    if (!_hasSeed) return UnlockMethod.none;
    if (_canBiometric) return UnlockMethod.biometric;
    // Made before the app dropped the PIN: it asks for it one last time.
    return _hasPin ? UnlockMethod.pin : UnlockMethod.none;
  }

  void _setGateStatus(String? message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _gateStatus = message;
      _gateStatusIsError = error;
    });
  }

  Future<void> _afterUnlock() async {
    if (!mounted) return;
    if (!walletService.isUnlocked) {
      setState(_resetLocked);
      return;
    }
    final walletId = walletService.activeWalletId;
    if (walletId == null || walletId != _walletId) return;
    _incoming.reset();
    _sync.activateWallet(walletId);
    if (_sync.receiveAddress != null) {
      setState(() {
        _walletUnlocked = true;
        _gateStatus = null;
      });
    }
    // Record the pinned address if only its index was ever stored, so the
    // wallet list shows the pinned address rather than index 0 once this
    // wallet is locked again.
    await walletService.backfillPinnedAddress().catchError((_) {});
    // 1. Derive the main address locally and paint from the cache (instant).
    if (walletService.activeWalletId != walletId || _walletId != walletId) return;
    final ok = await _sync.hydrateAfterUnlock();
    if (!mounted ||
        walletService.activeWalletId != walletId ||
        _walletId != walletId) {
      return;
    }
    if (!walletService.isUnlocked) {
      setState(_resetLocked);
      return;
    }
    await _overview.loadWallets();
    if (!mounted ||
        walletService.activeWalletId != walletId ||
        _walletId != walletId) {
      return;
    }
    setState(() {
      _walletUnlocked = true;
      _gateStatus = null;
    });
    if (!ok) {
      debugPrint('argus: address derivation failed after unlock');
      _snack(context.l10n.dashboardNoAddressDerived);
      return;
    }
    notificationService.requestPermission();
    // 2. Refresh known addresses; rescan only when discovery is due.
    await _sync.refresh(discover: true, forceDiscovery: false);
  }

  Future<bool> _pinAllowed() async {
    try {
      final blocked = await SecureStorageService.pinBlockedMessage();
      if (blocked != null) {
        _snack(blocked);
        return false;
      }
      return true;
    } on SecureStorageException {
      _snack(context.l10n.dashboardPinLockoutCheckFailed);
      return false;
    }
  }

  Future<void> _runUnlock(Future<void> Function() work) async {
    if (_unlockBusy) return;
    setState(() => _unlockBusy = true);
    try {
      // Keep the auto-lock from destroying the handle mid-unlock (the
      // biometric sheet, or any backgrounding, otherwise re-arms the
      // grace timer while restore/derive is still in flight).
      await sessionLock.run(work);
    } finally {
      if (mounted) setState(() => _unlockBusy = false);
    }
  }

  /// The wallet unlocked before is locked only once this one's key is in
  /// hand, so an abandoned gate does not cost the user their open wallet.
  Future<void> _lockOtherWallet(String walletId) async {
    if (walletService.isUnlocked && walletService.activeWalletId != walletId) {
      await walletService.lockForSwitch();
    }
  }

  /// A wallet made before the app dropped the PIN: its PIN, one last time. Then it opens
  /// with the fingerprint or the screen lock of the phone like the others.
  Future<void> _unlockWithPin() async {
    final walletId = _walletId;
    if (walletId == null) return;
    final err = validatePin(_pinCtrl.text);
    if (err != null) {
      _snack(err);
      return;
    }
    await _runUnlock(() async {
      if (!await _pinAllowed()) return;
      try {
        final json = await SecureStorageService.loadEncryptedSeed(walletId: walletId);
        final pinWrap = await SecureStorageService.loadPinWrap(walletId: walletId);
        if (json == null || pinWrap == null) {
          _setGateStatus(context.l10n.dashboardNoPinWallet, error: true);
          return;
        }
        final wrapKey = await movePinWalletToDeviceLock(
          walletId: walletId,
          pinWrapJson: pinWrap,
          pin: _pinCtrl.text,
        );
        _hasPin = false;
        _canBiometric = true;
        if (_walletId != walletId) return;
        await _lockOtherWallet(walletId);
        await walletService.restoreWallet(json, wrapKey: wrapKey, walletId: walletId);
        _pinCtrl.clear();
        HapticFeedback.lightImpact();
        await _afterUnlock();
      } on ArgusException catch (e) {
        try {
          await SecureStorageService.recordPinFailure();
        } catch (_) {}
        if (mounted) showErrorSheet(context, code: e.code, message: e.message);
      } on SecureStorageException catch (e) {
        if (mounted) showErrorSheet(context, message: e.message);
      }
    });
  }

  /// One prompt of the phone (fingerprint or screen lock). Called when a wallet is opened
  /// and when the user taps Unlock on its gate; never from a lifecycle event or a rebuild.
  Future<void> _unlockBiometric() async {
    final walletId = _walletId;
    if (walletId == null) return;
    await _runUnlock(() async {
      try {
        final wrapKey = await sessionLock.run(
          () => SecureStorageService.authenticateBiometric(walletId: walletId),
        );
        if (!mounted || _walletId != walletId) return;
        if (wrapKey == null) {
          if (!await SecureStorageService.hasWrapKey(walletId: walletId)) {
            _canBiometric = false;
            _setGateStatus(context.l10n.dashboardBiometricNotSetUp);
          } else {
            _setGateStatus(context.l10n.dashboardBiometricCancelled);
          }
          return;
        }
        final json = await SecureStorageService.loadEncryptedSeed(walletId: walletId);
        if (json == null) {
          _setGateStatus(context.l10n.dashboardWalletDataMissing, error: true);
          return;
        }
        await _lockOtherWallet(walletId);
        await walletService.restoreWallet(json, wrapKey: wrapKey, walletId: walletId);
        await dropPinWrap(walletId);
        _hasPin = false;
        HapticFeedback.lightImpact();
        await _afterUnlock();
      } on ArgusException catch (e) {
        if (mounted) showErrorSheet(context, code: e.code, message: e.message);
      } on SecureStorageException catch (e) {
        if (mounted) showErrorSheet(context, message: e.message);
      }
    });
  }

  Future<void> _lock() async {
    await walletService.lock();
    if (mounted) setState(_resetLocked);
  }

  // ── Wallet page actions ───────────────────────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _labelAddress(String address) async {
    final label = await showAddressLabelDialog(
      context,
      address: address,
      existing: addressLabelService.labelFor(address) ?? '',
    );
    if (label == null) return;
    await addressLabelService.setLabel(address, label);
    if (mounted) setState(() {});
  }

  WalletRouteArgs _args({Map<String, dynamic>? transaction}) {
    final receive = _sync.receiveAddress ?? '';
    return WalletRouteArgs(
      senderAddress: _sync.senderAddress ?? receive,
      receiveAddress: receive,
      changeAddress: _sync.changeAddress ?? receive,
      historyAddresses: _sync.historyAddresses,
      tokens: _sync.tokens,
      spendableNano: _sync.balanceNano,
      transaction: transaction,
    );
  }

  bool _guardUnlocked() {
    if (!walletService.isUnlocked || !_walletUnlocked) {
      _snack(context.l10n.dashboardUnlockFirst);
      return false;
    }
    if (_sync.receiveAddress == null) {
      _snack(context.l10n.dashboardAddressLoading);
      return false;
    }
    return true;
  }

  void _go(String route) {
    if (!_guardUnlocked()) return;
    Navigator.pushNamed(context, route, arguments: _args());
  }

  void _selectTab(int index) {
    if (index == _tab) return;
    if (index != 0 && !_guardUnlocked()) return;
    final leavingSettings = _tab == 3;
    setState(() {
      _tab = index;
      _visitedTabs.add(index);
    });
    if (leavingSettings) {
      _refreshUnlockMethods().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  void _openTx(Map<String, dynamic> tx) {
    Navigator.push(
      context,
      fadeRoute(
        const TransactionDetailScreen(),
        settings: RouteSettings(arguments: _args(transaction: tx)),
      ),
    );
  }

  void _openToken(TokenBalance t) {
    showTokenDetailSheet(
      context,
      token: t,
      explorerUrl: networkController.explorerToken(t.id),
      onSend: (token) {
        if (!_guardUnlocked()) return;
        Navigator.push(
          context,
          fadeRoute(
            SendScreen(initialAssetId: token.id),
            settings: RouteSettings(arguments: _args()),
          ),
        );
      },
    );
  }

  void _openSettings() => _selectTab(3);

  /// A Discover row: the feature's explainer, whose button opens it.
  void _openDiscover(DiscoverFeature feature) {
    showDiscoverSheet(context, feature: feature, onGo: () => _go(discoverExplainers[feature]!.route));
  }

  bool get _balanceHidden => privacyService.hideBalances;

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _splash();
    final open = _open;
    _showErgoTheme(open != null);
    if (open == null) {
      if (!(widget.computeHome ?? computeHomeFlag.value)) return _overviewScreen();
      return _home();
    }
    return _seedPage(open.id);
  }

  /// The page of the wallet, and what opens from it, is the Ergo part of the app and always
  /// has Ergo's look (`ergoThemeActive`, applied by the app). Set after the frame: the
  /// app rebuilds on it, and a build must not start another.
  void _showErgoTheme(bool on) {
    if (ergoThemeActive.value == on) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ergoThemeActive.value = _open != null;
    });
  }

  /// Cold-start splash while the wallet core initialises: same branding as
  /// the overview so the app doesn't open on a bare spinner.
  Widget _splash() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CellMark(size: 72),
            const SizedBox(height: 20),
            const CelautWordmark(size: 30),
            const SizedBox(height: 8),
            const SizedBox(width: 48, child: Hairline(gold: true)),
            const SizedBox(height: 28),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }

  final _homeKey = GlobalKey<HomeTabsState>();

  /// The home screen: the tabs of the bottom bar, chat first
  /// (`docs/celaut/ui-chat-first.md`). The Wallet tab is the overview of the wallet,
  /// with "Deposit to a node"; the Compute tab is the compute view
  /// (`docs/celaut/ui.md`, section 2). The ERG of the wallet comes from the same
  /// figures as the overview; the USD price is the oracle pool price of the pricer of
  /// the app.
  Widget _home() {
    return ListenableBuilder(
      listenable: Listenable.merge([_overview, tokenPricer, walletService.currentWalletId]),
      builder: (context, _) {
        return HomeTabs(
          key: _homeKey,
          initialTab: _homeTab,
          onTab: (tab) => _homeTab = tab,
          money: WalletMoney.of(_overview.entries()),
          usdPerErg: tokenPricer.result.ergUsd,
          refreshPrice: () => tokenPricer.refresh(),
          // The Wallet tab shows the ERG and the latest transactions and nothing else; the rest
          // is in the details, the page of the wallet. With no wallet, the welcome.
          wallet: (context, deposit) => _overview.wallets.isEmpty
              ? _overviewScreen(
                  extra: deposit,
                  onSettings: () => _homeKey.currentState?.select(HomeTab.settings),
                )
              : WalletSummaryScreen(
                  model: _overview,
                  onDetails: () => _openWallet(WalletRef.seed(_overview.wallets.first.walletId)),
                  onBitcoin: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const BitcoinWalletScreen()),
                  ),
                ),
        );
      },
    );
  }

  /// The overview of the wallet. In the Wallet tab it has [extra] under the wallet,
  /// and its settings button shows the Settings tab ([onSettings]).
  Widget _overviewScreen({Widget? extra, VoidCallback? onSettings}) {
    return WalletsOverviewScreen(
      model: _overview,
      priceFeed: _price,
      onOpen: _openWallet,
      onCreate: _openCreate,
      onRestore: _openRestore,
      extra: extra,
      onSettings: onSettings ?? () => Navigator.push(context, fadeRoute(const SettingsScreen())),
      onNetwork: () => Navigator.push(context, fadeRoute(const NetworkSettingsPage())),
      notice: _notice,
      noticeIsError: _noticeIsError,
      onAction: _overviewAction,
    );
  }

  /// The overview's own Send, Receive and More act on a wallet: the
  /// unlocked one, else the first with keys here. It opens; when it is
  /// already unlocked the action follows at once, else its gate asks for
  /// the key first and the wallet's own buttons are a tap away.
  Future<void> _overviewAction(WalletAction action) async {
    final unlocked = _walletUnlocked ? _walletId : null;
    final id = unlocked ?? (_overview.wallets.isEmpty ? null : _overview.wallets.first.walletId);
    if (id == null) return;
    await _openWallet(WalletRef.seed(id));
    if (!mounted || !_walletUnlocked || _walletId != id) return;
    switch (action) {
      case WalletAction.send:
        _go('/send');
      case WalletAction.receive:
        _go('/receive');
      case WalletAction.more:
        break;
    }
  }

  Widget _seedPage(String walletId) {
    final info = _overview.wallet(walletId);
    final name = context.l10n.commonWallet;
    final unlocked = _walletUnlocked && _walletId == walletId;
    final owns = unlocked && _sync.ownsWallet(walletId);
    final tab = _tabOrder[_tab];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: WalletPageScreen(
        title: owns && tab != WalletTab.wallet ? walletTabLook(tab).label : name,
        // The wallet's own page, open or locked, lies under a clear header
        // with its state beneath its name.
        immersive: !owns || tab == WalletTab.wallet,
        subtitle: !owns || tab == WalletTab.wallet ? (unlocked ? context.l10n.homeUnlocked : context.l10n.homeLocked) : null,
        subtitleLive: unlocked,
        onBack: _closeWallet,
        actions: [
          if (owns && tab == WalletTab.wallet) ...[
            IconButton(
              key: const Key('wallet-scan'),
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: context.l10n.dashboardScanQrTooltip,
              onPressed: _scan,
            ),
            IconButton(
              key: const Key('wallet-menu'),
              icon: const Icon(Icons.more_vert),
              tooltip: context.l10n.dashboardWalletSettingsTooltip,
              onPressed: _openSettings,
            ),
          ],
        ],
        body: ListenableBuilder(
          listenable: Listenable.merge([addressLabelService, privacyService]),
          builder: (context, _) => WalletViewBoundary(
            controller: _sync,
            walletId: walletId,
            unlocked: unlocked,
            ledger: (_) => _tabs(walletId),
            gate: (_) => _gate(walletId, info),
          ),
        ),
        navBar: owns
            ? ListenableBuilder(
                listenable: _sync,
                builder: (context, _) => WalletNavBar(
                  current: tab,
                  onSelect: (t) => _selectTab(_tabOrder.indexOf(t)),
                  pendingCount: _sync.displayActivity.where(isPendingTx).length,
                ),
              )
            : null,
      ),
    );
  }

  Widget _gate(String walletId, WalletInfo? info) {
    final known = _overview.lastKnown(walletId);
    final ready = _methodsFor == walletId && _walletId == walletId;
    return UnlockGate(
      address: info?.displayAddress,
      pinnedIndex: info?.pinnedAddressIndex,
      lastKnownNano: known?.balanceNano,
      lastKnownAge: known?.age,
      hidden: _balanceHidden,
      // Until this wallet's methods are read, offer nothing that would act
      // on the previous wallet's.
      method: ready ? _unlockMethod : UnlockMethod.biometric,
      pinController: _pinCtrl,
      busy: _unlockBusy || !ready,
      onUnlock: _unlockBiometric,
      onUnlockWithPin: _unlockWithPin,
      status: _gateStatus ?? (_noticeIsError ? null : _notice),
      statusIsError: _gateStatus != null && _gateStatusIsError,
    );
  }

  /// The unlocked wallet's tabs share one [WalletArgsScope] so embedded
  /// screens see the same live balances a pushed route would get as
  /// arguments.
  Widget _tabs(String walletId) {
    final args = _args();
    Widget lazy(int i, Widget Function() build) =>
        _visitedTabs.contains(i) ? build() : const SizedBox.shrink();
    return WalletArgsScope(
      key: const ValueKey('tabs'),
      args: args,
      child: IndexedStack(
        index: _tab,
        children: [
          WalletLedger(
            sync: _sync,
            wallet: _overview.wallet(walletId),
            priceFeed: _price,
            actions: WalletLedgerActions(
              go: _go,
              showActivity: () => _selectTab(1),
              showSettings: _openSettings,
              viewAssets: () => Navigator.push(
                context,
                fadeRoute(AssetsScreen(args: _args())),
              ),
              openTx: _openTx,
              openToken: _openToken,
              labelAddress: _labelAddress,
              lock: _lock,
              openDeposit: () => Navigator.push(context, fadeRoute(const DepositScreen())),
            ),
          ),
          lazy(
            1,
            () => TransactionsScreen(
              key: ValueKey('activity-${_sync.receiveAddress}'),
              embedded: true,
              args: args,
            ),
          ),
          lazy(2, () => WalletDiscover(onExplain: _openDiscover)),
          lazy(
            3,
            () => SettingsScreen(
              key: ValueKey('settings-$walletId'),
              embedded: true,
              walletId: walletId,
              onWalletChanged: _onWalletEdited,
              onWalletRemoved: _onWalletRemoved,
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether a poll tick should refresh: always once [pollInterval] has
/// passed, and every [fastPollInterval] while a transaction is unconfirmed,
/// so a Pending row flips to Confirmed within seconds of the block.
bool shouldPoll({
  required DateTime now,
  required DateTime lastPollAt,
  required bool hasPending,
  Duration pollInterval = const Duration(seconds: 20),
  Duration fastPollInterval = const Duration(seconds: 5),
}) {
  final since = now.difference(lastPollAt);
  if (since >= pollInterval) return true;
  return hasPending && since >= fastPollInterval;
}
