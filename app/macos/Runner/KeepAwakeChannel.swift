import Cocoa
import FlutterMacOS

/// The macOS side of `org.celaut.chatui/conversation` (`lib/celaut/conversation_keep_alive.dart`).
/// On Android the holds run a foreground service; a Mac does not suspend an app in the
/// background, but App Nap slows the timers and the network of an app that is hidden or
/// covered. While a hold is taken, the app runs a `ProcessInfo` activity that turns App Nap off:
///
/// - a launch, a transfer, an import or an answer that the app waits for: `.userInitiated`,
///   which also keeps the Mac from going to sleep when it is idle (the wake lock of Android);
/// - only an open conversation or automatic top-up: `.userInitiatedAllowingIdleSystemSleep`.
///   The Mac can still sleep when it is idle; then nothing of the app runs.
final class KeepAwakeChannel: NSObject {
  static let channelName = "org.celaut.chatui/conversation"

  private static let busyReasons: Set<String> = ["launch", "transfer", "answer", "import"]

  private var activity: NSObjectProtocol?
  private var options: ProcessInfo.ActivityOptions = []
  private var reasons: [String] = []

  static func register(with messenger: FlutterBinaryMessenger) -> KeepAwakeChannel {
    let handler = KeepAwakeChannel()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(handler.handle)
    return handler
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      let args = call.arguments as? [String: Any] ?? [:]
      apply(args["reasons"] as? [String] ?? [])
      result(nil)
    case "stop":
      apply([])
      result(nil)
    case "requestNotificationPermission":
      // No foreground service, so no notification to allow.
      result(nil)
    case "state":
      result(["reasons": reasons, "activity": Self.name(of: options)])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func apply(_ wanted: [String]) {
    reasons = wanted
    var next: ProcessInfo.ActivityOptions = []
    if !wanted.isEmpty {
      next = wanted.contains(where: Self.busyReasons.contains)
        ? .userInitiated
        : .userInitiatedAllowingIdleSystemSleep
    }
    if next == options && (activity != nil) == !next.isEmpty { return }
    let old = activity
    activity = nil
    if !next.isEmpty {
      // The new activity starts before the old one ends: App Nap never comes in between.
      activity = ProcessInfo.processInfo.beginActivity(
        options: next, reason: "Chatui: \(wanted.joined(separator: ", "))")
    }
    if let old = old { ProcessInfo.processInfo.endActivity(old) }
    options = next
  }

  private static func name(of options: ProcessInfo.ActivityOptions) -> String {
    if options.isEmpty { return "none" }
    if options == .userInitiated { return "userInitiated" }
    return "userInitiatedAllowingIdleSystemSleep"
  }
}
