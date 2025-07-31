// lib/services/app_services.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class AppServices {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppServices(this._firestore, this._auth);

  // Método para añadir comentarios (ya existía en tu MainScreen)
  Future<void> addComment(BuildContext context, String requestId, String commentText) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      _showSnackBar(context, 'Debes iniciar sesión para comentar.', Colors.red);
      return;
    }

    String userName = currentUser.displayName ?? 'Usuario Anónimo';
    String? userAvatar = currentUser.photoURL;

    // Puedes buscar el nombre y avatar del usuario desde Firestore si no están en Firebase Auth
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
          .collection('solicitudes-de-ayuda') // Asume esta es la colección de requests
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
      _showSnackBar(context, 'Error al enviar comentario: $e', Colors.red);
    }
  }

  // Método para lanzar Google Maps
  Future<void> launchGoogleMaps(BuildContext context, double latitude, double longitude) async {
    final String googleMapsUrl = 'http://googleusercontent.com/maps.google.com/8';
    final Uri uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar(context, 'No se pudo abrir Google Maps.', Colors.red);
    }
  }

  // Método para lanzar WhatsApp
  Future<void> launchWhatsapp(BuildContext context, String phoneNumber) async {
    String whatsappUrl = "whatsapp://send?phone=$phoneNumber";
    if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
      await launchUrl(Uri.parse(whatsappUrl));
    } else {
      _showSnackBar(context, 'No se pudo abrir WhatsApp. Asegúrate de tener la aplicación instalada.', Colors.red);
    }
  }

  // Método privado para mostrar SnackBar
  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}