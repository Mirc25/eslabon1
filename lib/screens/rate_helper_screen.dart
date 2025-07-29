// lib/screens/rate_helper_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class RateHelperScreen extends StatefulWidget {
  final String requestId;
  final String helperId; // ✅ AGREGADO: Id del ayudador
  final String helperName; // ✅ AGREGADO: Nombre del ayudador
  final Map<String, dynamic>? requestData; // Ya estaba

  const RateHelperScreen({
    super.key,
    required this.requestId,
    required this.helperId, // ✅ HACER REQUERIDO
    required this.helperName, // ✅ HACER REQUERIDO
    this.requestData,
  });

  @override
  State<RateHelperScreen> createState() => _RateHelperScreenState();
}

class _RateHelperScreenState extends State<RateHelperScreen> {
  double _rating = 0.0;
  // String? _helperId; // ✅ ELIMINADO: Ahora se obtiene del widget

  @override
  void initState() {
    super.initState();
    // No necesitas _fetchHelperId() si lo pasas al constructor.
    // _helperId = widget.helperId; // Puedes asignarlo si quieres una variable de estado local, pero no es estrictamente necesario.
  }

  // ✅ Puedes eliminar _fetchHelperId si ya no lo necesitas o adaptarlo.
  // Future<void> _fetchHelperId() async {
  //   try {
  //     final doc = await FirebaseFirestore.instance
  //         .collection('requests')
  //         .doc(widget.requestId)
  //         .get();
  //     if (doc.exists) {
  //       final data = doc.data() as Map<String, dynamic>?;
  //       setState(() {
  //         _helperId = data?['helperId'];
  //       });
  //     }
  //   } catch (e) {
  //     debugPrint('Error fetching helperId: $e');
  //   }
  // }


  Future<void> _submitRating() async {
    // Usar widget.helperId directamente
    if (widget.helperId == null || _rating == 0.0) { // ✅ Usar widget.helperId
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una calificación y asegúrate de tener el ID del ayudante.')),
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
        'helperId': widget.helperId, // ✅ Usar widget.helperId
        'raterId': userId,
        'rating': _rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Actualizar el promedio de calificación y el contador del ayudante
      final helperRef = firestore.collection('users').doc(widget.helperId); // ✅ Usar widget.helperId
      await firestore.runTransaction((transaction) async {
        final helperSnapshot = await transaction.get(helperRef);
        final data = helperSnapshot.data() as Map<String, dynamic>?;

        final currentRatings = data?['ratings'] as List<dynamic>? ?? [];
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
          'ratings': FieldValue.arrayUnion([_rating]),
        });
      });

      // Enviar notificación al ayudante de que ha recibido una calificación
      await firestore.collection('notifications').add({
        'userId': widget.helperId, // ✅ Usar widget.helperId
        'senderId': userId,
        'type': 'rating_received',
        'requestId': widget.requestId,
        'message': '¡Has recibido una nueva calificación de ayuda de ${FirebaseAuth.instance.currentUser?.displayName ?? 'un usuario'}!', // Puedes hacer esto más descriptivo
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'requestId': widget.requestId,
          'raterId': userId,
          'requestData': widget.requestData,
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calificación enviada con éxito.')),
      );

      context.go('/main');
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
            context.pop();
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Califica a ${widget.helperName} por su ayuda en la solicitud:'), // ✅ Usar widget.helperName
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
            // ✅ ELIMINADO el indicador de _helperId == null
            // Ya que _helperId ahora es requerido en el constructor
          ],
        ),
      ),
    );
  }
}