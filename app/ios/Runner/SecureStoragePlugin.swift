import Flutter
import LocalAuthentication
import UIKit

/// `com.argus.wallet/secure_storage` on iOS: the port of `SecureStorageHandler.kt`, over the
/// shared `KeychainStore` (`app/darwin`). Each value is an item of the Keychain that is never
/// in a backup and never goes to another device, like the Android `EncryptedSharedPreferences`
/// with `allowBackup="false"`. The first start of an install deletes the items that a former
/// install left (`KeychainStore.claim`), so a deleted app loses its data as on Android.
final class SecureStoragePlugin: NSObject, FlutterPlugin {
  private static let channelName = "com.argus.wallet/secure_storage"
  private static let walletRegistryKey = "wallet_registry"
  // The key of the Celaut database: one for the app, not one per wallet.
  private static let celautDbKey = "celaut_db_key_v1"
  private static let pinGateKey = "pin_gate"
  private static let service = "org.celaut.chatui.secure"
  private static let installedFlag = "org.celaut.chatui.keychain_owner"

  static func register(with registrar: FlutterPluginRegistrar) {
    KeychainStore(service: service).claim(flag: installedFlag)
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SecureStoragePlugin(), channel: channel)
  }

  private let store = KeychainStore(service: SecureStoragePlugin.service)

  private func read(_ key: String) throws -> String? { try store.read(key) }
  private func write(_ key: String, _ value: String) throws { try store.write(key, value) }
  private func remove(_ key: String) throws { try store.remove(key) }
  private func has(_ key: String) throws -> Bool { try store.has(key) }

  private func seedKey(_ walletId: String?) -> String { walletId.map { "seed_\($0)" } ?? "encrypted_seed" }
  private func wrapKey(_ walletId: String?) -> String { walletId.map { "wrap_\($0)" } ?? "wrap_key" }
  private func pinWrapKey(_ walletId: String?) -> String { walletId.map { "pin_\($0)" } ?? "pin_wrap" }

  private func walletIds() throws -> [String] {
    guard let raw = try read(Self.walletRegistryKey), let data = raw.data(using: .utf8),
      let ids = try? JSONSerialization.jsonObject(with: data) as? [String]
    else { return [] }
    return ids
  }

  private func saveWalletIds(_ ids: [String]) throws {
    // A set, as on Android: no order, no duplicate.
    let unique = Array(Set(ids)).sorted()
    let data = try JSONSerialization.data(withJSONObject: unique)
    try write(Self.walletRegistryKey, String(data: data, encoding: .utf8) ?? "[]")
  }

  // MARK: - Calls

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let walletId = args["walletId"] as? String
    do {
      switch call.method {
      case "saveEncryptedSeed":
        guard let json = args["encryptedSeedJson"] as? String, !json.isEmpty else {
          return result(FlutterError(code: "INVALID_ARGS", message: "Missing encryptedSeedJson", details: nil))
        }
        try write(seedKey(walletId), json)
        if let id = walletId { try saveWalletIds(try walletIds() + [id]) }
        result(true)
      case "loadEncryptedSeed":
        result(try read(seedKey(walletId)))
      case "saveWrapKey":
        guard let key = args["wrapKey"] as? String, !key.isEmpty else {
          return result(FlutterError(code: "INVALID_ARGS", message: "Missing wrapKey", details: nil))
        }
        try write(wrapKey(walletId), key)
        result(true)
      case "loadWrapKey":
        result(try read(wrapKey(walletId)))
      case "savePinWrap":
        guard let json = args["pinWrapJson"] as? String, !json.isEmpty else {
          return result(FlutterError(code: "INVALID_ARGS", message: "Missing pinWrapJson", details: nil))
        }
        try write(pinWrapKey(walletId), json)
        result(true)
      case "loadPinWrap":
        result(try read(pinWrapKey(walletId)))
      case "deletePinWrap":
        try remove(pinWrapKey(walletId))
        result(nil)
      case "deleteWrapKey":
        try remove(wrapKey(walletId))
        result(nil)
      case "deleteEncryptedSeed":
        try remove(seedKey(walletId))
        try remove(wrapKey(walletId))
        try remove(pinWrapKey(walletId))
        if let id = walletId { try saveWalletIds(try walletIds().filter { $0 != id }) }
        result(nil)
      case "deleteWallet":
        guard let id = walletId else {
          return result(FlutterError(code: "INVALID_ARGS", message: "Missing walletId", details: nil))
        }
        try remove(seedKey(id))
        try remove(wrapKey(id))
        try remove(pinWrapKey(id))
        try saveWalletIds(try walletIds().filter { $0 != id })
        result(nil)
      case "hasEncryptedSeed":
        if let id = walletId {
          result(try has(seedKey(id)))
        } else {
          result(try has("encrypted_seed") || has(Self.walletRegistryKey))
        }
      case "hasPinWrap":
        result(try has(pinWrapKey(walletId)))
      case "hasWrapKey":
        result(try has(wrapKey(walletId)))
      case "listWalletIds":
        var ids = try walletIds()
        // Migration: if a legacy single-wallet seed exists, add a migration ID.
        if try has("encrypted_seed"), !ids.contains("legacy") { ids.append("legacy") }
        result(ids)
      case "loadCelautDbKey":
        result(try read(Self.celautDbKey))
      case "saveCelautDbKey":
        guard let key = args["key"] as? String, !key.isEmpty else {
          return result(FlutterError(code: "INVALID_ARGS", message: "Missing key", details: nil))
        }
        try write(Self.celautDbKey, key)
        result(nil)
      case "celautDbPath":
        result(try Self.celautDbPath())
      case "loadPinGate":
        var count = 0
        var until: Int64 = 0
        if let raw = try read(Self.pinGateKey), let data = raw.data(using: .utf8),
          let map = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
          count = (map["count"] as? NSNumber)?.intValue ?? 0
          until = (map["until"] as? NSNumber)?.int64Value ?? 0
        }
        result(["count": count, "until": until])
      case "savePinGate":
        let count = (args["count"] as? NSNumber)?.intValue ?? 0
        let until = (args["until"] as? NSNumber)?.int64Value ?? 0
        let data = try JSONSerialization.data(withJSONObject: ["count": count, "until": until])
        try write(Self.pinGateKey, String(data: data, encoding: .utf8) ?? "{}")
        result(nil)
      case "hasBiometric":
        result(Self.canAuthenticateDevice())
      case "authenticateBiometric":
        authenticate(walletId: walletId, result: result)
      case "setSecureFlag":
        // iOS has no FLAG_SECURE: an app cannot block a screenshot or a recording. The app
        // switcher shows a cover instead (LifecyclePlugin). The app tells the user.
        result(false)
      case "migrateLegacyWallet":
        guard let newId = args["newWalletId"] as? String else {
          return result(FlutterError(code: "INVALID_ARGS", message: "Missing newWalletId", details: nil))
        }
        guard let legacySeed = try read("encrypted_seed") else { return result(false) }
        let legacyWrap = try read("wrap_key")
        let legacyPin = try read("pin_wrap")
        try write("seed_\(newId)", legacySeed)
        if let w = legacyWrap { try write("wrap_\(newId)", w) }
        if let p = legacyPin { try write("pin_\(newId)", p) }
        try saveWalletIds(try walletIds() + [newId])
        try remove("encrypted_seed")
        try remove("wrap_key")
        try remove("pin_wrap")
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch let e as KeychainStore.Failure {
      result(FlutterError(code: "STORAGE_ERROR", message: e.message, details: nil))
    } catch {
      result(FlutterError(code: "STORAGE_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  /// The Celaut database (`AppPaths`, shared with macOS).
  static func celautDbPath() throws -> String { try AppPaths.celautDbPath() }

  // MARK: - Device authentication

  /// Face ID or Touch ID, or the passcode of the phone, is set up.
  private static func canAuthenticateDevice() -> Bool {
    var error: NSError?
    return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
  }

  private func authenticate(walletId: String?, result: @escaping FlutterResult) {
    let answer: () -> Void = { [self] in
      do {
        result(try read(wrapKey(walletId)))
      } catch let e as KeychainStore.Failure {
        result(FlutterError(code: "STORAGE_ERROR", message: e.message, details: nil))
      } catch {
        result(FlutterError(code: "STORAGE_ERROR", message: error.localizedDescription, details: nil))
      }
    }
    // A phone with no passcode has nothing to ask: the wallet opens, as on Android.
    guard Self.canAuthenticateDevice() else { return answer() }
    let context = LAContext()
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Celaut") { ok, error in
      DispatchQueue.main.async {
        if ok { return answer() }
        switch (error as? LAError)?.code {
        case .userCancel?, .appCancel?, .systemCancel?:
          result(nil)
        default:
          result(FlutterError(code: "BIOMETRIC", message: error?.localizedDescription, details: nil))
        }
      }
    }
  }
}
