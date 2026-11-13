/// Links to a service (issue #135, `docs/celaut/package.md`, "From a link").
///
/// A link can come typed or pasted in the import sheet, from a QR code, from a web page or
/// another app (`chatui://import?url=…`), or shared as text. This file finds the link of
/// the service in what came. The core checks it again (`celautCheckLink`) before the
/// download.
library;

/// The scheme of the deep link of the app: `chatui://import?url=<the link, encoded>`.
const importLinkScheme = 'chatui';

/// The `http(s)://` link in [raw]: the link itself, the `url` of a
/// `chatui://import?url=…` link, or the first `http(s)://` link in a text (a shared text
/// often has a title before the link). Null if there is none.
String? serviceLinkOf(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (lower.startsWith('$importLinkScheme:')) {
    final uri = Uri.tryParse(text);
    final url = uri?.queryParameters['url']?.trim();
    if (uri == null || uri.host.toLowerCase() != 'import' || url == null) return null;
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

/// The deep link that opens the import of [url] in the app (for a QR code or a web page).
String importDeepLink(String url) =>
    Uri(scheme: importLinkScheme, host: 'import', queryParameters: {'url': url}).toString();
