import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class DevicePushService {
  DevicePushService(this.api, this.userId, this.navigate);
  final ApiService api;
  final int userId;
  final void Function(String) navigate;
  static const channel = MethodChannel('sqs/notifications');
  final List<StreamSubscription<dynamic>> subscriptions = [];
  bool disposed = false;
  Future<void> open(Map<String, dynamic> data) async {
    if (disposed || data['user_id'] != '$userId') return;
    if (data['mark_read'] == 'true') {
      final id = int.tryParse('${data['notification_id']}');
      if (id != null) {
        try {
          await api.post('/notifications/$id/read', {});
          await channel.invokeMethod('cancel', {'notification_id': '$id'});
        } catch (_) {
          debugPrint(
            'Read status could not be saved; opening Alerts to retry.',
          );
        }
      }
      if (!disposed) navigate('Alerts');
      return;
    }
    navigate(
      ['My Queue', 'Verify'].contains(data['destination'])
          ? data['destination'] as String
          : 'Alerts',
    );
  }

  Future<void> register(String token) async {
    if (disposed) return;
    try {
      await api.post('/push/device', {'token': token});
    } catch (_) {
      debugPrint(
        'Device notification registration will retry when the app resumes.',
      );
    }
  }

  Future<void> start() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        Firebase.apps.isEmpty) {
      return;
    }
    try {
      await channel.invokeMethod('initialize');
      channel.setMethodCallHandler((call) async {
        if (call.method == 'open' && call.arguments is Map) {
          open(Map<String, dynamic>.from(call.arguments));
        }
      });
      final permission = await FirebaseMessaging.instance.requestPermission();
      if (disposed ||
          permission.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen(register),
      );
      subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((m) => open(m.data)),
      );
      subscriptions.add(
        FirebaseMessaging.onMessage.listen((m) async {
          if (disposed || m.data['user_id'] != '$userId') return;
          try {
            await channel.invokeMethod('show', {
              ...m.data,
              'title': m.notification?.title ?? m.data['title'] ?? 'SQS update',
              'body':
                  m.notification?.body ??
                  m.data['body'] ??
                  'Open SQS to view your update.',
            });
          } catch (_) {
            debugPrint('Unable to display device notification.');
          }
        }),
      );
      await refreshToken();
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) open(initial.data);
      final local = await channel.invokeMapMethod<String, dynamic>('initial');
      if (local != null) open(local);
    } catch (_) {
      debugPrint('Device notifications could not initialize.');
    }
  }

  Future<void> refreshToken() async {
    if (disposed ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        Firebase.apps.isEmpty) {
      return;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await register(token);
    } catch (_) {
      debugPrint('Device notification token not available yet.');
    }
  }

  void dispose() {
    disposed = true;
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        Firebase.apps.isNotEmpty) {
      channel.setMethodCallHandler(null);
      channel.invokeMethod('clear').catchError((_) => null);
    }
  }
}
