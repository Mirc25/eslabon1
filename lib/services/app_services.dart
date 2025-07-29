// lib/services/app_services.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AppServices {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  AppServices(this.firestore, this.auth);

  void showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> addComment(BuildContext context, String requestId, String comment) async {
    final User? currentUser = auth.currentUser;
    if (currentUser == null) {
      showSnackBar(context, 'Debes iniciar sesión para comentar.', Colors.red);
      return;
    }

    try {
      await firestore
          .collection('solicitudes-de-ayuda')
          .doc(requestId)
          .collection('comments')
          .add({
        'userId': currentUser.uid,
        'userName': currentUser.displayName ?? 'Usuario Anónimo',
        'userAvatar': currentUser.photoURL,
        'text': comment,
        'timestamp': FieldValue.serverTimestamp(),
      });
      showSnackBar(context, 'Comentario enviado.', Colors.green);
    } catch (e) {
      showSnackBar(context, 'Error al enviar el comentario: $e', Colors.red);
      print('Error al agregar comentario: $e');
    }
  }

  Future<void> launchMap(BuildContext context, double latitude, double longitude) async {
    final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'; // Revisa esta URL
    final Uri uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      showSnackBar(context, 'No se pudo abrir el mapa. Asegúrate de tener una aplicación de mapas instalada.', Colors.red);
      print('No se pudo lanzar el mapa: $googleMapsUrl');
    }
  }

  Future<void> launchWhatsapp(BuildContext context, String phone) async {
    String formattedPhone = phone;
    if (!phone.startsWith('+')) {
      if (!phone.startsWith('54')) { 
          formattedPhone = '549$phone';
      }
      formattedPhone = '+$formattedPhone';
    }

    final String whatsappUrl = 'whatsapp://send?phone=$formattedPhone';
    final Uri uri = Uri.parse(whatsappUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      showSnackBar(context, 'No se pudo abrir WhatsApp. Asegúrate de tener WhatsApp instalado y el número sea correcto.', Colors.red);
      print('No se pudo lanzar WhatsApp: $whatsappUrl');
    }
  }

  Future<void> addNotification({
    required BuildContext context,
    required String recipientUserId,
    required String type, // ✅ Campo 'type' es requerido
    required String message,
    String? requestId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? chatPartnerId,
    String? requestTitle,
    Map<String, dynamic>? navigationData, // ✅ Campo 'navigationData' es opcional
  }) async {
    try {
      if (recipientUserId.isEmpty) {
        print('Error: recipientUserId es nulo o vacío en addNotification. No se puede guardar la notificación.');
        return;
      }
      await firestore
          .collection('users')
          .doc(recipientUserId)
          .collection('notifications')
          .add({
        'type': type,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        if (requestId != null) 'requestId': requestId,
        if (senderId != null) 'senderId': senderId,
        if (senderName != null) 'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        if (chatPartnerId != null) 'chatPartnerId': chatPartnerId,
        if (requestTitle != null) 'requestTitle': requestTitle,
        if (navigationData != null) 'navigationData': navigationData,
      });
      print('Notificación "$type" guardada en Firestore para $recipientUserId. Mensaje: $message');
    } catch (e) {
      showSnackBar(context, 'Error al guardar notificación en Firestore.', Colors.red);
      print('Error al guardar notificación "$type" en Firestore: $e');
    }
  }

  Future<void> sendRatingToCloudFunction({
    required String requestId,
    required String helperId,
    required String requesterId,
    required int rating,
    required String comment,
    required String ratedByUserName,
    String? ratedByUserPhotoUrl,
  }) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('sendRatingNotification');
      final result = await callable.call(<String, dynamic>{
        'requestId': requestId,
        'helperId': helperId,
        'requesterId': requesterId,
        'rating': rating,
        'comment': comment,
        'ratedByUserName': ratedByUserName,
        'ratedByUserPhotoUrl': ratedByUserPhotoUrl,
      });
      print('Resultado de Cloud Function sendRatingNotification: ${result.data}');
    } on FirebaseFunctionsException catch (e) {
      print('Error al llamar a Cloud Function sendRatingNotification: ${e.code} - ${e.message}');
      throw Exception('Error al enviar calificación: ${e.message}');
    } catch (e) {
      print('Error inesperado al llamar a Cloud Function sendRatingNotification: $e');
      throw Exception('Error inesperado al enviar calificación.');
    }
  }
}