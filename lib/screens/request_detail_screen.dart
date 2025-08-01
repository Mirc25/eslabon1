// lib/screens/request_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; 
import 'package:go_router/go_router.dart';

import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/user_reputation_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eslabon_flutter/utils/firestore_utils.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  final Map<String, dynamic>? requestData;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
    this.requestData,
  });

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final AppServices _appServices;

  final Map<String, TextEditingController> _commentControllers = {};
  
  bool _hasOfferedHelp = false; // Estado para controlar si el usuario ya ofreció ayuda

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
    _checkIfUserOfferedHelp(); // Verificar si ya ofreció ayuda al cargar la pantalla
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

  Future<void> _checkIfUserOfferedHelp() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final offersSnapshot = await _firestore
          .collection('solicitudes-de-ayuda')
          .doc(widget.requestId)
          .collection('offers')
          .where('helperId', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _hasOfferedHelp = offersSnapshot.docs.isNotEmpty;
          debugPrint('DEBUG: _hasOfferedHelp actualizado a: $_hasOfferedHelp');
        });
      }
    } catch (e) {
      print("Error checking if user offered help: $e");
    }
  }

  Future<void> _showOfferHelpConfirmation(Map<String, dynamic> requestData) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('¿Estás seguro de ofrecer ayuda?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Al aceptar, te comprometes a intentar ayudar a esta persona. Recuerda que tu ayuda será calificada, lo cual puede influir en tu reputación.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false), // Cerrar
              child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true), // Aceptar
              child: const Text('Aceptar', style: TextStyle(color: Colors.amber)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _handleOfferHelp(requestData);
    }
  }

  Future<void> _handleOfferHelp(Map<String, dynamic> requestData) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showSnackBar('Debes iniciar sesión para ofrecer ayuda.', Colors.red);
      return;
    }

    final String requesterUserId = requestData['userId'] as String? ?? '';

    if (currentUser.uid == requesterUserId) {
      _showSnackBar('No puedes ofrecerte ayuda a ti mismo.', Colors.orange);
      return;
    }

    if (_hasOfferedHelp) {
      _showSnackBar('Ya has ofrecido ayuda para esta solicitud.', Colors.orange);
      return;
    }

    try {
      final DocumentSnapshot helperProfile = await _firestore.collection('users').doc(currentUser.uid).get();
      final Map<String, dynamic> helperData = helperProfile.data() as Map<String, dynamic>? ?? {};

      final String helperName = helperData['name'] ?? currentUser.displayName ?? 'Ayudador';
      final String? helperAvatarUrl = helperData['profilePicture'] ?? currentUser.photoURL;

      await _appServices.createOfferAndNotifyRequester(
        context: context,
        requestId: widget.requestId,
        requesterId: requesterUserId,
        helperId: currentUser.uid,
        helperName: helperName,
        helperAvatarUrl: helperAvatarUrl,
        requestTitle: requestData['titulo'] ?? requestData['descripcion'] ?? 'Solicitud de ayuda',
        requestData: requestData,
      );

      if (mounted) {
        setState(() {
          _hasOfferedHelp = true;
        });
      }
      _showSnackBar('¡Has ofrecido ayuda con éxito! El solicitante ha sido notificado.', Colors.green);

    } on FirebaseException catch (e) {
      print("Error al ofrecer ayuda: $e");
      _showSnackBar('Error de Firebase al ofrecer ayuda: ${e.message}', Colors.red);
    } catch (e) {
      print("Error inesperado al ofrecer ayuda: $e");
      _showSnackBar('Ocurrió un error inesperado al ofrecer ayuda.', Colors.red);
    }
  }

  void _startChat(String chatPartnerId, String chatPartnerName) {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showSnackBar('Debes iniciar sesión para chatear.', Colors.red);
      return;
    }
    if (currentUser.uid == chatPartnerId) {
      _showSnackBar('No puedes chatear contigo mismo.', Colors.orange);
      return;
    }

    context.pushNamed(
      'chat_screen',
      pathParameters: {'chatPartnerId': chatPartnerId},
      extra: {'chatPartnerName': chatPartnerName},
    );
  }

  Future<void> _addComment(String requestId, String commentText) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null || commentText.trim().isEmpty) {
      _showSnackBar('Debes iniciar sesión para comentar y el comentario no puede estar vacío.', Colors.red);
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
    final User? currentUser = _auth.currentUser;

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
                        reverse: true,
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
                if (currentUser == null)
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

        final int commentsCount = commentSnapshot.data!.docs.length;

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

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.black, 
      appBar: AppBar(
        title: const Text('Detalles de la Solicitud', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900], 
        iconTheme: const IconThemeData(color: Colors.white), 
      ),
      body: CustomBackground( // CustomBackground solo para el fondo
        child: Column( // Columna principal para logo fijo y contenido scrollable
          children: [
            // ✅ LOGO FIJO: Colocado directamente en la parte superior de la columna
            Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 10.0), // Ajusta el padding según necesites
              child: Center(
                child: Image.asset(
                  'assets/icon.jpg', // Ruta de tu logo
                  height: 60, // Tamaño del logo (50% de 120)
                ),
              ),
            ),
            Expanded( // El resto del contenido es scrollable
              child: widget.requestData != null 
                  ? _buildBodyWithData(context, widget.requestData!)
                  : StreamBuilder<DocumentSnapshot>(
                      stream: _firestore.collection('solicitudes-de-ayuda').doc(widget.requestId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.amber));
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('Error al cargar la solicitud: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                        }

                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Center(child: Text('Solicitud no encontrada.', style: TextStyle(color: Colors.white)));
                        }

                        final requestData = snapshot.data!.data() as Map<String, dynamic>;
                        return _buildBodyWithData(context, requestData);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: Widget para el banner de publicidad (video)
  Widget _buildAdVideoBanner(BuildContext context, {String text = 'Espacio para Video Ad', String imageUrl = 'https://placehold.co/400x150/000000/FFFFFF?text=Video+Ad'}) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9, // Un poco más ancho
        height: 150, // Altura considerable para video
        margin: const EdgeInsets.symmetric(vertical: 20.0), // Más espacio
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(imageUrl), // Placeholder para video ad
            fit: BoxFit.cover,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ✅ ACTUALIZADO: Método para construir el cuerpo de la pantalla con los datos de la solicitud
  Widget _buildBodyWithData(BuildContext context, Map<String, dynamic> requestData) {
    final User? currentUser = _auth.currentUser;
    final String requesterUserId = requestData['userId'] as String? ?? '';

    // ✅ DEBUG PRINTS para verificar la visibilidad del botón
    debugPrint('DEBUG BUTTON: currentUser: ${currentUser?.uid}');
    debugPrint('DEBUG BUTTON: requesterUserId: $requesterUserId');
    debugPrint('DEBUG BUTTON: _hasOfferedHelp: $_hasOfferedHelp');
    debugPrint('DEBUG BUTTON: currentUser != requesterUserId: ${currentUser?.uid != requesterUserId}');


    final String requesterName = requestData['nombre'] as String? ?? 'Usuario Anónimo';
    final String requesterPhone = requestData['phone'] as String? ?? 'N/A'; 
    final String requesterEmail = requestData['email'] as String? ?? 'N/A';
    final String requesterAddress = requestData['address'] as String? ?? 'No especificada';
    final String requesterDOB = requestData['fecha_nacimiento'] as String? ?? 'No especificada'; 
    final String requesterProvincia = requestData['provincia'] as String? ?? 'No especificada';
    final String requesterCountry = requestData['country'] as String? ?? 'No especificado';

    final bool showWhatsapp = requestData['showWhatsapp'] as bool? ?? false;
    final bool showEmail = requestData['showEmail'] as bool? ?? false;
    final bool showAddress = requestData['showAddress'] as bool? ?? false; 
    
    final dynamic timestampData = requestData['timestamp'];
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
    switch (requestData['prioridad'] as String?) {
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

    List<String> imageUrls = [];
    dynamic rawImages = requestData['imagenes'];
    if (rawImages != null) {
      if (rawImages is List) {
        imageUrls = List<String>.from(rawImages.where((item) => item is String));
      } else if (rawImages is String && rawImages.isNotEmpty) {
        imageUrls = [rawImages];
      }
    }
    String imageUrlToDisplay = imageUrls.isNotEmpty ? imageUrls.first : '';
    
    final double? latitude = requestData['latitude'] as double?;
    final double? longitude = requestData['longitude'] as double?;


    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdVideoBanner(context, text: 'Video Ad Superior'),
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
                        CircleAvatar(
                          radius: 25,
                          backgroundImage: (requestData['avatar'] as String?) != null && (requestData['avatar'] as String).startsWith('http')
                              ? NetworkImage(requestData['avatar'] as String)
                              : const AssetImage('assets/default_avatar.png') as ImageProvider,
                          backgroundColor: Colors.grey[700],
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
                                '${requestData['localidad'] as String? ?? 'Desconocida'}, $requesterProvincia, $requesterCountry', 
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Categoría: ${requestData['categoria'] as String? ?? 'N/A'}', 
                                style: TextStyle(
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
                      const Text('Información de Contacto:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      if (currentUser?.uid == requesterUserId || showWhatsapp)
                        Text('Teléfono: $requesterPhone', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      if (currentUser?.uid == requesterUserId || showEmail)
                        Text('Email: $requesterEmail', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      if (currentUser?.uid == requesterUserId || showAddress)
                        Text('Dirección: $requesterAddress', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      if (currentUser?.uid == requesterUserId || showAddress)
                        Text('Fecha Nacimiento: $requesterDOB', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                          'Prioridad ${requestData['prioridad'] as String? ?? 'N/A'}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Expira en $timeRemainingText',
                    style: TextStyle(
                        color: remainingTime.isNegative ? Colors.red : Colors.lightGreenAccent,
                        fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: Colors.grey),
          
          if (imageUrls.isNotEmpty)
            GestureDetector(
              onTap: () => _showImageFullScreen(context, imageUrlToDisplay),
              child: Center(
                child: Container(
                  height: 200,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(imageUrlToDisplay),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Text(
                          '${imageUrls.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          Text(
            'Descripción: ${requestData['descripcion'] as String? ?? 'Sin descripción'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            requestData['detalle'] as String? ?? 'Sin detalles adicionales.',
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
                  tooltip: 'Ver mapa',
                ),
              if (showWhatsapp && requesterPhone.isNotEmpty) 
                IconButton(
                  icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 28),
                  onPressed: () => _appServices.launchWhatsapp(context, requesterPhone),
                  tooltip: 'WhatsApp',
                ),
              if (showEmail && requesterEmail.isNotEmpty) 
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
                      _showSnackBar('No se pudo abrir el correo.', Colors.red);
                    }
                  },
                  tooltip: 'Email',
                ),
            ],
          ),
          const SizedBox(height: 24),

          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(requesterUserId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snapshot.hasError) {
                return Text('Error al cargar datos del usuario: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Text('Datos del usuario no disponibles.', style: TextStyle(color: Colors.white54));
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final String memberSince = userData['memberSince'] as String? ?? 'N/A';
              // ✅ CORREGIDO: Leer como tipo numérico para evitar errores de tipo
              final int helpedCount = (userData['helpedCount'] as num? ?? 0).toInt();
              final int receivedHelpCount = (userData['receivedHelpCount'] as num? ?? 0).toInt();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Miembro desde: $memberSince',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Ayudó a ${helpedCount.toString().padLeft(4, '0')} Personas',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Text(
                    'Recibió Ayuda de ${receivedHelpCount.toString().padLeft(4, '0')} Personas',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),

          _buildAdVideoBanner(context, text: 'Video Ad Inferior'),
          const SizedBox(height: 30),

          if (currentUser?.uid != requesterUserId)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _startChat(requesterUserId, requesterName),
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
                  label: const Text('Iniciar Chat', style: TextStyle(fontSize: 14, color: Colors.black)),
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
                    _hasOfferedHelp ? 'Ayuda Ofrecida' : 'Ofrecer Ayuda',
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
  }
}