// lib/services/app_services.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; // Importado para obtener la ubicación
import 'package:firebase_storage/firebase_storage.dart';

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

  /// Sube un archivo a Storage en `pending/{type}/{uid}/...` con metadata `docPath` (y `thumbnailPath` opcional)
  /// y marca el documento en Firestore como `pending`.
  /// Retorna la ruta completa en Storage donde quedó el archivo.
  Future<String> uploadPendingMedia({
    required String uid,
    required String type, // 'images' | 'videos'
    required File file,
    required String docPath,
    String? contentType,
    String? filename,
    String? thumbnailPath,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = file.path.split('.').last.toLowerCase();
    final name = filename ?? 'media_$ts.$ext';
    final storagePath = 'pending/$type/$uid/$name';

    final ref = FirebaseStorage.instance.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: contentType,
      customMetadata: {
        'docPath': docPath,
        if (thumbnailPath != null) 'thumbnailPath': thumbnailPath,
      },
    );

    await ref.putFile(file, metadata);

    // Marca el documento como pendiente para que la UI muestre "En revisión" al dueño
    await _firestore.doc(docPath).set({
      'moderation': {
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));

    return storagePath;
  }

  /// Crea un reporte de contenido para moderación manual
  Future<void> createReport({
    required String reporterUid,
    required String docPath,
    String? reason,
  }) async {
    await _firestore.collection('reports').add({
      'reporterUid': reporterUid,
      'docPath': docPath,
      'reason': reason,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
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
      print('🔄 INICIO: Creando oferta para requestId: $requestId');
      print('🔄 Datos: helperId=$helperId, helperName=$helperName');
      
      // Agregar la oferta a Firestore
      print('📝 PASO 1: Agregando oferta a Firestore...');
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
      print('✅ PASO 1: Oferta agregada a Firestore exitosamente');

      // Incrementar el contador de ofertas (verificar existencia y manejar FAILED_PRECONDITION)
      print('📝 PASO 2: Incrementando contador de ofertas...');
      final reqRef = _firestore.collection('solicitudes-de-ayuda').doc(requestId);
      final reqSnap = await reqRef.get();
      if (reqSnap.exists) {
        try {
          await reqRef.update({'offersCount': FieldValue.increment(1)});
          print('✅ PASO 2: Contador incrementado exitosamente');
        } on FirebaseException catch (e) {
          if (e.code == 'failed-precondition') {
            print('⚠️ PASO 2: Incremento omitido por FAILED_PRECONDITION');
          } else {
            rethrow;
          }
        }
      } else {
        print('⚠️ PASO 2: Request no existe, omito incremento de offersCount');
      }

      // Preparar datos para la notificación HTTP
      print('📝 PASO 3: Preparando datos para notificación HTTP...');
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
      print('✅ PASO 3: Datos preparados: ${jsonEncode(notificationPayload)}');

      final Uri uri = Uri.parse('https://sendhelpnotification-eeejjqorja-uc.a.run.app');
      print('📝 PASO 4: Enviando petición HTTP a: $uri');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(notificationPayload),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('❌ TIMEOUT: La petición HTTP tardó más de 30 segundos');
          throw TimeoutException('La petición tardó demasiado tiempo', const Duration(seconds: 30));
        },
      );

      print('📨 RESPUESTA HTTP: Status ${response.statusCode}');
      print('📨 RESPUESTA BODY: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ ÉXITO COMPLETO: Oferta creada y notificación HTTP enviada con éxito.');
      } else {
        print('❌ ERROR HTTP ${response.statusCode}: ${response.body}');
        throw Exception('Error al enviar la notificación HTTP (${response.statusCode}): ${response.body}');
      }
    } on SocketException catch (e) {
      print('Error de conexión de red: $e');
      AppServices.showSnackBar(context, 'Error de conexión. Verifica tu internet.', Colors.red);
      rethrow;
    } on TimeoutException catch (e) {
      print('Timeout al enviar notificación: $e');
      AppServices.showSnackBar(context, 'Tiempo de espera agotado. Intenta nuevamente.', Colors.red);
      rethrow;
    } on FormatException catch (e) {
      print('Error de formato en la respuesta: $e');
      AppServices.showSnackBar(context, 'Error de formato en la respuesta del servidor.', Colors.red);
      rethrow;
    } catch (e) {
      print('Error al crear oferta y notificar: $e');
      print('Tipo de error: ${e.runtimeType}');
      AppServices.showSnackBar(context, 'Error al ofrecer ayuda: ${e.toString()}', Colors.red);
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

  // ✅ Función CORREGIDA/VERIFICADA para notificar al ayudador y pedirle que califique.
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
        // Se añade el mensaje sobre el turno de calificar
        body: '¡Excelente trabajo! $requesterName te ha calificado con ${rating.toStringAsFixed(1)} estrellas y es tu turno para calificar.',
        data: {
          'notificationType': 'helper_rated',
          // La ruta debe llevar al ayudador a la pantalla para calificar al solicitante
          'route': '/rate-requester/$requestId?requesterId=$requesterId&requesterName=${Uri.encodeComponent(requesterName)}', 
          'requestId': requestId,
          'requesterId': requesterId,
          'requesterName': requesterName,
          'rating': rating,
          'reviewComment': reviewComment,
        },
      );
      print('Notificación de solicitud de calificación enviada al ayudador.');
    } catch (e) {
      print('Error al notificar al ayudador sobre la calificación: $e');
      AppServices.showSnackBar(context, 'Error al enviar notificación de solicitud de calificación.', Colors.red);
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
    required String receiverToken,
    required String senderName,
    required String message,
    required String chatId,
    required String senderId,
    required String receiverId,
    String? senderPhotoUrl,
  }) async {
    print('🔔 INICIANDO ENVÍO DE NOTIFICACIÓN');
    print('🔔 Receiver Token: ${receiverToken.isEmpty ? "VACÍO" : "Disponible (${receiverToken.length} chars)"}');
    print('🔔 Sender Name: $senderName');
    print('🔔 Message: $message');
    print('🔔 Chat ID: $chatId');
    
    if (receiverToken.isEmpty) {
      print('❌ ERROR: Token del receptor está vacío, no se puede enviar notificación');
      return;
    }
    
    try {
      // Obtener el contador de mensajes no leídos
      final unreadCount = await _getUnreadMessagesCount(chatId, receiverId);
      
      final requestBody = {
        'receiverToken': receiverToken,
        'title': 'Chat $senderName',
        'body': unreadCount > 1 
            ? '$unreadCount mensajes nuevos' 
            : message,
        'data': {
          'chatId': chatId,
          'senderId': senderId,
          'receiverId': receiverId,
          'senderName': senderName,
          'senderPhotoUrl': senderPhotoUrl ?? '',
          'route': '/chat/$chatId?partnerId=$senderId&partnerName=$senderName&partnerAvatar=${senderPhotoUrl ?? ''}',
          'type': 'chat_message',
          'unreadCount': unreadCount,
        }
      };
      
      print('🔔 Request Body: ${json.encode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('https://us-central1-pablo-oviedo.cloudfunctions.net/sendChatNotificationHTTP2'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('🔔 Response Status Code: ${response.statusCode}');
      print('🔔 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Chat notification sent successfully');
        // Guardar la notificación en Firestore para tracking
        await _saveNotificationToFirestore(receiverId, chatId, senderName, message, unreadCount, senderId, senderPhotoUrl);
      } else {
        print('❌ Error sending chat notification: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception sending chat notification: $e');
    }
  }

  Future<int> _getUnreadMessagesCount(String chatId, String receiverId) async {
    try {
      // Obtener el último timestamp de lectura del usuario
      final userDoc = await _firestore.collection('users').doc(receiverId).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final lastReadTimestamps = userData['lastReadTimestamps'] as Map<String, dynamic>? ?? {};
      final lastReadTimestamp = lastReadTimestamps[chatId] as Timestamp?;

      // Contar mensajes no leídos
      Query query = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: receiverId);

      if (lastReadTimestamp != null) {
        query = query.where('timestamp', isGreaterThan: lastReadTimestamp);
      }

      final unreadMessages = await query.get();
      return unreadMessages.docs.length;
    } catch (e) {
      print('Error getting unread messages count: $e');
      return 1; // Default to 1 if error
    }
  }

  Future<void> _saveNotificationToFirestore(String receiverId, String chatId, String senderName, String message, int unreadCount, String senderId, String? senderPhotoUrl) async {
    try {
      await _firestore
          .collection('users')
          .doc(receiverId)
          .collection('notifications')
          .add({
        'type': 'chat_message',
        'title': 'Chat $senderName',
        'body': message,
        'chatId': chatId,
        'senderName': senderName,
        'unreadCount': unreadCount,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'route': '/chat/$chatId?partnerId=$senderId&partnerName=$senderName&partnerAvatar=${senderPhotoUrl ?? ''}',
        'data': {
          'chatId': chatId,
          'senderId': senderId,
          'senderName': senderName,
          'senderPhotoUrl': senderPhotoUrl ?? '',
          'chatRoomId': chatId,
          'chatPartnerId': senderId,
          'chatPartnerName': senderName,
        },
      });
    } catch (e) {
      print('Error saving notification to Firestore: $e');
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