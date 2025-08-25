// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth; // âœ… CORREGIDO: Agregado alias para evitar conflicto de tipos
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:eslabon_flutter/widgets/custom_app_bar.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/notification_card.dart';
import 'package:eslabon_flutter/providers/user_provider.dart';
import 'package:eslabon_flutter/providers/notification_service_provider.dart';
import 'package:eslabon_flutter/models/user_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? currentUser = ref.watch(userProvider).value;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('notifications'.tr())),
        body: Center(
          child: Text('Debes iniciar sesiÃ³n para ver tus notificaciones.'.tr(), style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    final String userId = currentUser.id;

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'notifications'.tr(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
                context.pop();
            },
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            debugPrint('DEBUG NOTIFICATIONS: ConnectionState: ${snapshot.connectionState}');
            debugPrint('DEBUG NOTIFICATIONS: HasError: ${snapshot.hasError}');

            if (snapshot.hasError) {
              debugPrint('DEBUG NOTIFICATIONS ERROR: ${snapshot.error}');
              return Center(child: Text('Error al cargar notificaciones: ${snapshot.error}'.tr(), style: const TextStyle(color: Colors.red)));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.amber));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              debugPrint('DEBUG NOTIFICATIONS: No hay notificaciones para el usuario: $userId');
              return Center(
                child: Text(
                  'No tienes notificaciones en este momento.'.tr(),
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final notifications = snapshot.data!.docs;
            debugPrint('DEBUG NOTIFICATIONS: Total de notificaciones cargadas: ${notifications.length}');

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final doc = notifications[index];
                final notificationData = doc.data() as Map<String, dynamic>;
                final String notificationId = doc.id;

                return NotificationCard(
                  notificationId: notificationId,
                  notificationData: notificationData,
                  onTap: () {
                    final Map<String, dynamic> payload = {
                      ...notificationData,
                      'notificationId': notificationId,
                    };
                    ref.read(notificationServiceProvider).handleNotificationNavigation(payload);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
