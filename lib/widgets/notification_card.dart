import 'package:flutter/material.dart';
import 'package:eslabon_flutter/models/notification_model.dart';
import 'package:intl/intl.dart';

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('MMM d, hh:mm a').format(notification.timestamp.toDate());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // ✅ CORREGIDO: Usar notification.body en lugar de notification.title
                notification.body,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              // Puedes usar notification.requestTitle o notification.type si quieres algo más detallado aquí
              Text(
                'Solicitud: ${notification.requestTitle ?? 'N/A'}', // ✅ Usar requestTitle para contexto
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tipo: ${notification.type}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    formattedTime,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}