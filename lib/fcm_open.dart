import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'notifications_nav.dart';

Future<void> bindNotificationOpenHandlers(GlobalKey<NavigatorState> navKey) async {
  // App cerrada y se abre desde notificación
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage?.data != null) {
    final route = routeFor(initialMessage!.data);
    navKey.currentState?.context.go(route);
  }

  // App en background y se toca notificación
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
    if (m.data.isNotEmpty) {
      final route = routeFor(m.data);
      navKey.currentState?.context.go(route);
    }
  });
}
