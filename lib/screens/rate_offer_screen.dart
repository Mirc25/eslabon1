// lib/screens/rate_offer_screen.dart
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
import 'package:eslabon_flutter/user_reputation_widget.dart';

class RateOfferScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String helperId;
  final Map<String, dynamic>? requestData; // opcional

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
  final _firestore = FirebaseFirestore.instance;
  final _auth = firebase_auth.FirebaseAuth.instance;

  String? _requesterId;
  String? _requestTitle;
  String? _helperName;
  String? _helperAvatarUrl;

  double _currentRating = 0.0;
  bool _hasRated = false;
  bool _loading = true;

  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDataAndCheckRatingStatus();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndCheckRatingStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _snack('Debes iniciar sesión para calificar.'.tr(), Colors.red);
        if (mounted) {
          context.go('/login');
        }
        return;
      }
      _requesterId = user.uid;

      final helperDoc =
          await _firestore.collection('users').doc(widget.helperId).get();
      if (helperDoc.exists) {
        final data = helperDoc.data() ?? {};
        _helperName = (data['name']?.toString() ?? 'Ayudador Desconocido'.tr());
        _helperAvatarUrl = (data['profilePicture']?.toString());
      } else {
        _snack('Error: Datos del ayudador no encontrados.'.tr(), Colors.red);
        if (mounted) {
          context.pop();
        }
        return;
      }

      Map<String, dynamic> currentRequestData =
          (widget.requestData ?? await _fetchRequest(widget.requestId)) ?? {};
      _requestTitle = (currentRequestData['titulo']?.toString() ??
              currentRequestData['descripcion']?.toString() ??
              'Solicitud de ayuda'.tr());

      final existing = await _firestore
          .collection('ratings')
          .where('requestId', isEqualTo: widget.requestId)
          .where('sourceUserId', isEqualTo: _requesterId)
          .where('ratedUserId', isEqualTo: widget.helperId)
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
          title: 'rate_helper_title'.tr(),
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
                        backgroundImage: (_helperAvatarUrl != null &&
                                _helperAvatarUrl!.isNotEmpty)
                            ? NetworkImage(_helperAvatarUrl!)
                            : null,
                        child: (_helperAvatarUrl == null ||
                                _helperAvatarUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(_helperName ?? 'Ayudador'.tr()),
                      subtitle: Text(_requestTitle ?? 'Solicitud de ayuda'.tr()),
                      tileColor: Colors.white.withOpacity(.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                        hintText: 'optional_comment'.tr(),
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
