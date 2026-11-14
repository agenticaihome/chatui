import 'package:flutter/material.dart';

import '../../celaut/celaut_link.dart';
import 'node_link.dart';

/// Opens one kind of `celaut://` link. It gets the whole link, as it came.
typedef CelautLinkOpener = Future<void> Function(BuildContext context, String link);

/// What the app does with each host of a `celaut://` link (`docs/celaut/invite.md`,
/// section 6.3). The key is the host in lower case.
///
/// Android gives every `celaut://` link to the app, whatever its host: `OpenLinkActivity`
/// has the only intent filter of the scheme, and `DeepLinkHandler` passes the link to Dart.
/// The home screen then calls [openCelautLink]. So a new kind of link is one more entry here,
/// for example `'import': openImportLink` for `celaut://import` (#135). Each opener checks
/// its own form and sizes, asks the user, and shows [showCelautLinkRefused] for a link that
/// it does not open.
const Map<String, CelautLinkOpener> celautLinkOpeners = {
  'node': openNodeLink,
};

/// Open a `celaut://` link that another app gave: the opener of its host in [openers]. For a
/// host that the app does not know, a dialog says that this app cannot open this kind of
/// link, and nothing else happens.
Future<void> openCelautLink(
  BuildContext context,
  String link, {
  Map<String, CelautLinkOpener> openers = celautLinkOpeners,
}) {
  final opener = openers[celautLinkHost(link)];
  if (opener == null) return showCelautLinkRefused(context, CelautLinkError.unknownKind);
  return opener(context, link);
}
