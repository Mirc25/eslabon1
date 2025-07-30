// lib/screens/request_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/user_reputation_widget.dart';
import 'package:eslabon_flutter/screens/rate_helper_screen.dart'; // Importación para navegación (ruta)
import 'package:eslabon_flutter/screens/chat_screen.dart'; // Importación para navegación (ruta)
import 'package:eslabon_flutter/screens/rate_requester_screen.dart'; // Importación para navegación (ruta)
import 'package:go_router/go_router.dart'; // Para navegación con GoRouter

// Si usas Google Maps, descomenta e importa el paquete.
// import 'package:Maps_flutter/Maps_flutter.dart';


class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  // requestData ahora puede ser nulo, para coincidir con el AppRouter.
  // Es crucial que MainScreen SIEMPRE pase un mapa válido (aunque sea vacío).
  final Map<String, dynamic>? requestData; 

  const RequestDetailScreen({
    Key? key,
    required this.requestId,
    this.requestData, // Ya no es 'required'
  }) : super(key: key);

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final AppServices _appServices;

  User? _currentUser;
  bool _isRequestAccepted = false;
  String? _acceptedHelperId;
  String? _acceptedHelperName;
  String? _acceptedHelperPhone;
  String? _acceptedHelperEmail;

  // CORRECCIÓN: Inicialización directa de _priority para evitar LateInitializationError
  String _priority = 'baja'; 
  bool _isOfferSent = false;
  bool _isLoading = false;

  final Map<String, TextEditingController> _commentControllers = {};

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
    _currentUser = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
    _checkRequestStatus();
    // Actualiza _priority desde requestData si está disponible
    _priority = widget.requestData?['prioridad'] as String? ?? 'baja'; 
    _checkIfOfferSent();
  }

  @override
  void dispose() {
    _commentControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error', style: TextStyle(color: Colors.black)),
        content: Text(message, style: const TextStyle(color: Colors.black87)),
        actions: <Widget>[
          TextButton(
            child: const Text('Ok', style: TextStyle(color: Colors.amber)),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
  }

  Future<void> _checkRequestStatus() async {
    try {
      final doc = await _firestore.collection('solicitudes-de-ayuda').doc(widget.requestId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['estado'] == 'aceptada' && data['helperId'] != null) {
          if (mounted) {
            setState(() {
              _isRequestAccepted = true;
              _acceptedHelperId = data['helperId'] as String?;
              _acceptedHelperName = data['helperName'] as String?;
              _acceptedHelperPhone = data['phone'] as String? ?? ''; // Asumiendo que el teléfono del helper aceptado viene aquí
              _acceptedHelperEmail = data['email'] as String? ?? ''; // Asumiendo que el email del helper aceptado viene aquí
            });
          }
        }
      }
    } catch (e) {
      print('Error checking request status: $e');
    }
  }

  Future<void> _checkIfOfferSent() async {
    if (_currentUser == null) return;

    try {
      final offerDoc = await _firestore
          .collection('solicitudes-de-ayuda')
          .doc(widget.requestId)
          .collection('offers')
          .doc(_currentUser!.uid)
          .get();

      if (mounted) {
        setState(() {
          _isOfferSent = offerDoc.exists;
        });
      }
    } catch (e) {
      print('Error checking if offer sent: $e');
      _showSnackBar('Error al verificar ofertas enviadas.', Colors.red);
    }
  }


  Future<void> _acceptHelpOffer(String helperId, String helperName, String helperPhone, String helperEmail) async {
    // Acceso seguro a userId ya que widget.requestData es anulable
    final String requesterUserId = widget.requestData?['userId'] as String? ?? '';
    if (_currentUser == null || _currentUser!.uid != requesterUserId || requesterUserId.isEmpty) {
      _showSnackBar('Solo el solicitante puede aceptar una oferta de ayuda y su ID debe estar disponible.', Colors.red);
      return;
    }
    
    final String currentUserName = _currentUser!.displayName ?? 'Usuario Anónimo';
    final String? currentUserPhotoUrl = _currentUser!.photoURL;

    try {
      await _firestore.collection('solicitudes-de-ayuda').doc(widget.requestId).update({
        'estado': 'aceptada',
        'helperId': helperId,
        'helperName': helperName,
        'helperPhone': helperPhone, // Guardar el teléfono del ayudador aceptado
        'helperEmail': helperEmail, // Guardar el email del ayudador aceptado
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // 1. Notificación al AYUDADOR (helperId) de que su oferta fue aceptada
      await _appServices.addNotification(
        context: context,
        recipientUserId: helperId,
        type: 'offer_accepted', 
        body: '¡Tu oferta de ayuda para "${widget.requestData?['descripcion'] as String? ?? 'tu solicitud'}" ha sido aceptada por $currentUserName!',
        requestId: widget.requestId,
        senderId: _currentUser!.uid,
        senderName: currentUserName,
        senderPhotoUrl: currentUserPhotoUrl,
        requestTitle: widget.requestData?['descripcion'] as String? ?? 'una solicitud',
        navigationData: { 
          'route': '/chat/${_getChatId(requesterUserId, helperId)}', 
          'chatPartnerId': requesterUserId, 
          'chatPartnerName': currentUserName,
          'ratingPromptRoute': '/rate-requester/${widget.requestId}', 
          'requesterId': requesterUserId, 
        }
      );

      // 2. Notificación al SOLICITANTE (a sí mismo) para CALIFICAR al ayudador
      await _appServices.addNotification(
        context: context,
        recipientUserId: requesterUserId, 
        type: 'requester_rates_helper_prompt', 
        body: 'Has aceptado la ayuda de $helperName para "${widget.requestData?['descripcion'] as String? ?? 'tu solicitud'}". ¡Califica a tu ayudante cuando la ayuda se complete!',
        requestId: widget.requestId,
        chatPartnerId: helperId, 
        senderId: helperId, 
        senderName: helperName,
        requestTitle: widget.requestData?['descripcion'] as String? ?? 'una solicitud',
        navigationData: { 
          'route': '/rate-helper/${widget.requestId}', 
          'requestData': widget.requestData, 
          'helperId': helperId, 
        }
      );

      setState(() {
        _isRequestAccepted = true;
        _acceptedHelperId = helperId;
        _acceptedHelperName = helperName;
        _acceptedHelperPhone = helperPhone;
        _acceptedHelperEmail = helperEmail;
      });

      _showSnackBar('Oferta de ayuda aceptada. Notificaciones enviadas.', Colors.green);
    } on FirebaseException catch (e) {
      print("Error accepting offer: $e");
      _showSnackBar('Error de Firebase al aceptar la oferta: ${e.message}', Colors.red);
    } catch (e) {
      print("Unexpected error accepting offer: $e");
      _showSnackBar('Ocurrió un error inesperado al aceptar la oferta.', Colors.red);
    }
  }
  
  Stream<List<Map<String, dynamic>>> _getOffersStream() {
    return _firestore
        .collection('solicitudes-de-ayuda')
        .doc(widget.requestId)
        .collection('offers')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> _sendOffer() async {
    if (_currentUser == null) {
      _showErrorDialog('Necesitas iniciar sesión para ofrecer ayuda.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (!userDoc.exists) {
        _showErrorDialog('No se encontraron tus datos de usuario para enviar la oferta. Asegúrate de que tu perfil exista.');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final userData = userDoc.data();
      
      final String helperName = (userData?['nombre'] as String?) ?? (_currentUser!.displayName as String?) ?? 'Usuario Anónimo';
      final String helperPhone = (userData?['phone'] as String?) ?? '';
      final String helperEmail = (userData?['email'] as String?) ?? '';
      final String? helperPhotoUrl = (userData?['profilePicture'] as String?) ?? (_currentUser!.photoURL as String?);

      // Acceso seguro a userId ya que widget.requestData es anulable
      final String recipientUserId = widget.requestData?['userId'] as String? ?? '';
      if (recipientUserId.isEmpty) {
        _showErrorDialog('Error: El ID del solicitante no está disponible en la solicitud. No se puede enviar la oferta.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      await _firestore
          .collection('solicitudes-de-ayuda')
          .doc(widget.requestId)
          .collection('offers')
          .doc(_currentUser!.uid) 
          .set({
        'helperId': _currentUser!.uid,
        'helperName': helperName,
        'helperPhone': helperPhone,
        'helperEmail': helperEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Notificación al SOLICITANTE (widget.requestData['userId']) de la nueva oferta
      await _appServices.addNotification(
        context: context,
        recipientUserId: recipientUserId,
        type: 'new_offer', 
        body: '¡$helperName ha ofrecido ayuda para tu solicitud "${widget.requestData?['descripcion'] as String? ?? 'sin título'}"!',
        requestId: widget.requestId,
        chatPartnerId: _currentUser!.uid, 
        senderId: _currentUser!.uid, 
        senderName: helperName,
        senderPhotoUrl: helperPhotoUrl,
        requestTitle: widget.requestData?['descripcion'] as String? ?? 'sin título',
        navigationData: { 
          'route': '/chat/${_getChatId(_currentUser!.uid, recipientUserId)}', 
          'chatPartnerId': _currentUser!.uid, 
          'chatPartnerName': helperName, 
          'requestData': widget.requestData,
        }
      );

      setState(() {
        _isOfferSent = true;
      });
      _showSnackBar('¡Tu oferta de ayuda ha sido enviada al solicitante!', Colors.green);
    } on FirebaseException catch (e) {
      print("Error sending offer: $e");
      _showErrorDialog('Error de Firebase al enviar la oferta: ${e.message}');
    } catch (e) {
      print("Unexpected error sending offer: $e");
      _showErrorDialog('Ocurrió un error inesperado al enviar la oferta: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment(String requestId, String commentText) async {
    if (_currentUser == null || commentText.trim().isEmpty) {
      _showSnackBar('Debes iniciar sesión para comentar.', Colors.red);
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      final userData = userDoc.data();
      final String userName = (userData?['nombre'] as String?) ?? (_currentUser!.displayName as String?) ?? 'Usuario Anónimo';
      final String? userAvatar = (userData?['profilePicture'] as String?) ?? (_currentUser!.photoURL as String?);

      await _firestore.collection('solicitudes-de-ayuda').doc(requestId).collection('comments').add({
        'userId': _currentUser!.uid,
        'userName': userName,
        'userAvatar': userAvatar,
        'text': commentText.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Comentario enviado.', Colors.green);
    } on FirebaseException catch (e) {
      print("Error adding comment: $e");
      _showSnackBar('Error de Firebase al enviar comentario: ${e.message}', Colors.red);
    } catch (e) {
      print("Unexpected error adding comment: $e");
      _showSnackBar('Ocurrió un error inesperado al enviar el comentario.', Colors.red);
    } finally {
      _commentControllers[requestId]?.clear();
    }
  }

  void _showCommentsModal(String requestId) {
    if (!_commentControllers.containsKey(requestId)) {
      _commentControllers[requestId] = TextEditingController();
    }
    final TextEditingController commentController = _commentControllers[requestId]!;

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
                  title: const Text('Comentarios', style: TextStyle(color: Colors.white)),
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

                      final List<Map<String, dynamic>> comments = commentSnapshot.data!.docs
                          .map((doc) => doc.data() as Map<String, dynamic>)
                          .toList();

                      if (comments.isEmpty) {
                        return const Center(
                          child: Text(
                            'Sé el primero en comentar.',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final String commentUser = comment['userName'] ?? 'Usuario';
                          final String commentText = comment['text'] ?? 'Sin comentario';
                          final String? userAvatar = comment['userAvatar'] as String?;
                          final Timestamp? commentTimestamp = comment['timestamp'] as Timestamp?;

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
                                            style: TextStyle(fontSize: 10, color: Colors.white54),
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
                if (_currentUser != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Escribe un comentario...',
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
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
                if (_currentUser == null)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Inicia sesión para comentar en esta publicación.',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
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
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, color: Colors.white54, size: 100),
                        const SizedBox(height: 10),
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

  // Helper para generar Chat ID consistente
  String _getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('-');
  }

  @override
  Widget build(BuildContext context) {
    // Acceso seguro a requestData y conversión a un mapa no nulo si es necesario
    final Map<String, dynamic> request = widget.requestData ?? {}; // request será {} si widget.requestData es null
    final String requestId = widget.requestId;
    final String requesterUserId = request['userId'] as String? ?? '';
    final bool isMyRequest = _currentUser?.uid == requesterUserId;

    // Acceso seguro a campos del mapa request
    final String description = request['descripcion'] as String? ?? 'Sin descripción';
    final String details = request['detalle'] as String? ?? 'Sin detalles adicionales.';
    final String locality = request['localidad'] as String? ?? 'Desconocida';
    final String province = request['provincia'] as String? ?? 'Desconocida';
    final String country = request['country'] as String? ?? 'Desconocido';
    final String category = request['categoria'] as String? ?? 'Sin categoría';

    final String requesterName = request['nombre'] as String? ?? 'Anónimo';
    final String? requesterAvatar = request['avatar'] as String?;
    final String? requesterEmail = request['email'] as String?;
    final String? requesterPhone = request['phone'] as String?;
    final String? requesterAddress = request['address'] as String?;
    final String? requesterDOB = request['fecha_nacimiento'] as String?;

    final bool showWhatsapp = request['showWhatsapp'] as bool? ?? false;
    final bool showEmail = request['showEmail'] as bool? ?? false;
    final bool showAddress = request['showAddress'] as bool? ?? false;


    final dynamic timestampData = request['timestamp'];
    final Timestamp timestamp = timestampData is Timestamp ? timestampData : Timestamp.now();
    final DateTime requestTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration remainingTime = requestTime.add(const Duration(hours: 24)).difference(now);

    String timeRemainingText;
    if (remainingTime.isNegative) {
      timeRemainingText = 'Expirada';
    } else {
      final hours = remainingTime.inHours;
      final minutes = remainingTime.inMinutes.remainder(60);
      timeRemainingText = '$hours h $minutes min';
    }

    Color priorityColor = Colors.grey;
    switch (_priority) {
      case 'alta':
        priorityColor = Colors.redAccent;
        break;
      case 'media':
        priorityColor = Colors.orange;
        break;
      case 'baja':
        priorityColor = Colors.green;
        break;
    }

    List<String> imageUrls = [];
    dynamic rawImages = request['imagenes'];
    if (rawImages != null) {
      if (rawImages is List) {
        imageUrls = List<String>.from(rawImages.where((item) => item is String));
      } else if (rawImages is String && rawImages.isNotEmpty) {
        imageUrls = [rawImages];
      }
    }
    
    List<String> videoUrls = [];
    dynamic rawVideos = request['videos'];
    if (rawVideos != null) {
      if (rawVideos is List) {
        videoUrls = List<String>.from(rawVideos.where((item) => item is String));
      } else if (rawVideos is String && rawVideos.isNotEmpty) {
        videoUrls = [rawVideos];
      }
    }

    final double? latitude = request['latitude'] as double?;
    final double? longitude = request['longitude'] as double?;

    final String memberSince = request['memberSince'] as String? ?? 'N/A'; 
    final int helpedCount = request['helpedCount'] as int? ?? 0; 
    final int receivedHelpCount = request['receivedHelpCount'] as int? ?? 0; 

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Detalles de la Solicitud'),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white), 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Espacio para publicidad (Video Ad 1) ---
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.deepPurple[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Placeholder para Video Ad 1',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Sección de Datos del Solicitante y Solicitud ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: (requesterAvatar != null && requesterAvatar.startsWith('http'))
                                    ? NetworkImage(requesterAvatar)
                                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                backgroundColor: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      requesterName,
                                      style: const TextStyle(
                                          fontSize: 16,
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
                                      '$locality, $province, $country',
                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Categoría: $category',
                                      style: TextStyle(
                                          color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Prioridad $_priority',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Expira en $timeRemainingText',
                          style: TextStyle(
                              color: remainingTime.isNegative ? Colors.red : Colors.lightGreenAccent,
                              fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16, thickness: 0.5, color: Colors.grey),
                const SizedBox(height: 4),

                // --- Imágenes (si las hay) ---
                if (imageUrls.isNotEmpty)
                  Column(
                    children: [
                      SizedBox(
                        height: 100, // Altura para el scroll horizontal
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imageUrls.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _showImageFullScreen(context, imageUrls[index]),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrls[index],
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[700],
                                      child: const Icon(Icons.broken_image, color: Colors.white54, size: 40),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16), // Espacio después de las imágenes
                    ],
                  ),
                
                // --- Videos (si los hay) ---
                if (videoUrls.isNotEmpty)
                  Column(
                    children: [
                      SizedBox(
                        height: 100, // Altura para el scroll horizontal
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: videoUrls.length,
                          itemBuilder: (context, index) {
                            // Aquí integrarías tu VideoPlayer o Chewie
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey[800],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 40),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16), // Espacio después de los videos
                    ],
                  ),
                
                // --- Descripción y Detalles ---
                Text(
                  'Descripción: $description',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detalles: $details',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),

                // --- Íconos de Contacto y Ubicación ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Botón para ver mapa
                    if (latitude != null && longitude != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: IconButton(
                          iconSize: 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.location_on, color: Colors.blue),
                          onPressed: () => _appServices.launchMap(context, latitude, longitude),
                          tooltip: 'Ver ubicación en mapa',
                        ),
                      ),
                    // Botón WhatsApp
                    if (showWhatsapp && (requesterPhone?.isNotEmpty == true))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: IconButton(
                          iconSize: 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                          onPressed: () => _appServices.launchWhatsapp(context, requesterPhone!),
                          tooltip: 'WhatsApp',
                        ),
                      ),
                    // Botón Email
                    if (showEmail && (requesterEmail?.isNotEmpty == true))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: IconButton(
                          iconSize: 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.email, color: Colors.blueAccent),
                          onPressed: () async {
                            final Uri emailLaunchUri = Uri(
                              scheme: 'mailto',
                              path: requesterEmail!,
                              queryParameters: {'subject': 'Ayuda en Eslabón'},
                            );
                            if (await canLaunchUrl(emailLaunchUri)) {
                              await launchUrl(emailLaunchUri);
                            } else {
                              _showErrorDialog('No se pudo abrir el correo. Asegúrate de tener una app de email configurada.');
                            }
                          },
                          tooltip: 'Email',
                        ),
                      ),
                    // Si showAddress es true, podrías mostrar un ícono para ver la dirección completa en texto
                    if (showAddress && (requesterAddress?.isNotEmpty == true))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: IconButton(
                          iconSize: 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.location_city, color: Colors.orange), // Icono para dirección
                          onPressed: () {
                            _showSnackBar('Dirección: ${requesterAddress!}', Colors.blueGrey);
                          },
                          tooltip: 'Ver dirección completa',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // --- Información de Reputación del Solicitante ---
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Miembro desde: ',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.normal),
                          ),
                          Text(
                            memberSince, 
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Ayudó a: ',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.normal),
                          ),
                          Text(
                            '$helpedCount Personas', 
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Recibió Ayuda de: ',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.normal),
                      ),
                      Text(
                        '$receivedHelpCount Personas', 
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Lógica del botón "Ofrecer mi Ayuda" o "Ir al Chat" / "Calificar" ---
            // Se muestra el botón "Ofrecer mi Ayuda" si NO es mi solicitud, no he enviado una oferta y la solicitud NO ha sido aceptada
            if (_auth.currentUser != null && _auth.currentUser!.uid != requesterUserId && !_isOfferSent && !_isRequestAccepted)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendOffer,
                  icon: const Icon(Icons.handshake, color: Colors.black),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Ofrecer mi Ayuda', style: TextStyle(color: Colors.black, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              )
            // Si no es mi solicitud, pero YA envié una oferta y la solicitud NO ha sido aceptada
            else if (_auth.currentUser != null && _auth.currentUser!.uid != requesterUserId && _isOfferSent && !_isRequestAccepted)
              Center(
                child: Column(
                  children: [
                    const Text(
                      '¡Oferta de ayuda enviada!',
                      style: TextStyle(color: Colors.lightGreenAccent, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navegar al chat con el solicitante.
                        context.push('/chat/${_getChatId(_currentUser!.uid, requesterUserId)}',
                          extra: {
                            'chatPartnerId': requesterUserId,
                            'chatPartnerName': requesterName,
                            'requestId': requestId,
                          }
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      label: const Text('Ir al Chat', style: TextStyle(color: Colors.white, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              )
            // Si es MI solicitud y NO ha sido aceptada todavía (mostrar ofertas recibidas)
            else if (isMyRequest && !_isRequestAccepted)
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Esta es tu solicitud. Esperando ofertas...',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    // Aquí se muestra la lista de ofertas recibidas
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _getOffersStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator(color: Colors.amber);
                        }
                        if (snapshot.hasError) {
                          return Text('Error al cargar ofertas: ${snapshot.error}', style: TextStyle(color: Colors.red));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('Aún no hay ofertas de ayuda.', style: TextStyle(color: Colors.white54));
                        }

                        final offers = snapshot.data!;
                        return Column(
                          children: [
                            const Text('Ofertas Recibidas:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            ...offers.map((offer) {
                              final String offerHelperId = offer['helperId'] as String? ?? 'N/A';
                              final String offerHelperName = offer['helperName'] as String? ?? 'Anónimo';
                              final String offerHelperPhone = offer['helperPhone'] as String? ?? '';
                              final String offerHelperEmail = offer['helperEmail'] as String? ?? ''; 

                              return Card(
                                color: Colors.grey[850],
                                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey[700],
                                    // Si tienes la URL de la foto del ayudador en la oferta, podrías usarla aquí:
                                    // backgroundImage: (offer['helperPhotoUrl'] != null && (offer['helperPhotoUrl'] as String).startsWith('http'))
                                    //     ? NetworkImage(offer['helperPhotoUrl'] as String)
                                    //     : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                  ),
                                  title: Text(offerHelperName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      UserReputationWidget(userId: offerHelperId, fromRequesters: true),
                                      Text('Ofreció ayuda', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => _acceptHelpOffer(offerHelperId, offerHelperName, offerHelperPhone, offerHelperEmail),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.lightGreen,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: const Text('Aceptar', style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              )
            // Si la solicitud YA fue aceptada (sin importar quién sea el usuario actual)
            else if (_isRequestAccepted)
              Center(
                child: Column(
                  children: [
                    const Text(
                      '¡Esta solicitud ha sido aceptada!',
                      style: TextStyle(color: Colors.lightGreenAccent, fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ayudado por: ${_acceptedHelperName ?? 'Anónimo'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    // Botón para ir al chat con el ayudador aceptado (si soy el solicitante o el ayudador aceptado)
                    if (_currentUser?.uid == requesterUserId || _currentUser?.uid == _acceptedHelperId)
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_acceptedHelperId != null && _currentUser != null) {
                            context.push('/chat/${_getChatId(_currentUser!.uid, _acceptedHelperId!)}',
                              extra: {
                                'chatPartnerId': _acceptedHelperId, 
                                'chatPartnerName': _acceptedHelperName,
                                'requestId': requestId,
                              }
                            );
                          } else {
                            _showSnackBar('No se puede iniciar el chat. Faltan datos del ayudador.', Colors.red);
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                        label: const Text('Ir al Chat', style: TextStyle(color: Colors.white, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    const SizedBox(height: 10),
                    // Botón para calificar al ayudador (si soy el solicitante de ESTA petición)
                    if (isMyRequest && _acceptedHelperId != null) 
                      ElevatedButton.icon(
                        onPressed: () {
                          context.push('/rate-helper/${widget.requestId}',
                            extra: {
                              'helperId': _acceptedHelperId,
                              'helperName': _acceptedHelperName,
                              'requestData': widget.requestData, 
                            }
                          );
                        },
                        icon: const Icon(Icons.star, color: Colors.black),
                        label: const Text('Calificar Ayudador', style: TextStyle(color: Colors.black, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    // Botón para calificar al solicitante (si soy el ayudador ACEPTADO de ESTA petición)
                    if (!isMyRequest && _currentUser?.uid == _acceptedHelperId) 
                      ElevatedButton.icon(
                        onPressed: () {
                          context.push('/rate-requester/${widget.requestId}',
                            extra: {
                              'requesterId': requesterUserId,
                              'requesterName': requesterName,
                            }
                          );
                        },
                        icon: const Icon(Icons.star, color: Colors.black),
                        label: const Text('Calificar Solicitante', style: TextStyle(color: Colors.black, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                  ],
                ),
              )
            // Este `else` final asegura que si ninguna de las condiciones anteriores se cumple,
            // no se muestre ningún botón de acción principal.
            else
              const SizedBox.shrink(), 

            const SizedBox(height: 20),

            // --- Espacio para publicidad (Video Ad 2) ---
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.deepPurple[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Placeholder para Video Ad 2',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}