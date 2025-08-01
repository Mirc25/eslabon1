// lib/screens/main_screen.dart
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
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importaciones de tus propias pantallas y proveedores
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
import 'package:eslabon_flutter/providers/user_provider.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/providers/location_provider.dart';
import 'package:eslabon_flutter/providers/help_requests_provider.dart';


class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final AppServices _appServices;

  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _notifiedRequestIds = {};

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
  }

  @override
  void dispose() {
    _commentControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  void _checkAndNotifyNearbyRequest(List<QueryDocumentSnapshot> allRequests, UserLocationData userLocation, double proximityRadiusKm) {
    if (userLocation.latitude == null || userLocation.longitude == null) {
      print('DEBUG NOTIFY: No se puede chequear notificaciones cercanas sin ubicación del usuario.');
      return;
    }

    Future.microtask(() {
      for (var doc in allRequests) {
        final request = doc.data() as Map<String, dynamic>;
        final String requestId = doc.id;
        final double? requestLat = request['latitude'];
        final double? requestLon = request['longitude'];
        final String requestDescription = request['descripcion'] ?? 'Solicitud de ayuda';
        final String requestName = request['nombre'] ?? 'Alguien';

        if (requestLat != null && requestLon != null) {
          final distance = _calculateDistance(userLocation.latitude!, userLocation.longitude!, requestLat, requestLon);
          if (distance <= proximityRadiusKm && !_notifiedRequestIds.contains(requestId)) {
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


  Future<void> _addComment(String requestId, String commentText) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null || commentText.trim().isEmpty) {
      _showSnackBar('Debes iniciar sesión para comentar y el comentario no puede estar vacío.', Colors.red);
      return;
    }

    try {
      await _appServices.addComment(context, requestId, commentText);
    } catch (e) {
      _showSnackBar('Error al enviar el comentario.', Colors.red);
    }
  }

  void _showCommentsModal(String requestId, User? currentUser) {
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
                        reverse: true,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final String commentUser = comment['userName'] ?? 'Usuario';
                          final String commentText = comment['text'] ?? 'Sin comentario';
                          final String? userAvatar = comment['userAvatar'] as String?;
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

  Widget _buildCommentsButtonInCard(String requestId, User? currentUser) {
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
          onTap: () => _showCommentsModal(requestId, currentUser),
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


  Widget _buildHelpCard(BuildContext context, Map<String, dynamic> request, String requestId, User? currentUser) {
    final Map<String, dynamic> requestData = request;

    final String requesterUserId = requestData['userId'] ?? '';
    final String requesterName = requestData['nombre'] ?? 'Usuario Anónimo';
    final bool showWhatsapp = requestData['showWhatsapp'] ?? false;
    final bool showEmail = requestData['email'] != null && (requestData['email'] as String).isNotEmpty;
    final String requestPhone = requestData['phone'] ?? '';
    final String requestEmail = requestData['email'] ?? '';

    final String memberSince = requestData['memberSince'] ?? 'N/A';
    // ✅ CORREGIDO: Leer como tipo numérico para evitar errores de tipo
    final int helpedCount = (requestData['helpedCount'] as num? ?? 0).toInt();
    final int receivedHelpCount = (requestData['receivedHelpCount'] as num? ?? 0).toInt();

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
    switch (requestData['prioridad']) {
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

    dynamic rawImages = requestData['imagenes'];
    String imageUrlToDisplay = '';
    if (rawImages != null) {
      if (rawImages is List && rawImages.isNotEmpty) {
        imageUrlToDisplay = rawImages.first.toString();
      } else if (rawImages is String) {
        imageUrlToDisplay = rawImages;
      }
    }
    
    final double? latitude = requestData['latitude'];
    final double? longitude = requestData['longitude'];


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
                            backgroundImage: (requestData['avatar'] != null && (requestData['avatar'] as String).startsWith('http'))
                                ? NetworkImage(requestData['avatar'] as String)
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
                                  requestData['localidad'] ?? 'Desconocida',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Categoría: ${requestData['categoria'] ?? 'N/A'}',
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
                      ElevatedButton(
                        onPressed: () {
                          if (currentUser == null) {
                            _showSnackBar('Debes iniciar sesión para ofrecer ayuda.', Colors.red);
                            return;
                          }

                          context.pushNamed(
                            'request_detail',
                            pathParameters: {'requestId': requestId},
                            extra: requestData,
                          );
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
                            'Prioridad ${requestData['prioridad'] ?? 'N/A'}',
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

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                            'Descripción: ${requestData['descripcion'] ?? 'Sin descripción'}',
                        style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                                'Detalles: ${requestData['detalle'] ?? 'Sin detalles'}',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          _buildCommentsButtonInCard(requestId, currentUser),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Este usuario es miembro desde el ${memberSince}',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        textAlign: TextAlign.start,
                      ),
                      Text(
                        'Ayudó a ${helpedCount.toString().padLeft(4, '0')} Personas',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        textAlign: TextAlign.start,
                      ),
                      Text(
                        'Recibió Ayuda de ${receivedHelpCount.toString().padLeft(4, '0')} Personas',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        textAlign: TextAlign.start,
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

  Future<void> _showFilterDialog(BuildContext dialogContext, String currentFilterScope, double proximityRadiusKm) async {
    String _dialogSelectedFilterScope = currentFilterScope;
    double _dialogProximityRadiusKm = proximityRadiusKm;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: dialogContext,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            final userLocation = ref.watch(userLocationProvider);
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
                          userLocation.statusMessage,
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                    leading: Radio<String>(
                      value: 'Cercano',
                      groupValue: _dialogSelectedFilterScope,
                      onChanged: (String? value) {
                        stfSetState(() {
                          _dialogSelectedFilterScope = value!;
                          if (value == 'Cercano' && (userLocation.latitude == null || userLocation.longitude == null)) {
                            ref.read(userLocationProvider.notifier).determineAndSetUserLocation();
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
                            stfSetState(() {
                              _dialogProximityRadiusKm = newValue;
                            });
                          },
                        ),
                        if (userLocation.latitude == null || userLocation.longitude == null)
                          TextButton.icon(
                            onPressed: () => ref.read(userLocationProvider.notifier).determineAndSetUserLocation(),
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
                        stfSetState(() {
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
                        stfSetState(() {
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
                        stfSetState(() {
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
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Aplicar', style: TextStyle(color: Colors.amber)),
                  onPressed: () {
                    Navigator.of(context).pop({
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
      ref.read(filterScopeProvider.notifier).state = result['filterScope'];
      ref.read(proximityRadiusProvider.notifier).state = result['proximityRadius'];
      print('DEBUG DIALOG: Filtro aplicado desde diálogo a MainScreen: ${result['filterScope']} con radio: ${result['proximityRadius']}');
    } else {
      print('DEBUG DIALOG: Diálogo de filtro cancelado o sin resultado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = ref.watch(userProvider).value;
    final String currentFilterScope = ref.watch(filterScopeProvider);
    final double proximityRadiusKm = ref.watch(proximityRadiusProvider);
    final UserLocationData userLocation = ref.watch(userLocationProvider);
    final AsyncValue<List<QueryDocumentSnapshot>> filteredRequestsAsyncValue = ref.watch(filteredHelpRequestsProvider);

    print('DEBUG BUILD: Pantalla principal reconstruida. Filtro actual: $currentFilterScope');
    print('DEBUG BUILD: Ubicación de usuario: Lat: ${userLocation.latitude}, Lon: ${userLocation.longitude}, Localidad: ${userLocation.locality}, Radio: ${proximityRadiusKm.toStringAsFixed(1)}km');

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomBackground(
        child: Stack(
          children: [
            Column(
              children: [
                AppBar(
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
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  toolbarHeight: 120,
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo pequeño
                      Image.asset(
                        'assets/icon.jpg',
                        height: 50,
                      ),
                      const SizedBox(height: 10),
                      // Texto
                      const Text(
                        'Cadena de Favores Solidaria',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                  centerTitle: true,
                  actions: [
                    TextButton(
                      onPressed: () => _showFilterDialog(context, currentFilterScope, proximityRadiusKm),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            currentFilterScope == 'Cercano'
                              ? '${proximityRadiusKm.toStringAsFixed(1)}km'
                              : currentFilterScope,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                Expanded(
                  child: filteredRequestsAsyncValue.when(
                    data: (filteredHelpRequestDocs) {
                      print('DEBUG STREAM: Estado de conexión: ConnectionState.active');
                      print('DEBUG STREAM: ¿Tiene error?: false');
                      print('DEBUG STREAM: Total de solicitudes filtradas a mostrar: ${filteredHelpRequestDocs.length}');

                      _checkAndNotifyNearbyRequest(filteredHelpRequestDocs, userLocation, proximityRadiusKm);

                      if (filteredHelpRequestDocs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'No hay solicitudes de ayuda disponibles para el filtro: $currentFilterScope' +
                                (currentFilterScope == 'Cercano' && userLocation.locality != 'No disponible'
                                  ? ' dentro de ${proximityRadiusKm.toStringAsFixed(1)} km de ${userLocation.locality}.'
                                  : '.'),
                                style: TextStyle(color: Colors.white70, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  _showFilterDialog(context, currentFilterScope, proximityRadiusKm);
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
                          return _buildHelpCard(context, doc.data() as Map<String, dynamic>, doc.id, currentUser);
                        },
                      );
                    },
                    loading: () {
                      print('DEBUG STREAM: Conexión esperando datos...');
                      return const Center(child: CircularProgressIndicator(color: Colors.amber));
                    },
                    error: (err, stack) {
                      print('DEBUG STREAM ERROR: Error al cargar datos: $err');
                      return Center(child: Text('Error al cargar datos: $err', style: const TextStyle(color: Colors.red)));
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 16.0,
              right: 16.0,
              child: FloatingActionButton(
                onPressed: () {
                  context.pushNamed('create_request');
                },
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(currentUser?.displayName ?? 'Usuario', style: const TextStyle(color: Colors.white)),
              accountEmail: Text(currentUser?.email ?? 'email@example.com', style: TextStyle(color: Colors.white70)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.grey[700],
                backgroundImage: currentUser?.photoURL != null && currentUser!.photoURL!.startsWith('http')
                    ? NetworkImage(currentUser!.photoURL!)
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
                context.go('/main');
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
                context.pushNamed('create_request');
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
                _showSnackBar(
                  'Desarrollado por Oviedo. Hecho con ❤️ en Argentina.',
                  Colors.blueAccent,
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
    );
  }
}