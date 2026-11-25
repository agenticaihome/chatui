import Flutter
import UIKit

/// The links and the files that other apps give to Celaut on iOS: the port of
/// `DeepLinkHandler.kt`, `OpenLinkActivity.kt`, `IncomingPackageHandler.kt` and
/// `OpenPackageActivity.kt`.
///
/// - `argus/deeplink`: an `ergopay:` or a `celaut:` link (the URL schemes of Info.plist).
///   The link of the launch is answered by `getInitialLink`; a later one goes through
///   `onLink`. A `celaut:` link longer than 4096 characters is cut after one more
///   character, enough for Flutter to see that it is too long.
/// - `org.celaut.superapp/incoming`: `celaut://import?url=<an http(s) link>` gives
///   `{link: url}`, and a `.celaut.bee` file that the user opens with the app (the
///   document type `org.celaut.bee`) gives `{uri, name, bytes}`; `PackagePlugin` copies it.
///   The item that came before Flutter listened is answered by `takeIncoming`.
///
/// iOS gives both in the scene events: `scene(_:willConnectTo:options:)` at a cold start
/// (the engine replays it to a plugin that registers late) and `scene(_:openURLContexts:)`
/// while the app runs. The deep linking of Flutter is off in Info.plist
/// (`FlutterDeepLinkingEnabled`), as on Android: an unknown route would be a second home.
final class LinksPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private static let deepLinkChannel = "argus/deeplink"
  private static let incomingChannel = "org.celaut.superapp/incoming"

  private var deepLink: FlutterMethodChannel?
  private var incoming: FlutterMethodChannel?
  private var initialLink: String?
  private var pending: [String: Any]?

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = LinksPlugin()
    let messenger = registrar.messenger()
    let deepLink = FlutterMethodChannel(name: deepLinkChannel, binaryMessenger: messenger)
    deepLink.setMethodCallHandler { [weak plugin] call, result in
      guard let plugin = plugin else { return result(nil) }
      switch call.method {
      case "getInitialLink":
        result(plugin.initialLink)
        plugin.initialLink = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let incoming = FlutterMethodChannel(name: incomingChannel, binaryMessenger: messenger)
    incoming.setMethodCallHandler { [weak plugin] call, result in
      guard let plugin = plugin else { return result(nil) }
      switch call.method {
      case "takeIncoming":
        result(plugin.pending)
        plugin.pending = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    plugin.deepLink = deepLink
    plugin.incoming = incoming
    registrar.addSceneDelegate(plugin)
    // Keep the plugin alive with the engine.
    registrar.publish(plugin)
  }

  // MARK: - Scene events

  @objc(scene:willConnectToSession:options:)
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let contexts = connectionOptions?.urlContexts, !contexts.isEmpty else { return false }
    var handled = false
    for context in contexts where receive(context.url, launch: true) { handled = true }
    return handled
  }

  @objc(scene:openURLContexts:)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for context in URLContexts where receive(context.url, launch: false) { handled = true }
    return handled
  }

  // MARK: - Links and files

  /// Give [url] to Flutter if it is one of ours. True if it was.
  private func receive(_ url: URL, launch: Bool) -> Bool {
    if url.isFileURL {
      give(Self.describe(url))
      return true
    }
    if let service = LinkRules.importLink(url) {
      // A link to a service (issue #135): Flutter asks before the download.
      give(["link": service])
      return true
    }
    guard let link = LinkRules.deepLink(url) else { return false }
    if launch || deepLink == nil {
      initialLink = link
    } else {
      deepLink?.invokeMethod("onLink", arguments: link)
    }
    return true
  }

  /// The uri, the name and the size of a file (`LinkRules.describe`). The URL object keeps
  /// the right to read the file (a security-scoped URL of the file picker); the copy finds it
  /// by its string.
  static func describe(_ url: URL) -> [String: Any] {
    PackagePlugin.remember(url)
    return LinkRules.describe(url)
  }

  /// The file or the link waits here until Flutter has it: `incoming` gives it at once if
  /// Flutter listens, and `takeIncoming` gives it after a cold start.
  private func give(_ item: [String: Any]) {
    pending = item
    pendingId += 1
    let id = pendingId
    incoming?.invokeMethod("incoming", arguments: item) { [weak self] answer in
      guard let self = self else { return }
      if answer is FlutterError { return }
      if let o = answer as? NSObject, o === FlutterMethodNotImplemented { return }
      // Flutter has it: it is not given again by `takeIncoming`, unless a newer one came.
      if self.pendingId == id { self.pending = nil }
    }
  }

  private var pendingId = 0
}
