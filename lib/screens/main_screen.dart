import 'package:eslabon_flutter/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' show cos, asin, sqrt, sin, atan2, pi;
import 'dart:io' show Platform;

// Importaciones de tus propias pantallas (¡CORREGIDAS A eslabon_flutter!)
import 'package:eslabon_flutter/screens/create_request_screen.dart';
import 'package:eslabon_flutter/screens/profile_screen.dart';
import 'package:eslabon_flutter/screens/my_requests_screen.dart';
import 'package:eslabon_flutter/screens/favorites_screen.dart';
import 'package:eslabon_flutter/screens/chat_list_screen.dart';
import 'package:eslabon_flutter/screens/notifications_screen.dart';
import 'package:eslabon_flutter/screens/history_screen.dart';
import 'package:eslabon_flutter/screens/search_users_screen.dart';
import 'package:eslabon_flutter/screens/settings_screen.dart';
import 'package:eslabon_flutter/screens/faq_screen.dart';
import 'package:eslabon_flutter/screens/report_problem_screen.dart';
import 'package:eslabon_flutter/screens/request_detail_screen.dart';
import 'package:eslabon_flutter/user_reputation_widget.dart';

import 'package:eslabon_flutter/services/app_services.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final AppServices _appServices;

  User? _currentUser;

  String _currentFilterScope = 'Cercano';
  
  double? _userLatitude;
  double? _userLongitude;
  String _userLocality = 'Cargando ubicación...';
  double _proximityRadiusKm = 3.0;

  final Map<String, bool> _showFullCommentsSectionMap = {};
  final Map<String, TextEditingController> _commentControllers = {};

  final Set<String> _notifiedRequestIds = {};

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
    _determineAndSetUserLocation();
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
      ),
    );
  }

  Future<void> _determineAndSetUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Los servicios de ubicación están deshabilitados.', Colors.orange);
      print('DEBUG: Los servicios de ubicación están deshabilitados.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Permisos de ubicación denegados.', Colors.red);
        print('DEBUG: Permisos de ubicación denegados.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Permisos de ubicación permanentemente denegados. Habilítalos manualmente.', Colors.red);
      print('DEBUG: Permisos de ubicación permanentemente denegados.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      String localityName = 'Desconocida';
      if (placemarks.isNotEmpty) {
        localityName = placemarks.first.locality ?? placemarks.first.subLocality ?? placemarks.first.name ?? 'Desconocida';
      }
      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
        _userLocality = localityName;
      });
      _showSnackBar('Ubicación actual: $_userLocality', Colors.green);
      print('DEBUG: Ubicación obtenida y actualizada: Lat: $_userLatitude, Lon: $_userLongitude, Localidad: $_userLocality');
      
      // Asegurar que la UI se reconstruye para reflejar la ubicación
      setState(() {}); 

    } catch (e) {
      _showSnackBar('No se pudo obtener tu ubicación actual para filtros cercanos.', Colors.red);
      setState(() {
        _userLocality = 'No disponible';
        _userLatitude = null;
        _userLongitude = null;
      });
      print('DEBUG: Error al obtener ubicación: $e');
    }
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;

    var latDistance = _degreesToRadians(lat2 - lat1);
    var lonDistance = _degreesToRadians(lon2 - lon1);

    var a = sin(latDistance / 2) * sin(latDistance / 2) + 
            cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
                sin(lonDistance / 2) * sin(lonDistance / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = R * c;

    return distance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  void _checkAndNotifyNearbyRequest(List<QueryDocumentSnapshot> allRequests) {
    if (_userLatitude == null || _userLongitude == null) {
      print('DEBUG NOTIFY: No se puede chequear notificaciones cercanas sin ubicación del usuario.');
      return;
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      for (var doc in allRequests) {
        final request = doc.data() as Map<String, dynamic>;
        final String requestId = doc.id;
        final double? requestLat = request['latitude'];
        final double? requestLon = request['longitude'];
        final String requestDescription = request['descripcion'] ?? 'Solicitud de ayuda';
        final String requestName = request['nombre'] ?? 'Alguien';

        if (requestLat != null && requestLon != null) {
          final distance = _calculateDistance(_userLatitude!, _userLongitude!, requestLat, requestLon);
          if (distance <= _proximityRadiusKm && !_notifiedRequestIds.contains(requestId)) {
            _showSnackBar(
              '¡Nueva solicitud a ${distance.toStringAsFixed(1)} km! "${requestDescription}" de ${requestName}',
              Colors.lightBlueAccent,
            );
            _notifiedRequestIds.add(requestId);
            print('DEBUG NOTIFY: Notificación de SNACKBAR para ID: $requestId - Distancia: ${distance.toStringAsFixed(1)} km');
          }
        }
      }
    });
  }

  Future<void> _addComment(String requestId, String commentText) async {
    if (_currentUser == null || commentText.trim().isEmpty) {
      _showSnackBar('Debes iniciar sesión para comentar y el comentario no puede estar vacío.', Colors.red);
      return;
    }

    try {
      await _appServices.addComment(context, requestId, commentText);
    } catch (e) {
      _showSnackBar('Error al enviar el comentario.', Colors.red);
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

  Widget _buildCommentsButtonInCard(String requestId) {
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


  Widget _buildHelpCard(BuildContext context, Map<String, dynamic> request, String requestId) {
    final String _cardId = requestId;
    final String requesterUserId = request['userId'] ?? '';
    final String requesterName = request['nombre'] ?? 'Usuario Anónimo';
    final bool showWhatsapp = request['showWhatsapp'] ?? false;
    final bool showEmail = request['email'] != null && (request['email'] as String).isNotEmpty;
    final String requestPhone = request['phone'] ?? '';
    final String requestEmail = request['email'] ?? '';

    final String memberSince = request['memberSince'] ?? '05/07/2025';
    final int helpedCount = request['helpedCount'] as int? ?? 89;
    final int receivedHelpCount = request['receivedHelpCount'] as int? ?? 23;

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
    switch (request['prioridad']) {
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

    dynamic rawImages = request['imagenes'];
    String imageUrlToDisplay = '';
    if (rawImages != null) {
      if (rawImages is List && rawImages.isNotEmpty) {
        imageUrlToDisplay = rawImages.first.toString();
      } else if (rawImages is String) {
        imageUrlToDisplay = rawImages;
      }
    }
    
    final double? latitude = request['latitude'];
    final double? longitude = request['longitude'];


    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
      color: Colors.grey[800],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: Info de usuario, Prioridad y Tiempo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded( // Información de usuario (izquierda)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: (request['avatar'] != null && (request['avatar'] as String).startsWith('http'))
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
                                  request['nombre'] ?? 'Anónimo',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // MODIFICACIÓN: Reemplazado userRating estático por UserReputationWidget
                                UserReputationWidget(
                                  userId: requesterUserId,
                                  fromRequesters: false,
                                ),
                                Text(
                                  request['localidad'] ?? 'Desconocida',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Categoría: ${request['categoria'] ?? 'N/A'}',
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
                      const SizedBox(height: 8),
                      // "Ayudar" button
                      ElevatedButton(
                        onPressed: () {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser == null) {
                            _showSnackBar('Debes iniciar sesión para ofrecer ayuda.', Colors.red);
                            return;
                          }

                          // MODIFICADO: Usar GoRouter para navegar a request_detail
                          context.push('/request_detail/$requestId');
                          // Nota: Si RequestDetailScreen necesita 'requestData', tendrías que cargarlo desde Firestore
                          // dentro de RequestDetailScreen usando el requestId, o pasarlo via 'extra'.
                          // Por ahora, solo pasamos el ID como está configurado en tu router.
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Ayudar', style: TextStyle(fontSize: 12, color: Colors.black)),
                      ),
                    ],
                  ),
                ),
                Column( // Priority and time (top right)
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                            'Prioridad ${request['prioridad'] ?? 'N/A'}',
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

            // Request content (Image, Description, Detail)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Request image (left)
                SizedBox(
                  width: 120,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: imageUrlToDisplay.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrlToDisplay,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[700],
                                child: const Icon(Icons.broken_image, color: Colors.white54, size: 40),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.image_not_supported, color: Colors.white54, size: 40),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded( // Rest of content (description, details, icons, member info)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                            'Descripción: ${request['descripcion'] ?? 'Sin descripción'}',
                        style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                                'Detalles: ${request['detalle'] ?? 'Sin detalles'}',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Row: Contact icons on the left, Comments on the right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contact icons (left)
                          Row(
                            mainAxisSize: MainAxisSize.min,
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
                                    tooltip: 'Ver mapa',
                                  ),
                                ),
                              if (showWhatsapp && requestPhone.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: IconButton(
                                    iconSize: 24,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                                    onPressed: () async {
                                      _appServices.launchWhatsapp(context, requestPhone);
                                    },
                                    tooltip: 'WhatsApp',
                                  ),
                                ),
                              if (showEmail && requestEmail.isNotEmpty)
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
                                        path: requestEmail,
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
                                ),
                            ],
                          ),
                          // Comments section (right)
                          _buildCommentsButtonInCard(requestId),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Este usuario es miembro desde el ${request['memberSince'] ?? 'N/A'}',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Ayudó a ${request['helpedCount']?.toString().padLeft(4, '0') ?? '0000'} Personas',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Recibió Ayuda de ${request['receivedHelpCount']?.toString().padLeft(4, '0') ?? '0000'} Personas',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Ad Banner',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    String _dialogSelectedFilterScope = _currentFilterScope;
    double _dialogProximityRadiusKm = _proximityRadiusKm;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('Filtrar Ayudas por Alcance', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cercano por GPS', style: TextStyle(color: Colors.white70)),
                        Text(
                          _userLocality != 'No disponible' && _userLocality != 'Cargando ubicación...'
                            ? 'Ubicación actual: $_userLocality'
                            : (_userLatitude != null ? 'Ubicación obtenida.' : 'Ubicación no disponible.'),
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                    leading: Radio<String>(
                      value: 'Cercano',
                      groupValue: _dialogSelectedFilterScope,
                      onChanged: (String? value) {
                        setState(() {
                          _dialogSelectedFilterScope = value!;
                          if (value == 'Cercano' && (_userLatitude == null || _userLongitude == null)) {
                            _determineAndSetUserLocation(); 
                          }
                        });
                        print('DEBUG DIALOG: Filtro seleccionado en diálogo: $_dialogSelectedFilterScope');
                      },
                      activeColor: Colors.amber,
                    ),
                  ),
                  if (_dialogSelectedFilterScope == 'Cercano')
                    Column(
                      children: [
                        const SizedBox(height: 10),
                        Text('Radio de búsqueda: ${_dialogProximityRadiusKm.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white70)),
                        Slider(
                          value: _dialogProximityRadiusKm,
                          min: 1.0,
                          max: 100.0,
                          divisions: 99,
                          activeColor: Colors.amber,
                          inactiveColor: Colors.grey,
                          onChanged: (double newValue) {
                            setState(() {
                              _dialogProximityRadiusKm = newValue;
                            });
                          },
                        ),
                        if (_userLatitude == null || _userLongitude == null)
                          TextButton.icon(
                            onPressed: _determineAndSetUserLocation, 
                            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
                            label: const Text('Reintentar ubicación', style: TextStyle(color: Colors.blueAccent)),
                          ),
                      ],
                    ),
                  const Divider(color: Colors.white12),

                  ListTile(
                    title: const Text('Provincial (San Juan)', style: TextStyle(color: Colors.white70)),
                    leading: Radio<String>(
                      value: 'Provincial',
                      groupValue: _dialogSelectedFilterScope,
                      onChanged: (String? value) {
                        setState(() {
                          _dialogSelectedFilterScope = value!;
                        });
                        print('DEBUG DIALOG: Filtro seleccionado en diálogo: $_dialogSelectedFilterScope');
                      },
                      activeColor: Colors.amber,
                    ),
                  ),
                  ListTile(
                    title: const Text('Nacional (Argentina)', style: TextStyle(color: Colors.white70)),
                    leading: Radio<String>(
                      value: 'Nacional',
                      groupValue: _dialogSelectedFilterScope,
                      onChanged: (String? value) {
                        setState(() {
                          _dialogSelectedFilterScope = value!;
                        });
                        print('DEBUG DIALOG: Filtro seleccionado en diálogo: $_dialogSelectedFilterScope');
                      },
                      activeColor: Colors.amber,
                    ),
                  ),
                  ListTile(
                    title: const Text('Internacional', style: TextStyle(color: Colors.white70)),
                    leading: Radio<String>(
                      value: 'Internacional',
                      groupValue: _dialogSelectedFilterScope,
                      onChanged: (String? value) {
                        setState(() {
                          _dialogSelectedFilterScope = value!;
                        });
                        print('DEBUG DIALOG: Filtro seleccionado en diálogo: $_dialogSelectedFilterScope');
                      },
                      activeColor: Colors.amber,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); 
                  },
                ),
                TextButton(
                  child: const Text('Aplicar', style: TextStyle(color: Colors.amber)),
                  onPressed: () {
                    Navigator.of(dialogContext).pop({ 
                      'filterScope': _dialogSelectedFilterScope,
                      'proximityRadius': _dialogProximityRadiusKm,
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() { 
        _currentFilterScope = result['filterScope'];
        _proximityRadiusKm = result['proximityRadius'];
      });
      print('DEBUG DIALOG: Filtro aplicado desde diálogo a MainScreen: $_currentFilterScope con radio: $_proximityRadiusKm');
    } else {
      print('DEBUG DIALOG: Diálogo de filtro cancelado o sin resultado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG BUILD: Pantalla principal reconstruida. Filtro actual: $_currentFilterScope');
    print('DEBUG BUILD: Ubicación de usuario: Lat: $_userLatitude, Lon: $_userLongitude, Localidad: $_userLocality, Radio: ${_proximityRadiusKm.toStringAsFixed(1)}km');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            );
          },
        ),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 120, 
        
        flexibleSpace: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/logo.png',
                          height: 50,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0, bottom: 8.0, left: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 30.0),
                              child: const Text(
                                'Cadena de Favores Solidaria',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _showFilterDialog(context),
                                child: Row(
                                  children: [
                                    const Icon(Icons.filter_list, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      _currentFilterScope == 'Cercano'
                                        ? '${_proximityRadiusKm.toStringAsFixed(1)}km'
                                        : _currentFilterScope,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                                onPressed: () {
                                  // MODIFICADO: Usar GoRouter para navegar a create_request
                                  context.push('/create_request');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(_currentUser?.displayName ?? 'Usuario', style: const TextStyle(color: Colors.white)),
              accountEmail: Text(_currentUser?.email ?? 'email@example.com', style: TextStyle(color: Colors.white70)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.grey[700],
                backgroundImage: _currentUser?.photoURL != null && _currentUser!.photoURL!.startsWith('http')
                    ? NetworkImage(_currentUser!.photoURL!)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[800],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: Colors.white70),
              title: const Text('Inicio', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.go('/main'); // Generalmente 'inicio' es la pantalla principal o la que muestra solicitudes
              },
            ),
            ListTile(
              leading: Icon(Icons.person, color: Colors.white70),
              title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
            ListTile(
              leading: Icon(Icons.add_box, color: Colors.white70),
              title: const Text('Crear Solicitud', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // MODIFICADO: Usar GoRouter para navegar a create_request
                context.push('/create_request');
              },
            ),
            ListTile(
              leading: Icon(Icons.list_alt, color: Colors.white70),
              title: const Text('Mis Solicitudes', style: TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.go('/my_requests');
                  },
            ),
            ListTile(
              leading: Icon(Icons.favorite_border, color: Colors.white70),
              title: const Text('Mis Favoritos', style: TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.go('/favorites');
                  },
            ),
            ListTile(
              leading: Icon(Icons.chat_bubble_outline, color: Colors.white70),
              title: const Text('Mensajes', style: TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.go('/messages');
                  },
            ),
            ListTile(
              leading: Icon(Icons.notifications_none, color: Colors.white70),
              title: const Text('Notificaciones', style: TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    // Si tienes una ruta específica para notificaciones que no requiere ID, usa esa.
                    // Si siempre requiere ID, necesitarás pasar uno aquí (o un valor por defecto si aplica).
                    // Asumiendo que '/notifications' sin ID lleva a la lista general.
                    context.go('/notifications');
                  },
            ),
            ListTile(
              leading: Icon(Icons.history, color: Colors.white70),
              title: const Text('Historial de Ayudas', style: TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.go('/history');
                  },
            ),
            ListTile(
              leading: Icon(Icons.search, color: Colors.white70),
              title: const Text('Buscar Usuarios', style: TextStyle(color: Colors.white70)),
              onTap: () {
                    Navigator.pop(context);
                    context.go('/search_users');
                  },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: Icon(Icons.settings, color: Colors.white70),
              title: const Text('Configuración', style: TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.go('/settings');
                  },
            ),
            ListTile(
              leading: Icon(Icons.help_outline, color: Colors.white70),
              title: const Text('Ayuda y FAQ', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.go('/faq');
              },
            ),
            ListTile(
              leading: Icon(Icons.report_problem_outlined, color: Colors.white70),
              title: const Text('Reportar un Problema', style: TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.go('/report_problem');
                  },
            ),
            ListTile(
              leading: Icon(Icons.info, color: Colors.white70),
              title: const Text('Acerca de', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Acerca de Eslabón')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.white70),
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
              onTap: () async {
                await _auth.signOut();
                if (mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 0),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('solicitudes-de-ayuda')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                print('DEBUG STREAM: Estado de conexión: ${snapshot.connectionState}');
                print('DEBUG STREAM: ¿Tiene error?: ${snapshot.hasError}');
                if (snapshot.hasError) {
                  print('DEBUG STREAM ERROR: Error al cargar datos: ${snapshot.error}');
                  return Center(child: Text('Error al cargar datos: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  print('DEBUG STREAM: Conexión esperando datos...');
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  print('DEBUG STREAM: Snapshot NO tiene datos o docs está vacío.');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No hay solicitudes de ayuda disponibles para el filtro: $_currentFilterScope' +
                          (_currentFilterScope == 'Cercano' && _userLocality != 'No disponible'
                            ? ' dentro de ${_proximityRadiusKm.toStringAsFixed(1)} km de $_userLocality.'
                            : '.'),
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            _showFilterDialog(context);
                          },
                          style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                          ),
                          child: const Text('Cambiar Filtro'),
                        ),
                      ],
                    ),
                  );
                }

                final List<QueryDocumentSnapshot> allHelpRequestDocs = snapshot.data!.docs;
                print('DEBUG STREAM: Total de solicitudes cargadas de Firestore (antes de filtrar): ${allHelpRequestDocs.length}');

                _checkAndNotifyNearbyRequest(allHelpRequestDocs);


                final List<QueryDocumentSnapshot> filteredHelpRequestDocs = allHelpRequestDocs.where((doc) {
                  final request = doc.data() as Map<String, dynamic>;
                  final String requestProvincia = request['provincia'] ?? '';
                  final String requestCountry = request['country'] ?? '';
                  final double? requestLat = request['latitude'];
                  final double? requestLon = request['longitude'];
                  final String requestId = doc.id;
                  final String requestDescription = request['descripcion'] ?? 'N/A';
                  final String requestLocalidad = request['localidad'] ?? 'N/A';

                  bool isNearbyLocal = false;
                  if (_userLatitude != null && _userLongitude != null && requestLat != null && requestLon != null) {
                    final distance = _calculateDistance(_userLatitude!, _userLongitude!, requestLat, requestLon);
                    isNearbyLocal = distance <= _proximityRadiusKm;
                    print('DEBUG FILTER: Request ID: $requestId (Desc: "$requestDescription", Loc: "$requestLocalidad") - UserLoc: (${_userLatitude?.toStringAsFixed(4)}, ${_userLongitude?.toStringAsFixed(4)}), ReqLoc: (${requestLat.toStringAsFixed(4)}, ${requestLon.toStringAsFixed(4)}) - Distancia: ${distance.toStringAsFixed(2)} km, ¿Está Cerca (${_proximityRadiusKm.toStringAsFixed(1)} km)? $isNearbyLocal');
                  } else {
                    print('DEBUG FILTER: Request ID: $requestId (Desc: "$requestDescription", Loc: "$requestLocalidad") - Ubicación de usuario ($_userLatitude, $_userLongitude) o solicitud ($requestLat, $requestLon) nula para filtro "Cercano". Pasa: false');
                  }

                  bool passesFilter = false;
                  if (_currentFilterScope == 'Cercano') {
                    passesFilter = isNearbyLocal;
                    print('DEBUG FILTER: Filtro: Cercano, Pasa: $passesFilter');
                  } else if (_currentFilterScope == 'Provincial') {
                    const String userProvincia = 'San Juan';
                    passesFilter = (requestProvincia == userProvincia); 
                    print('DEBUG FILTER: Request ID: $requestId (Desc: "$requestDescription", Loc: "$requestLocalidad") - Filtro: Provincial, Request Provincia: "$requestProvincia", Pasa: $passesFilter');
                  } else if (_currentFilterScope == 'Nacional') {
                    passesFilter = (requestCountry == 'Argentina'); 
                    print('DEBUG FILTER: Filtro: Nacional, Request País: "$requestCountry", Pasa: $passesFilter');
                  } else if (_currentFilterScope == 'Internacional') {
                    passesFilter = true;
                    print('DEBUG FILTER: Filtro: Internacional, Pasa: $passesFilter');
                  }
                  print('DEBUG FILTER: Solicitud ID: $requestId (Desc: "$requestDescription") - Resultado final del filtro: $passesFilter');
                  return passesFilter;
                }).toList();

                print('DEBUG STREAM: Total de solicitudes filtradas a mostrar: ${filteredHelpRequestDocs.length}');


                if (filteredHelpRequestDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No hay solicitudes de ayuda disponibles para el filtro: $_currentFilterScope' +
                          (_currentFilterScope == 'Cercano' && _userLocality != 'No disponible'
                            ? ' dentro de ${_proximityRadiusKm.toStringAsFixed(1)} km de $_userLocality.'
                            : '.'),
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            _showFilterDialog(context);
                          },
                          style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                          ),
                          child: const Text('Cambiar Filtro'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredHelpRequestDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredHelpRequestDocs[index];
                    print('DEBUG STREAM: Mostrando publicación: ID: ${doc.id}, Descripción: ${doc.data() is Map ? (doc.data() as Map)['descripcion'] ?? 'N/A' : 'N/A'}');
                    return _buildHelpCard(context, doc.data() as Map<String, dynamic>, doc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}