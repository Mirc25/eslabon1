// lib/services/notification_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  late GoRouter _router;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static final Set<String> _dedupeCache = <String>{};
  static String? _activeChatId;
  static String? _lastChatNotificationId;
  static DateTime? _lastChatNotificationTime;
  static bool _isAppInForeground = false;

  static void setActiveChatId(String? chatId) => _activeChatId = chatId;
  static void setAppInForeground(bool inForeground) => _isAppInForeground = inForeground;

  // Método público que será llamado desde el handler global en main.dart
  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Handling a background message via public method: ${message.messageId}');
    await _handleMessage(message);
  }

  Future<void> initialize(GoRouter router) async {
    _router = router;
    await _restoreDedupeCache();
    await _initLocalNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // 📨 DEBUGGING: Capturar exactamente lo que llega al teléfono
      print('📨 FCM.data: ${message.data}');
      print('📨 FCM.route: ${message.data['route']}');
      print('📨 FCM.notificationType: ${message.data['notificationType']}');
      print('📨 FCM.requestId: ${message.data['requestId']}');
      print('📨 FCM.helperId: ${message.data['helperId']}');
      print('📨 FCM.requesterId: ${message.data['requesterId']}');
      
      final String? chatRoomId = message.data['chatRoomId']?.toString();
      final String? notificationType = message.data['notificationType']?.toString();

      // Si la app está en primer plano, no mostrar notificaciones push
      if (_isAppInForeground) {
        debugPrint('App en primer plano, notificación suprimida.');
        return;
      }

      if (notificationType == 'chat_message' && _activeChatId == chatRoomId) {
        debugPrint('Mensaje de chat en primer plano en chat activo, se ignora.');
        return;
      }
      await _handleMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      // 📨 DEBUGGING: Capturar exactamente lo que llega al teléfono (onMessageOpenedApp)
      print('📨 FCM.data: ${message.data}');
      print('📨 FCM.route: ${message.data['route']}');
      print('📨 FCM.notificationType: ${message.data['notificationType']}');
      print('📨 FCM.requestId: ${message.data['requestId']}');
      print('📨 FCM.helperId: ${message.data['helperId']}');
      print('📨 FCM.requesterId: ${message.data['requesterId']}');
      
      print('[FCM] onMessageOpenedApp data=${message.data}');
      print('[FCM] route=${message.data['route']} requestId=${message.data['requestId'] ?? message.data['solicitudId']} type=${message.data['type']}');
      await _handleNavigation(message);
    });
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
  }

  Future<void> _handleNotificationTap(NotificationResponse response) async {
    print('🔔 === DEBUGGING LOCAL NOTIFICATION TAP ===');
    print('🔔 Response completo: ${response.toString()}');
    print('🔔 Payload: ${response.payload}');
    print('🔔 Action ID: ${response.actionId}');
    print('🔔 Notification ID: ${response.id}');
    
    // 📨 DEBUGGING: Capturar datos de notificación local
    print('📨 LOCAL.payload: ${response.payload}');
    if (response.payload != null && response.payload!.contains('?')) {
      final uri = Uri.tryParse(response.payload!);
      if (uri != null) {
        print('📨 LOCAL.parsed_route: ${uri.path}');
        print('📨 LOCAL.query_params: ${uri.queryParameters}');
        print('📨 LOCAL.helperId: ${uri.queryParameters['helperId']}');
        print('📨 LOCAL.requesterId: ${uri.queryParameters['requesterId']}');
      }
    }
    
    if (response.payload != null) {
      try {
        final route = response.payload!;
        print('🔔 ✅ NAVEGANDO A (LOCAL): $route');
        
        // Extraer chatId de la ruta si es un chat
        if (route.startsWith('/chat/')) {
          final chatId = route.split('/chat/')[1];
          await _markChatNotificationsAsRead(chatId);
        }
        
        _router.go(route);
        print('🔔 ✅ NAVEGACIÓN LOCAL EXITOSA');
      } catch (e) {
        print('🔔 ❌ ERROR EN NAVEGACIÓN LOCAL: $e');
      }
    } else {
      print('🔔 ❌ NO HAY PAYLOAD en notificación local');
    }
    print('🔔 === FIN DEBUGGING LOCAL NOTIFICATION TAP ===');
  }

  Future<void> _markChatNotificationsAsRead(String chatId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      debugPrint('🗑️ Marcando notificaciones del chat como leídas: $chatId');
      
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .where('type', isEqualTo: 'chat_message')
          .where('chatId', isEqualTo: chatId)
          .where('read', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        await doc.reference.update({'read': true});
      }
      
      debugPrint('✅ ${notifications.docs.length} notificaciones marcadas como leídas');
    } catch (e) {
      debugPrint('❌ Error marking chat notifications as read: $e');
    }
  }

  Future<void> _handleNavigation(RemoteMessage message) async {
    print('🔔 === DEBUGGING NOTIFICATION TAP ===');
    print('🔔 Message data completo: ${message.data}');
    print('🔔 Message notification: ${message.notification?.toMap()}');
    
    final String? route = message.data['route'] as String?;
    print('🔔 Route extraída: $route');
    
    if (route != null && route.isNotEmpty) {
      print('🔔 ✅ NAVEGANDO A: $route');
      try {
        _router.go(route);
        print('🔔 ✅ NAVEGACIÓN EXITOSA');
      } catch (e) {
        print('🔔 ❌ ERROR EN NAVEGACIÓN: $e');
      }
    } else {
      print('🔔 ❌ NO HAY ROUTE - route es null o vacía');
      print('🔔 Intentando buscar route en otros campos...');
      
      // Buscar route en otros posibles campos
      final allKeys = message.data.keys.toList();
      print('🔔 Todas las keys disponibles: $allKeys');
      
      for (String key in allKeys) {
        if (key.toLowerCase().contains('route') || key.toLowerCase().contains('path')) {
          print('🔔 Campo relacionado con route encontrado: $key = ${message.data[key]}');
        }
      }
    }
    print('🔔 === FIN DEBUGGING NOTIFICATION TAP ===');
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    final String dedupeKey = _getDedupeKey(message);

    if (await _isDuplicate(dedupeKey)) {
      debugPrint('Mensaje duplicado, se descarta. Clave: $dedupeKey');
      return;
    }

    _dedupeCache.add(dedupeKey);
    _saveDedupeKey(dedupeKey);
    
    final String? chatRoomId = message.data['chatRoomId']?.toString();
    if (chatRoomId != null) {
      final now = DateTime.now();
      if (_lastChatNotificationId == chatRoomId && now.difference(_lastChatNotificationTime!).inSeconds < 5) {
        debugPrint('Ráfaga de mensajes de chat en curso, se suprime la notificación.');
        return;
      }
      _lastChatNotificationId = chatRoomId;
      _lastChatNotificationTime = now;
    }

    await _showNotification(message);
    debugPrint('Mensaje recibido y procesado. Clave: $dedupeKey');
  }

  Future<void> _showNotification(RemoteMessage message) async {
    print('🔔 === DEBUGGING SHOW NOTIFICATION ===');
    print('🔔 Message data completo: ${message.data}');
    print('🔔 Message notification: ${message.notification?.toMap()}');
    
    // Usar title y body de notification si están disponibles, sino usar los de data
    final String? title = message.notification?.title ?? message.data['title'];
    final String? body = message.notification?.body ?? message.data['body'];
    final String? route = message.data['route'] as String?;
    final String? senderAvatarUrl = message.data['senderPhotoUrl'] as String?;

    print('🔔 Title extraído: $title');
    print('🔔 Body extraído: $body');
    print('🔔 Route extraída para payload: $route');
    print('🔔 Sender avatar URL: $senderAvatarUrl');

    if (title != null && body != null) {
      print('🔔 ✅ CREANDO NOTIFICACIÓN LOCAL con payload: $route');
      
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'chat_channel_id',
        'Chat Notifications',
        channelDescription: 'Canal para notificaciones de chat.',
        importance: Importance.max,
        priority: Priority.high,
        icon: senderAvatarUrl,
      );

      final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
      await _flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        platformDetails,
        payload: route,
      );
      print('🔔 ✅ NOTIFICACIÓN LOCAL MOSTRADA EXITOSAMENTE');
    } else {
      print('🔔 ❌ NO SE PUDO MOSTRAR NOTIFICACIÓN - Title: $title, Body: $body');
    }
    print('🔔 === FIN DEBUGGING SHOW NOTIFICATION ===');
  }

  String _getDedupeKey(RemoteMessage message) {
    if (message.data.containsKey('dedupeKey')) {
      return message.data['dedupeKey'].toString();
    }
    final String? chatRoomId = message.data['chatRoomId']?.toString();
    final String? messageId = message.messageId;
    if (chatRoomId != null && messageId != null) {
      return '$chatRoomId-$messageId';
    }
    return message.messageId ?? '';
  }

  Future<bool> _isDuplicate(String dedupeKey) async {
    if (_dedupeCache.contains(dedupeKey)) {
      return true;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool existsInPrefs = prefs.getBool('esl_dk_$dedupeKey') ?? false;
    if (existsInPrefs) {
      _dedupeCache.add(dedupeKey);
      return true;
    }
    return false;
  }
  
  Future<void> _saveDedupeKey(String dedupeKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('esl_dk_$dedupeKey', true);
    Timer(const Duration(minutes: 10), () async {
      await prefs.remove('esl_dk_$dedupeKey');
      _dedupeCache.remove(dedupeKey);
    });
  }

  Future<void> _restoreDedupeCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    _dedupeCache.clear();
    for (var key in allKeys) {
      if (key.startsWith('esl_dk_')) {
        _dedupeCache.add(key.substring(7));
      }
    }
  }

  Future<String?> getDeviceToken() async => _messaging.getToken();
}