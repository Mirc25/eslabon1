// lib/screens/rate_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/custom_app_bar.dart';
import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/utils/firestore_utils.dart'; // Para saveRating
import 'package:eslabon_flutter/user_reputation_widget.dart'; // Para mostrar la reputación

class RateOfferScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String helperId;
  final Map<String, dynamic>? requestData; // Datos de la solicitud, opcional

  const RateOfferScreen({
    Key? key,
    required this.requestId,
    required this.helperId,
    this.requestData,
  }) : super(key: key);

  @override
  ConsumerState<RateOfferScreen> createState() => _RateOfferScreenState();
}

class _RateOfferScreenState extends ConsumerState<RateOfferScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final AppServices _appServices;
  double _currentRating = 0.0; // Calificación inicial
  bool _hasRated = false; // Estado para evitar doble calificación

  String? _helperName;
  String? _helperAvatarUrl;
  String? _requestTitle;
  String? _requesterId; // El ID del usuario actual (solicitante)

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
    _loadDataAndCheckRatingStatus();
  }

  Future<void> _loadDataAndCheckRatingStatus() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      AppServices.showSnackBar(context, 'Debes iniciar sesión para calificar.', Colors.red);
      return;
    }
    _requesterId = currentUser.uid; // El usuario actual es el solicitante

    // Cargar datos del ayudador
    final helperDoc = await _firestore.collection('users').doc(widget.helperId).get();
    if (helperDoc.exists) {
      final data = helperDoc.data() as Map<String, dynamic>;
      setState(() {
        _helperName = data['name'] ?? 'Ayudador Desconocido';
        _helperAvatarUrl = data['profilePicture'];
      });
    } else {
      AppServices.showSnackBar(context, 'Error: Datos del ayudador no encontrados.', Colors.red);
      return;
    }

    // Cargar datos de la solicitud si no se pasaron
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

    // Verificar si el solicitante ya calificó a este ayudador para esta solicitud
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'Calificar Oferta',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: _helperName == null || _requestTitle == null
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ✅ Logo de la app centrado
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                child: Center(
                  child: Image.asset(
                    'assets/icon.jpg', // Ruta de tu logo
                    height: 60, // Tamaño del logo
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[700],
                backgroundImage: (_helperAvatarUrl != null && _helperAvatarUrl!.startsWith('http'))
                    ? NetworkImage(_helperAvatarUrl!)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
              const SizedBox(height: 16),
              Text(
                _helperName!,
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
