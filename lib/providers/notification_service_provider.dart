import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ✅ Mantenemos la importación del archivo original del router
import 'package:eslabon_flutter/router/app_router.dart';
import 'package:eslabon_flutter/services/notification_service.dart';

// ✅ Corregido: La definición del proveedor del router debe estar solo en un archivo
// Se elimina la definición duplicada.

final notificationServiceProvider = Provider<NotificationService>((ref) {
  // ✅ Corregido: Usar el proveedor del router que se define en app_router.dart
  final goRouter = ref.watch(appRouterProvider);
  return NotificationService(appRouter: goRouter);
});