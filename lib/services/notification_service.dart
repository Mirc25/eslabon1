import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// No se importa flutter_riverpod aquí, ya que el proveedor se define en otro archivo.

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final GoRouter _router; // Instancia de GoRouter, inicializada vía constructor

  NotificationService(this._router); // Constructor ahora toma GoRouter

  // Método de inicialización de instancia
  Future<void> initialize() async {
    // Solicitar permisos (iOS)
    await _messaging.requestPermission();

    // Configurar canal para notificaciones locales
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null && details.payload!.isNotEmpty) {
          debugPrint('Payload de notificación local: ${details.payload}');
        }
      },
    );

    // Manejar notificaciones cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showFlutterNotification(message);
      // Opcionalmente, manejar navegación para mensajes en primer plano si es necesario
      // handleMessage(message);
    });

    // FirebaseMessaging.onMessageOpenedApp y getInitialMessage serán manejados en main.dart
    // para asegurar que el contexto de GoRouter esté disponible vía Riverpod.
  }

  // Método estático para mostrar notificaciones locales
  static void showFlutterNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: '',
      );
    }
  }

  /// Maneja la navegación profunda de las notificaciones FCM (estado de segundo plano/terminado).
  void handleMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    switch (type) {
      case 'new_offer':
        final requestId = data['requestId'];
        final helperId = data['helperId'];
        if (requestId != null && helperId != null) {
          _router.push('/rate-offer/$requestId/$helperId');
        }
        break;
      case 'rating_received':
        final requestId = data['requestId'];
        if (requestId != null) {
          _router.push('/rate-helper/$requestId');
        }
        break;
      case 'chat_message':
        final chatId = data['chatId'];
        if (chatId != null) {
          _router.push('/chat/$chatId');
        }
        break;
      default:
        debugPrint('Tipo de notificación no reconocido: $type');
    }
  }

  /// Maneja la navegación al tocar una notificación en la lista de la UI.
  void handleNotificationNavigation({
    required String type,
    String? requestId,
    String? helperId,
    String? chatId,
  }) {
    switch (type) {
      case 'new_offer':
        if (requestId != null && helperId != null) {
          _router.push('/rate-offer/$requestId/$helperId');
        }
        break;
      case 'rating_received':
        if (requestId != null) {
          _router.push('/rate-helper/$requestId');
        }
        break;
      case 'chat_message':
        if (chatId != null) {
          _router.push('/chat/$chatId');
        }
        break;
      default:
        debugPrint('Tipo de notificación de UI no reconocido: $type');
    }
  }

  static Future<void> updateFcmToken(String userId) async {
    final token = await _messaging.getToken();
    if (token != null) {
      // Guardar token en Firestore
    }
  }
}
