// lib/screens/rate_requester_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/utils/firestore_utils.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/custom_app_bar.dart';
import 'package:eslabon_flutter/user_reputation_widget.dart';

class RateRequesterScreen extends StatefulWidget {
  final String requestId;
  final String? requesterId;
  final String? requesterName;

  const RateRequesterScreen({
    Key? key,
    required this.requestId,
    this.requesterId,
    this.requesterName,
  }) : super(key: key);

  @override
  State<RateRequesterScreen> createState() => _RateRequesterScreenState();
}

class _RateRequesterScreenState extends State<RateRequesterScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final AppServices _appServices;
  double _currentRating = 0.0;
  String? _requesterName;
  String? _requesterId;
  String? _requestTitle;
  String? _requesterAvatarUrl;
  bool _hasRated = false;
  bool _isLoading = true;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
    
    // ⭐ DEBUGGING: Logging IDs al recibir argumentos
    final currentUser = _auth.currentUser;
    print('⭐ currentUser=${currentUser?.uid}');
    print('⭐ args: requestId=${widget.requestId} requesterId=${widget.requesterId} requesterName=${widget.requesterName}');
    
    _loadRequesterData();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadRequesterData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      print('🔍 [RATE_REQUESTER] === DEBUGGING PARAMETERS ===');
      print('🔍 [RATE_REQUESTER] currentUser.uid: ${currentUser?.uid}');
      print('🔍 [RATE_REQUESTER] widget.requestId: ${widget.requestId}');
      print('🔍 [RATE_REQUESTER] widget.requesterId: ${widget.requesterId}');
      print('🔍 [RATE_REQUESTER] widget.requesterName: ${widget.requesterName}');
      print('🔍 [RATE_REQUESTER] === END DEBUGGING PARAMETERS ===');
      
      _requesterId = widget.requesterId;
      _requesterName = widget.requesterName;

      // 🛡️ BARRERA 1: Implementando las tres barreras como sugirió ChatGPT
      // Obtener información completa de la solicitud para validar correctamente
      final requestDoc = await _firestore.collection('solicitudes-de-ayuda').doc(widget.requestId).get();
      if (!requestDoc.exists) {
        AppServices.showSnackBar(context, 'Error: Solicitud no encontrada.', Colors.red);
        if (mounted) context.pop();
        return;
      }

      final requestData = requestDoc.data()!;
      _requestTitle = requestData['titulo'] ?? requestData['descripcion'] ?? 'Solicitud de ayuda';

      if (_requesterId == null || _requesterName == null) {
        // Si los parámetros no vienen de la notificación, obtener el requester de la solicitud
        // En RateRequesterScreen, el helper califica al requester (userId/owner de la solicitud)
        _requesterId = requestData['userId'];  // El owner/requester de la solicitud
        _requesterName = requestData['userName'] ?? 'Solicitante Desconocido';
      }
      
      // 🧪 ASSERT LOG: Validación antes del auto-rating
      assert(() {
        print('🧪 VALIDACION: current=${currentUser?.uid} '
              'vs requesterId=$_requesterId type=rate_requester');
        return true;
      }());
      
      // CRITICAL VALIDATION: Check for self-rating
      // En RateRequesterScreen, el AYUDADOR (currentUser) califica al SOLICITANTE (requesterId)
      // Solo debe impedir si el usuario intenta calificarse a sí mismo
      print('[RATE_REQUESTER] VALIDATION: currentUser.uid="${currentUser?.uid}" vs requesterId="$_requesterId"');
      print('[RATE_REQUESTER] VALIDATION: Types - currentUser.uid: ${currentUser?.uid.runtimeType}, requesterId: ${_requesterId.runtimeType}');
      print('[RATE_REQUESTER] VALIDATION: String comparison: "${currentUser?.uid?.toString()}" == "${_requesterId?.toString()}" = ${currentUser?.uid?.toString() == _requesterId?.toString()}');
      
      if (currentUser != null && currentUser.uid?.toString() == _requesterId?.toString()) {
        print('[RATE_REQUESTER] ERROR: Self-rating detected! User trying to rate themselves');
        AppServices.showSnackBar(context, 'No puedes calificarte a ti mismo.', Colors.red);
        if (mounted) {
           if (Navigator.of(context).canPop()) {
             Navigator.of(context).pop();
           } else {
             context.go('/main');
           }
         }
        return;
      }
      
      // VALIDACIÓN ADICIONAL: Verificar que el currentUser sea realmente un ayudador de esta solicitud
      // Buscar en las ofertas de ayuda para confirmar que este usuario ofreció ayuda
      final offersQuery = await _firestore
          .collection('help_requests')
          .doc(widget.requestId)
          .collection('offers')
          .where('userId', isEqualTo: currentUser?.uid)
          .get();
      
      if (offersQuery.docs.isEmpty) {
        print('[RATE_REQUESTER] ERROR: User is not a helper for this request, cannot rate requester');
        AppServices.showSnackBar(context, 'Solo los ayudadores pueden calificar al solicitante.', Colors.red);
        if (mounted) {
           if (Navigator.of(context).canPop()) {
             Navigator.of(context).pop();
           } else {
             context.go('/main');
           }
         }
        return;
      }

      final requesterDoc = await _firestore.collection('users').doc(_requesterId).get();
      if (requesterDoc.exists) {
          _requesterAvatarUrl = requesterDoc.data()?['profilePicture'] as String?;
      }
      if (currentUser == null) {
        AppServices.showSnackBar(context, 'Debes iniciar sesión para calificar.', Colors.red);
        if (mounted) context.go('/login');
        return;
      }

      // 🔍 DEBUG: Logging para diagnosticar el problema
      print("🔍 DEBUG rate_requester_screen:");
      print("  - currentUser.uid: ${currentUser.uid}");
      print("  - _requesterId: $_requesterId");
      print("  - widget.requesterId: ${widget.requesterId}");
      print("  - widget.requesterName: ${widget.requesterName}");
      print("  - widget.requestId: ${widget.requestId}");

      if (_requesterId == null) {
        AppServices.showSnackBar(context, 'Error: No se pudo identificar al solicitante.', Colors.red);
        if (mounted) context.pop();
        return;
      }
      final String? ownerId = requestData['userId'];
      final String? helperId = requestData['helperId'];
      
      print("🔍 DEBUG solicitud completa:");
      print("  - ownerId: $ownerId");
      print("  - helperId: $helperId");
      print("  - currentUser.uid: ${currentUser.uid}");

      // Calcular otherUserId según la lógica de ChatGPT
      final String? otherUserId;
      if (currentUser.uid == ownerId) {
        otherUserId = helperId; // Si soy el owner, califico al helper
      } else if (currentUser.uid == helperId) {
        otherUserId = ownerId; // Si soy el helper, califico al owner
      } else {
        otherUserId = null; // No soy parte de esta solicitud
      }

      print("🔍 DEBUG otherUserId calculado: $otherUserId");

      // Validaciones de las tres barreras
      if (otherUserId == null) {
        print("🚨 ERROR: No eres parte de esta solicitud");
        AppServices.showSnackBar(context, 'Error: No eres parte de esta solicitud.', Colors.red);
        if (mounted) context.go('/main');
        return;
      }

      if (otherUserId == currentUser.uid) {
        print("🚨 ERROR: Intentando auto-calificarse");
        AppServices.showSnackBar(context, 'No podés calificarte a vos mismo; solo a la otra persona del intercambio.', Colors.red);
        if (mounted) context.go('/main');
        return;
      }

      // Verificar que el otherUserId coincida con el _requesterId de la notificación
      if (otherUserId != _requesterId) {
        print("🚨 ERROR: Inconsistencia en los datos de la notificación");
        print("  - otherUserId calculado: $otherUserId");
        print("  - _requesterId de notificación: $_requesterId");
        AppServices.showSnackBar(context, 'Error: Inconsistencia en los datos. Por favor, intenta desde el historial.', Colors.red);
        if (mounted) context.go('/main');
        return;
      }

      final QuerySnapshot existingRatings = await _firestore
          .collection('ratings')
          .where('requestId', isEqualTo: widget.requestId)
          .where('sourceUserId', isEqualTo: currentUser.uid)
          .where('targetUserId', isEqualTo: _requesterId)
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
      if (mounted) {
        AppServices.showSnackBar(context, 'Error al cargar datos del solicitante: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      AppServices.showSnackBar(context, 'Ya has calificado a este solicitante.', Colors.orange);
      return;
    }

    try {
      final User? currentUser = _auth.currentUser;
      final helperName = currentUser?.displayName ?? 'Ayudador';

      await FirestoreUtils.saveRating(
        targetUserId: _requesterId!,
        sourceUserId: currentUser!.uid,
        rating: _currentRating,
        requestId: widget.requestId,
        comment: _reviewController.text,
        type: 'requester_rating',
      );
      setState(() {
        _hasRated = true;
      });
      AppServices.showSnackBar(context, 'Calificación enviada con éxito.', Colors.green);

      // Note: Notification is now sent automatically by ratingNotificationTrigger.js

      if (mounted) {
        context.go('/main');
      }
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
          title: 'Calificar Solicitante',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              print('🔍 [RATE_REQUESTER] Back button pressed, navigating back');
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                // If no previous route, go to main screen
                context.go('/main');
              }
            },
          ),
        ),
        body: _isLoading || _requesterName == null
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
                backgroundImage: (_requesterAvatarUrl != null && _requesterAvatarUrl!.startsWith('http'))
                    ? NetworkImage(_requesterAvatarUrl!)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
                child: (_requesterAvatarUrl == null || !_requesterAvatarUrl!.startsWith('http'))
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                _requesterName!,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (_requesterId != null)
                UserReputationWidget(userId: _requesterId!),
              const SizedBox(height: 24),
              Text(
                'Califica tu experiencia con ${_requesterName!} en la solicitud:\n"${_requestTitle!}"',
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

