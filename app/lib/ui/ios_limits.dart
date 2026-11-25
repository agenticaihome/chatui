import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../services/linux_app.dart';

/// The limits of the app on iOS, in the words of issue #152 (`docs/ios.md`): iOS suspends
/// the app a few seconds after it goes to the background, so the conversations disconnect,
/// no notification comes for a new message, and the automatic top-up ("Keep running")
/// stops. The full set shows once, at the first start; the top-up warning also shows where
/// the user turns the top-up on. On macOS (`docs/macos.md`) only the top-up warning shows:
/// the top-up runs while the app is open and the Mac is awake. The Linux app (`docs/linux.md`)
/// is the same: only the top-up warning, with its own text. Nothing shows on Android.

/// True on iOS. [debugDefaultTargetPlatformOverride] sets it in tests.
bool get onIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// True on macOS. [debugDefaultTargetPlatformOverride] sets it in tests.
bool get onMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// The key of the preference that says the full set was shown.
const iosLimitsSeenKey = 'ios_limits_seen_v1';

/// Show the full set of iOS warnings, once per install. Off iOS it does nothing.
Future<void> showIosLimitsOnce(BuildContext context) async {
  if (!onIos) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(iosLimitsSeenKey) == true || !context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => const IosLimitsDialog());
  await prefs.setBool(iosLimitsSeenKey, true);
}

/// The full set of iOS warnings.
class IosLimitsDialog extends StatelessWidget {
  const IosLimitsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (Icons.cloud_off_outlined, l.iosLimitsConversations),
      (Icons.notifications_off_outlined, l.iosLimitsNotifications),
      (Icons.timer_off_outlined, l.iosLimitsTopUp),
    ];
    return AlertDialog(
      key: const Key('ios-limits'),
      title: Text(l.iosLimitsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (icon, text) in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const Key('ios-limits-ok'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.iosLimitsOk),
        ),
      ],
    );
  }
}

/// The top-up warning, where the user turns the automatic top-up on: the iOS text on iOS,
/// the macOS text on macOS, the Linux text in the Linux app. Empty on Android.
class TopUpWarning extends StatelessWidget {
  const TopUpWarning({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!onIos && !onMacOS && !isLinuxApp) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Container(
        key: Key(onIos ? 'ios-top-up-warning' : onMacOS ? 'mac-top-up-warning' : 'linux-top-up-warning'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                onIos
                    ? context.l10n.iosLimitsTopUp
                    : onMacOS
                        ? context.l10n.celautKeepMacNote
                        : context.l10n.celautKeepLinuxNote,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
