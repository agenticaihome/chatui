import Cocoa
import FlutterMacOS

/// What the system opens with the app (`Info.plist`):
///
/// - `celaut:` and `ergopay:` links go to `argus/deeplink`
///   (`lib/services/deep_link_channel.dart`), as from `DeepLinkHandler.kt`;
/// - `.celaut.bee` files (Finder, "Open With", a drop on the Dock icon) go to
///   `org.celaut.chatui/incoming` (`lib/celaut/incoming_package.dart`), as from
///   `IncomingPackageHandler.kt`.
///
/// A link or a file can come before the Dart side listens (the app starts because of it):
/// it waits until Dart asks for it (`getInitialLink`, `takeIncoming`). After that, each one
/// goes to Dart at once.
final class OpenedItemsChannel: NSObject, FlutterAppLifecycleDelegate {
  static let shared = OpenedItemsChannel()

  private static let linkSchemes: Set<String> = ["celaut", "ergopay"]

  private var deepLink: FlutterMethodChannel?
  private var incoming: FlutterMethodChannel?
  private var linkListening = false
  private var fileListening = false
  private var pendingLink: String?
  private var pendingFile: [String: Any]?

  func register(with messenger: FlutterBinaryMessenger) {
    let deepLink = FlutterMethodChannel(name: "argus/deeplink", binaryMessenger: messenger)
    deepLink.setMethodCallHandler { [weak self] call, result in
      guard let self = self, call.method == "getInitialLink" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.linkListening = true
      result(self.pendingLink)
      self.pendingLink = nil
    }
    let incoming = FlutterMethodChannel(name: "org.celaut.chatui/incoming", binaryMessenger: messenger)
    incoming.setMethodCallHandler { [weak self] call, result in
      guard let self = self, call.method == "takeIncoming" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.fileListening = true
      result(self.pendingFile)
      self.pendingFile = nil
    }
    self.deepLink = deepLink
    self.incoming = incoming
  }

  /// `application(_:open:)` of the app delegate, through `FlutterAppDelegate`
  /// (`handleOpenURLs:` of `FlutterAppLifecycleDelegate`).
  func handleOpen(_ urls: [URL]) -> Bool {
    var handled = false
    for url in urls {
      if url.isFileURL {
        handled = true
        openFile(url)
      } else if let scheme = url.scheme?.lowercased(), Self.linkSchemes.contains(scheme) {
        handled = true
        openLink(url.absoluteString)
      }
    }
    if handled { NSApp.activate(ignoringOtherApps: true) }
    return handled
  }

  private func openLink(_ link: String) {
    if linkListening, let channel = deepLink {
      channel.invokeMethod("onLink", arguments: link)
    } else {
      pendingLink = link
    }
  }

  private func openFile(_ url: URL) {
    var file: [String: Any] = ["uri": url.absoluteString, "name": url.lastPathComponent]
    if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
      file["bytes"] = size
    }
    if fileListening, let channel = incoming {
      channel.invokeMethod("incoming", arguments: file)
    } else {
      pendingFile = file
    }
  }
}
