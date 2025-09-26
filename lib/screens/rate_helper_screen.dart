// lib/screens/rate_helper_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:easy_localization/easy_localization.dart';
import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/utils/firestore_utils.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/custom_app_bar.dart';

class RateHelperScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String helperId;
  final String helperName;
  final Map<String, dynamic>? requestData; // opcional

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
  final _firestore = FirebaseFirestore.instance;
  final _auth = firebase_auth.FirebaseAuth.instance;

  String? _requesterId;
  String? _requesterName;
  String? _requestTitle;
  String? _helperAvatarUrl;
  String? _helperPhone;

  double _currentRating = 0.0;
  bool _hasRated = false;
  bool _loading = true;

  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // ⭐ DEBUGGING: Logging IDs al recibir argumentos
    final currentUser = _auth.currentUser;
    print('⭐ currentUser=${currentUser?.uid}');
    print('⭐ args: requestId=${widget.requestId} helperId=${widget.helperId} helperName=${widget.helperName}');
    
    _loadRequesterAndRequestData();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadRequesterAndRequestData() async {
    try {
      final currentUser = _auth.currentUser;
      print('[RATE_HELPER] uid=${currentUser?.uid} requestId=${widget.requestId}');
      print('[RATE_HELPER] helperId=${widget.helperId} helperName=${widget.helperName}');
      
      if (currentUser == null) {
        _snack('Debes iniciar sesión para calificar.'.tr(), Colors.red);
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      _requesterId = currentUser.uid;
      _requesterName = currentUser.displayName?.toString() ?? 'Usuario'.tr();

      Map<String, dynamic> currentRequestData =
          (widget.requestData ?? await _fetchRequest(widget.requestId)) ?? {};

      _requestTitle = (currentRequestData['titulo']?.toString() ??
              currentRequestData['descripcion']?.toString() ??
              'Solicitud de ayuda'.tr());
              
      // 🧪 ASSERT LOG: Validación antes del auto-rating
      assert(() {
        print('🧪 VALIDACION: current=${currentUser.uid} '
              'vs helperId=${widget.helperId} type=rate_helper');
        return true;
      }());
      
      // CRITICAL VALIDATION: Check for self-rating
      // En RateHelperScreen, el SOLICITANTE (currentUser) califica al AYUDADOR (helperId)
      // Solo debe impedir si el usuario intenta calificarse a sí mismo
      print('[RATE_HELPER] VALIDATION: currentUser.uid=${currentUser.uid} vs helperId=${widget.helperId}');
      if (currentUser.uid == widget.helperId) {
        print('[RATE_HELPER] ERROR: Self-rating detected! User trying to rate themselves');
        _snack('No puedes calificarte a ti mismo.'.tr(), Colors.red);
        if (mounted) {
          context.pop();
        }
        return;
      }
      
      // VALIDACIÓN ADICIONAL: Verificar que el currentUser sea realmente el solicitante
      // Usar los datos de la solicitud ya obtenidos
      final String requestOwnerId = currentRequestData['userId']?.toString() ?? '';
      print('[RATE_HELPER] VALIDATION: currentUser.uid=${currentUser.uid} vs requestOwnerId=$requestOwnerId');
      
      if (currentUser.uid != requestOwnerId) {
        print('[RATE_HELPER] ERROR: User is not the request owner, cannot rate helper');
        _snack('Solo el solicitante puede calificar al ayudador.'.tr(), Colors.red);
        if (mounted) {
          context.pop();
        }
        return;
      }

      final helperDoc =
          await _firestore.collection('users').doc(widget.helperId).get();
      if (helperDoc.exists) {
        final data = helperDoc.data() ?? {};
        _helperPhone = (data['phone']?.toString());
        _helperAvatarUrl = (data['profilePicture']?.toString());
      }

      final existing = await _firestore
          .collection('ratings')
          .where('requestId', isEqualTo: widget.requestId)
          .where('sourceUserId', isEqualTo: _requesterId)
          .where('targetUserId', isEqualTo: widget.helperId)
          .where('type', isEqualTo: 'helper_rating')
          .limit(1)
          .get();

      if (!mounted) return;
      setState(() {
        _hasRated = existing.docs.isNotEmpty;
        _loading = false;
      });

      if (_hasRated) {
        _snack('Ya has calificado a este ayudador para esta ayuda.'.tr(), Colors.orange);
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Error cargando datos: $e'.tr(), Colors.red);
      setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchRequest(String id) async {
    final doc = await _firestore.collection('solicitudes-de-ayuda').doc(id).get();
    if (doc.exists) {
      return (doc.data() ?? {}) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> _submitRating() async {
    if (_currentRating == 0.0) {
      _snack('Por favor, selecciona una calificación.'.tr(), Colors.orange);
      return;
    }
    if (_hasRated) {
      _snack('Ya has calificado a este ayudador.'.tr(), Colors.orange);
      return;
    }
    if (_requesterId == null) {
      _snack('Error: usuario no autenticado.'.tr(), Colors.red);
      return;
    }

    try {
      await FirestoreUtils.saveRating(
        targetUserId: widget.helperId,
        sourceUserId: _requesterId!,
        rating: _currentRating,
        requestId: widget.requestId,
        comment: _reviewController.text.trim(),
        type: 'helper_rating',
      );

      if (!mounted) return;
      setState(() => _hasRated = true);
      _snack('Calificación enviada con éxito.'.tr(), Colors.green);
      context.pop();
    } catch (e) {
      _snack('No se pudo guardar la calificación: $e'.tr(), Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'Calificar Ayudador'.tr(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (_helperAvatarUrl != null && _helperAvatarUrl!.isNotEmpty)
                            ? NetworkImage(_helperAvatarUrl!)
                            : null,
                        child: (_helperAvatarUrl == null || _helperAvatarUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(widget.helperName),
                      subtitle: Text(_helperPhone ?? 'Sin teléfono'.tr()),
                      tileColor: Colors.white.withOpacity(.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _requestTitle ?? 'Solicitud de ayuda'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final idx = i + 1;
                        final filled = _currentRating >= idx;
                        return IconButton(
                          onPressed: _hasRated
                              ? null
                              : () => setState(() {
                                    _currentRating = idx.toDouble();
                                  }),
                          icon: Icon(
                            filled ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reviewController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Deja un comentario (opcional)'.tr(),
                        filled: true,
                        fillColor: Colors.white.withOpacity(.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintStyle: const TextStyle(color: Colors.white70),
                      ),
                      style: const TextStyle(color: Colors.white),
                      enabled: !_hasRated,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _hasRated ? null : _submitRating,
                      child: Text('Enviar calificación'.tr()),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
