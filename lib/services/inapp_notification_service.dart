// lib/services/inapp_notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class InAppNotificationService {
  static Future<void> createChatNotification({
    required String recipientUid,
    required String chatId,
    required String senderUid,
    required String senderName,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .add({
        'type': 'chat',
        'title': 'Nuevo mensaje',
        'body': ' te escribió',
        'unread': true,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'recipientId': recipientUid,
          'senderId': senderUid,
          'senderName': senderName,
          'chatRoomId': chatId,
          'route': '/chat/',
        },
      });
      print('? Notificación de chat creada para .');
    } catch (e) {
      print('? Error al crear notificación de chat: ');
    }
  }
}
