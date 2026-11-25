import Cocoa
import FlutterMacOS
import LocalAuthentication

/// The macOS side of `com.argus.wallet/secure_storage` (`lib/services/secure_storage.dart`),
/// with the same methods and the same names of the values as `SecureStorageHandler.kt`.
///
/// The values live in ONE item of the login keychain (a JSON object), not one item per value.
/// The app has no Apple signature: the signature of each build is ad hoc, so the keychain
/// does not know a new version of the app as the same app. After an update, macOS asks the
/// user once for the password of the keychain ("Always Allow"), for the one item. The data
/// protection keychain needs an Apple team (keychain-access-groups), so it is not used.
/// The keychain calls and the folder of the Celaut database are shared with the iOS app
/// (`app/darwin`: `KeychainStore`, `AppPaths`).
final class SecureStorageChannel: NSObject {
  static let channelName = "com.argus.wallet/secure_storage"

  private static let account = "secure-store-v1"
  private static let walletRegistry = "wallet_registry"
  private static let celautDbKey = "celaut_db_key_v1"

  private let queue = DispatchQueue(label: "org.celaut.superapp.secure-storage")
  private let keychain = KeychainStore(service: "org.celaut.superapp", label: "Celaut wallet keys")
  private weak var window: NSWindow?

  init(window: NSWindow?) {
    self.window = window
  }

  static func register(with messenger: FlutterBinaryMessenger, window: NSWindow?) -> SecureStorageChannel {
    let handler = SecureStorageChannel(window: window)
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler(handler.handle)
    return handler
  }

  // MARK: The store

  private struct StoreError: Error {
    let message: String
  }

  private func load() throws -> [String: Any] {
    let text: String?
    do {
      text = try keychain.read(Self.account)
    } catch let failure as KeychainStore.Failure {
      throw StoreError(message: "keychain read failed: \(failure.status) \(failure.message)")
    }
    guard let text = text else { return [:] }
    guard let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
      throw StoreError(message: "the keychain item is not a JSON object")
    }
    return object
  }

  private func save(_ values: [String: Any]) throws {
    let data = try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
    do {
      try keychain.write(Self.account, String(decoding: data, as: UTF8.self))
    } catch let failure as KeychainStore.Failure {
      throw StoreError(message: "keychain write failed: \(failure.status) \(failure.message)")
    }
  }

  private static func seedKey(_ id: String?) -> String { id.map { "seed_\($0)" } ?? "encrypted_seed" }
  private static func wrapKey(_ id: String?) -> String { id.map { "wrap_\($0)" } ?? "wrap_key" }
  private static func pinWrapKey(_ id: String?) -> String { id.map { "pin_\($0)" } ?? "pin_wrap" }

  private static func walletIds(_ values: [String: Any]) -> [String] {
    values[walletRegistry] as? [String] ?? []
  }

  private static func setWalletIds(_ ids: [String], in values: inout [String: Any]) {
    values[walletRegistry] = Array(Set(ids)).sorted()
  }

  // MARK: The calls

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let walletId = args["walletId"] as? String
    switch call.method {
    case "hasBiometric":
      result(Self.canAuthenticate())
      return
    case "authenticateBiometric":
      authenticate(walletId: walletId, result: result)
      return
    case "setSecureFlag":
      let enable = args["enable"] as? Bool ?? true
      // The macOS equal of FLAG_SECURE: the window is left out of screenshots, screen
      // recordings and screen sharing.
      window?.sharingType = enable ? .none : .readOnly
      result(window != nil)
      return
    case "celautDbPath":
      do {
        result(try AppPaths.celautDbPath())
      } catch {
        result(FlutterError(code: "STORAGE_ERROR", message: "\(error)", details: nil))
      }
      return
    default:
      break
    }
    queue.async {
      let answer: Any?
      do {
        answer = try self.storeCall(call.method, args: args, walletId: walletId)
      } catch let error as StoreError {
        answer = FlutterError(code: "STORAGE_ERROR", message: error.message, details: nil)
      } catch {
        answer = FlutterError(code: "STORAGE_ERROR", message: "\(error)", details: nil)
      }
      DispatchQueue.main.async { result(answer) }
    }
  }

  /// The calls that read or write the store. Runs on [queue]: a read can wait for the
  /// password prompt of the keychain.
  private func storeCall(_ method: String, args: [String: Any], walletId: String?) throws -> Any? {
    func missing(_ name: String) -> FlutterError {
      FlutterError(code: "INVALID_ARGS", message: "Missing \(name)", details: nil)
    }
    switch method {
    case "saveEncryptedSeed":
      guard let json = args["encryptedSeedJson"] as? String, !json.isEmpty else { return missing("encryptedSeedJson") }
      var values = try load()
      values[Self.seedKey(walletId)] = json
      if let id = walletId { Self.setWalletIds(Self.walletIds(values) + [id], in: &values) }
      try save(values)
      return true
    case "loadEncryptedSeed":
      return try load()[Self.seedKey(walletId)] as? String
    case "saveWrapKey":
      guard let key = args["wrapKey"] as? String, !key.isEmpty else { return missing("wrapKey") }
      var values = try load()
      values[Self.wrapKey(walletId)] = key
      try save(values)
      return true
    case "loadWrapKey":
      return try load()[Self.wrapKey(walletId)] as? String
    case "savePinWrap":
      guard let json = args["pinWrapJson"] as? String, !json.isEmpty else { return missing("pinWrapJson") }
      var values = try load()
      values[Self.pinWrapKey(walletId)] = json
      try save(values)
      return true
    case "loadPinWrap":
      return try load()[Self.pinWrapKey(walletId)] as? String
    case "deletePinWrap":
      var values = try load()
      values.removeValue(forKey: Self.pinWrapKey(walletId))
      try save(values)
      return nil
    case "deleteWrapKey":
      var values = try load()
      values.removeValue(forKey: Self.wrapKey(walletId))
      try save(values)
      return nil
    case "deleteEncryptedSeed":
      var values = try load()
      for key in [Self.seedKey(walletId), Self.wrapKey(walletId), Self.pinWrapKey(walletId)] {
        values.removeValue(forKey: key)
      }
      if let id = walletId { Self.setWalletIds(Self.walletIds(values).filter { $0 != id }, in: &values) }
      try save(values)
      return nil
    case "deleteWallet":
      guard let id = walletId else { return missing("walletId") }
      var values = try load()
      for key in [Self.seedKey(id), Self.wrapKey(id), Self.pinWrapKey(id)] {
        values.removeValue(forKey: key)
      }
      Self.setWalletIds(Self.walletIds(values).filter { $0 != id }, in: &values)
      try save(values)
      return nil
    case "hasEncryptedSeed":
      let values = try load()
      if let id = walletId { return values[Self.seedKey(id)] != nil }
      return values["encrypted_seed"] != nil || values[Self.walletRegistry] != nil
    case "hasPinWrap":
      return try load()[Self.pinWrapKey(walletId)] != nil
    case "hasWrapKey":
      return try load()[Self.wrapKey(walletId)] != nil
    case "listWalletIds":
      let values = try load()
      var ids = Self.walletIds(values)
      if values["encrypted_seed"] != nil && !ids.contains("legacy") { ids.append("legacy") }
      return ids
    case "loadCelautDbKey":
      return try load()[Self.celautDbKey] as? String
    case "saveCelautDbKey":
      guard let key = args["key"] as? String, !key.isEmpty else { return missing("key") }
      var values = try load()
      values[Self.celautDbKey] = key
      try save(values)
      return nil
    case "loadPinGate":
      let values = try load()
      return [
        "count": (values["pin_fail_count"] as? NSNumber)?.intValue ?? 0,
        "until": (values["pin_lock_until"] as? NSNumber)?.int64Value ?? 0,
      ]
    case "savePinGate":
      var values = try load()
      values["pin_fail_count"] = (args["count"] as? NSNumber)?.intValue ?? 0
      values["pin_lock_until"] = (args["until"] as? NSNumber)?.int64Value ?? 0
      try save(values)
      return nil
    case "migrateLegacyWallet":
      guard let newId = args["newWalletId"] as? String else { return missing("newWalletId") }
      var values = try load()
      guard let seed = values["encrypted_seed"] else { return false }
      values["seed_\(newId)"] = seed
      if let wrap = values["wrap_key"] { values["wrap_\(newId)"] = wrap }
      if let pin = values["pin_wrap"] { values["pin_\(newId)"] = pin }
      for key in ["encrypted_seed", "wrap_key", "pin_wrap"] { values.removeValue(forKey: key) }
      Self.setWalletIds(Self.walletIds(values) + [newId], in: &values)
      try save(values)
      return true
    default:
      return FlutterMethodNotImplemented
    }
  }

  // MARK: Touch ID or the password of the Mac

  /// Touch ID, or the password of the user of the Mac. A Mac always has the password.
  private static func canAuthenticate() -> Bool {
    LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
  }

  private func authenticate(walletId: String?, result: @escaping FlutterResult) {
    let context = LAContext()
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
      // Nothing to ask (as on a phone with no screen lock): the wallet opens.
      queue.async {
        let answer: Any?
        do {
          answer = try self.load()[Self.wrapKey(walletId)] as? String
        } catch {
          answer = FlutterError(code: "STORAGE_ERROR", message: "\(error)", details: nil)
        }
        DispatchQueue.main.async { result(answer) }
      }
      return
    }
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "unlock the wallet") { ok, error in
      guard ok else {
        let code = (error as? LAError)?.code
        let cancelled = code == .userCancel || code == .appCancel || code == .systemCancel
        DispatchQueue.main.async {
          if cancelled {
            result(nil)
          } else {
            result(FlutterError(code: "BIOMETRIC", message: error?.localizedDescription ?? "failed", details: nil))
          }
        }
        return
      }
      self.queue.async {
        let answer: Any?
        do {
          answer = try self.load()[Self.wrapKey(walletId)] as? String
        } catch {
          answer = FlutterError(code: "STORAGE_ERROR", message: "\(error)", details: nil)
        }
        DispatchQueue.main.async { result(answer) }
      }
    }
  }
}
