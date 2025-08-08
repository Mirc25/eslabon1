// lib/services/app_services.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; // Importado para obtener la ubicación

class AppServices {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppServices(this._firestore, this._auth);

  static void showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> addComment(BuildContext context, String requestId, String commentText) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      AppServices.showSnackBar(context, 'Debes iniciar sesión para comentar.', Colors.red);
      return;
    }

    String userName = currentUser.displayName ?? 'Usuario Anónimo';
    String? userAvatar = currentUser.photoURL;

    if (currentUser.displayName == null || currentUser.displayName!.isEmpty || currentUser.photoURL == null) {
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          userName = userDoc.data()!['name'] ?? userName;
          userAvatar = userDoc.data()!['profilePicture'] ?? userAvatar;
        }
      } catch (e) {
        print('Error fetching user name/avatar for comment: $e');
      }
    }

    try {
      await _firestore
          .collection('solicitudes-de-ayuda')
          .doc(requestId)
          .collection('comments')
          .add({
        'userId': currentUser.uid,
        'userName': userName,
        'userAvatar': userAvatar,
        'text': commentText,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding comment: $e');
      AppServices.showSnackBar(context, 'Error al enviar comentario: $e', Colors.red);
    }
  }

  Future<void> createOfferAndNotifyRequester({
    required BuildContext context,
    required String requestId,
    required String requesterId,
    required String helperId,
    required String helperName,
    String? helperAvatarUrl,
    required String requestTitle,
    required Map<String, dynamic> requestData,
  }) async {
    try {
      await _firestore
          .collection('solicitudes-de-ayuda')
          .doc(requestId)
          .collection('offers')
          .add({
        'helperId': helperId,
        'requesterId': requesterId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'helperName': helperName,
        'helperAvatarUrl': helperAvatarUrl,
        'requestId': requestId,
      });

      await _firestore.collection('solicitudes-de-ayuda').doc(requestId).update({
        'offersCount': FieldValue.increment(1),
      });

      final notificationPayload = {
        'requestId': requestId,
        'requestTitle': requestData['titulo'],
        'receiverId': requesterId,
        'helperId': helperId,
        'helperName': helperName,
        'requestData': {
          'descripcion': requestData['descripcion'],
        },
        'priority': requestData['prioridad'],
        'location': {
          'latitude': requestData['latitude'],
          'longitude': requestData['longitude'],
        },
      };

      final Uri uri = Uri.parse('https://us-central1-eslabon-app.cloudfunctions.net/sendHelpNotification');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notificationPayload),
      );

      if (response.statusCode == 200) {
        print('Oferta creada y notificación HTTP enviada con éxito.');
      } else {
        throw Exception('Error al enviar la notificación HTTP: ${response.body}');
      }
    } catch (e) {
      print('Error al crear oferta y notificar: $e');
      AppServices.showSnackBar(context, 'Error al ofrecer ayuda.', Colors.red);
      rethrow;
    }
  }

  Future<void> addNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('users').doc(recipientId).collection('notifications').add({
        'type': type,
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'data': data ?? {},
      });
    } catch (e) {
      print('Error al añadir notificación: $e');
    }
  }

  Future<void> notifyHelperAfterRequesterRates({
    required BuildContext context,
    required String helperId,
    required String requesterId,
    required String requesterName,
    required double rating,
    required String requestId,
    required String requestTitle,
    String? reviewComment,
  }) async {
    try {
      await addNotification(
        recipientId: helperId,
        type: 'helper_rated',
        title: '¡Tienes una nueva calificación!',
        body: '¡Excelente trabajo! $requesterName te ha calificado con ${rating.toStringAsFixed(1)} estrellas.',
        data: {
          'notificationType': 'helper_rated',
          'navigationPath': '/rate-requester/$requestId',
          'requestId': requestId,
          'requesterId': requesterId,
          'requesterName': requesterName,
          'rating': rating,
          'reviewComment': reviewComment,
        },
      );
      print('Notificación de calificación enviada al ayudador.');
    } catch (e) {
      print('Error al notificar al ayudador sobre la calificación: $e');
      AppServices.showSnackBar(context, 'Error al enviar notificación de calificación.', Colors.red);
    }
  }

  Future<void> notifyRequesterAfterHelperRates({
    required BuildContext context,
    required String requesterId,
    required String helperId,
    required String helperName,
    required double rating,
    required String requestId,
    required String requestTitle,
    String? reviewComment,
  }) async {
    try {
      await addNotification(
        recipientId: requesterId,
        type: 'requester_rated',
        title: '¡Has recibido una nueva calificación!',
        body: '$helperName te ha calificado con ${rating.toStringAsFixed(1)} estrellas por tu solicitud.',
        data: {
          'notificationType': 'requester_rated',
          'requestId': requestId,
          'helperId': helperId,
          'helperName': helperName,
          'rating': rating,
          'reviewComment': reviewComment,
        },
      );
      print('Notificación de calificación enviada al solicitante.');
    } catch (e) {
      print('Error al notificar al solicitante sobre la calificación: $e');
      AppServices.showSnackBar(context, 'Error al enviar notificación de calificación.', Colors.red);
    }
  }

  Future<void> sendChatNotification({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String recipientId,
    required String messageText,
  }) async {
    final notificationPayload = {
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'recipientId': recipientId,
      'messageText': messageText,
    };

    final Uri uri = Uri.parse('https://us-central1-eslabon-app.cloudfunctions.net/sendChatNotification');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notificationPayload),
      );
      if (response.statusCode == 200) {
        print('Notificación de chat enviada con éxito.');
      } else {
        print('Error al enviar la notificación de chat: ${response.body}');
      }
    } catch (e) {
      print('Error de conexión al enviar notificación de chat: $e');
    }
  }

  Future<void> sendPanicAlert(BuildContext context) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      showSnackBar(context, 'Debes iniciar sesión para enviar una alerta.', Colors.red);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      if (userData == null || userData['name'] == null) {
        showSnackBar(context, 'Datos de perfil incompletos. No se puede enviar la alerta.', Colors.red);
        return;
      }
      
      final panicPayload = {
        'userId': currentUser.uid,
        'userName': userData['name'],
        'userPhone': userData['phone'],
        'userEmail': currentUser.email,
        'userPhotoUrl': userData['profilePicture'],
        'latitude': position.latitude,
        'longitude': position.longitude,
      };

      final Uri uri = Uri.parse('https://us-central1-eslabon-app.cloudfunctions.net/sendPanicNotification');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(panicPayload),
      );
      
      if (response.statusCode == 200) {
        print('Alerta de pánico enviada con éxito. Respuesta: ${response.body}');
        showSnackBar(context, '¡Alerta de pánico enviada a usuarios cercanos!', Colors.green);
      } else {
        print('Error al enviar la alerta de pánico: ${response.body}');
        showSnackBar(context, 'Error al enviar la alerta. Intenta de nuevo.', Colors.red);
      }
      
    } catch (e) {
      print("Error al enviar la alerta de pánico: $e");
      showSnackBar(context, 'Ocurrió un error al enviar la alerta.', Colors.red);
    }
  }

  Future<void> launchMap(BuildContext context, double latitude, double longitude) async {
    final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final Uri uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      AppServices.showSnackBar(context, 'No se pudo abrir Google Maps.', Colors.red);
    }
  }

  Future<void> launchWhatsapp(BuildContext context, String phoneNumber) async {
    String whatsappUrl = "whatsapp://send?phone=$phoneNumber";
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    } else {
      AppServices.showSnackBar(context, 'No se pudo abrir WhatsApp. Asegúrate de tener la aplicación instalada.', Colors.red);
    }
  }
}