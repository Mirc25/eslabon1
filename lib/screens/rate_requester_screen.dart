// lib/screens/rate_requester_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/utils/firestore_utils.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/custom_app_bar.dart';

class RateRequesterScreen extends StatefulWidget {
  final String requestId; // ✅ Ahora recibe solo el requestId

  const RateRequesterScreen({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  State<RateRequesterScreen> createState() => _RateRequesterScreenState();
}

class _RateRequesterScreenState extends State<RateRequesterScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _currentRating = 0.0;
  String? _requesterName;
  String? _requesterId;
  String? _requestTitle;
  bool _hasRated = false;

  @override
  void initState() {
    super.initState();
    _loadRequesterData();
  }

  Future<void> _loadRequesterData() async {
    try {
      final requestDoc = await _firestore.collection('solicitudes-de-ayuda').doc(widget.requestId).get();
      if (requestDoc.exists) {
        final data = requestDoc.data() as Map<String, dynamic>;
        setState(() {
          _requesterName = data['nombre'] ?? 'Solicitante Desconocido';
          _requesterId = data['userId'];
          _requestTitle = data['titulo'] ?? data['descripcion'] ?? 'Solicitud de ayuda';
        });
      } else {
        AppServices.showSnackBar(context, 'Error: Solicitud no encontrada.', Colors.red);
        return;
      }

      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        AppServices.showSnackBar(context, 'Debes iniciar sesión para calificar.', Colors.red);
        return;
      }

      if (_requesterId == null) {
        AppServices.showSnackBar(context, 'Error: No se pudo identificar al solicitante.', Colors.red);
        return;
      }

      // ✅ CORREGIDO: Si el usuario actual es el solicitante, no debería calificar aquí.
      // Esta pantalla es para que el AYUDADOR califique al SOLICITANTE.
      if (currentUser.uid == _requesterId) {
        AppServices.showSnackBar(context, 'No puedes calificar tu propia solicitud aquí. Esta pantalla es para que califiques al solicitante.', Colors.red);
        // Puedes redirigir a /main o a una pantalla de error/información
        // context.go('/main');
        return;
      }

      final QuerySnapshot existingRatings = await _firestore
          .collection('ratings')
          .where('requestId', isEqualTo: widget.requestId)
          .where('raterUserId', isEqualTo: currentUser.uid) // El ayudador es el que califica
          .where('ratedUserId', isEqualTo: _requesterId) // El solicitante es el calificado
          .where('type', isEqualTo: 'requester_rating')
          .limit(1)
          .get();

      if (existingRatings.docs.isNotEmpty) {
        setState(() {
          _hasRated = true;
        });
        AppServices.showSnackBar(context, 'Ya has calificado a este solicitante para esta ayuda.', Colors.orange);
      }

    } catch (e) {
      print("Error loading requester data: $e");
      AppServices.showSnackBar(context, 'Error al cargar datos del solicitante: $e', Colors.red);
    }
  }

  // ✅ ACTUALIZADO: _submitRating para enviar calificación y notificar al solicitante
  Future<void> _submitRating() async {
    if (_currentRating == 0.0) {
      AppServices.showSnackBar(context, 'Por favor, selecciona una calificación.', Colors.orange);
      return;
    }
    if (_requesterId == null || _auth.currentUser == null) {
      AppServices.showSnackBar(context, 'Error: Datos de usuario o solicitante faltantes.', Colors.red);
      return;
    }
    if (_hasRated) {
      AppServices.showSnackBar(context, 'Ya has calificado a este solicitante.', Colors.orange);
      return;
    }

    try {
      // 1. Guardar la calificación del ayudador al solicitante
      await FirestoreUtils.saveRating(
        targetUserId: _requesterId!, // El solicitante es el calificado
        sourceUserId: _auth.currentUser!.uid, // El ayudador es el que califica
        rating: _currentRating,
        requestId: widget.requestId,
        comment: '', // Puedes añadir un campo de comentario si lo deseas
        type: 'requester_rating', // Tipo de calificación
      );
      setState(() {
        _hasRated = true;
      });
      AppServices.showSnackBar(context, 'Calificación enviada con éxito.', Colors.green);

      // ✅ ELIMINADO: La llamada a notifyRequesterOfRating (ahora notifyHelperAfterRequesterRates)
      // ya no va aquí, porque esta pantalla es para que el AYUDADOR califique al SOLICITANTE.
      // La notificación al AYUDADOR la envía el SOLICITANTE desde RateHelperScreen.
      // La notificación al SOLICITANTE de que fue calificado por el AYUDADOR es opcional y no se había pedido explícitamente aquí.
      // Si se desea, se podría añadir una llamada a addNotification aquí para notificar al solicitante.
      // Pero el ciclo principal se cierra con la notificación de RateHelperScreen.

      context.go('/main'); // Redirigir al main después de calificar
    } catch (e) {
      print("Error submitting rating: $e");
      AppServices.showSnackBar(context, 'Error al enviar calificación: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      showAds: false, // Puedes ajustar si quieres ads en esta pantalla
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'Calificar Solicitante',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: _requesterName == null
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[700],
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                _requesterName!,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Califica al solicitante por la ayuda recibida:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _currentRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                    onPressed: _hasRated ? null : () {
                      setState(() {
                        _currentRating = (index + 1).toDouble();
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu calificación: ${_currentRating.round()}/5',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _hasRated ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasRated ? Colors.grey : Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(_hasRated ? 'Calificado' : 'Enviar Calificación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
