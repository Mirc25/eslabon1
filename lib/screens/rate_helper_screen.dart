// lib/screens/rate_helper_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../services/app_services.dart';
import '../utils/firestore_utils.dart';
import '../user_reputation_widget.dart';

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
  late final AppServices _appServices;
  double _currentRating = 0.0;
  bool _hasRated = false;
  final TextEditingController _reviewController = TextEditingController();

  String? _requesterName;
  String? _requesterId;
  String? _requestTitle;
  String? _helperPhone;
  String? _helperAvatarUrl;

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
    _loadRequesterAndRequestData();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadRequesterAndRequestData() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      AppServices.showSnackBar(context, 'Debes iniciar sesión para calificar.', Colors.red);
      return;
    }
    _requesterId = currentUser.uid;
    _requesterName = currentUser.displayName ?? 'Usuario';

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

    final helperDoc = await _firestore.collection('users').doc(widget.helperId).get();
    if (helperDoc.exists) {
      _helperPhone = helperDoc.data()?['phone'] as String?;
      _helperAvatarUrl = helperDoc.data()?['profilePicture'] as String?;
    }

    final QuerySnapshot existingRatings = await _firestore
        .collection('ratings')
        .where('requestId', isEqualTo: widget.requestId)
        .where('sourceUserId', isEqualTo: _requesterId)
        .where('targetUserId', isEqualTo: widget.helperId)
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
      await FirestoreUtils.saveRating(
        targetUserId: widget.helperId,
        sourceUserId: _requesterId!,
        rating: _currentRating,
        requestId: widget.requestId,
        comment: _reviewController.text,
        type: 'helper_rating',
      );
      setState(() {
        _hasRated = true;
      });
      AppServices.showSnackBar(context, 'Calificación enviada con éxito.', Colors.green);

      await _appServices.notifyHelperAfterRequesterRates(
        context: context,
        helperId: widget.helperId,
        requesterId: _requesterId!,
        requesterName: _auth.currentUser!.displayName ?? 'Solicitante',
        rating: _currentRating,
        requestId: widget.requestId,
        requestTitle: _requestTitle!,
        reviewComment: _reviewController.text,
      );
      context.go('/main');
    } catch (e) {
      print("Error submitting rating: $e");
      AppServices.showSnackBar(context, 'Error al enviar calificación: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      showAds: false,
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
                backgroundImage: (_helperAvatarUrl != null && _helperAvatarUrl!.startsWith('http'))
                    ? NetworkImage(_helperAvatarUrl!)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
                child: (_helperAvatarUrl == null || !_helperAvatarUrl!.startsWith('http'))
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                widget.helperName,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (_helperPhone != null)
                Text(
                  _helperPhone!,
                  style: const TextStyle(
                      fontSize: 16, color: Colors.white70),
                ),
              UserReputationWidget(userId: widget.helperId, fromRequesters: false),
              const SizedBox(height: 24),
              Text(
                'Tu opinión importa. Califica la ayuda de ${widget.helperName} para la solicitud:\n"${_requestTitle!}"',
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
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: TextField(
                  controller: _reviewController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu reseña aquí...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
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
                child: Text(_hasRated ? 'Calificado' : 'Enviar Calificación y Reseña'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}