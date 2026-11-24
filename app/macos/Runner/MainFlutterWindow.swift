import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// The channels of the app (the plugins register themselves). Kept for the life of the window.
  private var channels: [NSObject] = []

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // The screens are made for a phone: a tall window, which the user can widen.
    self.setContentSize(NSSize(width: 480, height: 860))
    self.contentMinSize = NSSize(width: 360, height: 560)
    self.center()
    self.title = "Chatui"

    RegisterGeneratedPlugins(registry: flutterViewController)

    let messenger = flutterViewController.engine.binaryMessenger
    channels = [
      SecureStorageChannel.register(with: messenger, window: self),
      PackageChannel.register(with: messenger),
      KeepAwakeChannel.register(with: messenger),
    ]
    OpenedItemsChannel.shared.register(with: messenger)
    // Links and files that the system opens with the app, also the one that starts it: the
    // delegate is in place before the app finishes its launch.
    (NSApp.delegate as? FlutterAppDelegate)?.addApplicationLifecycleDelegate(OpenedItemsChannel.shared)

    super.awakeFromNib()
  }
}
