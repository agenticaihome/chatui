import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart' show ExternalLibrary;

import '../bridge/frb_generated.dart';

/// Load the Rust core. On Android and Linux it is `libwallet_ffi.so` (the default of the
/// bridge). On iOS and macOS the core is a static library linked into the app
/// (`app/ios/Flutter/RustCore.xcconfig` with `scripts/build_ios.sh`,
/// `app/macos/Runner/Configs/RustCore.xcconfig` with `scripts/build_macos.sh`): its
/// functions are in the process, not in a file to open (the default of the bridge on iOS
/// looks for a framework).
Future<void> initRustLib() => RustLib.init(
      externalLibrary:
          Platform.isIOS || Platform.isMacOS ? ExternalLibrary.process(iKnowHowToUseIt: true) : null,
    );
