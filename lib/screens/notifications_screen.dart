// lib/screens/notifications_screen.dart
import '../notifications_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:eslabon_flutter/widgets/custom_app_bar.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/notification_card.dart';
import 'package:eslabon_flutter/providers/user_provider.dart';
import 'package:eslabon_flutter/providers/notification_service_provider.dart';
import 'package:eslabon_flutter/models/user_model.dart';

// Clase para representar notificaciones agrupadas de chat
class GroupedChatNotification {
  final String chatPartnerId;
  final String chatPartnerName;
  final String? chatPartnerAvatar;
  final String chatRoomId;
  final int unreadCount;
  final DateTime lastMessageTime;
  final String lastMessageText;

  GroupedChatNotification({
    required this.chatPartnerId,
    required this.chatPartnerName,
    this.chatPartnerAvatar,
    required this.chatRoomId,
    required this.unreadCount,
    required this.lastMessageTime,
    required this.lastMessageText,
  });
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? currentUser = ref.watch(userProvider).value;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('notifications'.tr())),
        body: Center(
          child: Text('Debes iniciar sesi�n para ver tus notificaciones.'.tr(), style: const TextStyle(color: Colors.white)),
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
              return Center(child: Text('Error al cargar notificaciones: '.tr(), style: const TextStyle(color: Colors.red)));
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

            // Separar notificaciones de chat y otras notificaciones
            final Map<String, List<QueryDocumentSnapshot>> chatNotificationsByPartner = {};
            final List<QueryDocumentSnapshot> otherNotifications = [];

            for (var doc in notifications) {
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'] ?? '';
              
              if (type == 'chat_message' || type == 'chat_started' || type == 'chat') {
                final chatPartnerId = data['data']?['chatPartnerId'] ?? 
                                    data['data']?['senderId'] ?? 
                                    data['senderId'] ?? 
                                    data['recipientId'];
                if (chatPartnerId != null) {
                  if (!chatNotificationsByPartner.containsKey(chatPartnerId)) {
                    chatNotificationsByPartner[chatPartnerId] = [];
                  }
                  chatNotificationsByPartner[chatPartnerId]!.add(doc);
                } else {
                  otherNotifications.add(doc);
                }
              } else {
                otherNotifications.add(doc);
              }
            }

            // Crear lista de notificaciones agrupadas de chat
            final List<GroupedChatNotification> groupedChatNotifications = [];
            for (var entry in chatNotificationsByPartner.entries) {
              final chatPartnerId = entry.key;
              final chatNotifications = entry.value;
              
              // Contar mensajes no leídos
              final unreadCount = chatNotifications.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return !(data['read'] ?? false);
              }).length;

              if (unreadCount > 0) {
                // Obtener la notificación más reciente para obtener datos del chat
                final latestNotification = chatNotifications.first;
                final latestData = latestNotification.data() as Map<String, dynamic>;
                
                final partnerName = latestData['data']?['chatPartnerName'] ?? 
                                 latestData['data']?['senderName'] ?? 
                                 'Usuario desconocido';
                
                groupedChatNotifications.add(GroupedChatNotification(
                  chatPartnerId: chatPartnerId,
                  chatPartnerName: 'Chat $partnerName',
                  chatPartnerAvatar: latestData['data']?['senderAvatar'],
                  chatRoomId: latestData['data']?['chatRoomId'] ?? '',
                  unreadCount: unreadCount,
                  lastMessageTime: (latestData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  lastMessageText: unreadCount > 1 
                      ? '$unreadCount mensajes nuevos'
                      : latestData['body'] ?? 'Nuevo mensaje',
                ));
              }
            }

            // Ordenar notificaciones agrupadas por tiempo
            groupedChatNotifications.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

            // Combinar notificaciones agrupadas de chat con otras notificaciones
            final totalItems = groupedChatNotifications.length + otherNotifications.length;

            if (totalItems == 0) {
              return Center(
                child: Text(
                  'No tienes notificaciones en este momento.'.tr(),
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: totalItems,
              itemBuilder: (context, index) {
                if (index < groupedChatNotifications.length) {
                  // Mostrar notificación agrupada de chat
                  final groupedNotification = groupedChatNotifications[index];
                  return _buildGroupedChatNotificationCard(context, groupedNotification, userId);
                } else {
                  // Mostrar otras notificaciones
                  final otherIndex = index - groupedChatNotifications.length;
                  final doc = otherNotifications[otherIndex];
                  final notificationData = doc.data() as Map<String, dynamic>;
                  final String notificationId = doc.id;

                  return NotificationCard(
                    notificationId: notificationId,
                    notificationData: notificationData,
                    onTap: () {
                      openNotificationAndMarkRead(context, doc);
                    },
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupedChatNotificationCard(BuildContext context, GroupedChatNotification groupedNotification, String userId) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: Colors.grey[700],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          // Marcar todas las notificaciones de este chat como leídas
          await _markChatNotificationsAsRead(userId, groupedNotification.chatPartnerId);
          
          // Navegar al chat
          if (context.mounted) {
            context.go('/chat/${groupedNotification.chatRoomId}?partnerId=${groupedNotification.chatPartnerId}&partnerName=${Uri.encodeComponent(groupedNotification.chatPartnerName)}&partnerAvatar=${groupedNotification.chatPartnerAvatar ?? ''}');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar del usuario o icono de chat
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.amber,
                backgroundImage: groupedNotification.chatPartnerAvatar != null 
                    ? NetworkImage(groupedNotification.chatPartnerAvatar!)
                    : null,
                child: groupedNotification.chatPartnerAvatar == null 
                    ? const Icon(Icons.person, color: Colors.white, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            groupedNotification.chatPartnerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Contador de mensajes no leídos
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${groupedNotification.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      groupedNotification.lastMessageText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        DateFormat('dd/MM HH:mm').format(groupedNotification.lastMessageTime),
                        style: const TextStyle(fontSize: 10, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markChatNotificationsAsRead(String userId, String chatPartnerId) async {
    try {
      final QuerySnapshot chatNotifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('data.chatPartnerId', isEqualTo: chatPartnerId)
          .where('read', isEqualTo: false)
          .get();

      if (chatNotifications.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in chatNotifications.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
        debugPrint('DEBUG NOTIFICATIONS: Notificaciones de chat marcadas como leídas para $chatPartnerId');
      }
    } catch (e) {
      debugPrint('Error al marcar notificaciones de chat como leídas: $e');
    }
  }
}
