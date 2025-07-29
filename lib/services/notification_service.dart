import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:eslabon_flutter/models/notification_model.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  GoRouter? _router;

  NotificationService();

  void setRouter(GoRouter router) {
    _router = router;
    debugPrint('GoRouter set in NotificationService');
  }

  Future<void> initialize() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    String? token = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification!.title}');
      }
      // handleMessage(message); // Puedes descomentar si quieres manejar la navegación en foreground
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message opened app from background: ${message.data}');
      handleMessage(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('App opened from terminated state: ${message.data}');
        handleMessage(message);
      }
    });
  }

  void handleMessage(RemoteMessage message) {
    if (_router == null) {
      debugPrint('Error: GoRouter not set in NotificationService.');
      return;
    }

    final data = message.data;
    final notificationType = data['type'];
    final requestId = data['requestId'];
    final helperId = data['helperId'];
    final requesterId = data['requesterId'];

    debugPrint('Handling message type: $notificationType');

    switch (notificationType) {
      case 'new_offer':
        if (requestId != null) {
          _router!.go('/request-detail/$requestId');
        }
        break;
      case 'offer_accepted':
        if (requestId != null && helperId != null) {
          _router!.go('/rate-offer/$requestId/$helperId');
        }
        break;
      case 'rating_received':
        if (requesterId != null) {
          _router!.go('/rate-requester/$requesterId');
        }
        break;
      case 'request_completed':
        if (requestId != null) {
          _router!.go('/rate-helper/$requestId');
        }
        break;
      default:
        _router!.go('/notifications');
        break;
    }
  }
}