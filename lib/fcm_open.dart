import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'notifications_nav.dart';

Future<void> bindNotificationOpenHandlers(GlobalKey<NavigatorState> navKey) async {
  // App cerrada y se abre desde notificación
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage?.data != null) {
    print('🔥 [FCM_OPEN] App abierta desde notificación - Datos: ${initialMessage!.data}');
    final route = routeFor(initialMessage.data);
    print('🔥 [FCM_OPEN] Ruta determinada: $route');
    navKey.currentState?.context.go(route);
  }

  // App en background y se toca notificación
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
    if (m.data.isNotEmpty) {
      print('🔥 [FCM_OPEN] App en background - Notificación tocada - Datos: ${m.data}');
      final route = routeFor(m.data);
      print('🔥 [FCM_OPEN] Ruta determinada: $route');
      navKey.currentState?.context.go(route);
    }
  });
}
