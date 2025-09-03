import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eslabon_flutter/services/notification_service.dart';
import 'package:eslabon_flutter/router/app_router.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(appRouter: AppRouter.router);
});
