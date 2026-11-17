import Flutter
import Network
import UIKit

/// `org.celaut.chatui/package` on iOS: the port of `PackageHandler.kt`.
///
/// The user picks a `.celaut.bee` file in the Files app (`pickPackage`, which answers with
/// its uri, name and size), then the app copies it into a private folder with a stream and
/// tells Flutter its bytes (`copied`) until it ends or `cancelCopy` stops it. `openPackage`
/// gives a file descriptor instead, for the setting "Do not keep the filesystem of a
/// service": Rust reads the file where it is and closes the descriptor. `isMetered` is true
/// on a cellular or a Low Data network.
final class PackagePlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private static let channelName = "org.celaut.chatui/package"
  /// The time between two counts of the copy that go to Flutter.
  private static let reportEvery: TimeInterval = 0.1

  private weak var registrar: FlutterPluginRegistrar?
  private var channel: FlutterMethodChannel?
  private var pendingPick: FlutterResult?
  private let cancelled = Cancelled()
  private let monitor = NWPathMonitor()
  private var expensive = false

  /// The files that the picker or another app gave: a security-scoped URL keeps the right to
  /// read its file only as the same object.
  private static var known: [String: URL] = [:]
  private static let knownLock = NSLock()

  static func remember(_ url: URL) {
    knownLock.lock()
    known[url.absoluteString] = url
    knownLock.unlock()
  }

  private static func url(of uri: String) -> URL? {
    knownLock.lock()
    defer { knownLock.unlock() }
    return known[uri] ?? URL(string: uri)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = PackagePlugin()
    plugin.registrar = registrar
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    plugin.channel = channel
    registrar.addMethodCallDelegate(plugin, channel: channel)
    plugin.monitor.pathUpdateHandler = { [weak plugin] path in
      let value = path.isExpensive || path.isConstrained
      DispatchQueue.main.async { plugin?.expensive = value }
    }
    plugin.monitor.start(queue: DispatchQueue(label: "org.celaut.chatui.network"))
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pickPackage":
      pick(result)
    case "copyPackage":
      copyInBackground(args["uri"] as? String, result)
    case "openPackage":
      openInBackground(args["uri"] as? String, result)
    case "cancelCopy":
      cancelled.set(true)
      result(nil)
    case "isMetered":
      result(expensive)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Pick

  private func pick(_ result: @escaping FlutterResult) {
    // One question at a time: an older one that is still open gets no file.
    pendingPick?(nil)
    pendingPick = result
    guard let host = registrar?.viewController else {
      pendingPick = nil
      return result(FlutterError(code: "no_picker", message: "no view controller", details: nil))
    }
    // Any type: a .celaut.bee file from another device has no type that iOS knows. The file
    // is opened where it is, not copied by the picker: a service can be large.
    let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .open)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    host.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingPick else { return }
    pendingPick = nil
    guard let url = urls.first else { return result(nil) }
    // The provider of the file gives its size: not on the main thread.
    DispatchQueue.global(qos: .userInitiated).async {
      let chosen = LinksPlugin.describe(url)
      DispatchQueue.main.async { result(chosen) }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingPick?(nil)
    pendingPick = nil
  }

  // MARK: - Copy

  private final class Cancelled {
    private let lock = NSLock()
    private var value = false
    func set(_ v: Bool) { lock.lock(); value = v; lock.unlock() }
    func get() -> Bool { lock.lock(); defer { lock.unlock() }; return value }
  }

  private struct CopyCancelled: Error {}

  private func copyInBackground(_ uri: String?, _ result: @escaping FlutterResult) {
    guard let uri = uri, let url = Self.url(of: uri) else {
      return result(FlutterError(code: "copy_failed", message: "the call has no uri", details: nil))
    }
    cancelled.set(false)
    // The copy reads and writes the disk: not on the main thread.
    DispatchQueue.global(qos: .userInitiated).async { [self] in
      do {
        let copied = try copy(url)
        DispatchQueue.main.async { result(copied) }
      } catch is CopyCancelled {
        DispatchQueue.main.async {
          result(FlutterError(code: "cancelled", message: "the copy was cancelled", details: nil))
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "copy_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  /// The folder of the copies: next to the Celaut database, out of the backups and out of
  /// the caches (iOS clears them when the storage is low). One copy at a time: what is in it
  /// is left from a copy that stopped.
  private static func incomingFolder() throws -> URL {
    let db = URL(fileURLWithPath: try SecureStoragePlugin.celautDbPath())
    let folder = db.deletingLastPathComponent().appendingPathComponent("packages/incoming", isDirectory: true)
    let fm = FileManager.default
    if let old = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
      for f in old { try? fm.removeItem(at: f) }
    }
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
  }

  /// A file that another app gave with "Open in" is a copy in Documents/Inbox, which is ours:
  /// it is moved, not copied again.
  private static func isInbox(_ url: URL) -> Bool {
    guard url.isFileURL,
      let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    else { return false }
    let inbox = documents.appendingPathComponent("Inbox").standardizedFileURL.path
    return url.standardizedFileURL.path.hasPrefix(inbox + "/")
  }

  private func copy(_ source: URL) throws -> [String: Any] {
    let folder = try Self.incomingFolder()
    let target = folder.appendingPathComponent("picked-\(Int64(Date().timeIntervalSince1970 * 1000)).bee")
    let fm = FileManager.default
    if Self.isInbox(source) {
      try fm.moveItem(at: source, to: target)
      let bytes = (try? fm.attributesOfItem(atPath: target.path)[.size] as? NSNumber)?.int64Value ?? 0
      report(bytes)
      return ["path": target.path, "bytes": bytes]
    }
    let scoped = source.startAccessingSecurityScopedResource()
    defer { if scoped { source.stopAccessingSecurityScopedResource() } }
    guard let input = InputStream(url: source) else {
      throw NSError(domain: "chatui", code: 1, userInfo: [NSLocalizedDescriptionKey: "the file cannot be opened"])
    }
    guard fm.createFile(atPath: target.path, contents: nil), let output = FileHandle(forWritingAtPath: target.path)
    else {
      throw NSError(domain: "chatui", code: 2, userInfo: [NSLocalizedDescriptionKey: "the copy cannot be written"])
    }
    input.open()
    var total: Int64 = 0
    var reported = Date.distantPast
    do {
      defer {
        input.close()
        output.closeFile()
      }
      var buffer = [UInt8](repeating: 0, count: 1 << 16)
      while true {
        if cancelled.get() { throw CopyCancelled() }
        let n = input.read(&buffer, maxLength: buffer.count)
        if n < 0 { throw input.streamError ?? NSError(domain: "chatui", code: 3) }
        if n == 0 { break }
        output.write(Data(buffer[0..<n]))
        total += Int64(n)
        if Date().timeIntervalSince(reported) >= Self.reportEvery {
          reported = Date()
          report(total)
        }
      }
      report(total)
    } catch {
      try? fm.removeItem(at: target)
      throw error
    }
    return ["path": target.path, "bytes": total]
  }

  /// Tell Flutter the bytes that the copy wrote so far.
  private func report(_ bytes: Int64) {
    DispatchQueue.main.async { [weak self] in self?.channel?.invokeMethod("copied", arguments: bytes) }
  }

  // MARK: - Open

  /// A file descriptor of the chosen file, with no copy. Rust takes it and closes it. An
  /// error makes Flutter copy the file as before.
  private func openInBackground(_ uri: String?, _ result: @escaping FlutterResult) {
    guard let uri = uri, let url = Self.url(of: uri), url.isFileURL else {
      return result(FlutterError(code: "open_failed", message: "the call has no file uri", details: nil))
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      let fd = open(url.path, O_RDONLY)
      if fd < 0 {
        let message = String(cString: strerror(errno))
        return DispatchQueue.main.async {
          result(FlutterError(code: "open_failed", message: message, details: nil))
        }
      }
      var info = stat()
      let size: Int64 = fstat(fd, &info) == 0 ? Int64(info.st_size) : -1
      DispatchQueue.main.async { result(["fd": Int(fd), "bytes": size]) }
    }
  }
}
