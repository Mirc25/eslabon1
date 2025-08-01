// lib/services/notification_service.dart
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

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

  void handleNotificationNavigation(Map<String, dynamic> notificationData) {
    final Map<String, dynamic> fcmData = notificationData['data'] ?? {};
    final String? notificationType = fcmData['notificationType'];
    final String? notificationId = fcmData['notificationId'];
    final String? requestId = fcmData['requestId'];
    final String? helperId = fcmData['helperId'];
    final String? helperName = fcmData['helperName'];
    final String? requesterId = fcmData['requesterId'];
    final String? requesterName = fcmData['requesterName'];
    final dynamic ratingValue = fcmData['rating'];
    final String? ratingString = ratingValue is num ? ratingValue.toString() : (ratingValue is String ? ratingValue : null);
    final double? rating = ratingString != null ? double.tryParse(ratingString) : null;
    final String? navigationPath = fcmData['navigationPath'];
    
    Map<String, dynamic> decodedRequestData = {};
    if (fcmData['requestData'] != null) {
      if (fcmData['requestData'] is String) {
        try {
          decodedRequestData = jsonDecode(fcmData['requestData']!) as Map<String, dynamic>;
        } catch (e) {
          print('Error al decodificar requestData: $e');
        }
      } else if (fcmData['requestData'] is Map<String, dynamic>) {
        decodedRequestData = fcmData['requestData'] as Map<String, dynamic>;
      }
    }


    debugPrint('--- INICIO DEBUG NAVEGACIÓN ---');
    debugPrint('Datos de notificación recibidos:');
    debugPrint('  notificationType: $notificationType');
    debugPrint('  notificationId: $notificationId');
    debugPrint('  requestId: $requestId');
    debugPrint('  helperId: $helperId');
    debugPrint('  helperName: $helperName');
    debugPrint('  requesterId: $requesterId');
    debugPrint('  requesterName: $requesterName');
    debugPrint('  rating: $rating');
    debugPrint('  decodedRequestData: $decodedRequestData');
    debugPrint('  navigationPath: $navigationPath');
    debugPrint('  _router está disponible: ${_router != null}');

    if (_router == null) {
      debugPrint('  DEBUG NAVIGATION ERROR: GoRouter no está disponible.');
      return;
    }

    switch (notificationType) {
      case 'offer_received':
        if (requestId != null && helperId != null && helperName != null) {
          debugPrint('  Redirigiendo a calificar ayudador: $requestId / $helperId');
          _router.pushNamed(
            'rate-helper',
            pathParameters: {'requestId': requestId},
            extra: {
              'helperId': helperId,
              'helperName': helperName,
              'requestData': decodedRequestData,
            },
          );
        } else {
          debugPrint('  DEBUG NAVIGATION ERROR: Datos incompletos para "offer_received" (requestId, helperId o helperName faltantes).');
        }
        break;
      case 'helper_rated':
        if (requestId != null && requesterId != null && requesterName != null) {
          debugPrint('  Redirigiendo a calificar solicitante: $requestId / $requesterId');
          _router.pushNamed(
            'rate-requester',
            pathParameters: {'requestId': requestId},
            extra: {
              'requesterId': requesterId,
              'requesterName': requesterName,
              'requestId': requestId,
            },
          );
        } else {
          debugPrint('  DEBUG NAVIGATION ERROR: Datos incompletos para "helper_rated" (requestId, requesterId o requesterName faltantes).');
        }
        break;
      case 'new_request':
        if (requestId != null) {
          debugPrint('  Redirigiendo a detalles de nueva solicitud: $requestId');
          _router.pushNamed(
            'request_detail',
            pathParameters: {'requestId': requestId},
            extra: decodedRequestData,
          );
        } else {
          debugPrint('  DEBUG NAVIGATION ERROR: ID de solicitud faltante para "new_request".');
        }
        break;
      case 'chat_message':
        final String? chatPartnerId = fcmData['chatPartnerId'];
        final String? chatPartnerName = fcmData['chatPartnerName'];
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
        _router.go('/main');
        break;
    }
    debugPrint('--- FIN DEBUG NAVEGACIÓN ---');
  }
}