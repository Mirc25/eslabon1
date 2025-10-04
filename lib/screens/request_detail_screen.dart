// lib/screens/request_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../widgets/avatar_optimizado.dart';

import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/user_reputation_widget.dart';
import 'package:eslabon_flutter/utils/firestore_utils.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/ad_banner_widget.dart';
import 'package:eslabon_flutter/services/ads_ids.dart';
import 'package:eslabon_flutter/widgets/spinning_image_loader.dart';
import '../widgets/custom_app_bar.dart';
import 'package:eslabon_flutter/services/inapp_notification_service.dart';
import 'package:eslabon_flutter/services/ads_service.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  final Map<String, dynamic>? requestData;

  // ✅ CORRECCIÓN: Usando la sintaxis explícita para Key para evitar la duplicidad
  const RequestDetailScreen({
    Key? key, 
    required this.requestId,
    this.requestData,
  }) : super(key: key); // Se corrige la referencia a super

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late final AppServices _appServices;

  final Map<String, TextEditingController> _commentControllers = {};
  
  // ✅ Sistema de caché para URLs de imágenes de perfil
  final Map<String, String> _profilePictureUrlCache = {};
  
  // ✅ Resolver URL de imagen con soporte de rutas http y Storage path
  Future<String> _resolveImageUrl(String path) async {
    if (path.isEmpty) return '';
    final cached = _profilePictureUrlCache[path];
    if (cached != null && cached.isNotEmpty) return cached;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      _profilePictureUrlCache[path] = path;
      return path;
    }
    try {
      final url = await _storage.ref().child(path).getDownloadURL();
      _profilePictureUrlCache[path] = url;
      return url;
    } catch (e) {
      print('Error resolving image URL for "$path": $e');
      return '';
    }
  }
  
  bool _hasOfferedHelp = false;
  bool _isLoading = true;
  bool _canRate = false;
  String? _acceptedHelperId;
  String? _acceptedHelperName;
  String _requestStatus = 'activa'; // ✅ CLAVE: Estado de la solicitud
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;
  List<DocumentSnapshot> _pendingOffers = []; // ✅ LISTA DE OFERTAS PENDIENTES

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
    _loadDataAndCheckOfferStatus();
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AdsIds.rewarded,
      request: AdsService.request(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          if (mounted) {
            setState(() {
              _rewardedAd = ad;
              _isRewardedAdLoaded = true;
            });
          }
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdLoaded = false;
              if (widget.requestData != null) {
                _goToChat(widget.requestData!['userId']?.toString() ?? 'error', widget.requestData!['requesterName']?.toString() ?? 'Usuario Anónimo', widget.requestData!['profilePicture']?.toString());
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdLoaded = false;
              print('❌ Error al mostrar RewardedAd: $error');
              if (widget.requestData != null) {
                _goToChat(widget.requestData!['userId']?.toString() ?? 'error', widget.requestData!['requesterName']?.toString() ?? 'Usuario Anónimo', widget.requestData!['profilePicture']?.toString());
              }
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (mounted) {
            setState(() {
              _isRewardedAdLoaded = false;
            });
          }
          AdsService.logLoadError(error, where: 'RequestDetailScreen.Rewarded');
        },
      ),
    );
  }

  @override
  void dispose() {
    _commentControllers.forEach((key, controller) => controller.dispose());
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<bool> _canShowRewardedAd() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('rewardedAdDate') ?? '';
    int viewsToday = prefs.getInt('rewardedAdViews') ?? 0;

    if (lastDate != today) {
      await prefs.setString('rewardedAdDate', today);
      await prefs.setInt('rewardedAdViews', 0);
      viewsToday = 0;
    }

    return viewsToday < 5;
  }

  Future<void> _incrementRewardedAdViews() async {
    final prefs = await SharedPreferences.getInstance();
    int viewsToday = prefs.getInt('rewardedAdViews') ?? 0;
    await prefs.setInt('rewardedAdViews', viewsToday + 1);
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showVideoPlayerBottomSheet(String videoUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return _VideoPlayerSheet(videoUrl: videoUrl);
      },
    );
  }

  void _navigateToRateHelper() {
    if (_acceptedHelperId != null && _acceptedHelperName != null) {
      context.push('/rate-helper/${widget.requestId}?helperId=$_acceptedHelperId&helperName=${Uri.encodeComponent(_acceptedHelperName!)}');
    }
  }
  
  Future<void> _finalizeRequest() async {
    if (_requestStatus != 'aceptada' || _acceptedHelperId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Verificar existencia del documento antes de actualizar
      final docRef = _firestore.collection('solicitudes-de-ayuda').doc(widget.requestId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        _showSnackBar('La solicitud no existe o fue eliminada.'.tr(), Colors.red);
      } else {
        // Actualizar el estado de la solicitud a 'finalizada'
        await docRef.update({
          'estado': 'finalizada',
          'finalizedAt': FieldValue.serverTimestamp(),
        });
        _showSnackBar('Ayuda marcada como finalizada. ¡Gracias!'.tr(), Colors.green);
      }
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        _showSnackBar('No se pudo finalizar: condición previa fallida.'.tr(), Colors.red);
      } else {
        _showSnackBar('Error al finalizar la ayuda: ${e.message}'.tr(), Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error al finalizar la ayuda: $e'.tr(), Colors.red);
    } finally {
      if (mounted) {
        await _loadDataAndCheckOfferStatus(); 
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 🚀 FUNCIÓN CRÍTICA FALTANTE: Aceptar la oferta y cambiar el estado
  Future<void> _acceptOffer(String offerId, String helperId, String helperName) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final requestRef = _firestore.collection('solicitudes-de-ayuda').doc(widget.requestId);
      final requestSnap = await requestRef.get();
      if (!requestSnap.exists) {
        _showSnackBar('La solicitud no existe o fue eliminada.'.tr(), Colors.red);
      } else {
        // 1. Marcar el estado de la solicitud como ACEPTADA (CLAVE)
        await requestRef.update({
          'estado': 'aceptada', // ESTO ES LO QUE DESBLOQUEA LA NAVEGACIÓN
          'helperId': helperId,
          'helperName': helperName,
          'acceptedOfferId': offerId,
        });

        // 2. Marcar la oferta específica como aceptada, si existe
        final offerRef = requestRef.collection('offers').doc(offerId);
        final offerSnap = await offerRef.get();
        if (offerSnap.exists) {
          await offerRef.update({'status': 'accepted'});
        } else {
          _showSnackBar('La oferta no existe o fue eliminada.'.tr(), Colors.red);
        }
      }

      // ✅ ACTUALIZAR ESTADO LOCAL para la navegación inmediata
      setState(() {
        _acceptedHelperId = helperId;
        _acceptedHelperName = helperName;
        _requestStatus = 'aceptada';
        _canRate = true; // El solicitante PUEDE calificar inmediatamente
      });
      
      _showSnackBar('Oferta de $helperName aceptada. ¡Redirigiendo a calificación!'.tr(), Colors.green);
      
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        _showSnackBar('No se pudo aceptar: condición previa fallida.'.tr(), Colors.red);
      } else {
        _showSnackBar('Error al aceptar la oferta: ${e.message}'.tr(), Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error al aceptar la oferta: $e'.tr(), Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // 🎯 CAMBIO CRÍTICO: Navegar a la pantalla de calificación, no al chat.
        _navigateToRateHelper();
      }
    }
  }

  Future<void> _loadDataAndCheckOfferStatus() async {
    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      // 1. Verificar si el usuario ha ofrecido ayuda (para el botón 'Ayuda Ofrecida' del Helper)
      final offersSnapshot = await _firestore
          .collection('solicitudes-de-ayuda')
          .doc(widget.requestId)
          .collection('offers')
          .where('helperId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      // 2. Obtener datos de la solicitud para verificar el estado
      final requestDoc = await _firestore
          .collection('solicitudes-de-ayuda')
          .doc(widget.requestId)
          .get();

      bool canRate = false;
      String? acceptedHelperId;
      String? acceptedHelperName;
      String currentRequestStatus = 'activa';
      List<DocumentSnapshot> pendingOffers = [];

      if (requestDoc.exists) {
        final requestData = requestDoc.data() as Map<String, dynamic>;
        currentRequestStatus = requestData['estado'] ?? 'activa';
        final String requestOwnerId = requestData['userId'] ?? '';
        
        setState(() {
            _requestStatus = currentRequestStatus;
        });

        if (currentUser.uid == requestOwnerId) {
             // Si soy el solicitante
            if (currentRequestStatus == 'activa') {
                final pendingOffersSnapshot = await _firestore
                    .collection('solicitudes-de-ayuda')
                    .doc(widget.requestId)
                    .collection('offers')
                    .where('status', isEqualTo: 'pending')
                    .get();
                pendingOffers = pendingOffersSnapshot.docs;
            } else if (currentRequestStatus == 'aceptada' || currentRequestStatus == 'finalizada') {
                // Buscamos el ayudador aceptado
                final acceptedOfferSnapshot = await _firestore
                    .collection('solicitudes-de-ayuda')
                    .doc(widget.requestId)
                    .collection('offers')
                    .where('status', isEqualTo: 'accepted')
                    .limit(1)
                    .get();

                if (acceptedOfferSnapshot.docs.isNotEmpty) {
                    final acceptedOffer = acceptedOfferSnapshot.docs.first.data();
                    acceptedHelperId = acceptedOffer['helperId'];
                    acceptedHelperName = acceptedOffer['helperName'];

                    // 4. Verificar si ya calificó a este ayudador (evitar índices compuestos)
                    final ratingSnap = await _firestore
                        .collection('ratings')
                        .where('requestId', isEqualTo: widget.requestId)
                        .get();
                    final hasAlreadyRated = ratingSnap.docs.any((doc) {
                        final data = doc.data();
                        final targetId = data['ratedUserId'] ?? data['targetUserId'];
                        return data['sourceUserId'] == currentUser.uid &&
                               targetId == acceptedHelperId &&
                               (data['type'] == 'helper_rating');
                    });
                    canRate = !hasAlreadyRated && currentRequestStatus == 'aceptada';
                }
            }
        }
      }

      if (mounted) {
        setState(() {
          _hasOfferedHelp = offersSnapshot.docs.isNotEmpty;
          _canRate = canRate;
          _acceptedHelperId = acceptedHelperId;
          _acceptedHelperName = acceptedHelperName;
          _pendingOffers = pendingOffers; // ✅ Actualiza la lista de ofertas
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error checking offer status and rating eligibility: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ FIX: FUNCIÓN ACEPTACIÓN
  Future<void> _showOfferHelpConfirmation(Map<String, dynamic> requestData) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('¿Estás seguro de ofrecer ayuda?'.tr(), style: const TextStyle(color: Colors.white)),
          content: Text(
            'Al aceptar, te comprometes a intentar ayudar a esta persona. Recuerda que tu ayuda será calificada, lo cual puede influir en tu reputación.'.tr(),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cerrar'.tr(), style: const TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Aceptar'.tr(), style: const TextStyle(color: Colors.amber)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _handleOfferHelp(requestData);
    }
  }

  // ✅ FIX: FUNCIÓN ACEPTACIÓN
  Future<void> _handleOfferHelp(Map<String, dynamic> requestData) async {
    print('🚀 INICIO _handleOfferHelp: Iniciando proceso de ofrecer ayuda');
    
    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('❌ ERROR: Usuario no autenticado');
      _showSnackBar('Debes iniciar sesión para ofrecer ayuda.'.tr(), Colors.red);
      return;
    }
    
    final String requesterUserId = requestData['userId']?.toString() ?? '';

    if (currentUser.uid == requesterUserId) {
      print('❌ ERROR: Usuario intentando ayudarse a sí mismo');
      _showSnackBar('No puedes ofrecerte ayuda a ti mismo.'.tr(), Colors.orange);
      return;
    }

    if (_hasOfferedHelp) {
      print('❌ ERROR: Ya ha ofrecido ayuda anteriormente');
      _showSnackBar('Ya has ofrecido ayuda para esta solicitud.'.tr(), Colors.orange);
      return;
    }

    try {
      final DocumentSnapshot helperProfile = await _firestore.collection('users').doc(currentUser.uid).get();
      final Map<String, dynamic> helperData = (helperProfile.data() as Map<String, dynamic>?) ?? {};

      final String helperName = helperData['name']?.toString() ?? currentUser.displayName ?? 'Ayudador';
      final String? helperAvatarPath = helperData['profilePicture']?.toString();
      final String requestTitle = requestData['titulo']?.toString() ?? requestData['descripcion']?.toString() ?? 'Solicitud de ayuda';

      // PASO B: Agregando oferta a Firestore 
      await _firestore
          .collection('solicitudes-de-ayuda')
          .doc(widget.requestId)
          .collection('offers')
          .add({
        'helperId': currentUser.uid,
        'helperName': helperName,
        'mensaje': 'El usuario $helperName ha ofrecido ayuda.',
        'timestamp': FieldValue.serverTimestamp(),
        'helperAvatarUrl': helperAvatarPath,
        'requesterId': requesterUserId,
      });

      // PASO C: Incrementando contador de ofertas (verificación de existencia)
      final reqRef = _firestore.collection('solicitudes-de-ayuda').doc(widget.requestId);
      final reqSnap = await reqRef.get();
      if (reqSnap.exists) {
        try {
          await reqRef.update({'offersCount': FieldValue.increment(1)});
        } on FirebaseException catch (e) {
          if (e.code == 'failed-precondition') {
            print('WARN: Incremento offersCount omitido por failed-precondition');
          } else {
            rethrow;
          }
        }
      } else {
        print('WARN: Request no existe, omito incremento de offersCount');
      }

      // PASO D: Llamando a createOfferAndNotifyRequester (Cloud Function)
      await _appServices.createOfferAndNotifyRequester(
        context: context,
        requestId: widget.requestId,
        requesterId: requesterUserId,
        helperId: currentUser.uid,
        helperName: helperName,
        helperAvatarUrl: helperAvatarPath,
        requestTitle: requestTitle,
        requestData: requestData,
      );

      if (mounted) {
        setState(() {
          _hasOfferedHelp = true;
        });
      }
      _showSnackBar('¡Has ofrecido ayuda con éxito! El solicitante ha sido notificado.'.tr(), Colors.green);

    } on FirebaseException catch (e) {
      String errorMessage = 'Error de Firebase: ';
      switch (e.code) {
        case 'permission-denied': errorMessage += 'Sin permisos para realizar esta acción.'; break;
        case 'network-request-failed': errorMessage += 'Error de conexión. Verifica tu internet.'; break;
        case 'unavailable': errorMessage += 'Servicio no disponible. Intenta más tarde.'; break;
        default: errorMessage += e.message ?? 'Error desconocido';
      }
      _showSnackBar(errorMessage.tr(), Colors.red);
    } catch (e) {
      _showSnackBar('Error inesperado: ${e.toString()}'.tr(), Colors.red);
    }
  }

  // ✅ FIX: FUNCIÓN FALTANTE
  void _startChat(String chatPartnerId, String chatPartnerName, String? chatPartnerAvatar) async {
    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showSnackBar('Debes iniciar sesión para chatear.'.tr(), Colors.red);
      return;
    }
    if (currentUser.uid == chatPartnerId) {
      _showSnackBar('No puedes chatear contigo mismo.'.tr(), Colors.orange);
      return;
    }
    
    if (_isRewardedAdLoaded && await _canShowRewardedAd()) {
      _rewardedAd?.show(
        onUserEarnedReward: (ad, reward) async {
          await _incrementRewardedAdViews();
          _goToChat(chatPartnerId, chatPartnerName, chatPartnerAvatar);
        },
      );
    } else {
      _goToChat(chatPartnerId, chatPartnerName, chatPartnerAvatar);
    }
  }

  // ✅ FIX: FUNCIÓN FALTANTE
  Future<void> _goToChat(String chatPartnerId, String chatPartnerName, String? chatPartnerAvatar) async {
    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final existingChat = await _firestore.collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      DocumentSnapshot? chatDoc;
      for (var doc in existingChat.docs) {
        final participants = doc.data() as Map<String, dynamic>?;
        final List<dynamic>? participantsList = participants?['participants'];
        if (participantsList != null && participantsList.contains(chatPartnerId)) {
          chatDoc = doc;
          break;
        }
      }

      String chatId;
      if (chatDoc != null) {
        chatId = chatDoc.id;
      } else {
        final newChat = await _firestore.collection('chats').add({
          'participants': [currentUser.uid, chatPartnerId],
          'lastMessage': {'text': '', 'timestamp': FieldValue.serverTimestamp()},
          'createdAt': FieldValue.serverTimestamp(),
        });
        chatId = newChat.id;
      }
      
      await InAppNotificationService.createChatNotification(
        recipientUid: chatPartnerId,
        chatId: chatId,
        senderUid: currentUser.uid,
        senderName: chatPartnerName,
      );

      if (mounted) {
        // Asegurarse de que el nombre esté codificado para la URL
        final encodedName = Uri.encodeComponent(chatPartnerName);
        context.go('/chat/$chatId?partnerId=$chatPartnerId&partnerName=$encodedName&partnerAvatar=${chatPartnerAvatar ?? ''}');
      }
    } catch (e) {
      print("Error starting chat: $e");
      _showSnackBar('Error al iniciar el chat.'.tr(), Colors.red);
    }
  }

  Future<void> _addComment(String requestId, String commentText) async {
    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null || commentText.trim().isEmpty) {
      _showSnackBar('Debes iniciar sesión para comentar y el comentario no puede estar vacío.'.tr(), Colors.red);
      return;
    }

    try {
      await _appServices.addComment(context, requestId, commentText);
      _showSnackBar('Comentario enviado.'.tr(), Colors.green);
    } on FirebaseException catch (e) {
      print("Error adding comment: $e");
      _showSnackBar('Error de Firebase al enviar comentario: ${e.message}'.tr(), Colors.red);
    } catch (e) {
      print("Unexpected error adding comment: $e");
      _showSnackBar('Ocurrió un error inesperado al enviar el comentario.'.tr(), Colors.red);
    } finally {
      _commentControllers[requestId]?.clear();
    }
  }

  void _showCommentsModal(String requestId) {
    if (!_commentControllers.containsKey(requestId)) {
      _commentControllers[requestId] = TextEditingController();
    }
    final TextEditingController commentController = _commentControllers[requestId]!;
    final firebase_auth.User? currentUser = _auth.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(modalContext).size.height * 0.75,
            color: Colors.grey[900],
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.grey[850],
                  title: Text('Comentarios'.tr(), style: const TextStyle(color: Colors.white)),
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('solicitudes-de-ayuda')
                        .doc(requestId)
                        .collection('comments')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, commentSnapshot) {
                      if (commentSnapshot.hasError) {
                        return Center(child: Text('Error: ${commentSnapshot.error}', style: const TextStyle(color: Colors.red)));
                      }
                      if (commentSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.amber));
                      }

                      final List<Map<String, dynamic>> comments = commentSnapshot.data?.docs
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .toList() ?? [];

                      if (comments.isEmpty) {
                        return Center(
                          child: Text(
                            'Sé el primero en comentar.'.tr(),
                            style: const TextStyle(color: Colors.white54, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: comments.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final String commentUser = comment['userName']?.toString() ?? 'Usuario'.tr();
                          final String commentText = comment['text']?.toString() ?? 'Sin comentario'.tr();
                          final String? userAvatar = comment['userAvatar']?.toString();
                          final dynamic commentTimestampData = comment['timestamp'];
                          final Timestamp? commentTimestamp = commentTimestampData is Timestamp ? commentTimestampData : null;

                          String formattedTime = '';
                          if (commentTimestamp != null) {
                            final DateTime date = commentTimestamp.toDate();
                            formattedTime = DateFormat('dd/MM HH:mm').format(date);
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: (userAvatar != null && userAvatar.startsWith('http'))
                                      ? NetworkImage(userAvatar)
                                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                  backgroundColor: Colors.grey[700],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              commentUser,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            formattedTime,
                                            style: const TextStyle(fontSize: 10, color: Colors.white54),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        commentText,
                                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (currentUser != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Escribe un comentario...'.tr(),
                              hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            minLines: 1,
                            maxLines: 5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.amber,
                          onPressed: () async {
                            if (commentController.text.trim().isNotEmpty) {
                              await _addComment(requestId, commentController.text);
                              commentController.clear();
                            }
                          },
                          child: const Icon(Icons.send, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                if (currentUser == null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Inicia sesión para comentar en esta publicación.'.tr(),
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageFullScreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: GestureDetector(
            onTap: () => Navigator.pop(dialogContext),
            child: InteractiveViewer(
              child: SizedBox(
                width: MediaQuery.of(dialogContext).size.width,
                height: MediaQuery.of(dialogContext).size.height,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white54, size: 100),
                        SizedBox(height: 10),
                        Text('Error al cargar imagen', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentsButton(String requestId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('solicitudes-de-ayuda')
          .doc(requestId)
          .collection('comments')
          .snapshots(),
      builder: (context, commentSnapshot) {
        if (commentSnapshot.hasError) {
          return const Row(children: [Icon(Icons.comment, color: Colors.red, size: 18), SizedBox(width: 4), Text('Error', style: TextStyle(fontSize: 10, color: Colors.red))]);
        }
        if (commentSnapshot.connectionState == ConnectionState.waiting) {
          return const Row(children: [Icon(Icons.comment, color: Colors.grey, size: 18), SizedBox(width: 4), Text('...', style: TextStyle(fontSize: 10, color: Colors.grey))]);
        }

        final int commentsCount = commentSnapshot.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () => _showCommentsModal(requestId),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.comment, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text(
                  commentsCount.toString(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetailsDialog(BuildContext context, String title, String details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(details, style: const TextStyle(color: Colors.white70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('close'.tr(), style: const TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }


  Widget _buildOffersListAndActions(String requesterUserId) {
    if (_auth.currentUser?.uid != requesterUserId) {
      return const SizedBox.shrink(); // Solo para el solicitante
    }
    
    if (_requestStatus == 'aceptada') {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ayuda Aceptada:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              '${_acceptedHelperName ?? 'Usuario'} está ayudando.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _goToChat(_acceptedHelperId!, _acceptedHelperName!, null), 
              icon: const Icon(Icons.chat, color: Colors.black),
              label: Text('Chatear con ${_acceptedHelperName ?? 'el ayudador'}'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            ),
          ],
        ),
      );
    }
    
    if (_pendingOffers.isEmpty && _requestStatus == 'activa') {
          return Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text('Aún no tienes ofertas de ayuda.', style: TextStyle(color: Colors.white54)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text('Ofertas Recibidas (${_pendingOffers.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        ..._pendingOffers.map((offerDoc) {
          final offerData = offerDoc.data() as Map<String, dynamic>;
          final String helperId = offerData['helperId']?.toString() ?? '';
          final String helperName = offerData['helperName']?.toString() ?? 'Ayudador Anónimo';
          
          return Card(
            color: Colors.grey[850],
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.handshake_outlined, color: Colors.amber),
              title: Text(helperName, style: const TextStyle(color: Colors.white)),
              subtitle: Text('Ha ofrecido ayuda.', style: const TextStyle(color: Colors.white70)),
              trailing: ElevatedButton(
                onPressed: () => _acceptOffer(offerDoc.id, helperId, helperName),
                child: const Text('Aceptar'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final Future<Map<String, dynamic>> requestDataFuture = widget.requestData != null
        ? Future.value(widget.requestData!)
        : _firestore.collection('solicitudes-de-ayuda').doc(widget.requestId).get().then((doc) {
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return {};
    });
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Detalles de la Solicitud'.tr(), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: CustomBackground(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: AdBannerWidget(adUnitId: AdsIds.banner),
            ),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
          future: requestDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
              return const Center(child: CircularProgressIndicator(color: Colors.amber));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error al cargar la solicitud: ${snapshot.error}'.tr(), style: const TextStyle(color: Colors.red)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('Solicitud no encontrada.'.tr(), style: const TextStyle(color: Colors.white)));
            }

            final requestData = snapshot.data!;
            return Column(
              children: [
                Expanded(child: _buildBodyWithData(context, requestData)),
            Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: AdBannerWidget(adUnitId: AdsIds.banner),
                ),
              ],
            );
          },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyWithData(BuildContext context, Map<String, dynamic> requestData) {
    final firebase_auth.User? currentUser = _auth.currentUser;
    final String requesterUserId = requestData['userId']?.toString() ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(requesterUserId).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }
        if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
          return Center(child: Text('Error al cargar los datos del solicitante.'.tr(), style: const TextStyle(color: Colors.red)));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) {
          return Center(child: Text('Error al cargar los datos del solicitante.'.tr(), style: const TextStyle(color: Colors.red)));
        }

        final String requesterName = userData['name']?.toString() ?? 'Usuario Anónimo'.tr();
        final String? requesterAvatarPath = userData['profilePicture']?.toString();
        final String requesterPhone = userData['phone']?.toString() ?? 'N/A';
        final String requesterEmail = userData['email']?.toString() ?? 'N/A';
        final String requesterAddress = userData['address']?.toString() ?? 'No especificada'.tr();
        
        final String? birthDay = (userData['birthDay'] as num?)?.toInt().toString();
        final String? birthMonth = (userData['birthMonth'] as num?)?.toInt().toString().padLeft(2, '0');
        final String? birthYear = (userData['birthYear'] as num?)?.toInt().toString();
        final String requesterDOB = (birthDay != null && birthMonth != null && birthYear != null)
            ? '$birthDay/$birthMonth/$birthYear'
            : 'No especificada'.tr();
        
        final String requesterProvincia = userData['province']?.toString() ?? 'No especificada'.tr();
        final String requesterCountry = userData['country']?['name']?.toString() ?? 'No especificado'.tr();
        
        final dynamic memberSinceTimestamp = userData['createdAt'];
        final String memberSince = memberSinceTimestamp != null ? DateFormat('dd/MM/yyyy').format((memberSinceTimestamp as Timestamp).toDate()) : 'N/A';
        final int helpedCount = (userData['helpedCount'] as num? ?? 0).toInt();
        final int receivedHelpCount = (userData['receivedHelpCount'] as num? ?? 0).toInt();

        final bool showWhatsapp = (requestData['showWhatsapp'] as bool?) ?? false;
        final bool showEmail = (requestData['showEmail'] as bool?) ?? false;
        final bool showAddress = (requestData['showAddress'] as bool?) ?? false;
        
        final String requestDescription = requestData['descripcion']?.toString() ?? 'Sin descripción'.tr();
        final String requestDetail = requestData['detalle']?.toString() ?? 'Sin detalles'.tr();
        final dynamic timestampData = requestData['timestamp'];
        final Timestamp timestamp = timestampData is Timestamp ? timestampData : Timestamp.now();
        final DateTime requestTime = timestamp.toDate();
        final DateTime now = DateTime.now();
        final Duration remainingTime = requestTime.add(const Duration(hours: 24)).difference(now);

        String timeRemainingText;
        if (remainingTime.isNegative) {
          timeRemainingText = 'Expirada'.tr();
        } else {
          final hours = remainingTime.inHours;
          final minutes = remainingTime.inMinutes.remainder(60);
          timeRemainingText = '$hours h $minutes min';
        }

        Color priorityColor = Colors.grey;
        switch (requestData['prioridad']?.toString()) {
          case 'alta':
            priorityColor = Colors.redAccent;
            break;
          case 'media':
            priorityColor = Colors.orange;
            break;
          case 'baja':
            priorityColor = Colors.green;
            break;
          default:
            priorityColor = Colors.grey;
            break;
        }

        List<String> imagePaths = [];
        dynamic rawImages = requestData['imagenes'];
        if (rawImages != null) {
          if (rawImages is List) {
            imagePaths = List<String>.from(rawImages.where((item) => item is String).map((e) => e.toString()));
          } else if (rawImages is String && rawImages.isNotEmpty) {
            imagePaths = [rawImages.toString()];
          }
        }
        String? imagePathToDisplay = imagePaths.isNotEmpty ? imagePaths.first : null;

        // ✅ Extraer y normalizar rutas de videos
        List<String> videoPaths = [];
        dynamic rawVideos = requestData['videos'];
        if (rawVideos != null) {
          if (rawVideos is List) {
            videoPaths = List<String>.from(rawVideos.where((item) => item is String).map((e) => e.toString()));
          } else if (rawVideos is String && rawVideos.isNotEmpty) {
            videoPaths = [rawVideos.toString()];
          }
        }

        final double? latitude = (requestData['latitude'] as num?)?.toDouble();
        final double? longitude = (requestData['longitude'] as num?)?.toDouble();
        final bool hasDetails = requestDetail.isNotEmpty && requestDetail != 'Sin detalles'.tr();
        
        // Determinar el botón de acción para el SOLICITANTE
        Widget? actionButton;
        if (currentUser?.uid == requesterUserId) {
            if (_requestStatus == 'aceptada') {
                if (_canRate) {
                    // El solicitante debe calificar al ayudador.
                    actionButton = ElevatedButton.icon(
                      onPressed: _navigateToRateHelper,
                      icon: const Icon(Icons.star_rate, color: Colors.black),
                      label: Text('Calificar Ayudador'.tr(), style: const TextStyle(fontSize: 16, color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                    );
                } else {
                    // El solicitante ya calificó, puede finalizar la ayuda.
                    actionButton = ElevatedButton.icon(
                      onPressed: _finalizeRequest,
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: Text('Finalizar Ayuda'.tr(), style: const TextStyle(fontSize: 16, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                    );
                }
            } else if (_requestStatus == 'finalizada') {
                // Ayuda finalizada, solo texto informativo.
                actionButton = Text('Ayuda Finalizada'.tr(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16));
            }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdBannerWidget(adUnitId: AdsIds.banner),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AvatarOptimizado(
                              url: (requesterAvatarPath != null && requesterAvatarPath.startsWith('http')) ? requesterAvatarPath : null,
                              storagePath: (requesterAvatarPath != null && !requesterAvatarPath.startsWith('http')) ? requesterAvatarPath : null,
                              radius: 25,
                              backgroundColor: Colors.grey[700],
                              placeholder: const CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.grey,
                                backgroundImage: AssetImage('assets/default_avatar.png'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    requesterName,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  UserReputationWidget(
                                    userId: requesterUserId,
                                    fromRequesters: false,
                                  ),
                                  Text(
                                    '${requestData['localidad']?.toString() ?? 'Desconocida'.tr()}, $requesterProvincia, $requesterCountry',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Categoría: ${requestData['categoria']?.toString() ?? 'N/A'}',
                                    style: const TextStyle(
                                        color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (currentUser?.uid == requesterUserId || showWhatsapp || showEmail || showAddress) ...[
                          const Divider(height: 16, thickness: 0.5, color: Colors.grey),
                          Text('Información de Contacto:'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 8),
                          if (currentUser?.uid == requesterUserId || showWhatsapp)
                            Text('Teléfono: $requesterPhone'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          if (currentUser?.uid == requesterUserId || showEmail)
                            Text('Email: $requesterEmail'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          if (currentUser?.uid == requesterUserId || showAddress)
                            Text('Dirección: $requesterAddress'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          if (currentUser?.uid == requesterUserId || showAddress)
                            Text('Fecha Nacimiento: $requesterDOB'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                              'Prioridad ${requestData['prioridad']?.toString() ?? 'N/A'}'.tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Expira en $timeRemainingText'.tr(),
                        style: TextStyle(
                            color: remainingTime.isNegative ? Colors.red : Colors.lightGreenAccent,
                            fontSize: 12),
                      ),
                       Text(
                        'Estado: $_requestStatus'.tr(),
                        style: TextStyle(
                            color: _requestStatus == 'aceptada' ? Colors.amber : Colors.white70,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1, color: Colors.grey),

              if (imagePaths.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imagePaths.length,
                    itemBuilder: (context, index) {
                      final imagePath = imagePaths[index];
                      return Container(
                        width: 300,
                        margin: const EdgeInsets.only(right: 12, bottom: 16),
                        child: GestureDetector(
                          onTap: () async {
                            final imageUrl = await _resolveImageUrl(imagePath);
                            if (imageUrl.isNotEmpty) {
                              _showImageFullScreen(context, imageUrl);
                            } else {
                              _showSnackBar('Error al cargar la imagen. Intenta de nuevo.'.tr(), Colors.red);
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey[800],
                              ),
                              child: FutureBuilder<String>(
                                future: _resolveImageUrl(imagePath),
                                builder: (context, urlSnapshot) {
                                  if (urlSnapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator(color: Colors.amber));
                                  }
                                  final hasUrl = urlSnapshot.hasData && (urlSnapshot.data?.isNotEmpty ?? false);
                                  if (!hasUrl || urlSnapshot.hasError) {
                                    return Container(
                                      color: Colors.grey[700],
                                      child: const Center(
                                        child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
                                      ),
                                    );
                                  }
                                  final imageUrl = urlSnapshot.data!;
                                  if (!_profilePictureUrlCache.containsKey(imagePath)) {
                                    _profilePictureUrlCache[imagePath] = imageUrl;
                                  }
                                  return Stack(
                                    children: [
                                      Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                      if (index == 0)
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: CircleAvatar(
                                              backgroundColor: Colors.black54,
                                              child: Text(
                                                '${imagePaths.length}',
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (videoPaths.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: videoPaths.length,
                    itemBuilder: (context, index) {
                      final videoPath = videoPaths[index];
                      return Container(
                        width: 300,
                        margin: const EdgeInsets.only(right: 12, bottom: 16),
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              String videoUrl;
                              if (_profilePictureUrlCache.containsKey(videoPath)) {
                                videoUrl = _profilePictureUrlCache[videoPath]!;
                              } else {
                                videoUrl = await _storage.ref().child(videoPath).getDownloadURL();
                                _profilePictureUrlCache[videoPath] = videoUrl;
                              }
                              _showVideoPlayerBottomSheet(videoUrl);
                            } catch (e) {
                              _showSnackBar('Error al abrir el video. Intenta de nuevo.'.tr(), Colors.red);
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black,
                              ),
                              child: Stack(
                                children: [
                                  // Placeholder oscuro con ícono de play
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black,
                                      child: const Center(
                                        child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 64),
                                      ),
                                    ),
                                  ),
                                  if (index == 0)
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black54,
                                          child: Text(
                                            '${videoPaths.length}',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              Text(
                'Descripción: ${requestData['descripcion']?.toString() ?? 'Sin descripción'.tr()}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                requestData['detalle']?.toString() ?? 'Sin detalles adicionales.'.tr(),
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (latitude != null && longitude != null)
                    IconButton(
                      icon: const Icon(Icons.location_on, color: Colors.blue, size: 28),
                      onPressed: () => _appServices.launchMap(context, latitude, longitude),
                      tooltip: 'Ver mapa'.tr(),
                    ),
                  if (showWhatsapp && requesterPhone.isNotEmpty && requesterPhone != 'N/A')
                    IconButton(
                      icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 28),
                      onPressed: () => _appServices.launchWhatsapp(context, requesterPhone),
                      tooltip: 'WhatsApp'.tr(),
                    ),
                  if (showEmail && requesterEmail.isNotEmpty && requesterEmail != 'N/A')
                    IconButton(
                      icon: const Icon(Icons.email, color: Colors.blueAccent, size: 28),
                      onPressed: () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: requesterEmail,
                          queryParameters: {'subject': 'Ayuda en Eslabón'},
                        );
                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri);
                        } else {
                          _showSnackBar('No se pudo abrir el correo.'.tr(), Colors.red);
                        }
                      },
                      tooltip: 'Email'.tr(),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Miembro desde: $memberSince'.tr(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Ayudó a ${helpedCount.toString().padLeft(4, '0')} Personas'.tr(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Recibió Ayuda de ${receivedHelpCount.toString().padLeft(4, '0')} Personas'.tr(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              
              // Lógica de botones de ACCIÓN (Calificar/Finalizar)
              if (actionButton != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: actionButton,
                  ),
                ),

              // 🚀 Listado de Ofertas (Solo si es el solicitante y está 'activa'/'aceptada')
              if (currentUser?.uid == requesterUserId && _requestStatus != 'finalizada')
                _buildOffersListAndActions(requesterUserId),
              
              // Botones de Iniciar Chat / Ofrecer Ayuda (solo si es un Helper y la solicitud está 'activa')
              if (currentUser?.uid != requesterUserId && _requestStatus == 'activa')
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _startChat(requesterUserId, requesterName, requesterAvatarPath), 
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
                      label: Text('Iniciar Chat'.tr(), style: const TextStyle(fontSize: 14, color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _hasOfferedHelp ? null : () => _showOfferHelpConfirmation(requestData), 
                      icon: const Icon(Icons.handshake_outlined, color: Colors.black),
                      label: Text(
                        _hasOfferedHelp ? 'Ayuda Ofrecida'.tr() : 'Ofrecer Ayuda'.tr(),
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasOfferedHelp ? Colors.grey : Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoPlayerSheet extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerSheet({required this.videoUrl});

  @override
  State<_VideoPlayerSheet> createState() => _VideoPlayerSheetState();
}

class _VideoPlayerSheetState extends State<_VideoPlayerSheet> {
  late VideoPlayerController _controller;
  bool _initializing = true;
  double _volume = 1.0;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      await _controller.setVolume(_volume);
      await _controller.play();
    } catch (e) {
      // Si falla, cerramos y notificamos
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo reproducir el video'.tr()), backgroundColor: Colors.red),
        );
        Navigator.of(context).pop();
      }
      return;
    }
    if (mounted) {
      setState(() {
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.isInitialized ? _controller.value.aspectRatio : 16 / 9,
              child: _initializing
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : VideoPlayer(_controller),
            ),
            const SizedBox(height: 12),
            if (!_initializing)
              Column(
                children: [
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(playedColor: Colors.amber, bufferedColor: Colors.white24, backgroundColor: Colors.white10),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(_controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 36),
                        onPressed: () {
                          setState(() {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                        onPressed: () async {
                          final pos = await _controller.position ?? Duration.zero;
                          _controller.seekTo(pos - const Duration(seconds: 10));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                        onPressed: () async {
                          final pos = await _controller.position ?? Duration.zero;
                          _controller.seekTo(pos + const Duration(seconds: 10));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _muted = !_muted;
                            _volume = _muted ? 0.0 : 1.0;
                          });
                          _controller.setVolume(_volume);
                        },
                      ),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: (_volume * 100).round().toString(),
                          activeColor: Colors.amber,
                          inactiveColor: Colors.white24,
                          onChanged: (v) {
                            setState(() {
                              _volume = v;
                              _muted = v == 0.0;
                            });
                            _controller.setVolume(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cerrar'.tr(), style: const TextStyle(color: Colors.amber)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}