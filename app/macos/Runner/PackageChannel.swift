import Cocoa
import FlutterMacOS

/// The macOS side of `org.celaut.chatui/package` (`lib/celaut/package_channel.dart`), as
/// `PackageHandler.kt`: pick a `.celaut.bee` file, give a descriptor of it to the core
/// (`openPackage`), or copy it into a private folder with the count of the bytes (`copied`).
/// The uri of a file is its `file://` URL.
final class PackageChannel: NSObject {
  static let channelName = "org.celaut.chatui/package"

  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "org.celaut.chatui.package-copy")
  private let lock = NSLock()
  private var cancelled = false

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with messenger: FlutterBinaryMessenger) -> PackageChannel {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let handler = PackageChannel(channel: channel)
    channel.setMethodCallHandler(handler.handle)
    return handler
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pickPackage":
      pick(result)
    case "openPackage":
      guard let url = Self.fileURL(args["uri"]) else {
        result(FlutterError(code: "uri", message: "not a file", details: nil))
        return
      }
      let fd = open(url.path, O_RDONLY | O_CLOEXEC)
      if fd < 0 {
        result(FlutterError(code: "open", message: String(cString: strerror(errno)), details: nil))
        return
      }
      var answer: [String: Any] = ["fd": Int(fd)]
      if let size = Self.size(of: url) { answer["bytes"] = size }
      result(answer)
    case "copyPackage":
      guard let url = Self.fileURL(args["uri"]) else {
        result(FlutterError(code: "uri", message: "not a file", details: nil))
        return
      }
      copy(url, result)
    case "cancelCopy":
      lock.lock()
      cancelled = true
      lock.unlock()
      result(nil)
    case "isMetered":
      // A Mac rarely runs on mobile data; the app does not ask for the cost of the network.
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pick(_ result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.message = "Choose a .celaut.bee file"
    panel.begin { response in
      guard response == .OK, let url = panel.url else {
        result(nil)
        return
      }
      var answer: [String: Any] = ["uri": url.absoluteString, "name": url.lastPathComponent]
      if let size = Self.size(of: url) { answer["bytes"] = size }
      result(answer)
    }
  }

  private func copy(_ source: URL, _ result: @escaping FlutterResult) {
    lock.lock()
    cancelled = false
    lock.unlock()
    queue.async {
      var target: URL?
      do {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("chatui-import", isDirectory: true)
        // One copy at a time: what an earlier copy left is deleted.
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let to = dir.appendingPathComponent(source.lastPathComponent)
        target = to
        let total = try self.copyBytes(from: source, to: to)
        DispatchQueue.main.async { result(["path": to.path, "bytes": total]) }
      } catch CopyError.cancelled {
        if let to = target { try? FileManager.default.removeItem(at: to) }
        DispatchQueue.main.async { result(FlutterError(code: "cancelled", message: "cancelled", details: nil)) }
      } catch {
        if let to = target { try? FileManager.default.removeItem(at: to) }
        DispatchQueue.main.async { result(FlutterError(code: "copy", message: "\(error)", details: nil)) }
      }
    }
  }

  private enum CopyError: Error {
    case cancelled
  }

  private func copyBytes(from source: URL, to target: URL) throws -> Int {
    let input = try FileHandle(forReadingFrom: source)
    defer { try? input.close() }
    FileManager.default.createFile(atPath: target.path, contents: nil)
    let output = try FileHandle(forWritingTo: target)
    defer { try? output.close() }
    var total = 0
    var lastSent = 0
    while true {
      lock.lock()
      let stop = cancelled
      lock.unlock()
      if stop { throw CopyError.cancelled }
      guard let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty else { break }
      try output.write(contentsOf: chunk)
      total += chunk.count
      if total - lastSent >= 4 << 20 {
        lastSent = total
        let sent = total
        DispatchQueue.main.async { self.channel.invokeMethod("copied", arguments: sent) }
      }
    }
    let sent = total
    DispatchQueue.main.async { self.channel.invokeMethod("copied", arguments: sent) }
    return total
  }

  private static func fileURL(_ value: Any?) -> URL? {
    guard let text = value as? String else { return nil }
    if text.hasPrefix("/") { return URL(fileURLWithPath: text) }
    guard let url = URL(string: text), url.isFileURL else { return nil }
    return url
  }

  private static func size(of url: URL) -> Int? {
    (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
  }
}
