import Flutter
import UIKit

/// The platform channels of the app on iOS. Each one is the port of an Android handler of
/// `app/android/app/src/main/kotlin/org/celaut/chatui`, with the same channel name, methods
/// and answers, so the Dart side does not change (`docs/ios.md`). Two Android parts have no
/// port: the in-app update (`UpdateChannel.supported` is false on iOS) and the foreground
/// service (`ForegroundHolds` does nothing on iOS; see `LifecyclePlugin`).
enum ChatuiPlugins {
  static func register(with registry: FlutterPluginRegistry) {
    let plugins: [(String, (FlutterPluginRegistrar) -> Void)] = [
      ("ChatuiSecureStorage", SecureStoragePlugin.register(with:)),
      ("ChatuiLinks", LinksPlugin.register(with:)),
      ("ChatuiPackage", PackagePlugin.register(with:)),
      ("ChatuiMotion", MotionPlugin.register(with:)),
      ("ChatuiCardsSensors", CardsSensorsPlugin.register(with:)),
      ("ChatuiLifecycle", LifecyclePlugin.register(with:)),
    ]
    for (name, register) in plugins {
      if let registrar = registry.registrar(forPlugin: name) {
        register(registrar)
      }
    }
  }
}
