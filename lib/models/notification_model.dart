import 'dart:convert'; // ✅ CORRECCIÓN: La directiva import debe estar al inicio del archivo

import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type;
  final String userId; // Receptor de la notificación
  final String? senderId; // Quien envía/genera la notificación
  final String message;
  final String? requestId; // Para new_offer, rating_received
  final String? helperId; // Para new_offer (el que ofrece ayuda)
  final String? requesterId; // Para rating_received (el que califica)
  final String? chatId; // Para chat_message
  final Timestamp timestamp;
  final bool isRead;
  final Map<String, dynamic>? requestData; // Datos adicionales de la solicitud

  AppNotification({
    required this.id,
    required this.type,
    required this.userId,
    this.senderId,
    required this.message,
    this.requestId,
    this.helperId,
    this.requesterId,
    this.chatId,
    required this.timestamp,
    this.isRead = false,
    this.requestData,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      type: data['type'] as String,
      userId: data['userId'] as String,
      senderId: data['senderId'] as String?,
      message: data['message'] as String? ?? 'Notificación', // Mensaje por defecto
      requestId: data['requestId'] as String?,
      helperId: data['helperId'] as String?,
      requesterId: data['requesterId'] as String?,
      chatId: data['chatId'] as String?,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      isRead: data['isRead'] as bool? ?? false,
      requestData: data['data'] is String // Asume que 'data' en Firestore podría ser un String JSON
          ? (data['data'] != null ? Map<String, dynamic>.from(jsonDecode(data['data'])) : null)
          : (data['data'] as Map<String, dynamic>?), // O directamente un Map
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'userId': userId,
      'senderId': senderId,
      'message': message,
      'requestId': requestId,
      'helperId': helperId,
      'requesterId': requesterId,
      'chatId': chatId,
      'timestamp': timestamp,
      'isRead': isRead,
      'data': requestData, // Usar 'data' como clave para la compatibilidad con Cloud Functions
    };
  }
}
