import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

Future<void> bindNotificationOpenHandlers(GlobalKey<NavigatorState> navKey) async {
  // App cerrada y se abre desde notificación
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage?.data["route"] != null) {
    navKey.currentState?.context.go(initialMessage!.data["route"]!);
  }

  // App en background y se toca notificación
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
    final r = m.data["route"];
    if (r != null) {
      navKey.currentState?.context.go(r);
    }
  });
}
