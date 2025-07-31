// lib/services/app_services.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class AppServices {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppServices(this._firestore, this._auth);

  // Método estático para mostrar SnackBar en cualquier parte de la app
  static void showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Método para añadir comentarios a una solicitud
  Future<void> addComment(BuildContext context, String requestId, String commentText) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      AppServices.showSnackBar(context, 'Debes iniciar sesión para comentar.', Colors.red);
      return;
    }

    String userName = currentUser.displayName ?? 'Usuario Anónimo';
    String? userAvatar = currentUser.photoURL;

    // Intenta obtener el nombre y avatar del perfil de usuario si no están en Firebase Auth
    if (currentUser.displayName == null || currentUser.displayName!.isEmpty || currentUser.photoURL == null) {
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          userName = userDoc.data()!['name'] ?? userName;
          userAvatar = userDoc.data()!['profilePicture'] ?? userAvatar; // Usa 'profilePicture' del perfil
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

  // ✅ ACTUALIZADO: Método para crear una oferta de ayuda y notificar al solicitante
  Future<void> createOfferAndNotifyRequester({
    required BuildContext context,
    required String requestId,
    required String requesterId,
    required String helperId,
    required String helperName,
    String? helperAvatarUrl,
    required String requestTitle,
    required Map<String, dynamic> requestData, // Datos completos de la solicitud
  }) async {
    try {
      // 1. Crear el documento de oferta en una subcolección 'offers' de la solicitud
      await _firestore
          .collection('solicitudes-de-ayuda')
          .doc(requestId)
          .collection('offers')
          .add({
        'helperId': helperId,
        'requesterId': requesterId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // Estado inicial de la oferta
        'helperName': helperName,
        'helperAvatarUrl': helperAvatarUrl,
        'requestId': requestId, // Referencia a la solicitud
      });

      // 2. Actualizar la solicitud para indicar que tiene una nueva oferta (opcional, pero útil)
      await _firestore.collection('solicitudes-de-ayuda').doc(requestId).update({
        'offersCount': FieldValue.increment(1),
      });

      // 3. Enviar notificación al solicitante para que CALIFIQUE al ayudador
      // ✅ CORREGIDO: Asegurando que 'navigationPath' esté en el nivel superior de 'data'
      await addNotification(
        recipientId: requesterId,
        type: 'offer_received',
        title: '¡Nueva oferta de ayuda!',
        body: '$helperName ha ofrecido ayuda para tu solicitud: "$requestTitle". ¡Por favor, coordina con él!',
        data: {
          'notificationType': 'offer_received',
          'navigationPath': '/rate-helper/$requestId', // ✅ Asegurado que navigationPath esté aquí
          'requestId': requestId,
          'helperId': helperId,
          'helperName': helperName,
          'requestData': requestData,
        },
      );

      print('Oferta creada y notificación enviada con éxito.');

    } catch (e) {
      print('Error al crear oferta y notificar: $e');
      AppServices.showSnackBar(context, 'Error al ofrecer ayuda.', Colors.red);
      rethrow; // Re-lanzar el error para que _handleOfferHelp lo capture
    }
  }

  // Método para añadir notificaciones a la colección 'notifications'
  Future<void> addNotification({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'recipientId': recipientId,
        'type': type,
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'data': data ?? {}, // Los datos adicionales que incluyen navigationPath
      });
    } catch (e) {
      print('Error al añadir notificación: $e');
    }
  }

  // ✅ MÉTODO: notifyHelperAfterRequesterRates - Notificación al AYUDADOR después de que el SOLICITANTE lo califica
  Future<void> notifyHelperAfterRequesterRates({
    required BuildContext context,
    required String helperId, // El ayudador que fue calificado (recipiente de la notificación)
    required String requesterId, // El solicitante que calificó (el que envía la calificación)
    required String requesterName, // Nombre del solicitante que calificó
    required double rating,
    required String requestId,
    required String requestTitle,
  }) async {
    // Este es un comentario adicional para forzar la actualización del Canvas.
    try {
      await addNotification(
        recipientId: helperId, // El ayudador es el que recibe la notificación
        type: 'helper_rated',
        title: '¡Has sido calificado!',
        body: '$requesterName te ha calificado con ${rating.toStringAsFixed(1)} estrellas por tu ayuda en "$requestTitle".',
        data: {
          'notificationType': 'helper_rated',
          'navigationPath': '/rate-requester/$requestId', // La pantalla RateRequesterScreen necesita el requestId
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

  // Método para lanzar Google Maps con una ubicación específica
  Future<void> launchMap(BuildContext context, double latitude, double longitude) async {
    final String googleMapsUrl = 'https://maps.google.com/?q=$latitude,$longitude';
    final Uri uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      AppServices.showSnackBar(context, 'No se pudo abrir Google Maps.', Colors.red);
    }
  }

  // Método para lanzar WhatsApp con un número de teléfono
  Future<void> launchWhatsapp(BuildContext context, String phoneNumber) async {
    String whatsappUrl = "whatsapp://send?phone=$phoneNumber";
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    } else {
      AppServices.showSnackBar(context, 'No se pudo abrir WhatsApp. Asegúrate de tener la aplicación instalada.', Colors.red);
    }
  }
}
