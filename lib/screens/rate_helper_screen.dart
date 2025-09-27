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
  
  Map<String, dynamic> currentRequestData = {};

  double _currentRating = 0.0;
  bool _hasRated = false;
  bool _loading = true;

  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('🚀 [RATE_HELPER] INIT: requestId=${widget.requestId}, helperId=${widget.helperId}, helperName=${widget.helperName}');
    print('🚀 [RATE_HELPER] WIDGET PARAMS: ${widget.toString()}');
    _loadData();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
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
                        backgroundImage: (_helperAvatarUrl != null && _helperAvatarUrl!.isNotEmpty)
                            ? NetworkImage(_helperAvatarUrl!)
                            : null,
                        child: (_helperAvatarUrl == null || _helperAvatarUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(widget.helperName),
                      subtitle: Text(_helperPhone ?? 'no_phone'.tr()),
                      tileColor: Colors.white.withOpacity(.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _requestTitle ?? 'help_request'.tr(),
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
                      child: Text('send_rating_button'.tr()),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _loadData() async {
  print('📊 [RATE_HELPER] _loadData() iniciado');
  
  final currentUser = _auth.currentUser;
  if (currentUser == null) {
    print('❌ [RATE_HELPER] Usuario no autenticado');
    AppServices.showSnackBar(context, 'Usuario no autenticado.', Colors.red);
    if (mounted) context.pop();
    return;
  }
  
  print('👤 [RATE_HELPER] Usuario actual: ${currentUser.uid}');
  print('🎯 [RATE_HELPER] Helper a calificar: ${widget.helperId}');
  print('📋 [RATE_HELPER] Request ID: ${widget.requestId}');

  setState(() {
    _loading = true;
  });

  try {
    // Obtener datos de la solicitud
    print('🔍 [RATE_HELPER] Obteniendo datos de solicitud...');
    final requestDoc = await _firestore
        .collection('solicitudes-de-ayuda')
        .doc(widget.requestId)
        .get();
  
    if (!requestDoc.exists) {
      print('❌ [RATE_HELPER] Solicitud no encontrada: ${widget.requestId}');
      AppServices.showSnackBar(context, 'Solicitud no encontrada.', Colors.red);
      if (mounted) context.pop();
      return;
    }

    currentRequestData = requestDoc.data() as Map<String, dynamic>;
    print('📋 [RATE_HELPER] Datos de solicitud obtenidos: $currentRequestData');
    print('📋 [RATE_HELPER] Propietario de solicitud (userId): ${currentRequestData['userId']}');
  
    // CRITICAL VALIDATION: Check for self-rating
    // En RateHelperScreen, el SOLICITANTE (currentUser) califica al AYUDADOR (helperId)
    // Solo debe impedir si el usuario intenta calificarse a sí mismo
    print('🔍 [RATE_HELPER] === VALIDACIÓN DE AUTO-CALIFICACIÓN ===');
    print('🔍 [RATE_HELPER] currentUser.uid: "${currentUser.uid}" (tipo: ${currentUser.uid.runtimeType})');
    print('🔍 [RATE_HELPER] widget.helperId: "${widget.helperId}" (tipo: ${widget.helperId.runtimeType})');
    print('🔍 [RATE_HELPER] ¿Son iguales? ${currentUser.uid == widget.helperId}');
    print('🔍 [RATE_HELPER] Comparación string: "${currentUser.uid.toString()}" == "${widget.helperId.toString()}" = ${currentUser.uid.toString() == widget.helperId.toString()}');
    
    if (currentUser.uid == widget.helperId) {
      print('❌ [RATE_HELPER] ERROR: Auto-calificación detectada! Usuario intenta calificarse a sí mismo');
      print('❌ [RATE_HELPER] currentUser.uid=${currentUser.uid} == helperId=${widget.helperId}');
      AppServices.showSnackBar(context, 'No puedes calificarte a ti mismo.', Colors.red);
      if (mounted) {
        context.pop();
      }
      return;
    }
    
    print('✅ [RATE_HELPER] Validación de auto-calificación PASADA');
  
    // VALIDACIÓN ADICIONAL: Verificar que el currentUser sea realmente el solicitante
    // Usar los datos de la solicitud ya obtenidos
    final String requestOwnerId = currentRequestData['userId']?.toString() ?? '';
    print('🔍 [RATE_HELPER] === VALIDACIÓN DE PROPIETARIO ===');
    print('🔍 [RATE_HELPER] currentUser.uid: "${currentUser.uid}"');
    print('🔍 [RATE_HELPER] requestOwnerId: "$requestOwnerId"');
    print('🔍 [RATE_HELPER] ¿Es el propietario? ${currentUser.uid == requestOwnerId}');
    
    if (currentUser.uid != requestOwnerId) {
      print('❌ [RATE_HELPER] ERROR: Usuario no es el propietario de la solicitud, no puede calificar al helper');
      AppServices.showSnackBar(context, 'Solo el solicitante puede calificar al ayudador.', Colors.red);
      if (mounted) {
        context.pop();
      }
      return;
    }
    
    print('✅ [RATE_HELPER] Validación de propietario PASADA');

     // Continuar con la carga de datos del helper
     print('🔍 [RATE_HELPER] Obteniendo datos del helper...');
     final helperDoc = await _firestore.collection('users').doc(widget.helperId).get();
     if (helperDoc.exists) {
       final data = helperDoc.data() ?? {};
       _helperPhone = (data['phone']?.toString());
       _helperAvatarUrl = (data['profilePicture']?.toString());
       print('👤 [RATE_HELPER] Datos del helper obtenidos: phone=${_helperPhone}, avatar=${_helperAvatarUrl}');
     } else {
       print('⚠️ [RATE_HELPER] No se encontraron datos del helper: ${widget.helperId}');
     }

     // Verificar si ya se calificó
     print('🔍 [RATE_HELPER] Verificando si ya se calificó...');
     final existing = await _firestore
         .collection('ratings')
         .where('requestId', isEqualTo: widget.requestId)
         .where('sourceUserId', isEqualTo: currentUser.uid)
         .where('targetUserId', isEqualTo: widget.helperId)
         .where('type', isEqualTo: 'helper_rating')
         .limit(1)
         .get();

     print('🔍 [RATE_HELPER] Consulta de rating existente: ${existing.docs.length} documentos encontrados');

     if (!mounted) return;
     setState(() {
       _hasRated = existing.docs.isNotEmpty;
       _loading = false;
       _requesterId = currentUser.uid; // Asignar el ID del usuario actual
     });

     print('✅ [RATE_HELPER] Carga de datos completada. _hasRated=$_hasRated, _requesterId=$_requesterId');

     if (_hasRated) {
       print('⚠️ [RATE_HELPER] Usuario ya calificó a este helper');
       AppServices.showSnackBar(context, 'Ya has calificado a este ayudador para esta ayuda.', Colors.orange);
     }
   } catch (e) {
      print('❌ [RATE_HELPER] Error en _loadData: $e');
      if (!mounted) return;
      AppServices.showSnackBar(context, 'Error cargando datos: $e', Colors.red);
      setState(() {
        _loading = false;
      });
     }
   }
}
