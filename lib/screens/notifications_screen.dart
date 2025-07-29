import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:eslabon_flutter/models/notification_model.dart';
import 'package:eslabon_flutter/widgets/notification_card.dart';
import 'package:eslabon_flutter/providers/notification_service_provider.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notificaciones')),
        body: const Center(child: Text('Inicia sesión para ver tus notificaciones.')),
      );
    }

    final String userId = currentUser.uid;

    return Scaffold(
      body: CustomBackground(
        child: Column(
          children: [
            AppBar(
              title: const Text('Tus Notificaciones', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No tienes notificaciones.'));
                  }

                  final notifications = snapshot.data!.docs.map((doc) {
                    return AppNotification.fromFirestore(doc);
                  }).toList();

                  return ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return NotificationCard(
                        notification: notification,
                        onTap: () {
                          // ✅ CORRECCIÓN: Pasar los datos necesarios al handleMessage
                          // handleMessage necesita un RemoteMessage completo, por lo que creamos uno
                          ref.read(notificationServiceProvider.notifier).notificationService.handleMessage(
                            RemoteMessage(
                              data: {
                                'type': notification.type,
                                'requestId': notification.requestId,
                                'helperId': notification.helperId, // Asegúrate de que el helperId esté en la notificación
                                'requesterId': notification.requesterId, // Asegúrate de que el requesterId esté en la notificación
                                // Otros datos si son necesarios para la navegación profunda
                                'chatPartnerId': notification.chatPartnerId,
                                'chatPartnerName': notification.senderName, // O el nombre del chat partner
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}