import Flutter
import UIKit

/// What iOS does in place of the Android foreground service (`ConversationService.kt`).
///
/// iOS suspends the app a few seconds after it goes to the background: the Tor circuits,
/// the tunnels and the gRPC streams stop, and the app uses no background mode in this phase
/// (`docs/ios.md`). When the scene goes to the background, this plugin asks iOS for a short
/// background task and calls `suspend` on `org.celaut.chatui/lifecycle`: Dart ends its chat
/// streams cleanly (`AppSuspension`), then answers, and the task ends. iOS gives the task
/// about 30 seconds; the plugin ends it after [limit] anyway. When the app comes back, Dart
/// reconnects and reads what it missed (`AppLifecycleState.resumed`).
///
/// The app switcher shows a plain cover instead of the screen: iOS has no FLAG_SECURE, and
/// the screen can show balances or a recovery phrase.
final class LifecyclePlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private static let channelName = "org.celaut.chatui/lifecycle"
  /// The longest time that the app keeps itself awake to close its sessions.
  private static let limit: TimeInterval = 8

  private var channel: FlutterMethodChannel?
  private var task: UIBackgroundTaskIdentifier = .invalid
  private var cover: UIView?

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = LifecyclePlugin()
    plugin.channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addSceneDelegate(plugin)
    registrar.publish(plugin)
  }

  @objc(sceneDidEnterBackground:)
  func sceneDidEnterBackground(_ scene: UIScene) {
    showCover(on: scene)
    beginClosing()
  }

  @objc(sceneWillEnterForeground:)
  func sceneWillEnterForeground(_ scene: UIScene) {
    hideCover()
    endClosing()
  }

  // MARK: - Closing the sessions

  private func beginClosing() {
    guard task == .invalid, let channel = channel else { return }
    task = UIApplication.shared.beginBackgroundTask(withName: "Close the Celaut sessions") { [weak self] in
      self?.endClosing()
    }
    channel.invokeMethod("suspend", arguments: nil) { [weak self] _ in
      self?.endClosing()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.limit) { [weak self] in
      self?.endClosing()
    }
  }

  private func endClosing() {
    guard task != .invalid else { return }
    UIApplication.shared.endBackgroundTask(task)
    task = .invalid
  }

  // MARK: - Cover of the app switcher

  private func showCover(on scene: UIScene) {
    guard cover == nil, let window = (scene as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })
      ?? (scene as? UIWindowScene)?.windows.first
    else { return }
    let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    view.frame = window.bounds
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(view)
    cover = view
  }

  private func hideCover() {
    cover?.removeFromSuperview()
    cover = nil
  }
}
