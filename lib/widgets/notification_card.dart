// lib/widgets/notification_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationCard extends StatelessWidget {
  final String notificationId;
  final Map<String, dynamic> notificationData;
  final VoidCallback onTap;

  const NotificationCard({
    Key? key,
    required this.notificationId,
    required this.notificationData,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String type = notificationData['type'] ?? 'general';
    
    // Manejar título para notificaciones de chat
    String title = notificationData['title'] ?? '';
    if (title.isEmpty && (type == 'chat_message' || type == 'chat')) {
      final String senderName = notificationData['senderName'] ?? 
                               notificationData['data']?['senderName'] ?? 
                               notificationData['data']?['chatPartnerName'] ?? 
                               'Usuario';
      title = 'Chat $senderName';
    }
    if (title.isEmpty) {
      title = 'Nueva Notificación';
    }
    
    final String body = notificationData['body'] ?? 'No hay contenido para esta notificación.';
    final Timestamp? timestamp = notificationData['timestamp'] as Timestamp?;
    final bool read = notificationData['read'] ?? false;

    String formattedTime = '';
    if (timestamp != null) {
      final DateTime date = timestamp.toDate();
      formattedTime = DateFormat('dd/MM HH:mm').format(date);
    }

    IconData icon;
    Color iconColor;
    switch (type) {
      case 'offer_received':
        icon = Icons.handshake;
        iconColor = Colors.green;
        break;
      case 'helper_rated':
        icon = Icons.star;
        iconColor = Colors.amber;
        break;
      case 'requester_rated':
        icon = Icons.star_half;
        iconColor = Colors.orange;
        break;
      case 'chat_message':
        icon = Icons.chat_bubble;
        iconColor = Colors.amber;
        break;
      case 'chat':
        icon = Icons.chat_bubble;
        iconColor = Colors.amber;
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: read ? Colors.grey[850] : Colors.grey[700],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .collection('notifications')
                .doc(notificationId)
                .update({'read': true});
          }
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: read ? Colors.white70 : Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 14,
                        color: read ? Colors.white54 : Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        formattedTime,
                        style: TextStyle(fontSize: 10, color: read ? Colors.grey : Colors.white54),
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
}

