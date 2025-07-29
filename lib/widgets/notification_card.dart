import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Timestamp
import '../models/notification_model.dart'; // Asegúrate de que la ruta sea correcta

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap; // Callback para el onTap

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap, // Inicializar el callback
  });

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: notification.isRead ? Colors.grey[800] : Colors.blueGrey[700], // Cambia el color si ya fue leída
      child: ListTile(
        leading: Icon(
          _getIconForNotificationType(notification.type), // Función para obtener el ícono
          color: Colors.white,
        ),
        title: Text(
          notification.message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _formatTimestamp(notification.timestamp),
          style: const TextStyle(color: Colors.grey),
        ),
        onTap: onTap, // Usar el callback onTap
        trailing: notification.isRead
            ? null
            : const Icon(Icons.circle, color: Colors.blue, size: 10), // Indicador de no leída
      ),
    );
  }

  IconData _getIconForNotificationType(String type) {
    switch (type) {
      case 'new_offer':
        return Icons.handshake;
      case 'rating_received':
        return Icons.star;
      case 'chat_message':
        return Icons.chat;
      default:
        return Icons.notifications;
    }
  }
}
