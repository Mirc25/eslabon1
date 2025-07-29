import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:eslabon_flutter/services/notification_service.dart';

class NotificationServiceNotifier extends StateNotifier<NotificationService> {
  NotificationServiceNotifier() : super(NotificationService());

  NotificationService get notificationService => state;

  void setRouter(GoRouter router) {
    state.setRouter(router);
  }
}

final notificationServiceProvider = StateNotifierProvider<NotificationServiceNotifier, NotificationService>(
  (ref) {
    return NotificationServiceNotifier();
  },
);