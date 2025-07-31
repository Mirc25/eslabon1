// lib/services/app_services.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class AppServices {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppServices(this._firestore, this._auth);

  // Método estático para mostrar SnackBar
  static void showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Método para añadir comentarios
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
          userAvatar = userDoc.data()!['photoUrl'] ?? userAvatar;
        }
      } catch (e) {
        print('Error fetching user name/avatar: $e');
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

  // Método para lanzar Google Maps
  Future<void> launchGoogleMaps(BuildContext context, double latitude, double longitude) async {
    final String googleMapsUrl = 'http://googleusercontent.com/maps.google.com/10';
    final Uri uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      AppServices.showSnackBar(context, 'No se pudo abrir Google Maps.', Colors.red);
    }
  }

  // Método para lanzar WhatsApp
  Future<void> launchWhatsapp(BuildContext context, String phoneNumber) async {
    String whatsappUrl = "whatsapp://send?phone=$phoneNumber";
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    } else {
      AppServices.showSnackBar(context, 'No se pudo abrir WhatsApp. Asegúrate de tener la aplicación instalada.', Colors.red);
    }
  }
}