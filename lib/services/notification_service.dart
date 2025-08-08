// lib/services/notification_service.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GoRouter _router;

  NotificationService({required GoRouter appRouter}) : _router = appRouter;

  Future<void> initialize() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      FirebaseMessaging.onMessage.listen(_handleMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
      
      const androidInitializationSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings =
          InitializationSettings(android: androidInitializationSettings);
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          if (response.payload != null) {
            handleNotificationNavigation(jsonDecode(response.payload!));
          }
        },
      );
    }
  }

  void _handleMessage(RemoteMessage message) {
    if (message.notification != null) {
      _showNotification(message);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    handleNotificationNavigation(data);
  }

  void handleNotificationNavigation(Map<String, dynamic> data) {
    print('DEBUG NOTIFICATION DATA: $data');

    final notificationType = data['notificationType'] ?? data['type'] ?? data['data']?['type'];
    final requestId = data['data']?['requestId'] as String?;
    final helperId = data['data']?['helperId'] as String?;
    final helperName = data['data']?['helperName'] as String?;
    final requesterId = data['data']?['requesterId'] as String?;
    final requesterName = data['data']?['requesterName'] as String?;
    final chatPartnerId = data['chatPartnerId'] ?? data['data']?['chatPartnerId'];
    final chatPartnerName = data['chatPartnerName'] ?? data['data']?['chatPartnerName'];
    final chatRoomId = data['chatRoomId'] ?? data['data']?['chatRoomId'];
    final chatPartnerAvatar = data['chatPartnerAvatar'] ?? data['data']?['chatPartnerAvatar'];
    final userId = data['userId'] ?? data['data']?['userId'] as String?;
    final userName = data['userName'] ?? data['data']?['userName'] as String?;
    final messageText = data['notification']?['body'] as String?;

    // ✅ CORRECCIÓN: Manejar primero las notificaciones específicas con un switch.
    switch (notificationType) {
      case 'offer_received':
        if (requestId != null && helperId != null && helperName != null) {
          _router.pushNamed(
            'rate-helper',
            pathParameters: {'requestId': requestId},
            extra: {
              'helperId': helperId,
              'helperName': helperName,
            },
          );
        }
        break;
      case 'helper_rated':
        if (requestId != null && requesterId != null && requesterName != null) {
          _router.pushNamed(
            'rate-requester',
            pathParameters: {'requestId': requestId},
            extra: {
              'requesterId': requesterId,
              'requesterName': requesterName,
            },
          );
        }
        break;
      case 'requester_rated':
        if (helperId != null && helperName != null) {
          _router.goNamed(
            'user_profile_view',
            pathParameters: {'userId': helperId},
            extra: {
              'userName': helperName,
              'message': 'Te ha calificado con ${data['data']?['rating']} estrellas.',
            },
          );
        }
        break;
      case 'chat_message':
        if (chatRoomId != null && chatPartnerId != null && chatPartnerName != null) {
          _router.pushNamed(
            'chat',
            pathParameters: {'chatId': chatRoomId},
            extra: {
              'chatPartnerId': chatPartnerId,
              'chatPartnerName': chatPartnerName,
              'chatPartnerAvatar': chatPartnerAvatar,
            },
          );
        }
        break;
      case 'panic_alert':
        if (userId != null && userName != null && messageText != null) {
            _router.pushNamed(
                'user_profile_view',
                pathParameters: {'userId': userId},
                extra: {
                  'userName': userName,
                  'message': messageText,
                },
            );
        }
        break;
      default:
        // ✅ CORRECCIÓN: Si no hay un tipo específico, entonces se usa la navegación genérica.
        final navigationPath = data['navigationPath'] ?? data['data']?['navigationPath'];
        if (navigationPath != null) {
          _router.go(navigationPath);
          return;
        }
        _router.go('/main');
        break;
    }
  }

  void _showNotification(RemoteMessage message) async {
    final notification = message.notification;
    final String soundFile = message.data['sound'] ?? 'default';

    final androidDetails = AndroidNotificationDetails(
      'eslabon_channel',
      'Eslabón Notificaciones',
      channelDescription: 'Canal de notificaciones para la app Eslabon.',
      importance: Importance.max,
      priority: Priority.high,
      sound: soundFile != 'default'
          ? RawResourceAndroidNotificationSound(soundFile.split('.').first)
          : null,
    );
    final platformDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification?.title,
      notification?.body,
      platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}