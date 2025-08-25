import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// âœ… Mantenemos la importaciÃ³n del archivo original del router
import 'package:eslabon_flutter/router/app_router.dart';
import 'package:eslabon_flutter/services/notification_service.dart';

// âœ… Corregido: La definiciÃ³n del proveedor del router debe estar solo en un archivo
// Se elimina la definiciÃ³n duplicada.

final notificationServiceProvider = Provider<NotificationService>((ref) {
  // âœ… Corregido: Usar el proveedor del router que se define en app_router.dart
  final goRouter = ref.watch(appRouterProvider);
  return NotificationService(appRouter: goRouter);
});
