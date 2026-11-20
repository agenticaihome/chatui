import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../build_info.dart';
import '../../format.dart';
import '../../l10n/l10n.dart';
import '../../services/apk_signature.dart';
import '../../services/linux_app.dart';
import '../../services/update_service.dart';
import '../../theme/argus_theme.dart';
import 'settings_shared.dart';
import 'update_card.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.updates});

  /// Defaults to the app-wide [updateService]; tests pass their own.
  final UpdateService? updates;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final UpdateService _updates = widget.updates ?? updateService;

  /// Read once: the key this build is signed with does not change while the
  /// page is open.
  late final Future<List<String>?> _signingKey = _updates.ownSigningFingerprints();

  @override
  void initState() {
    super.initState();
    // Saved settings only; nothing is fetched by opening this page.
    _updates.ensureLoaded();
  }

  Future<void> _setChecking(bool value) async {
    final saved = await _updates.setEnabled(value);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.aboutSaveSettingFailed)));
    }
  }

  /// One line on where the last check stands.
  String _checkStatus() {
    final u = _updates;
    final t = context.l10n;
    if (u.checking) return t.aboutAskingGithub;
    if (u.checkError != null) return u.checkError!;
    final at = u.lastChecked;
    if (at == null) return t.aboutNotCheckedYet;
    final when = formatRelativeTime(at);
    final lower = when.isEmpty ? when : '${when[0].toLowerCase()}${when.substring(1)}';
    return u.available == null
        ? t.aboutUpToDateChecked(lower)
        : t.aboutVersionAvailableChecked('${u.available!.version}', lower);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _updates,
      builder: (context, _) => SettingsPage(
        title: context.l10n.aboutTitle,
        children: [
          const SizedBox(height: 16),
          const Center(child: CellMark(size: 64)),
          const SizedBox(height: 14),
          const CelautWordmark(size: 28, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            context.l10n.aboutVersionBuild(appVersion, '$appBuildNumber'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          UpdateCard(updates: _updates),
          SettingsGroup(
            title: context.l10n.aboutUpdatesGroup,
            scope: context.l10n.settingsScopeAppWide,
            children: [
              SettingsRow(
                icon: Icons.update,
                title: context.l10n.aboutCheckForUpdates,
                subtitle: context.l10n.aboutCheckForUpdatesSubtitle,
                trailing: Switch(
                  key: const Key('update-check-toggle'),
                  value: _updates.enabled,
                  onChanged: _setChecking,
                ),
                onTap: () => _setChecking(!_updates.enabled),
              ),
              SettingsRow(
                icon: Icons.refresh,
                title: context.l10n.aboutCheckNow,
                subtitle: _checkStatus(),
                trailing: _updates.checking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const SizedBox.shrink(),
                onTap: _updates.checking || _updates.busy ? null : _updates.checkNow,
              ),
            ],
          ),
          SettingsNote(isLinuxApp ? context.l10n.aboutUpdatesNoteLinux : context.l10n.aboutUpdatesNote),
          SettingsGroup(
            title: context.l10n.aboutThisBuild,
            children: [
              SettingsRow(
                icon: Icons.shield_outlined,
                title: context.l10n.aboutUnauditedTitle,
                subtitle: context.l10n.aboutUnauditedSubtitle,
              ),
              // The .deb has no signing key to compare: its sums are in SHA256SUMS.
              if (!isLinuxApp) _SigningKeyRow(fingerprints: _signingKey),
              SettingsRow(
                icon: Icons.new_releases_outlined,
                title: context.l10n.aboutReleasesTitle,
                subtitle: isLinuxApp ? context.l10n.aboutReleasesSubtitleLinux : context.l10n.aboutReleasesSubtitle,
                onTap: () => launchUrl(Uri.parse(releasesUrl), mode: LaunchMode.externalApplication),
              ),
              SettingsRow(
                icon: Icons.description_outlined,
                title: context.l10n.aboutLicenses,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: CelautWordmark.name,
                  applicationVersion: appVersion,
                ),
              ),
            ],
          ),
          SettingsNote(context.l10n.aboutLightClientNote),
        ],
      ),
    );
  }
}

/// The SHA-256 of the certificate this build is signed with, in the form
/// release notes publish it, so it can be compared by eye. Read from Android
/// at run time, never a constant.
class _SigningKeyRow extends StatelessWidget {
  const _SigningKeyRow({required this.fingerprints});

  final Future<List<String>?> fingerprints;

  /// Eight bytes to a line so the fingerprint fits a narrow phone.
  static String _lines(String hex) {
    final pairs = formatFingerprint(hex).split(':');
    return [
      for (var i = 0; i < pairs.length; i += 8) pairs.sublist(i, i + 8 > pairs.length ? pairs.length : i + 8).join(':'),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final colors = ArgusColors.of(context);
    return FutureBuilder<List<String>?>(
      future: fingerprints,
      builder: (context, snapshot) {
        final done = snapshot.connectionState == ConnectionState.done;
        final prints = snapshot.data;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: colors.chip, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.verified_user_outlined, size: 19, color: accentTextOf(context)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.aboutSigningCertificate, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.aboutSigningCertificateSubtitle,
                      style: TextStyle(fontSize: 12.5, color: colors.muted),
                    ),
                    const SizedBox(height: 8),
                    if (!done)
                      Text(context.l10n.aboutReading, style: TextStyle(fontSize: 12.5, color: colors.muted))
                    else if (prints == null)
                      Text(context.l10n.aboutNotAvailableOnDevice, style: TextStyle(fontSize: 12.5, color: colors.muted))
                    else
                      for (final hex in prints)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            _lines(hex),
                            key: const Key('signing-fingerprint'),
                            style: monoStyle(context, size: 12),
                          ),
                        ),
                  ],
                ),
              ),
              if (prints != null)
                IconButton(
                  tooltip: context.l10n.commonCopy,
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: prints.map(formatFingerprint).join('\n')));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.aboutFingerprintCopied)));
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
