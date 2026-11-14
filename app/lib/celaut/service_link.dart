/// Links to a service (issue #135, `docs/celaut/package.md`, "From a link").
///
/// A link can come typed or pasted in the import sheet, from a QR code, or from a web page
/// or another app (`celaut://import?url=…`, the scheme of the `celaut://` links of the
/// app). This file finds the link of the service in what came. The core checks it again
/// (`celautCheckLink`) before the download.
library;

/// The scheme of the deep link of the app: `celaut://import?url=<the link, encoded>`.
const importLinkScheme = 'celaut';

/// The host of the deep link of an import: `celaut://import`.
const importLinkHost = 'import';

final _serviceId = RegExp(r'^[0-9a-fA-F]{64}$');

/// The `http(s)://` link in [raw]: the link itself, the `url` of a
/// `celaut://import?url=…` link, or the first `http(s)://` link in a pasted text (a copied
/// text often has a title before the link). Null if there is none.
String? serviceLinkOf(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (lower.startsWith('$importLinkScheme:')) {
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.toLowerCase() != importLinkHost) return null;
    final String? url;
    try {
      url = uri.queryParameters['url']?.trim();
    } on FormatException {
      // A bad percent encoding (UTF-8 that does not decode).
      return null;
    } on ArgumentError {
      // A bad percent encoding (a `%` with no two hex digits).
      return null;
    }
    if (url == null) return null;
    return _isHttp(url) ? url : null;
  }
  if (_isHttp(text) && !text.contains(RegExp(r'\s'))) return text;
  final found = RegExp(r'https?://\S+', caseSensitive: false).firstMatch(text);
  if (found == null) return null;
  // A link in a sentence often ends with a mark that is not part of it.
  return found.group(0)!.replaceFirst(RegExp(r'''[)\].,;:!?'">]+$'''), '');
}

bool _isHttp(String s) {
  final l = s.toLowerCase();
  return l.startsWith('https://') || l.startsWith('http://');
}

/// [url] with the id of its service as the fragment: `…/x.celaut.bee#<64 hex>`. The app
/// checks that the file is that service. A QR code or a catalog entry always gives the link
/// in this form (issue #135); reading it stays optional. A fragment that [url] had is
/// replaced. Throws [ArgumentError] if [serviceId] is not 64 hexadecimal characters.
String serviceLinkWithId(String url, String serviceId) {
  if (!_serviceId.hasMatch(serviceId)) {
    throw ArgumentError.value(serviceId, 'serviceId', 'not 64 hexadecimal characters');
  }
  final hash = url.indexOf('#');
  final base = hash < 0 ? url : url.substring(0, hash);
  return '$base#${serviceId.toLowerCase()}';
}

/// The deep link that opens the import of [url] in the app, for a QR code or a web page:
/// `celaut://import?url=<the link with #<service id>, encoded>`. It always names the service
/// ([serviceLinkWithId]).
String importDeepLink(String url, String serviceId) => Uri(
      scheme: importLinkScheme,
      host: importLinkHost,
      queryParameters: {'url': serviceLinkWithId(url, serviceId)},
    ).toString();
