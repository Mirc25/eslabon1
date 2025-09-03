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

    final notificationType = (data['notificationType'] ?? data['type'] ?? data['data']?['type'])?.toString();
    final requestId = data['data']?['requestId']?.toString();
    final helperId = data['data']?['helperId']?.toString();
    final helperName = data['data']?['helperName']?.toString();
    final requesterId = data['data']?['requesterId']?.toString();
    final requesterName = data['data']?['requesterName']?.toString();
    final chatPartnerId = (data['chatPartnerId'] ?? data['data']?['chatPartnerId'])?.toString();
    final chatPartnerName = (data['chatPartnerName'] ?? data['data']?['chatPartnerName'])?.toString();
    final chatRoomId = (data['chatRoomId'] ?? data['data']?['chatRoomId'])?.toString();
    final chatPartnerAvatar = (data['chatPartnerAvatar'] ?? data['data']?['chatPartnerAvatar'])?.toString();
    final userId = (data['userId'] ?? data['data']?['userId'])?.toString();
    final userName = (data['userName'] ?? data['data']?['userName'])?.toString();
    final messageText = (data['notification']?['body'] as String?) ?? (data['messageText'] as String?);

    switch (notificationType) {
      case 'offer_received':
        if (requestId != null && helperId != null && helperName != null) {
          _router.pushNamed(
            'request_detail',
            pathParameters: {'requestId': requestId},
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
              'message': 'Te ha calificado con ${data['data']?['rating']?.toStringAsFixed(1)} estrellas.',
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
        final navigationPath = (data['navigationPath'] ?? data['data']?['navigationPath'])?.toString();
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
