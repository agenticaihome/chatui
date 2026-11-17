import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../home/home_style.dart';

/// macOS (issue #154): automatic top-up runs only while the app runs and the Mac is awake.
/// Shown where the user turns it on. Nothing on the other platforms.
class MacKeepNote extends StatelessWidget {
  const MacKeepNote({super.key, this.top = 0});

  /// The space above the note, only when it shows.
  final double top;

  static bool get shows => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (!shows) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Text(
        context.l10n.celautKeepMacNote,
        key: const Key('keep-mac-note'),
        style: HomeText.of(context).secondary,
      ),
    );
  }
}
