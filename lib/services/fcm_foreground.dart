// lib/services/fcm_foreground.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:eslabon_flutter/services/notification_service.dart';

final _fm = FirebaseMessaging.instance;

Future<void> initFcmForeground() async {
  await _fm.requestPermission();
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage m) async {
  await NotificationService.handleBackgroundMessage(m);
}