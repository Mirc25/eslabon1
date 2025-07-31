// lib/services/notification_service.dart
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final GoRouter _router;

  NotificationService({required GoRouter appRouter}) : _router = appRouter {
    _initFirebaseMessaging();
  }

  void _initFirebaseMessaging() {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessage(message);
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      _handleMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(message);
    });
  }

  void _handleMessage(RemoteMessage message) {
    print("Received message: ${message.notification?.title}");
    print("Message data: ${message.data}");

    if (message.data.isNotEmpty) {
      handleNotificationNavigation(message.data);
    }
  }

  // ✅ ACTUALIZADO: Implementación de la lógica switch para navegación
  void handleNotificationNavigation(Map<String, dynamic> notificationData) {
    final String? notificationType = notificationData['type']; // ✅ Leer 'type' directamente
    final String? requestId = notificationData['requestId'];
    final String? helperId = notificationData['helperId'];
    final String? helperName = notificationData['helperName'];
    final Map<String, dynamic>? requestData = notificationData['requestData'] as Map<String, dynamic>?;
    final String? notificationId = notificationData['notificationId']; // Para marcar como leída

    debugPrint('--- INICIO DEBUG NAVEGACIÓN ---');
    debugPrint('Datos de notificación recibidos:');
    debugPrint('  notificationType: $notificationType');
    debugPrint('  requestId: $requestId');
    debugPrint('  helperId: $helperId');
    debugPrint('  helperName: $helperName');
    debugPrint('  requestData: $requestData');
    debugPrint('  notificationId: $notificationId');
    debugPrint('  _router está disponible: ${_router != null}');

    if (_router == null) {
      debugPrint('  DEBUG NAVIGATION ERROR: GoRouter no está disponible.');
      return;
    }

    // Marcar la notificación como leída en Firestore
    if (notificationId != null) {
      FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({'read': true});
      debugPrint('  Notificación $notificationId marcada como leída.');
    }

    switch (notificationType) {
      case 'offer_received':
        if (requestId != null && helperId != null) {
          debugPrint('  Redirigiendo a calificar ayudador: $requestId / $helperId');
          _router.go(
            '/rate-offer/$requestId/$helperId', // ✅ USADO: /rate-offer/:requestId/:helperId
            extra: {
              'helperId': helperId,
              'helperName': helperName,
              'requestData': requestData,
            },
          );
        } else {
          debugPrint('  DEBUG NAVIGATION ERROR: Datos incompletos para "offer_received" (requestId o helperId faltantes).');
        }
        break;
      case 'helper_rated': // Cuando el ayudador es calificado por el solicitante
        final String? requesterId = notificationData['requesterId'];
        final String? requesterName = notificationData['requesterName'];
        if (requestId != null && requesterId != null) {
          debugPrint('  Redirigiendo a calificar solicitante: $requestId / $requesterId');
          _router.go(
            '/rate-requester/$requestId', // ✅ USADO: /rate-requester/:requestId
            extra: {
              'requesterId': requesterId,
              'requesterName': requesterName,
            },
          );
        } else {
          debugPrint('  DEBUG NAVIGATION ERROR: Datos incompletos para "helper_rated" (requestId o requesterId faltantes).');
        }
        break;
      case 'new_request':
        if (requestId != null) {
          debugPrint('  Redirigiendo a detalles de nueva solicitud: $requestId');
          _router.go(
            '/request_detail/$requestId', // ✅ USADO: /request_detail/:requestId
            extra: requestData, // Pasa los datos de la solicitud si están disponibles
          );
        } else {
          debugPrint('  DEBUG NAVIGATION ERROR: ID de solicitud faltante para "new_request".');
        }
        break;
      case 'chat_message':
        final String? chatPartnerId = notificationData['chatPartnerId'];
        final String? chatPartnerName = notificationData['chatPartnerName'];
        if (chatPartnerId != null && chatPartnerName != null) {
          debugPrint('  Redirigiendo a chat con: $chatPartnerName ($chatPartnerId)');
          _router.go(
            '/chat/$chatPartnerId',
            extra: {'chatPartnerName': chatPartnerName},
          );
        } else {
          debugPrint('  DEBUG NAVIGATION ERROR: Datos de chat incompletos.');
        }
        break;
      default:
        debugPrint('  Tipo de notificación desconocido o sin lógica de navegación específica: $notificationType');
        // Opcional: Redirigir a una pantalla por defecto o mostrar un mensaje
        _router.go('/main'); // Redirige a la pantalla principal por defecto
        break;
    }
    debugPrint('--- FIN DEBUG NAVEGACIÓN ---');
  }
}
