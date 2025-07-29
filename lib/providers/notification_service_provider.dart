import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Importar GoRouter
import '../services/notification_service.dart';

// ✅ DEFINICIÓN: StateNotifierProvider para NotificationService
final notificationServiceProvider = StateNotifierProvider<NotificationServiceNotifier, NotificationService>((ref) {
  // Inicializamos con un GoRouter dummy. El router real se pasará en el método setRouter.
  return NotificationServiceNotifier(NotificationService(GoRouter(routes: [])));
});

// Clase Notifier para manejar el estado de NotificationService
class NotificationServiceNotifier extends StateNotifier<NotificationService> {
  NotificationServiceNotifier(NotificationService initialService) : super(initialService);

  // Método para actualizar la instancia de NotificationService con el router real
  void setRouter(GoRouter router) {
    state = NotificationService(router);
  }
}
