import 'dart:convert';
import 'dart:typed_data';

import 'host_port.dart';
import 'invite_scan.dart';

/// A `celaut://` link that opens the app (`docs/celaut/invite.md`, section 6).
///
/// - `celaut://node?invite=<base64url>`: a peer invitation of nodo. The invitation is
///   binary, so the link carries its bytes as URL-safe base64 (RFC 4648 section 5), with
///   or without the `=` padding.
/// - `celaut://node?addr=<host>:<port>`: a node address, as in a QR code (`wire.md`,
///   section 6).
///
/// The size is checked before anything is decoded, and nothing in a link can make the
/// parser throw.
sealed class CelautLink {
  const CelautLink();
}

/// A link with a peer invitation: the bytes for `celaut_read_invite`.
class CelautInviteLink extends CelautLink {
  const CelautInviteLink(this.bytes);
  final Uint8List bytes;
}

/// A link with a node address.
class CelautAddressLink extends CelautLink {
  const CelautAddressLink(this.address);
  final HostPort address;
}

/// Why a link was refused.
enum CelautLinkError {
  /// Longer than any invitation can be. Nothing in it was decoded.
  tooLong,

  /// Not a node link that the app reads: another host, a bad form, a bad address, or
  /// characters that are not URL-safe base64.
  invalid,

  /// Base64 that decodes, but not to an invitation.
  damaged,
}

/// A link that the app does not open, and why.
class CelautLinkRefused extends CelautLink {
  const CelautLinkRefused(this.error);
  final CelautLinkError error;
}

/// nodo refuses an invitation of more than 1000 bytes (`invite.md`, section 1).
const maxInviteBytes = 1000;

/// The base64 of [maxInviteBytes] bytes: 1336 characters with the padding.
const maxInviteChars = (maxInviteBytes + 2) ~/ 3 * 4;

/// The longest link that the app reads: the invitation and room for the rest of the URL.
/// A longer link is refused before it is parsed.
const maxCelautLinkLength = 2048;

final _base64Url = RegExp(r'^[A-Za-z0-9_-]*$');

/// True for a link of the scheme `celaut:`, which [parseCelautLink] reads. The Android
/// side gives only such links (and `ergopay:` ones) to the app.
bool isCelautLink(String link) => link.trimLeft().toLowerCase().startsWith('celaut:');

/// Read a `celaut://` link. See [CelautLink].
CelautLink parseCelautLink(String input) {
  final text = input.trim();
  // First the size: a link of a megabyte is refused without a look at its content.
  if (text.length > maxCelautLinkLength) return const CelautLinkRefused(CelautLinkError.tooLong);
  try {
    return _parse(text);
  } on ArgumentError {
    // A bad percent encoding.
    return const CelautLinkRefused(CelautLinkError.invalid);
  } on FormatException {
    return const CelautLinkRefused(CelautLinkError.invalid);
  }
}

CelautLink _parse(String text) {
  const invalid = CelautLinkRefused(CelautLinkError.invalid);

  const prefix = 'celaut://node';
  if (!text.toLowerCase().startsWith(prefix) || text.contains('#')) return invalid;
  var rest = text.substring(prefix.length);
  if (rest.startsWith('/')) rest = rest.substring(1);
  if (!rest.startsWith('?')) return invalid;

  final invites = <String>[];
  for (final pair in rest.substring(1).split('&')) {
    final eq = pair.indexOf('=');
    final key = eq < 0 ? pair : pair.substring(0, eq);
    if (key != 'invite') continue;
    invites.add(Uri.decodeQueryComponent(eq < 0 ? '' : pair.substring(eq + 1)));
  }
  // No invitation: the form of a node address, which has its own rules.
  if (invites.isEmpty) {
    final address = parseNodeQr(text).value;
    return address == null ? invalid : CelautAddressLink(address);
  }
  if (invites.length != 1) return invalid;
  return _invite(invites.single);
}

CelautLink _invite(String encoded) {
  const invalid = CelautLinkRefused(CelautLinkError.invalid);
  var data = encoded;
  // The padding is optional: at most two `=` at the end.
  if (data.endsWith('==')) {
    data = data.substring(0, data.length - 2);
  } else if (data.endsWith('=')) {
    data = data.substring(0, data.length - 1);
  }
  if (data.length > maxInviteChars) return const CelautLinkRefused(CelautLinkError.tooLong);
  if (data.isEmpty || !_base64Url.hasMatch(data) || data.length % 4 == 1) return invalid;
  final bytes = base64Url.decode(data.padRight((data.length + 3) ~/ 4 * 4, '='));
  if (bytes.length > maxInviteBytes) return const CelautLinkRefused(CelautLinkError.tooLong);
  if (!looksLikeInvite(bytes)) return const CelautLinkRefused(CelautLinkError.damaged);
  return CelautInviteLink(bytes);
}

/// The link of an invitation, as [parseCelautLink] reads it: URL-safe base64 with no
/// padding. The tests use it; a screen that shares an invitation could.
String celautInviteLink(List<int> invite) =>
    'celaut://node?invite=${base64Url.encode(invite).replaceAll('=', '')}';
