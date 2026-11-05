import 'package:flutter/material.dart';

import '../../bridge/api/celaut_service.dart';
import '../../celaut/package_channel.dart';
import '../../celaut/payers.dart';
import '../../l10n/l10n.dart';
import '../home/home_scene.dart';
import '../layout.dart';
import 'run_service_section.dart';

/// Run a service: the catalog of skills, the service files of the user, and the import
/// of a file, on a screen of its own. The home screen has only the button that opens it,
/// so the catalog is read only when the user wants to run something.
class RunServiceScreen extends StatelessWidget {
  const RunServiceScreen({
    super.key,
    this.wallets = const AppFullWallets(),
    this.newClient,
    this.onChanged,
    this.section,
    this.title,
    this.onStarted,
    this.importFile,
  });

  /// The title of the bar: "New conversation" from the pencil button, "Services" from
  /// the Compute tab. Null: "Run a service".
  final String? title;

  /// What to do after a start (see [RunServiceSection.onStarted]).
  final StartedCall? onStarted;

  /// A file that the user opened in a file manager: its import starts at once.
  final ChosenFile? importFile;

  final FullWallets wallets;

  /// Make a new client on a node that forgot the client id. Tests give their own.
  final Future<NewClientView> Function(NodeAddress node)? newClient;

  /// Called when an instance started, so that the home screen loads its data again.
  final VoidCallback? onChanged;

  /// The content. Tests give their own section.
  final RunServiceSection? section;

  @override
  Widget build(BuildContext context) {
    return SceneBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(title ?? context.l10n.celautRunTitle)),
        body: ReadableWidth(
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, 8, 0, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              section ??
                  RunServiceSection(
                    wallets: wallets,
                    newClient: newClient,
                    onChanged: onChanged,
                    onStarted: onStarted,
                    importFile: importFile,
                    showTitle: false,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
