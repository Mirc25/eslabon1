import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/user_reputation_widget.dart';
import 'package:eslabon_flutter/screens/rate_helper_screen.dart';
import 'package:eslabon_flutter/screens/chat_screen.dart';
import 'package:eslabon_flutter/screens/rate_requester_screen.dart';
// Asegúrate de que las siguientes importaciones sean correctas en tu proyecto:
// import 'package:eslabon_flutter/screens/rate_offer_screen.dart'; 


class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const RequestDetailScreen({
    Key? key,
    required this.requestId,
    required this.requestData,
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

  late String _priority;
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
    _priority = widget.requestData['prioridad'] as String? ?? 'baja';
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
              _acceptedHelperPhone = data['helperPhone'] as String? ?? ''; 
              _acceptedHelperEmail = data['helperEmail'] as String? ?? '';
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
    final String requesterUserId = widget.requestData['userId'] as String? ?? '';
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
        'helperPhone': helperPhone,
        'helperEmail': helperEmail,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // 1. Notificación al AYUDADOR (helperId) de que su oferta fue aceptada
      await _appServices.addNotification(
        context: context,
        recipientUserId: helperId,
        type: 'offer_accepted', // ✅ TIPO DE NOTIFICACIÓN AGREGADO
        message: '¡Tu oferta de ayuda para "${widget.requestData['descripcion'] as String? ?? 'tu solicitud'}" ha sido aceptada por $currentUserName!',
        requestId: widget.requestId,
        senderId: _currentUser!.uid,
        senderName: currentUserName,
        senderPhotoUrl: currentUserPhotoUrl,
        requestTitle: widget.requestData['descripcion'] as String? ?? 'una solicitud',
        navigationData: { // Datos para que la notificación lleve a una acción específica
          'route': '/chat/$helperId-$requesterUserId', // Ejemplo: ruta a un chat específico
          'chatPartnerId': requesterUserId,
          'chatPartnerName': currentUserName,
          // ✅ AÑADIDO: Datos para la calificación del SOLICITANTE por el AYUDADOR
          'ratingPromptRoute': '/rate-requester/${widget.requestId}', // Ruta a la pantalla de calificación del solicitante
          'requesterId': requesterUserId, // ID del solicitante
        }
      );

      // 2. Notificación al SOLICITANTE (a sí mismo) para CALIFICAR al ayudador
      await _appServices.addNotification(
        context: context,
        recipientUserId: requesterUserId, // El solicitante
        type: 'requester_rates_helper_prompt', // ✅ TIPO DE NOTIFICACIÓN AGREGADO
        message: 'Has aceptado la ayuda de $helperName para "${widget.requestData['descripcion'] as String? ?? 'tu solicitud'}". ¡Califica a tu ayudante cuando la ayuda se complete!',
        requestId: widget.requestId,
        chatPartnerId: helperId, // ID del ayudador para el chat o contexto
        senderId: helperId, // El sender de esta notificación es el helper que fue aceptado
        senderName: helperName,
        // senderPhotoUrl: <URL_FOTO_HELPER>, // Si tienes la foto del helper aquí, pásala
        requestTitle: widget.requestData['descripcion'] as String? ?? 'una solicitud',
        navigationData: { // Datos para que la notificación lleve a la pantalla de calificación
          'route': '/rate-helper/${widget.requestId}', // Ruta a la pantalla de calificación del ayudador
          'requestData': widget.requestData, // Pasamos la data completa de la solicitud
          'helperId': helperId, // El ID del ayudador que debe ser calificado
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
      final String? helperPhotoUrl = (userData?['photoUrl'] as String?) ?? (_currentUser!.photoURL as String?);

      final String recipientUserId = widget.requestData['userId'] as String? ?? '';
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
        type: 'new_offer', // ✅ TIPO DE NOTIFICACIÓN AGREGADO
        message: '¡$helperName ha ofrecido ayuda para tu solicitud "${widget.requestData['descripcion'] as String? ?? 'sin título'}"!',
        requestId: widget.requestId,
        chatPartnerId: _currentUser!.uid,
        senderId: _currentUser!.uid,
        senderName: helperName,
        senderPhotoUrl: helperPhotoUrl,
        requestTitle: widget.requestData['descripcion'] as String? ?? 'sin título',
        navigationData: { // Datos para que la notificación lleve a un chat o al detalle
          'route': '/chat/${_currentUser!.uid}-$recipientUserId', // Ejemplo: ruta a un chat entre ambos
          'chatPartnerId': _currentUser!.uid,
          'chatPartnerName': helperName,
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
      await _appServices.addComment(context, requestId, commentText);
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

  @override
  Widget build(BuildContext context) {
    final request = widget.requestData;
    final String requestId = widget.requestId;
    final String requesterUserId = request['userId'] as String? ?? '';
    final bool isMyRequest = _currentUser?.uid == requesterUserId;

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

    final double? latitude = request['latitude'];
    final double? longitude = request['longitude'];

    final String memberSince = request['memberSince'] as String? ?? 'N/A';
    final int helpedCount = request['helpedCount'] as int? ?? 0;
    final int receivedHelpCount = request['receivedHelpCount'] as int? ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Detalles de la Solicitud'),
        backgroundColor: Colors.grey[900],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                                backgroundImage: (request['avatar'] as String?) != null && (request['avatar'] as String).startsWith('http')
                                    ? NetworkImage(request['avatar'] as String)
                                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                backgroundColor: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request['nombre'] as String? ?? 'Anónimo',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                    UserReputationWidget(
                                      userId: requesterUserId,
                                      fromRequesters: false,
                                    ),
                                    Text(
                                      request['localidad'] as String? ?? 'Desconocida',
                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                    Text(
                                      'Categoría: ${request['categoria'] as String? ?? 'N/A'}',
                                      style: TextStyle(
                                          color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.w600),
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
                            'Prioridad ${request['prioridad'] as String? ?? 'N/A'}',
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

                if (imageUrls.isNotEmpty)
                  SizedBox(
                    height: 100,
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
                  )
                else
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image_not_supported, color: Colors.white54, size: 60),
                  ),
                const SizedBox(height: 16),

                Text(
                  'Descripción: ${request['descripcion'] as String? ?? 'Sin descripción'}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detalles: ${request['detalle'] as String? ?? 'Sin detalles'}',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
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
                    if (request['showWhatsapp'] == true && (request['phone'] as String?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: IconButton(
                          iconSize: 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                          onPressed: () => _appServices.launchWhatsapp(context, request['phone'] as String? ?? ''),
                          tooltip: 'WhatsApp',
                        ),
                      ),
                    if ((request['email'] as String?)?.isNotEmpty == true)
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
                              path: request['email'] as String? ?? '',
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
                  ],
                ),
                const SizedBox(height: 8),

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

            if (_auth.currentUser != null && _auth.currentUser!.uid != requesterUserId && !_isOfferSent)
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
              ),
            const SizedBox(height: 20),

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