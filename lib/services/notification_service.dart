import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:eslabon_flutter/models/notification_model.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  GoRouter? _router;

  NotificationService();

  void setRouter(GoRouter router) {
    _router = router;
    debugPrint('GoRouter set in NotificationService');
  }

  Future<void> initialize() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    String? token = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification!.title}');
      }
      // handleMessage(message); // Puedes descomentar si quieres manejar la navegación en foreground
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message opened app from background: ${message.data}');
      handleMessage(message);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('App opened from terminated state: ${message.data}');
        handleMessage(message);
      }
    });
  }

  void handleMessage(RemoteMessage message) {
    if (_router == null) {
      debugPrint('Error: GoRouter not set in NotificationService.');
      return;
    }

    final data = message.data;
    final notificationType = data['type'];
    final requestId = data['requestId'];
    final helperId = data['helperId'];
    final requesterId = data['requesterId'];
    final chatPartnerId = data['chatPartnerId']; // ✅ Nuevo: Para chat
    final chatPartnerName = data['chatPartnerName']; // ✅ Nuevo: Para chat

    debugPrint('Handling message type: $notificationType');

    switch (notificationType) {
      case 'new_offer':
        if (requestId != null) {
          // Si una notificación de 'new_offer' lleva a la pantalla de detalle,
          // y la pantalla de detalle necesita el ID del que ofreció ayuda para el chat,
          // asegúrate de que el 'data' de la notificación lo incluya.
          _router!.go(
            '/request-detail/$requestId',
            extra: {
              'requesterId': requesterId, // El solicitante es el que recibe la oferta
              'helperId': helperId, // El ayudador que hizo la oferta
              'chatPartnerId': chatPartnerId, // El ID del que envió la oferta
              'chatPartnerName': chatPartnerName, // El nombre del que envió la oferta
            }
          );
        }
        break;
      case 'offer_accepted': // Notificación al AYUDADOR
        if (requestId != null && helperId != null && requesterId != null) {
          // Asumiendo que helperId es el ID del ayudador que la oferta fue aceptada
          // Y requesterId es el ID del solicitante.
          // Si queremos que el AYUDADOR califique al SOLICITANTE después de la ayuda,
          // esto es mejor manejarlo después de que la solicitud esté completada.
          // Por ahora, te enviará al chat de la solicitud.
          _router!.go(
            '/chat/${_getChatId(requesterId, helperId)}', // Generar ChatId
            extra: {
              'chatPartnerId': requesterId,
              'chatPartnerName': data['requesterName'], // Asumiendo que la notif tiene el nombre del solicitante
            }
          );
        }
        break;
      case 'rating_received': // Notificación a quien RECIBIÓ la calificación
        if (requesterId != null) { // Si el ID en la notificación es el requesterId, significa que el requester recibió calificación
          _router!.go(
            '/rate-requester/$requestId', // La ruta espera el requestId
            extra: {
              'requesterId': requesterId,
              'requesterName': data['requesterName'], // Asumiendo que la notif tiene el nombre
            }
          );
        }
        // También puede ser para un helper que recibe calificación
        if (helperId != null) {
          _router!.go(
            '/rate-helper/$requestId',
            extra: {
              'helperId': helperId,
              'helperName': data['helperName'],
            }
          );
        }
        break;
      case 'request_completed': // Notificación cuando la solicitud se completa
        if (requestId != null && (helperId != null || requesterId != null)) {
          // Si el que recibe la notificacion es el SOLICITANTE (le avisan que se completó)
          // Y el que debe calificar es el HELPER
          if (data['targetUserId'] == requesterId) { // Si esta notificación es para el SOLICITANTE
              _router!.go(
                  '/rate-helper/$requestId', // Ruta para calificar al ayudante
                  extra: {
                    'helperId': helperId, // El ayudante que debe calificar
                    'helperName': data['helperName'], // El nombre del ayudante
                    'requestData': data['requestData'], // Pasa los datos de la solicitud
                  }
              );
          }
          // Si el que recibe la notificacion es el AYUDADOR (le avisan que se completó)
          // Y el que debe calificar es el SOLICITANTE
          if (data['targetUserId'] == helperId) { // Si esta notificación es para el AYUDADOR
              _router!.go(
                  '/rate-requester/$requestId', // Ruta para calificar al solicitante
                  extra: {
                    'requesterId': requesterId, // El solicitante que debe calificar
                    'requesterName': data['requesterName'], // El nombre del solicitante
                  }
              );
          }
        }
        break;
      case 'requester_rates_helper_prompt': // Solicitante califica al ayudante (notificación específica)
        if (requestId != null && helperId != null) {
          _router!.go(
            '/rate-helper/$requestId',
            extra: {
              'helperId': helperId,
              'helperName': data['helperName'],
            }
          );
        }
        break;
      case 'helper_rates_requester_prompt': // Ayudador califica al solicitante (notificación específica)
        if (requestId != null && requesterId != null) {
          _router!.go(
            '/rate-requester/$requestId',
            extra: {
              'requesterId': requesterId,
              'requesterName': data['requesterName'],
            }
          );
        }
        break;
      default:
        _router!.go('/notifications'); // Si no coincide, va a la bandeja de entrada de notificaciones
        break;
    }
  }

  // Helper para generar Chat ID consistente (copia de _getChatId de RequestDetailScreen)
  String _getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('-');
  }
}