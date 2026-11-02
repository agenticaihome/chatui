import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/motion_cues.dart';
import '../../services/network_controller.dart';
import '../../services/privacy_service.dart';
import '../../services/token_pricer.dart';
import '../../services/token_pricing.dart';
import '../../theme/argus_theme.dart';
import '../../theme/theme_controller.dart';
import 'settings_shared.dart';

class DisplaySettingsPage extends StatelessWidget {
  const DisplaySettingsPage({super.key});

  Widget _radio(bool on) => Builder(
        builder: (context) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: on ? accentOf(context) : Colors.transparent,
            border: Border.all(color: accentOf(context), width: 1.2),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, networkController, privacyService, tokenPricer, motionCues]),
      builder: (context, _) => SettingsPage(
        title: context.l10n.displayTitle,
        children: [
          SettingsGroup(
            title: context.l10n.displayAppearance,
            scope: context.l10n.settingsScopeAppWide,
            children: [
              for (final m in ArgusThemeMode.values)
                SettingsRow(
                  icon: switch (m) {
                    ArgusThemeMode.system => Icons.brightness_auto_outlined,
                    ArgusThemeMode.dark => Icons.dark_mode_outlined,
                    ArgusThemeMode.light => Icons.light_mode_outlined,
                  },
                  title: switch (m) {
                    ArgusThemeMode.system => context.l10n.displayFollowSystem,
                    ArgusThemeMode.dark => context.l10n.displayAlwaysDark,
                    ArgusThemeMode.light => context.l10n.displayAlwaysLight,
                  },
                  subtitle: switch (m) {
                    ArgusThemeMode.system =>
                      context.l10n.displaySystemPalettes(themeController.darkPalette.name, themeController.lightPalette.name),
                    ArgusThemeMode.dark => themeController.darkPalette.name,
                    ArgusThemeMode.light => themeController.lightPalette.name,
                  },
                  trailing: _radio(themeController.mode == m),
                  onTap: () => themeController.setMode(m),
                ),
            ],
          ),
          SectionLabel(context.l10n.displayDarkPalette, scope: context.l10n.settingsScopeAppWide),
          const SizedBox(height: 10),
          _PaletteRow(
            palettes: allPalettes.where((p) => p.isDark).toList(),
            selected: themeController.darkPalette,
            onPick: themeController.setDarkPalette,
          ),
          const SizedBox(height: 24),
          SectionLabel(context.l10n.displayLightPalette, scope: context.l10n.settingsScopeAppWide),
          const SizedBox(height: 10),
          _PaletteRow(
            palettes: allPalettes.where((p) => !p.isDark).toList(),
            selected: themeController.lightPalette,
            onPick: themeController.setLightPalette,
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            title: context.l10n.displayVehicleMotionCues,
            scope: context.l10n.settingsScopeAppWide,
            children: [
              for (final m in MotionCuesMode.values)
                SettingsRow(
                  icon: switch (m) {
                    MotionCuesMode.off => Icons.block_outlined,
                    MotionCuesMode.automatic => Icons.directions_car_outlined,
                    MotionCuesMode.always => Icons.blur_on_outlined,
                  },
                  title: switch (m) {
                    MotionCuesMode.off => context.l10n.displayMotionCuesOff,
                    MotionCuesMode.automatic => context.l10n.displayMotionCuesAutomatic,
                    MotionCuesMode.always => context.l10n.displayMotionCuesAlways,
                  },
                  subtitle: switch (m) {
                    MotionCuesMode.off => null,
                    MotionCuesMode.automatic => context.l10n.displayMotionCuesAutomaticSubtitle,
                    MotionCuesMode.always => context.l10n.displayMotionCuesAlwaysSubtitle,
                  },
                  trailing: _radio(motionCues.mode == m),
                  onTap: () => motionCues.setMode(m),
                ),
              if (motionCues.mode == MotionCuesMode.automatic)
                SettingsRow(
                  icon: Icons.speed_outlined,
                  title: context.l10n.displayMotionCuesGps,
                  subtitle: context.l10n.displayMotionCuesGpsSubtitle,
                  trailing: Switch(
                    value: motionCues.useGps,
                    onChanged: (v) async {
                      final ok = await motionCues.setUseGps(v);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(context.l10n.displayMotionCuesGpsDenied)));
                      }
                    },
                  ),
                ),
            ],
          ),
          SettingsNote(context.l10n.displayVehicleMotionCuesNote),
          SettingsGroup(
            title: context.l10n.displayMoney,
            scope: context.l10n.settingsScopeAppWide,
            children: [
              SettingsRow(
                icon: Icons.price_change_outlined,
                title: context.l10n.displayPricesInUsd,
                subtitle: tokenPricer.sourceLine,
              ),
              SettingsRow(
                icon: Icons.visibility_off_outlined,
                title: context.l10n.displayHideBalances,
                subtitle: context.l10n.displayHideBalancesSubtitle,
                trailing: Switch(
                  value: privacyService.hideBalances,
                  onChanged: (v) => privacyService.setHideBalances(v),
                ),
              ),
            ],
          ),
          SettingsNote(priceSourceBlurb),
        ],
      ),
    );
  }
}

/// Swatch cards for one brightness: background, surface, ink and accent.
class _PaletteRow extends StatelessWidget {
  const _PaletteRow({required this.palettes, required this.selected, required this.onPick});
  final List<PaletteSpec> palettes;
  final PaletteSpec selected;
  final ValueChanged<PaletteSpec> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: palettes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = palettes[i];
          final on = p.id == selected.id;
          return InkWell(
            onTap: () => onPick(p),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: on ? p.accent : p.cardBorder, width: on ? 2 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.cardBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '1,277.94',
                      style: TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700, fontSize: 16, color: p.ink),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(width: 22, height: 22, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(width: 6),
                      Container(width: 22, height: 22, decoration: BoxDecoration(color: p.muted, borderRadius: BorderRadius.circular(6))),
                      const Spacer(),
                      if (on) Icon(Icons.check_circle, size: 18, color: p.accentText),
                    ],
                  ),
                  const Spacer(),
                  Text(p.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: p.ink)),
                  Text(p.hint, style: TextStyle(fontSize: 11, color: p.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
