// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:eslabon_flutter/widgets/custom_app_bar.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/notification_card.dart';
import 'package:eslabon_flutter/providers/user_provider.dart';
import 'package:eslabon_flutter/providers/notification_service_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? currentUser = ref.watch(userProvider).value;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notificaciones')),
        body: const Center(
          child: Text('Debes iniciar sesión para ver tus notificaciones.', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final String userId = currentUser.uid;

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'Mis Notificaciones',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
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
              return Center(child: Text('Error al cargar notificaciones: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.amber));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              debugPrint('DEBUG NOTIFICATIONS: No hay notificaciones para el usuario: $userId');
              return const Center(
                child: Text(
                  'No tienes notificaciones en este momento.',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
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
                    // ✅ CORREGIDO: Lógica para marcar como leída
                    if (notificationId != null) {
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('notifications')
                          .doc(notificationId)
                          .update({'read': true});
                    }
                    
                    // La lógica para manejar la navegación y marcar como leída
                    notificationData['notificationId'] = notificationId;
                    ref.read(notificationServiceProvider.notifier).handleNotificationNavigation(notificationData);
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