import 'package:flutter/material.dart';
// ¡CRÍTICO: Eliminadas importaciones de carousel_slider!
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importa tu pantalla de chat (asegúrate de que exista en esta ruta)
import 'package:eslabon_flutter/screens/chat_screen.dart';


class RequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final String requestId;

  const RequestDetailScreen({
    super.key,
    required this.requestData,
    required this.requestId,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  List<VideoPlayerController> _videoControllers = [];
  List<ChewieController> _chewieControllers = [];

  final PageController _pageController = PageController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _initializeVideoPlayers();
  }

  void _initializeVideoPlayers() {
    List<dynamic> allMedia = [];
    final List<dynamic>? images = widget.requestData['imagenes'];
    final List<dynamic>? videos = widget.requestData['videos'];

    if (images != null) {
      allMedia.addAll(images);
    }
    if (videos != null) {
      allMedia.addAll(videos);
    }

    for (var item in allMedia) {
      String url = item.toString();
      if (url.toLowerCase().contains('.mp4') || url.toLowerCase().contains('.mov') ||
          url.toLowerCase().contains('.avi') || url.toLowerCase().contains('.mkv')) {
        final videoController = VideoPlayerController.networkUrl(Uri.parse(url));
        _videoControllers.add(videoController);

        videoController.initialize().then((_) {
          if (mounted) {
            _chewieControllers.add(ChewieController(
              videoPlayerController: videoController,
              autoPlay: false,
              looping: false,
              aspectRatio: videoController.value.aspectRatio,
              showControls: true,
              materialProgressColors: ChewieProgressColors(
                playedColor: Colors.amber,
                handleColor: Colors.amber,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.black,
              ),
              placeholder: const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
              autoInitialize: true,
            ));
            setState(() {});
          }
        }).catchError((e) {
          print("Error al inicializar video ($url): $e");
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _videoControllers) {
      controller.dispose();
    }
    for (var controller in _chewieControllers) {
      controller.dispose();
    }
    super.dispose();
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

  Future<void> _launchMap(double latitude, double longitude) async {
    final uri =
        Uri.parse('http://googleusercontent.com/maps.google.com/?q=$latitude,$longitude');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('No se pudo abrir el mapa.', Colors.red);
    }
  }

  Future<void> _launchWhatsapp(String phone) async {
    final url = 'https://wa.me/${phone.replaceAll('+', '')}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showSnackBar('No se pudo abrir WhatsApp.', Colors.red);
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'Ayuda en Eslabón'},
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      _showSnackBar('No se pudo abrir el correo.', Colors.red);
    }
  }

  Future<void> _startChatWithRequester(BuildContext context, String requesterUserId, String requesterName) async {
    if (_currentUser == null) {
      _showSnackBar('Debes iniciar sesión para chatear.', Colors.red);
      return;
    }

    if (_currentUser!.uid == requesterUserId) {
      _showSnackBar('No puedes iniciar un chat contigo mismo.', Colors.orange);
      return;
    }

    final List<String> participants = [_currentUser!.uid, requesterUserId]..sort();
    final String chatId = participants.join('_');

    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) {
        await _firestore.collection('chats').doc(chatId).set({
          'participants': participants,
          'lastMessage': '',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'requestCreatorId': requesterUserId,
          'requestCreatorName': requesterName,
          'helperId': _currentUser!.uid,
          'helperName': _currentUser!.displayName ?? 'Usuario Anónimo',
        });
        _showSnackBar('Nuevo chat iniciado con $requesterName.', Colors.green);
      } else {
        _showSnackBar('Chat existente abierto con $requesterName.', Colors.blue);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            otherUserId: requesterUserId,
            otherUserName: requesterName,
          ),
        ),
      );

    } catch (e) {
      print('Error al iniciar chat: $e');
      _showSnackBar('Error al iniciar el chat. Intenta de nuevo.', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.requestData;

    final String userName = request['nombre'] ?? 'Anónimo';
    final String requesterUserId = request['userId'] ?? '';
    final String userAvatar = request['avatar'] ?? 'assets/default_avatar.png';
    final String description = request['descripcion'] ?? 'Sin descripción';
    final String detail = request['detalle'] ?? 'Sin detalles adicionales.';
    final String category = request['categoria'] ?? 'N/A';
    final String locality = request['localidad'] ?? 'Desconocida';
    final String priority = request['prioridad'] ?? 'N/A';
    final double? latitude = request['latitude'];
    final double? longitude = request['longitude'];
    final String phone = request['phone'] ?? '';
    final String email = request['email'] ?? '';
    final bool showWhatsapp = request['showWhatsapp'] ?? false;
    final int userRating = request['userRating'] as int? ?? 4;
    final String memberSince = request['memberSince'] ?? 'Fecha no disponible';
    final int helpedCount = request['helpedCount'] as int? ?? 0;
    final int receivedHelpCount = request['receivedHelpCount'] as int? ?? 0;

    List<String> mediaUrls = [];
    final dynamic rawImages = request['imagenes'];
    final dynamic rawVideos = request['videos'];

    if (rawImages != null) {
      if (rawImages is List) {
        mediaUrls.addAll(List<String>.from(rawImages));
      } else if (rawImages is String) {
        mediaUrls.add(rawImages);
      }
    }
    if (rawVideos != null) {
      if (rawVideos is List) {
        for (var videoUrl in rawVideos) {
          if (!mediaUrls.contains(videoUrl.toString())) {
            mediaUrls.add(videoUrl.toString());
          }
        }
      } else if (rawVideos is String && !mediaUrls.contains(rawVideos)) {
        mediaUrls.add(rawVideos);
      }
    }

    Color priorityColor = Colors.grey;
    switch (priority) {
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Detalle de Solicitud',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección de Usuario y Prioridad
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: (userAvatar.startsWith('http'))
                        ? NetworkImage(userAvatar)
                        : AssetImage(userAvatar) as ImageProvider,
                    backgroundColor: Colors.grey[700],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < userRating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 18,
                            );
                          }),
                        ),
                        Text(
                          locality,
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: priorityColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Prioridad ${priority.toUpperCase()}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 0.5, color: Colors.grey),

              // Carrusel de Imágenes/Videos (¡Usando PageView.builder!)
              if (mediaUrls.isNotEmpty) ...[
                SizedBox(
                  height: 250, // Altura fija para el PageView
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: mediaUrls.length,
                    itemBuilder: (context, index) {
                      final mediaItem = mediaUrls[index];
                      // Lógica para mostrar videos o imágenes
                      if (mediaItem.toLowerCase().contains('.mp4') || mediaItem.toLowerCase().contains('.mov') ||
                          mediaItem.toLowerCase().contains('.avi') || mediaItem.toLowerCase().contains('.mkv')) {
                        final videoIndex = _videoControllers.indexWhere((controller) => controller.dataSource == Uri.parse(mediaItem));
                        if (videoIndex != -1 && _chewieControllers.length > videoIndex) {
                           final chewieController = _chewieControllers[videoIndex];
                           if (chewieController.videoPlayerController.value.isInitialized) {
                             return Padding(
                               padding: const EdgeInsets.symmetric(horizontal: 4.0),
                               child: ClipRRect(
                                 borderRadius: BorderRadius.circular(8),
                                 child: Chewie(
                                   controller: chewieController,
                                 ),
                               ),
                             );
                           } else {
                             return Container(
                               color: Colors.grey[700],
                               child: const Center(
                                 child: CircularProgressIndicator(color: Colors.amber),
                               ),
                             );
                           }
                        } else {
                           return Container(
                             color: Colors.grey[700],
                             child: const Center(
                               child: CircularProgressIndicator(color: Colors.amber),
                             ),
                           );
                        }
                      } else {
                        // Es una imagen
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              mediaItem,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[700],
                                child: const Icon(Icons.broken_image, color: Colors.white54, size: 60),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Descripción y Detalles
              Text(
                description,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),

              // Información del miembro
              const Text(
                'Información del Miembro:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Text(
                'Miembro desde: $memberSince',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                'Ayudó a ${helpedCount.toString().padLeft(4, '0')} Personas',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                'Recibió Ayuda de ${receivedHelpCount.toString().padLeft(4, '0')} Personas',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Opciones de Contacto
              const Text(
                'Contacto:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  if (latitude != null && longitude != null)
                    ActionChip(
                      avatar: const Icon(Icons.location_on, color: Colors.blue),
                      label: const Text('Ver en Mapa', style: TextStyle(color: Colors.black)),
                      backgroundColor: Colors.white,
                      onPressed: () => _launchMap(latitude, longitude),
                    ),
                  if (showWhatsapp && phone.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                      label: const Text('WhatsApp', style: TextStyle(color: Colors.black)),
                      backgroundColor: Colors.white,
                      onPressed: () => _launchWhatsapp(phone),
                    ),
                  if (email.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.email, color: Colors.blueAccent),
                      label: const Text('Email', style: TextStyle(color: Colors.black)),
                      backgroundColor: Colors.white,
                      onPressed: () => _launchEmail(email),
                    ),
                  // ¡Botón de Chat en RequestDetailScreen!
                  if (_currentUser != null && _currentUser!.uid != requesterUserId)
                    ActionChip(
                      avatar: const Icon(Icons.chat_bubble, color: Colors.blue),
                      label: const Text('Iniciar Chat', style: TextStyle(color: Colors.black)),
                      backgroundColor: Colors.white,
                      onPressed: () {
                        _startChatWithRequester(context, requesterUserId, userName); // Pasa el nombre del creador para el chat
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}