import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:eslabon_flutter/utils/firestore_utils.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para obtener el usuario actual

class RateRequesterScreen extends ConsumerStatefulWidget {
  final String? requesterId; 

  const RateRequesterScreen({
    super.key,
    required this.requesterId, 
  });

  @override
  ConsumerState<RateRequesterScreen> createState() => _RateRequesterScreenState();
}

class _RateRequesterScreenState extends ConsumerState<RateRequesterScreen> {
  double _currentRating = 3.0; 

  @override
  Widget build(BuildContext context) {
    if (widget.requesterId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('ID de solicitante no proporcionado.')),
      );
    }

    // Obtener el ID del usuario actual (el que califica)
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Usuario no autenticado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Calificar Solicitante')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Califica al solicitante (ID: ${widget.requesterId})',
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Slider(
                value: _currentRating,
                min: 1.0,
                max: 5.0,
                divisions: 4,
                label: _currentRating.toString(),
                onChanged: (double value) {
                  setState(() {
                    _currentRating = value;
                  });
                },
              ),
              Text('Tu calificación: ${_currentRating.toStringAsFixed(1)}'),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirestoreUtils.saveRating(
                      targetUserId: widget.requesterId!,
                      sourceUserId: currentUserId, // El usuario actual es quien califica
                      rating: _currentRating,
                      requestId: 'some_request_id', // <-- IMPORTANTE: Reemplaza con el ID REAL de la solicitud
                      type: 'requester_rating',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calificación guardada con éxito')),
                    );
                    context.go('/'); 
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al guardar la calificación: $e')),
                    );
                  }
                },
                child: const Text('Enviar Calificación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}