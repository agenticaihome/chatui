import Foundation

/// The private folders of the app on Apple systems: Foundation only, so the iOS app and the
/// macOS app share it.
enum AppPaths {
  /// The folder of the Celaut database, and of the state of the Tor client: in Application
  /// Support, out of the backups (the file is useless without its key, which stays on this
  /// device). A macOS app without the App Sandbox shares Application Support with the other
  /// apps of the user, so there the folder is under the bundle id.
  static func celautDir() throws -> URL {
    var base = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    #if os(macOS)
      base = base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "org.celaut.superapp", isDirectory: true)
    #endif
    var dir = base.appendingPathComponent("celaut", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try dir.setResourceValues(values)
    return dir
  }

  static func celautDbPath() throws -> String {
    try celautDir().appendingPathComponent("celaut.db").path
  }
}

/// The rules of the links that other apps give to Celaut (`docs/celaut/invite.md` section 6,
/// `docs/celaut/package.md` "From a link"): Foundation only, shared by iOS and macOS.
enum LinkRules {
  /// A `celaut:` link longer than this is cut after one more character, enough for Flutter
  /// to see that it is too long (as `DeepLinkHandler.kt`).
  static let maxCelautLink = 4096

  /// The link to give to `argus/deeplink`, if [url] is an `ergopay:` or a `celaut:` link.
  static func deepLink(_ url: URL) -> String? {
    guard let scheme = url.scheme?.lowercased(), scheme == "ergopay" || scheme == "celaut" else { return nil }
    let link = url.absoluteString
    if scheme == "celaut", link.count > maxCelautLink { return String(link.prefix(maxCelautLink + 1)) }
    return link
  }

  /// The `url` of `celaut://import?url=<the link, encoded>`, if it is an http(s) link.
  static func importLink(_ url: URL) -> String? {
    guard url.scheme?.lowercased() == "celaut", url.host?.lowercased() == "import",
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
      let value = items.first(where: { $0.name == "url" })?.value?.trimmingCharacters(in: .whitespaces)
    else { return nil }
    let lower = value.lowercased()
    return lower.hasPrefix("http://") || lower.hasPrefix("https://") ? value : nil
  }

  /// The uri, the name and the size (-1 if unknown) of a file, as `PackageHandler.describe`.
  static func describe(_ url: URL) -> [String: Any] {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? -1
    let name = url.lastPathComponent.isEmpty ? "package" : url.lastPathComponent
    return ["uri": url.absoluteString, "name": name, "bytes": size]
  }
}
