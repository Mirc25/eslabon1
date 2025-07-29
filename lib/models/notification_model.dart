import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type; 
  final String title;
  final String body; 
  final String receiverId; 
  final String? senderId;   
  final String? requestId;  
  final String? helperId;   
  final String? requesterId; 
  final Timestamp timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.receiverId,
    this.senderId,
    this.requestId,
    this.helperId,
    this.requesterId,
    required this.timestamp,
    this.isRead = false,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: data['type'] ?? 'general',
      title: data['title'] ?? 'Notificación',
      body: data['body'] ?? '', 
      receiverId: data['receiverId'] ?? '',
      senderId: data['senderId'],
      requestId: data['requestId'],
      helperId: data['helperId'],
      requesterId: data['requesterId'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'title': title,
      'body': body,
      'receiverId': receiverId,
      'senderId': senderId,
      'requestId': requestId,
      'helperId': helperId,
      'requesterId': requesterId,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }
}