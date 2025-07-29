import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppNotification {
  final String id;
  final String type;
  final String body; // Contenido del mensaje de la notificación
  final Timestamp timestamp;
  final bool read;
  final String? requestId;
  final String? senderId;
  final String? senderName;
  final String? senderPhotoUrl;
  final String? chatPartnerId;
  final String? requestTitle; // Título de la solicitud relacionada
  final String? helperId;
  final String? requesterId;
  final Map<String, dynamic>? navigationData;

  AppNotification({
    required this.id,
    required this.type,
    required this.body,
    required this.timestamp,
    required this.read,
    this.requestId,
    this.senderId,
    this.senderName,
    this.senderPhotoUrl,
    this.chatPartnerId,
    this.requestTitle,
    this.helperId,
    this.requesterId,
    this.navigationData,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: data['type'] as String,
      body: data['body'] as String,
      timestamp: data['timestamp'] as Timestamp,
      read: data['read'] as bool? ?? false,
      requestId: data['requestId'] as String?,
      senderId: data['senderId'] as String?,
      senderName: data['senderName'] as String?,
      senderPhotoUrl: data['senderPhotoUrl'] as String?,
      chatPartnerId: data['chatPartnerId'] as String?,
      requestTitle: data['requestTitle'] as String?,
      helperId: data['helperId'] as String?,
      requesterId: data['requesterId'] as String?,
      navigationData: data['navigationData'] as Map<String, dynamic>?,
    );
  }

  Future<void> markAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('Error: No hay usuario autenticado para marcar la notificación como leída.');
      return;
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('notifications')
        .doc(id)
        .update({'read': true});
  }
}