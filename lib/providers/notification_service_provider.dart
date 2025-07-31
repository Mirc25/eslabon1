// lib/providers/notification_service_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Importa GoRouter
import 'package:eslabon_flutter/services/notification_service.dart';

// ✅ CORREGIDO: NotificationServiceNotifier ya no necesita setRouter
class NotificationServiceNotifier extends StateNotifier<NotificationService> {
  NotificationServiceNotifier(NotificationService service) : super(service);

  // ✅ ELIMINADO: setRouter ya no es necesario aquí
  // void setRouter(GoRouter router) {
  //   state.setRouter(router);
  // }

  void handleNotificationNavigation(Map<String, dynamic> notificationData) {
    state.handleNotificationNavigation(notificationData);
  }
}

// Proveedor para NotificationService
final notificationServiceProvider = StateNotifierProvider<NotificationServiceNotifier, NotificationService>((ref) {
  // ✅ CORREGIDO: Este throw solo debería ocurrir si no se sobrescribe en main.dart
  // La instancia real se proporciona en main.dart.
  throw UnimplementedError('notificationServiceProvider debe ser sobrescrito en main.dart');
});
