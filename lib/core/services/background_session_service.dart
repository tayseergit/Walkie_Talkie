import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

class BackgroundSessionService {
  BackgroundSessionService._();
  static final BackgroundSessionService instance = BackgroundSessionService._();

  static const String _channelId = 'walkie_talkie_foreground';
  static const int _notificationId = 1107;

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: false,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'Walkie_Talkie',
        initialNotificationContent: 'Maintaining walkie-talkie session',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );

    _initialized = true;
  }

  Future<void> startSession() async {
    await initialize();
    final running = await _service.isRunning();
    if (!running) {
      await _service.startService();
    }
    _service.invoke('session_started');
  }

  Future<void> stopSession() async {
    final running = await _service.isRunning();
    if (running) {
      _service.invoke('stop_service');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: 'Walkie_Talkie',
        content: 'Walkie-talkie session running in background',
      );
    }

    service.on('session_started').listen((_) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Walkie_Talkie',
          content: 'Signaling and voice session active',
        );
      }
    });

    service.on('stop_service').listen((_) {
      service.stopSelf();
    });

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      final running = await service.isServiceRunning();
      if (!running) {
        timer.cancel();
        return;
      }
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Walkie_Talkie',
          content: 'Maintaining signaling and call session',
        );
      }
    });
  }
}
