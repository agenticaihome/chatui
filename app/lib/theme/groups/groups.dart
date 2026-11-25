import '../../l10n/app_localizations.dart';
import '../argus_theme.dart' show PaletteGroup;
import 'christmas.dart';
import 'cyberpunk.dart';
import 'gta.dart';
import 'harry_potter.dart';
import 'marvel.dart';

export 'christmas.dart';
export 'cyberpunk.dart';
export 'gta.dart';
export 'harry_potter.dart';
export 'marvel.dart';

// The groups of themed palettes, one file each in this folder, so that a group can change
// without a change to the others.

/// The palettes of all the groups, after the standard ones in the picker.
const groupPalettes = [
  ...harryPotterPalettes,
  ...christmasPalettes,
  ...gtaPalettes,
  ...marvelPalettes,
  ...cyberpunkPalettes,
];

/// The name of the palette [id] of a group in the language of the app, or null.
String? groupPaletteName(AppLocalizations l, String id) =>
    harryPotterName(l, id) ?? christmasName(l, id) ?? gtaName(l, id) ?? marvelName(l, id) ?? cyberpunkName(l, id);

/// What the palette [id] of a group looks like, in the language of the app, or null.
String? groupPaletteHint(AppLocalizations l, String id) =>
    harryPotterHint(l, id) ?? christmasHint(l, id) ?? gtaHint(l, id) ?? marvelHint(l, id) ?? cyberpunkHint(l, id);

/// The name of the folder of [group] in the picker.
String paletteGroupLabel(AppLocalizations l, PaletteGroup group) => switch (group) {
      PaletteGroup.standard => l.displayPaletteGroupStandard,
      PaletteGroup.harryPotter => l.displayPaletteGroupHarryPotter,
      PaletteGroup.christmas => l.displayPaletteGroupChristmas,
      PaletteGroup.gta => l.displayPaletteGroupGta,
      PaletteGroup.marvel => l.displayPaletteGroupMarvel,
      PaletteGroup.cyberpunk => l.displayPaletteGroupCyberpunk,
    };
