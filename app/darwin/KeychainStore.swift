import Foundation
import Security

/// The secrets of the app in the Keychain: Foundation and Security only, no Flutter, so the
/// iOS app (`app/ios`) and the macOS app (`app/macos`) share it. Each value is a generic
/// password item of [service]. On iOS its access is `AfterFirstUnlockThisDeviceOnly`: never
/// in a backup, never on another device. On macOS the item is in the login keychain, which
/// has no such access: the data protection keychain needs an Apple team, and the app has none.
///
/// The Keychain outlives the app: an item stays after the app is deleted, while on Android
/// the data goes with the app. [claim] deletes, once per install, the items that a former
/// install left. A new sideload of the same Apple ID (every 7 days with a free account) is
/// not a new install: its UserDefaults stay, and so do the items.
final class KeychainStore {
  struct Failure: Error {
    let status: OSStatus
    var message: String {
      (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)"
    }
  }

  let service: String

  /// The name of the items in Keychain Access, and in the password prompt of macOS. Without
  /// it, macOS shows [service].
  let label: String?

  init(service: String, label: String? = nil) {
    self.service = service
    self.label = label
  }

  /// Delete the items of a former install, once per install ([flag] in UserDefaults).
  func claim(flag: String) {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: flag) { return }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]
    SecItemDelete(query as CFDictionary)
    defaults.set(true, forKey: flag)
  }

  private func query(_ key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
  }

  func read(_ key: String) throws -> String? {
    var q = query(key)
    q[kSecReturnData as String] = true
    q[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(q as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else { throw Failure(status: status) }
    return String(data: data, encoding: .utf8)
  }

  func write(_ key: String, _ value: String) throws {
    var attributes: [String: Any] = [kSecValueData as String: Data(value.utf8)]
    #if os(iOS)
      attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    #endif
    var status = SecItemUpdate(query(key) as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var add = query(key)
      add.merge(attributes) { _, new in new }
      if let label { add[kSecAttrLabel as String] = label }
      status = SecItemAdd(add as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw Failure(status: status) }
  }

  func remove(_ key: String) throws {
    let status = SecItemDelete(query(key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
  }

  func has(_ key: String) throws -> Bool { try read(key) != nil }
}
