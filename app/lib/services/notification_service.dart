import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import 'deep_link_controller.dart';

/// Local notifications for incoming payments. Nothing leaves the device.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _permissionAsked = false;

  static AndroidNotificationChannel get _channel => AndroidNotificationChannel(
        'argus_payments',
        appL10n.notifyChannelName,
        description: appL10n.notifyChannelDescription,
        importance: Importance.high,
      );

  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: const DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
          macOS: const DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
          // The notification server of the desktop, over D-Bus; the icon is the one of the .deb.
          linux: LinuxInitializationSettings(defaultActionName: 'Open', defaultIcon: ThemeLinuxIcon('org.celaut.superapp')),
        ),
        // A tap while the app runs: the payload names the screen.
        onDidReceiveNotificationResponse: (response) => _openTap(response.payload),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      _ready = true;
    } catch (e) {
      debugPrint('argus: notifications unavailable: $e');
    }
  }

  /// The notification that launched the app, if one did: its tap is
  /// honoured once the home screen is up and the wallet unlocked.
  Future<void> openLaunchTap() async {
    if (!_ready) return;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp == true) {
        _openTap(details!.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('argus: launch notification unreadable: $e');
    }
  }

  static void _openTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    deepLinkController.push('argus://$payload');
  }

  /// Asks once per launch, after the wallet is unlocked (Android 13+, iOS, macOS). On iOS the
  /// notifications come only while the app runs: iOS suspends it in the background.
  Future<void> requestPermission() async {
    if (!_ready || _permissionAsked) return;
    _permissionAsked = true;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
    } catch (_) {}
  }

  Future<void> incomingPayment({
    required int nanoErg,
    required String walletName,
    required bool pending,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: nanoErg.hashCode & 0x7fffffff,
        title: incomingTitle(pending: pending),
        body: appL10n.notifyIncomingBody(formatErg(nanoErg, maxFrac: 4), walletName),
        payload: 'activity',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('argus: notification failed: $e');
    }
  }
}

final notificationService = NotificationService();

String incomingTitle({required bool pending}) =>
    pending ? appL10n.notifyPaymentOnTheWay : appL10n.notifyPaymentReceived;
