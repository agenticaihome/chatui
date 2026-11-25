import AVFoundation
import CoreLocation
import CoreMotion
import Flutter
import UIKit

/// The axes of the screen as it is shown, from the axes of the phone held upright (x to the
/// right, y up, z out of the glass, as on Android). The rotations are those of
/// `Surface.ROTATION_*` in `MotionHandler.kt`: landscapeRight is ROTATION_90.
private func screenAxes(_ v: (Double, Double, Double)) -> (Double, Double, Double) {
  switch currentOrientation() {
  case .landscapeRight: return (-v.1, v.0, v.2)
  case .portraitUpsideDown: return (-v.0, -v.1, v.2)
  case .landscapeLeft: return (v.1, -v.0, v.2)
  default: return v
  }
}

private func currentOrientation() -> UIInterfaceOrientation {
  if Thread.isMainThread { return orientationNow() }
  return DispatchQueue.main.sync { orientationNow() }
}

private func orientationNow() -> UIInterfaceOrientation {
  let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
  return scene?.interfaceOrientation ?? .portrait
}

/// The motion of the phone for the vehicle motion cues (`lib/services/motion_cues.dart`):
/// the port of `MotionHandler.kt`.
///
/// `argus/motion`: while Dart listens, each sample is `[ax, ay, az, gx, gy, gz, t]`, the
/// acceleration without gravity then gravity in m/s² on the axes of the screen, then the
/// time in seconds. CoreMotion gives them in g with the opposite sign of Android (a phone
/// flat on a table has gravity z = -1 on iOS, +9.81 on Android), so both are multiplied by
/// -9.80665. About 50 Hz, like SENSOR_DELAY_GAME. No permission.
///
/// `argus/speed`: the speed over the ground in m/s from Core Location, once a second at most,
/// while Dart listens. It needs the precise location while the app is in use, which
/// `argus/motion_permission` asks for.
final class MotionPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {
  private static let gravity = 9.80665

  private let motion = CMMotionManager()
  private let locations = CLLocationManager()
  private var motionSink: FlutterEventSink?
  private var speedSink: FlutterEventSink?
  private var pendingPermission: FlutterResult?
  private var lastSpeed = Date.distantPast

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = MotionPlugin()
    plugin.locations.delegate = plugin
    let messenger = registrar.messenger()
    FlutterEventChannel(name: "argus/motion", binaryMessenger: messenger)
      .setStreamHandler(EventStream(listen: plugin.listenMotion, cancel: plugin.cancelMotion))
    FlutterEventChannel(name: "argus/speed", binaryMessenger: messenger)
      .setStreamHandler(EventStream(listen: plugin.listenSpeed, cancel: plugin.cancelSpeed))
    let permission = FlutterMethodChannel(name: "argus/motion_permission", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(plugin, channel: permission)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasLocation": result(hasLocation())
    case "requestLocation": requestLocation(result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Motion

  private func listenMotion(_ events: @escaping FlutterEventSink) -> FlutterError? {
    guard motion.isDeviceMotionAvailable else {
      return FlutterError(code: "no_sensor", message: "This phone has no accelerometer", details: nil)
    }
    motionSink = events
    motion.deviceMotionUpdateInterval = 1.0 / 50
    motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
      guard let self = self, let sink = self.motionSink, let m = data else { return }
      let g = Self.gravity
      let a = screenAxes((-m.userAcceleration.x * g, -m.userAcceleration.y * g, -m.userAcceleration.z * g))
      let gr = screenAxes((-m.gravity.x * g, -m.gravity.y * g, -m.gravity.z * g))
      sink([a.0, a.1, a.2, gr.0, gr.1, gr.2, m.timestamp])
    }
    return nil
  }

  private func cancelMotion() -> FlutterError? {
    motion.stopDeviceMotionUpdates()
    motionSink = nil
    return nil
  }

  // MARK: - Speed

  private func authorization() -> CLAuthorizationStatus {
    if #available(iOS 14.0, *) { return locations.authorizationStatus }
    return CLLocationManager.authorizationStatus()
  }

  /// The precise location while in use (iOS 14 can give an approximate one: no GPS speed).
  private func hasLocation() -> Bool {
    let status = authorization()
    guard status == .authorizedWhenInUse || status == .authorizedAlways else { return false }
    if #available(iOS 14.0, *) { return locations.accuracyAuthorization == .fullAccuracy }
    return true
  }

  private func requestLocation(_ result: @escaping FlutterResult) {
    if hasLocation() { return result(true) }
    // One question at a time: an older one that is still open is answered "no".
    pendingPermission?(false)
    if authorization() == .notDetermined {
      pendingPermission = result
      locations.requestWhenInUseAuthorization()
    } else {
      // iOS asks once; then only the Settings app can change it.
      result(false)
    }
  }

  private func authorizationChanged() {
    guard authorization() != .notDetermined, let pending = pendingPermission else { return }
    pendingPermission = nil
    pending(hasLocation())
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { authorizationChanged() }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    authorizationChanged()
  }

  private func listenSpeed(_ events: @escaping FlutterEventSink) -> FlutterError? {
    guard hasLocation() else {
      return FlutterError(code: "no_permission", message: "The precise location is not allowed", details: nil)
    }
    guard CLLocationManager.locationServicesEnabled() else {
      return FlutterError(code: "no_gps", message: "Location services are off", details: nil)
    }
    speedSink = events
    locations.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    locations.activityType = .automotiveNavigation
    locations.startUpdatingLocation()
    return nil
  }

  private func cancelSpeed() -> FlutterError? {
    locations.stopUpdatingLocation()
    speedSink = nil
    return nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations list: [CLLocation]) {
    guard let sink = speedSink, let last = list.last, last.speed >= 0 else { return }
    // Once a second at most, as the 1000 ms of LocationManager on Android.
    let now = Date()
    if now.timeIntervalSince(lastSpeed) < 1 { return }
    lastSpeed = now
    sink(last.speed)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// A `FlutterStreamHandler` made of two functions.
final class EventStream: NSObject, FlutterStreamHandler {
  private let listen: (@escaping FlutterEventSink) -> FlutterError?
  private let cancel: () -> FlutterError?

  init(listen: @escaping (@escaping FlutterEventSink) -> FlutterError?, cancel: @escaping () -> FlutterError?) {
    self.listen = listen
    self.cancel = cancel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    listen(events)
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? { cancel() }
}

/// The sensors of the cards deck (`docs/celaut/cards.md`, section 13): the port of
/// `CardsSensorsHandler.kt`.
///
/// `argus/cards_device` `caps`: a gyroscope, and the haptics of an iPhone (an iPad has
/// none). `argus/cards_gyro`: the turn rate in rad/s on the axes of the screen, then the
/// time in seconds, about 50 Hz while Dart listens. CoreMotion and Android both turn
/// counterclockwise for a positive rate, on the same axes. `argus/cards_sound` `play`: a
/// short 16-bit mono PCM sound, with the silent switch and the volume of the phone (the
/// ambient audio session). No permission.
final class CardsSensorsPlugin: NSObject, FlutterPlugin {
  private let motion = CMMotionManager()
  private var gyroSink: FlutterEventSink?
  private var players: [AVAudioPlayerBox] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = CardsSensorsPlugin()
    let messenger = registrar.messenger()
    let device = FlutterMethodChannel(name: "argus/cards_device", binaryMessenger: messenger)
    device.setMethodCallHandler { [weak plugin] call, result in
      guard let plugin = plugin else { return result(nil) }
      switch call.method {
      case "caps":
        result([
          "gyroscope": plugin.motion.isGyroAvailable,
          "vibrator": UIDevice.current.userInterfaceIdiom == .phone,
        ])
      default: result(FlutterMethodNotImplemented)
      }
    }
    FlutterEventChannel(name: "argus/cards_gyro", binaryMessenger: messenger)
      .setStreamHandler(EventStream(listen: plugin.listenGyro, cancel: plugin.cancelGyro))
    let sound = FlutterMethodChannel(name: "argus/cards_sound", binaryMessenger: messenger)
    sound.setMethodCallHandler { [weak plugin] call, result in
      guard let plugin = plugin else { return result(false) }
      switch call.method {
      case "play":
        let args = call.arguments as? [String: Any] ?? [:]
        guard let pcm = args["pcm"] as? FlutterStandardTypedData, let rate = args["rate"] as? Int else {
          return result(FlutterError(code: "bad_args", message: "pcm and rate are needed", details: nil))
        }
        let gain = args["gain"] as? Double ?? 1.0
        result(plugin.play(pcm.data, rate: rate, gain: gain))
      default: result(FlutterMethodNotImplemented)
      }
    }
    registrar.publish(plugin)
  }

  private func listenGyro(_ events: @escaping FlutterEventSink) -> FlutterError? {
    guard motion.isDeviceMotionAvailable || motion.isGyroAvailable else {
      return FlutterError(code: "no_sensor", message: "This phone has no gyroscope", details: nil)
    }
    gyroSink = events
    if motion.isDeviceMotionAvailable {
      // The rate of device motion has the bias of the gyroscope removed, like the
      // calibrated TYPE_GYROSCOPE of Android.
      motion.deviceMotionUpdateInterval = 1.0 / 50
      motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
        guard let sink = self?.gyroSink, let m = data else { return }
        let r = screenAxes((m.rotationRate.x, m.rotationRate.y, m.rotationRate.z))
        sink([r.0, r.1, r.2, m.timestamp])
      }
    } else {
      motion.gyroUpdateInterval = 1.0 / 50
      motion.startGyroUpdates(to: .main) { [weak self] data, _ in
        guard let sink = self?.gyroSink, let g = data else { return }
        let r = screenAxes((g.rotationRate.x, g.rotationRate.y, g.rotationRate.z))
        sink([r.0, r.1, r.2, g.timestamp])
      }
    }
    return nil
  }

  private func cancelGyro() -> FlutterError? {
    motion.stopDeviceMotionUpdates()
    motion.stopGyroUpdates()
    gyroSink = nil
    return nil
  }

  /// Play 16-bit mono PCM. False when the phone cannot play it.
  private func play(_ pcm: Data, rate: Int, gain: Double) -> Bool {
    guard !pcm.isEmpty, pcm.count <= 64 * 1024, rate > 0 else { return false }
    players.removeAll { !$0.playing }
    guard let box = AVAudioPlayerBox(wav: Self.wav(pcm, rate: rate), gain: gain) else { return false }
    players.append(box)
    return box.start()
  }

  /// A WAV file in memory around the samples.
  private static func wav(_ pcm: Data, rate: Int) -> Data {
    var d = Data()
    func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
    func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
    d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + pcm.count))
    d.append(contentsOf: Array("WAVE".utf8))
    d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1)
    u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
    d.append(contentsOf: Array("data".utf8)); u32(UInt32(pcm.count))
    d.append(pcm)
    return d
  }
}

/// One short sound and its player, kept until it ends.
final class AVAudioPlayerBox: NSObject, AVAudioPlayerDelegate {
  private let player: AVAudioPlayer
  private(set) var playing = false

  init?(wav: Data, gain: Double) {
    guard let player = try? AVAudioPlayer(data: wav) else { return nil }
    self.player = player
    super.init()
    player.volume = Float(max(0, min(1, gain)))
    player.delegate = self
  }

  func start() -> Bool {
    // Ambient: the silent switch mutes it and other audio goes on, like a system sound.
    try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    playing = player.play()
    return playing
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { playing = false }
}
