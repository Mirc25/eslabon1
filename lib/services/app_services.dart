// lib/services/app_services.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

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

      final Uri uri = Uri.parse('https://sendhelpnotification-zt5fozxika-uc.a.run.app');

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
  }) async {
    try {
      await addNotification(
        recipientId: helperId,
        type: 'helper_rated',
        title: '¡Has sido calificado!',
        body: '$requesterName te ha calificado con ${rating.toStringAsFixed(1)} estrellas por tu ayuda en "$requestTitle".',
        data: {
          'notificationType': 'helper_rated',
          'navigationPath': '/rate-requester/$requestId',
          'requestId': requestId,
          'requesterId': requesterId,
          'requesterName': requesterName,
          'rating': rating,
        },
      );
      print('Notificación de calificación enviada al ayudador.');
    } catch (e) {
      print('Error al notificar al ayudador sobre la calificación: $e');
      AppServices.showSnackBar(context, 'Error al enviar notificación de calificación.', Colors.red);
    }
  }

  Future<void> launchMap(BuildContext context, double latitude, double longitude) async {
    final String googleMapsUrl = 'https://maps.google.com/?q=$latitude,$longitude';
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