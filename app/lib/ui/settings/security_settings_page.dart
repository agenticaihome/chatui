import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/linux_app.dart';
import '../../services/privacy_service.dart';
import '../../services/session_lock.dart';
import '../../services/spend_policy.dart';
import 'settings_shared.dart';

/// Auto-lock (app-wide), how the wallet unlocks, and the screen and spending policies.
class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key, this.walletId});
  final String? walletId;

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  int _graceKey = 0;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<(int, String)> get _graceOptions {
    final t = context.l10n;
    return [
      (0, t.securityLockImmediately),
      (2, t.securityLockAfterSeconds(2)),
      (30, t.securityLockAfterSeconds(30)),
      (60, t.securityLockAfterMinutes(1)),
      (300, t.securityLockAfterMinutes(5)),
    ];
  }

  Future<void> _pickGrace() async {
    final t = context.l10n;
    final current = sessionLock.grace.inSeconds;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.securityLockWhenBackgrounded),
        children: [
          for (final (secs, label) in _graceOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, secs),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  if (secs == current) const Icon(Icons.check, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == current) return;
    try {
      await sessionLock.setGrace(Duration(seconds: picked));
    } catch (_) {
      _snack(t.securityAutoLockUpdateFailed);
    }
    if (mounted) setState(() => _graceKey++);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final graceLabel = _graceOptions
        .firstWhere((o) => o.$1 == sessionLock.grace.inSeconds, orElse: () => (0, '${sessionLock.grace.inSeconds}s'))
        .$2;
    return SettingsPage(
      title: t.securityTitle,
      children: [
        SettingsGroup(
          title: t.securityAutoLock,
          scope: t.settingsScopeAppWide,
          children: [
            SettingsRow(
              key: ValueKey(_graceKey),
              icon: Icons.timer_outlined,
              title: t.securityLockWhenBackgrounded,
              subtitle: graceLabel,
              onTap: _pickGrace,
            ),
          ],
        ),
        SettingsGroup(
          title: t.securityUnlockGroup,
          scope: t.commonThisWallet,
          children: [
            SettingsRow(
              icon: isLinuxApp ? Icons.key_outlined : Icons.fingerprint,
              title: t.securityBiometricUnlock,
              subtitle: isLinuxApp ? t.securityUnlockKeyring : t.securityBiometricOn,
            ),
          ],
        ),
        SettingsNote(isLinuxApp ? t.securityKeyringNote : t.securityDeviceLockNote),
        // X11 and Wayland let no app keep its window out of a screenshot, so Linux has no
        // such setting (#156). Screens with a secret still say when they cannot block one.
        if (!isLinuxApp) ...[
          ListenableBuilder(
            listenable: privacyService,
            builder: (context, _) => SettingsGroup(
              title: t.securityScreen,
              scope: t.settingsScopeAppWide,
              children: [
                SettingsRow(
                  icon: Icons.screenshot_monitor_outlined,
                  title: t.securityBlockScreenshots,
                  subtitle: privacyService.blockScreenshots
                      ? t.securityScreenshotsBlocked
                      : t.securityScreenshotsAllowed,
                  trailing: Switch(
                    value: privacyService.blockScreenshots,
                    onChanged: (v) => privacyService.setBlockScreenshots(v),
                  ),
                ),
              ],
            ),
          ),
          SettingsNote(t.securitySeedScreensNote),
        ],
        ListenableBuilder(
          listenable: spendPolicy,
          builder: (context, _) => SettingsGroup(
            title: t.securitySpending,
            scope: t.settingsScopeAppWide,
            children: [
              SettingsRow(
                icon: Icons.hourglass_bottom_rounded,
                title: t.securitySpendUnconfirmed,
                subtitle: spendPolicy.spendUnconfirmed
                    ? t.securitySpendUnconfirmedOn
                    : t.securitySpendUnconfirmedOff,
                trailing: Switch(
                  key: const Key('spend-unconfirmed-switch'),
                  value: spendPolicy.spendUnconfirmed,
                  onChanged: (v) async {
                    try {
                      await spendPolicy.setSpendUnconfirmed(v);
                    } catch (_) {
                      _snack(t.securitySpendingSaveFailed);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        SettingsNote(spendUnconfirmedNote),
      ],
    );
  }
}
