import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'celaut/auto_top_up.dart';
import 'celaut/background_work.dart';
import 'celaut/chat_groups.dart';
import 'celaut/chat_prefs.dart';
import 'l10n/l10n.dart';
import 'services/address_label_service.dart';
import 'services/contacts_service.dart';
import 'services/deep_link_channel.dart';
import 'services/motion_cues.dart';
import 'services/notification_service.dart';
import 'services/network_controller.dart';
import 'services/preview/preview_service.dart';
import 'services/privacy_service.dart';
import 'services/token_pricer.dart';
import 'services/session_lock.dart';
import 'services/spend_policy.dart';
import 'services/update_service.dart';
import 'services/wallet_service.dart';
import 'services/wallet_sync_controller.dart';
import 'theme/argus_theme.dart';
import 'theme/theme_controller.dart';
import 'ui/contacts_screen.dart';
import 'ui/create_wallet_screen.dart';
import 'ui/dashboard_screen.dart';
import 'ui/receive_screen.dart';
import 'ui/restore_wallet_screen.dart';
import 'ui/send_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/transaction_detail_screen.dart';
import 'ui/transactions_screen.dart';
import 'ui/token_tools_screen.dart';
import 'ui/utxo_management_screen.dart';
import 'ui/widgets/motion_cues_overlay.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// The page a named route opens, or null for a name the app does not know.
Widget? appPage(String? name) => switch (name) {
      '/' || null => const DashboardScreen(),
      '/receive' => const ReceiveScreen(),
      '/send' => const SendScreen(),
      '/transactions' => const TransactionsScreen(),
      '/create' => const CreateWalletScreen(),
      '/restore' => const RestoreWalletScreen(),
      '/settings' => const SettingsScreen(),
      '/contacts' => const ContactsScreen(),
      '/tx' => const TransactionDetailScreen(),
      '/utxos' => const UtxoManagementScreen(),
      UtxoManagementScreen.cleanupRoute => const UtxoManagementScreen(openCleanup: true),
      '/tokens' => const TokenToolsScreen(),
      _ => null,
    };

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  themeController.load().catchError((_) {});
  // Independent preference loads; run them together so the first frame
  // waits on the slowest one instead of the sum.
  await Future.wait<void>([
    sessionLock.loadGrace().catchError((_) {}),
    contactsService.load().catchError((_) {}),
    addressLabelService.load().catchError((_) {}),
    privacyService.load().catchError((_) {}),
    motionCues.load().catchError((_) {}),
    spendPolicy.load().catchError((_) {}),
    previewSettings.load().catchError((_) {}),
    chatPrefs.load().catchError((_) {}),
    chatGroups.load().catchError((_) {}),
  ]);
  networkController.priceRefresher = tokenPricer.refresh;
  runApp(const ArgusApp());
  // Off until the user turns it on in About; then at most one request a day.
  updateService.checkOnStart().catchError((_) {});
}

class ArgusApp extends StatefulWidget {
  const ArgusApp({super.key});

  @override
  State<ArgusApp> createState() => _ArgusAppState();
}

class _ArgusAppState extends State<ArgusApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    walletService.unlocked.addListener(_onUnlockChanged);
    // A broadcast shows on the home screen at once, not at the next poll.
    walletService.onBroadcast = (txId, delta) =>
        walletSyncController.noteBroadcast(txId, valueNano: delta);
    DeepLinkChannel.start();
    // The automatic top-up checks the instances once a minute, only if the user turned it
    // on (Settings, Compute).
    unawaited(autoTopUp.start());
    notificationService.init().then((_) => notificationService.openLaunchTap());
  }

  @override
  void dispose() {
    walletService.unlocked.removeListener(_onUnlockChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    sessionLock.onLifecycle(state);
  }

  void _onUnlockChanged() {
    // A lock closes the pages over the home screen, except while a launch, a transfer or
    // an import of a service runs (`BackgroundWork`).
    if (!walletService.unlocked.value) backgroundWork.onWalletLocked(navigatorKey.currentState);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, ergoThemeActive]),
      builder: (context, _) {
        final ergo = ergoThemeActive.value;
        return MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          navigatorKey: navigatorKey,
          // The device language when the app has it, else English.
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          // The Ergo part always has its own look (`ergoThemeActive`).
          theme: ergo ? argusThemeFor(ergoPalette) : themeController.lightTheme,
          darkTheme: ergo ? argusThemeFor(ergoPalette) : themeController.darkTheme,
          themeMode: ergo ? ThemeMode.dark : themeController.themeMode,
          // Densities in the wallet card assume at most ~1.6x text; larger
          // system font scales would overflow fixed rows.
          // Every route sees live wallet context through WalletArgsScope, so
          // a pushed screen's balances update instead of freezing at push
          // time. Route arguments still carry per-route data (a transaction).
          builder: (context, child) {
            // Code without a BuildContext reads its texts from appL10n.
            setAppLocale(Localizations.localeOf(context));
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler:
                    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
              ),
              child: ListenableBuilder(
                listenable: walletSyncController,
                builder: (context, _) => WalletArgsScope(
                  args: walletSyncController.routeArgs,
                  // The dots of the vehicle motion cues, when they are on (Display).
                  child: MotionCuesOverlay(child: child!),
                ),
              ),
            );
          },
          onGenerateRoute: (settings) {
            final page = appPage(settings.name);
            if (page == null) return null;
            return fadeRoute(page, settings: settings);
          },
          onUnknownRoute: (settings) =>
              fadeRoute(const DashboardScreen(), settings: settings),
        );
      },
    );
  }
}
