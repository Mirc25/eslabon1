import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eslabon_flutter/services/notification_service.dart';
import 'package:eslabon_flutter/providers/user_provider.dart'; // ✅ CORRECCIÓN: Importación del proveedor de usuario
import 'package:eslabon_flutter/providers/notification_service_provider.dart'; // Importar el proveedor de NotificationService
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Importar GoRouter
import '../models/notification_model.dart';
import '../widgets/notification_card.dart';

class NotificationsScreen extends ConsumerWidget {
  // ✅ CORRECCIÓN: Constructor sin parámetros, como se espera en app_router.dart
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ CORRECCIÓN: Usar userProvider para obtener el usuario actual
    final currentUser = ref.watch(userProvider);
    final userId = currentUser.value?.uid; // Acceder a .value para el StreamProvider

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Usuario no autenticado')),
      );
    }

    final notificationsQuery = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')), // Añadir AppBar para mejor navegación
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/eslabon_background.png'), // Asegúrate de que el asset esté en pubspec.yaml
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Center(
              child: Image.asset(
                'assets/icon.jpg', // Asegúrate de que el asset esté en pubspec.yaml
                width: 120,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Notificaciones',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: notificationsQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay notificaciones',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index]; // Obtener el documento completo
                      final notificationData = doc.data() as Map<String, dynamic>;
                      // ✅ CORRECCIÓN: Pasar doc.id a fromMap
                      final notification = AppNotification.fromMap(doc.id, notificationData);

                      final type = notification.type;
                      final requestId = notification.requestId;
                      final helperId = notification.helperId;
                      final chatId = notification.chatId;

                      return NotificationCard(
                        notification: notification,
                        onTap: () {
                          // ✅ CORRECCIÓN: Acceder a la instancia de NotificationService a través del proveedor de Riverpod
                          // y llamar a handleNotificationNavigation sin el parámetro 'context'.
                          ref.read(notificationServiceProvider.notifier).setRouter(GoRouter.of(context)); // Actualiza el router en el notifier
                          ref.read(notificationServiceProvider).handleNotificationNavigation(
                            type: type,
                            requestId: requestId,
                            helperId: helperId,
                            chatId: chatId,
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

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
