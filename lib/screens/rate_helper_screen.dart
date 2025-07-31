// lib/screens/rate_helper_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../services/app_services.dart'; // Importa AppServices
import '../utils/firestore_utils.dart'; // Para la función saveRating
import '../user_reputation_widget.dart'; // Para mostrar la reputación

class RateHelperScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String helperId;
  final String helperName;
  final Map<String, dynamic>? requestData;

  const RateHelperScreen({
    Key? key,
    required this.requestId,
    required this.helperId,
    required this.helperName,
    this.requestData,
  }) : super(key: key);

  @override
  ConsumerState<RateHelperScreen> createState() => _RateHelperScreenState();
}

class _RateHelperScreenState extends ConsumerState<RateHelperScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final AppServices _appServices; // Instancia de AppServices
  double _currentRating = 0.0; // Valor inicial de la calificación
  bool _hasRated = false; // Para saber si el usuario ya calificó

  // Datos del solicitante actual (el que está calificando)
  String? _requesterName;
  String? _requesterId;
  String? _requestTitle; // Título de la solicitud

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth); // Inicializar AppServices
    _loadRequesterAndRequestData();
  }

  Future<void> _loadRequesterAndRequestData() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      AppServices.showSnackBar(context, 'Debes iniciar sesión para calificar.', Colors.red);
      return;
    }
    _requesterId = currentUser.uid;
    _requesterName = currentUser.displayName ?? 'Usuario';

    // Si requestData no se pasó, cárgalo
    Map<String, dynamic>? currentRequestData = widget.requestData;
    if (currentRequestData == null) {
      final requestDoc = await _firestore.collection('solicitudes-de-ayuda').doc(widget.requestId).get();
      if (requestDoc.exists) {
        currentRequestData = requestDoc.data() as Map<String, dynamic>;
      }
    }

    if (currentRequestData != null) {
      _requestTitle = currentRequestData['titulo'] ?? currentRequestData['descripcion'] ?? 'Solicitud de ayuda';
    } else {
      AppServices.showSnackBar(context, 'Error: Datos de la solicitud no encontrados.', Colors.red);
      return;
    }

    // Verificar si el solicitante ya calificó al ayudador
    final QuerySnapshot existingRatings = await _firestore
        .collection('ratings')
        .where('requestId', isEqualTo: widget.requestId)
        .where('raterUserId', isEqualTo: _requesterId) // El solicitante es el que califica
        .where('ratedUserId', isEqualTo: widget.helperId) // El ayudador es el calificado
        .where('type', isEqualTo: 'helper_rating')
        .limit(1)
        .get();

    if (existingRatings.docs.isNotEmpty) {
      setState(() {
        _hasRated = true;
      });
      AppServices.showSnackBar(context, 'Ya has calificado a este ayudador para esta ayuda.', Colors.orange);
    }
  }

  // ✅ ACTUALIZADO: _submitRating para enviar calificación y notificar al ayudador
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
      AppServices.showSnackBar(context, 'Ya has calificado a este ayudador.', Colors.orange);
      return;
    }

    try {
      // 1. Guardar la calificación del solicitante al ayudador
      await FirestoreUtils.saveRating(
        targetUserId: widget.helperId, // El ayudador es el calificado
        sourceUserId: _requesterId!, // El solicitante es el que califica
        rating: _currentRating,
        requestId: widget.requestId,
        comment: '', // Puedes añadir un campo de comentario si lo deseas
        type: 'helper_rating', // Tipo de calificación
      );
      setState(() {
        _hasRated = true;
      });
      AppServices.showSnackBar(context, 'Calificación enviada con éxito.', Colors.green);

      // 2. Notificar al ayudador que ha sido calificado por el solicitante
      // ✅ CORREGIDO: Llamada al método con el nombre correcto
      await _appServices.notifyHelperAfterRequesterRates(
        context: context,
        helperId: widget.helperId, // El ayudador es el que recibe la notificación
        requesterId: _requesterId!, // El solicitante que calificó
        requesterName: _auth.currentUser!.displayName ?? 'Solicitante', // Nombre del solicitante que calificó
        rating: _currentRating,
        requestId: widget.requestId,
        requestTitle: _requestTitle!,
      );

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
          title: 'Calificar Ayudador',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: _requesterName == null || _requestTitle == null
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
                // Aquí deberías cargar la foto de perfil del ayudador (widget.helperId)
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                widget.helperName, // Muestra el nombre del ayudador
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              UserReputationWidget(userId: widget.helperId, fromRequesters: false), // Reputación del ayudador
              const SizedBox(height: 24),
              Text(
                'Califica la ayuda recibida para tu solicitud:\n"${_requestTitle!}"',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                    onPressed: _hasRated ? null : () { // Deshabilitar si ya calificó
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
                onPressed: _hasRated ? null : _submitRating, // Deshabilitar si ya calificó
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
