import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class RateHelperScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic>? requestData;

  const RateHelperScreen({
    super.key,
    required this.requestId,
    this.requestData,
  });

  @override
  State<RateHelperScreen> createState() => _RateHelperScreenState();
}

class _RateHelperScreenState extends State<RateHelperScreen> {
  double _rating = 0.0;
  String? _helperId;

  @override
  void initState() {
    super.initState();
    _fetchHelperId();
  }

  Future<void> _fetchHelperId() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('requests')
          .doc(widget.requestId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _helperId = data?['helperId'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching helperId: $e');
    }
  }

  Future<void> _submitRating() async {
    if (_helperId == null || _rating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una calificación.')),
      );
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final String? userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Usuario no autenticado.')),
        );
        return;
      }

      // Guardar la calificación
      await firestore.collection('ratings').add({
        'requestId': widget.requestId,
        'helperId': _helperId,
        'raterId': userId,
        'rating': _rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Actualizar el promedio de calificación y el contador del ayudante
      final helperRef = firestore.collection('users').doc(_helperId);
      await firestore.runTransaction((transaction) async {
        final helperSnapshot = await transaction.get(helperRef);
        final data = helperSnapshot.data() as Map<String, dynamic>?;

        final currentRatings = data?['ratings'] as List<dynamic>? ?? [];
        // No necesitamos currentAverageRating aquí si calculamos el nuevo promedio
        // final currentAverageRating = data?['averageRating'] as double? ?? 0.0;

        final List<double> allRatings = [];
        for (var r in currentRatings) {
          if (r is num) {
            allRatings.add(r.toDouble());
          }
        }
        allRatings.add(_rating);

        final newAverage = allRatings.isEmpty
            ? 0.0
            : allRatings.reduce((a, b) => a + b) / allRatings.length;

        transaction.update(helperRef, {
          'averageRating': newAverage,
          'ratingsCount': FieldValue.increment(1),
          'ratings': FieldValue.arrayUnion([_rating]), // Añade la nueva calificación al array
        });
      });

      // Enviar notificación al ayudante de que ha recibido una calificación
      await firestore.collection('notifications').add({
        'userId': _helperId, // El ayudador es el receptor de esta notificación
        'senderId': userId, // El que califica es el remitente
        'type': 'rating_received',
        'requestId': widget.requestId,
        'message': '¡Has recibido una nueva calificación de ayuda!',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'requestId': widget.requestId,
          'requesterId': userId, // El ID de quien calificó
          'requestData': widget.requestData, // Datos de la solicitud, stringified en la Cloud Function
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calificación enviada con éxito.')),
      );

      context.go('/main'); // Redirige a la pantalla principal después de calificar
    } catch (e) {
      debugPrint('Error al enviar calificación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar calificación: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calificar Ayudante'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop(); // Permite volver atrás
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Solicitud ID: ${widget.requestId}'),
            if (widget.requestData != null)
              Text('Descripción: ${widget.requestData!['descripcion'] ?? 'N/A'}'),
            const SizedBox(height: 20),
            Text('Calificación: ${_rating.toStringAsFixed(1)}'),
            Slider(
              value: _rating,
              min: 0,
              max: 5,
              divisions: 10,
              label: _rating.toStringAsFixed(1),
              onChanged: (newValue) {
                setState(() {
                  _rating = newValue;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitRating,
              child: const Text('Enviar Calificación'),
            ),
            if (_helperId == null)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            if (_helperId != null)
              Text('ID del ayudador: $_helperId'),
          ],
        ),
      ),
    );
  }
}
