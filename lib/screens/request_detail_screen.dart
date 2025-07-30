import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/notification_service.dart';
import '../utils/firestore_utils.dart';

class RequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final String requestId;

  const RequestDetailScreen({
    Key? key,
    required this.requestData,
    required this.requestId,
  }) : super(key: key);

  @override
  _RequestDetailScreenState createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _isLoading = false;

  Future<void> _sendOffer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final helperId = FirebaseAuth.instance.currentUser?.uid;
      if (helperId == null) throw Exception('Usuario no autenticado');

      final requesterId = widget.requestData['userId'];
      final requestId = widget.requestId;

      // Actualizar solicitud con la oferta
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .update({'helperId': helperId});

      // Obtener datos del ayudador
      final helperSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(helperId)
          .get();
      final helperData = helperSnapshot.data();

      if (helperData == null) throw Exception('Datos del ayudador no encontrados');

      // Crear documento de notificación en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(requesterId)
          .collection('notifications')
          .add({
        'title': 'Nueva oferta de ayuda',
        'body': '${helperData['name']} quiere ayudarte',
        'type': 'new_offer',
        'timestamp': FieldValue.serverTimestamp(),
        'requestId': requestId,
        'helperId': helperId,
        'isRead': false,
      });

      // Enviar notificación push
      await NotificationService().sendPushNotification(
        receiverId: requesterId,
        title: 'Nueva oferta de ayuda',
        body: '${helperData['name']} quiere ayudarte',
        data: {
          'type': 'new_offer',
          'requestId': requestId,
          'helperId': helperId,
        },
      );

      // Mostrar confirmación
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Oferta enviada con éxito!')),
        );
        context.pop(); // Volver atrás o cerrar pantalla
      }
    } catch (e) {
      debugPrint('Error al enviar oferta: $e');
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              )
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.requestData;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalles de la Solicitud')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Descripción: ${request['description'] ?? ''}'),
            const SizedBox(height: 10),
            Text('Ubicación: ${request['locationName'] ?? ''}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendOffer,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Ofrecer Ayuda'),
            ),
          ],
        ),
      ),
    );
  }
}
