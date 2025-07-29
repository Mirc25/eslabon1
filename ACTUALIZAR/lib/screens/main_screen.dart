import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; // Eliminado
import 'package:geolocator/geolocator.dart'; // Importar geolocator
import 'package:geocoding/geocoding.dart'; // Importar geocoding
import 'dart:math' show cos, asin, sqrt, sin, atan2, pi; // Añade sin, atan2, pi para Haversine
import 'dart:io';

// Importa tus pantallas internas del Drawer
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
// import 'package:eslabon_flutter/screens/request_detail_screen.dart'; // Mantener si usas esta pantalla
// import 'package:eslabon_flutter/screens/chat_screen.dart'; // Mantener si usas esta pantalla


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  String _currentFilterScope = 'Cercano'; 
  
  double? _userLatitude;
  double? _userLongitude;
  String _userLocality = 'Cargando ubicación...';
  double _proximityRadiusKm = 20.0; 

  final Map<String, bool> _showFullCommentsSectionMap = {};  
  final Map<String, TextEditingController> _commentControllers = {};
  // final Map<String, bool> _showEmojiPickerMap = {}; // Eliminado


  @override
  void initState() {
    super.initState();
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

  Future<void> _determineAndSetUserLocation() async { 
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Los servicios de ubicación están deshabilitados.', Colors.orange);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Permisos de ubicación denegados.', Colors.red);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Permisos de ubicación permanentemente denegados. Habilítalos manualmente.', Colors.red);
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
    } catch (e) {
      debugPrint("Error al obtener ubicación del usuario: $e");
      _showSnackBar('No se pudo obtener tu ubicación actual.', Colors.red);
      setState(() {
        _userLocality = 'No disponible';
      });
    }
  }
  
  // Función para calcular la distancia entre dos puntos geográficos (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Radius of Earth in kilometers

    var latDistance = _degreesToRadians(lat2 - lat1);
    var lonDistance = _degreesToRadians(lon2 - lon1);

    var a = sin(latDistance / 2) * sin(latDistance / 2) +
            cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
                sin(lonDistance / 2) * sin(lonDistance / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = R * c;

    return distance; // Distance in kilometers
  }

  // Función auxiliar para convertir grados a radianes
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }


  Future<void> _launchMap(double latitude, double longitude) async {
    final uri = Uri.parse('http://googleusercontent.com/maps.google.com/?q=$latitude,$longitude');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa.')),
      );
    }
  }

  Future<void> _addComment(String requestId, String commentText) async {
    if (_currentUser == null || commentText.trim().isEmpty) {
      _showSnackBar('Debes iniciar sesión para comentar y el comentario no puede estar vacío.', Colors.red);
      return;
    }

    try {
      await _firestore
          .collection('solicitudes-de-ayuda')
          .doc(requestId)
          .collection('comments')
          .add({
        'userId': _currentUser!.uid,
        'userName': _currentUser!.displayName ?? 'Usuario de Eslabón',
        'userAvatar': _currentUser!.photoURL,
        'text': commentText.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (_commentControllers.containsKey(requestId)) {
        _commentControllers[requestId]!.clear();
      }
    } catch (e) {
      print('Error al añadir comentario: $e');
      _showSnackBar('Error al enviar el comentario.', Colors.red);
    }
  }

  // Si aún necesitas _startChatWithRequester, asegúrate de que ChatScreen esté importado
  // Future<void> _startChatWithRequester(BuildContext context, String requesterUserId, String requesterName) async {
  //   if (_currentUser == null) {
  //     _showSnackBar('Debes iniciar sesión para chatear.', Colors.red);
  //     return;
  //   }
  //   // ... lógica de chat ...
  // }


  // REESTRUCTURADO: _buildCommentsSection para manejar la lógica de expandir/colapsar y el input
  Widget _buildCommentsSection(String requestId) {
    // Inicializar controladores y estados si no existen
    if (!_commentControllers.containsKey(requestId)) {
      _commentControllers[requestId] = TextEditingController();
      _showFullCommentsSectionMap[requestId] = false; // Por defecto no expandido
    }
    final TextEditingController commentController = _commentControllers[requestId]!;
    final bool showFullCommentsSection = _showFullCommentsSectionMap[requestId]!;


    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('solicitudes-de-ayuda')
          .doc(requestId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, commentSnapshot) {
        if (commentSnapshot.hasError) {
          return Text('Error: ${commentSnapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 10));
        }
        if (commentSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2));
        }

        final List<Map<String, dynamic>> allComments = commentSnapshot.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        final int commentsCount = allComments.length;

        // ESTA ES LA SECCIÓN QUE VA A LA IZQUIERDA DEL BLOQUE DE ICONOS DE CONTACTO Y INFO DE MIEMBRO
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Alinea el contenido a la izquierda (por ejemplo, el texto de "Sé el primero...")
          children: [
            // Botón "Comentarios (X)" para expandir/colapsar - SOLO EL NÚMERO
            GestureDetector(
              onTap: () {
                setState(() {
                  _showFullCommentsSectionMap[requestId] = !showFullCommentsSection;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0), // Pequeño padding para el área táctil
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Ajusta al contenido
                  children: [
                    const Icon(Icons.comment, color: Colors.amber, size: 18), // Icono más pequeño para no robar espacio
                    const SizedBox(width: 4),
                    Text(
                      commentsCount.toString(), // Solo el número de comentarios
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber), // Fuente pequeña
                    ),
                  ],
                ),
              ),
            ),

            // Contenido de la sección de comentarios expandida (lista + input)
            if (showFullCommentsSection)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Los elementos dentro de esta columna se alinean a la izquierda
                children: [
                  const SizedBox(height: 8), // Espacio entre el botón y la lista

                  // Lista de comentarios
                  if (commentsCount > 0)
                    ...allComments.map((comment) {
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
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: (userAvatar != null && userAvatar.startsWith('http'))
                                  ? NetworkImage(userAvatar)
                                  : const AssetImage('assets/default_avatar.png') as ImageProvider,
                              backgroundColor: Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
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
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        formattedTime,
                                        style: TextStyle(fontSize: 9, color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    commentText,
                                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  if (commentsCount == 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: Text(
                          'Sé el primero en comentar.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Campo de entrada de comentario
                  if (_currentUser != null)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: commentController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Tu comentario...',
                                  hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                                  filled: true,
                                  fillColor: Colors.grey[900],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  // Eliminado: el prefixIcon para emojis ya no existe
                                ),
                                minLines: 1,
                                maxLines: 3,
                                onTap: () {
                                  // Eliminado: la lógica de onTap para emojis ya no existe
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                _addComment(requestId, commentController.text);
                                commentController.clear();
                                // Eliminado: la lógica de emojis al enviar ya no existe
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.send, color: Colors.black, size: 20),
                              ),
                            ),
                          ],
                        ),
                        // Eliminado: el Offstage para el EmojiPicker ya no existe
                      ],
                    ),
                  // Mensaje si no está logueado
                  if (_currentUser == null)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(
                        child: Text(
                          'Inicia sesión para comentar.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
          ],
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

    final int userRating = request['userRating'] as int? ?? 4;
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
                                Row( // Estrellas de calificación
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < userRating ? Icons.star : Icons.star_border,
                                      color: Colors.amber, 
                                      size: 14, 
                                    );
                                  }),
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
                      // Botón "Ayudar"
                      ElevatedButton(
                        onPressed: () {
                          // Lógica para "Ayudar"
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Necesitas ayuda con ${request['descripcion']} de ${request['nombre']}')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber, 
                          foregroundColor: Colors.black, 
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Ayudar', style: TextStyle(fontSize: 12, color: Colors.black)),
                      ),
                    ],
                  ),
                ),
                Column( // Prioridad y tiempo (derecha superior)
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                            'Prioridad ${request['prioridad'] ?? 'N/A'}', // Texto completo "Prioridad"
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expira en $timeRemainingText', // Texto completo "Expira en"
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

            // Contenido de la solicitud (Imagen, Descripción, Detalle)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                // Imagen de la solicitud (izquierda)
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
                Expanded( // El resto del contenido (descripción, detalles, iconos, info miembro)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(
                            request['descripcion'] ?? 'Sin descripción',
                        style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                            request['detalle'] ?? 'Sin detalles',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8), // Reducido el espacio aquí para compactar
                      
                      // BLOQUE DE ÍCONOS Y DATOS DE MIEMBRO
                      Row( // Fila principal para comentarios a la izquierda y grupo de íconos/info a la derecha
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribuye el espacio horizontalmente
                        crossAxisAlignment: CrossAxisAlignment.start, // Alinea al inicio verticalmente
                        children: [
                          // Sección de Comentarios (izquierda)
                          _buildCommentsSection(requestId),
                          
                          // Grupo de Íconos de Contacto y Información de Miembro (derecha)
                          Column( 
                            mainAxisSize: MainAxisSize.min, 
                            crossAxisAlignment: CrossAxisAlignment.center, // Centra horizontalmente los elementos dentro de esta columna
                            children: [
                              // Fila de los 3 íconos (Mapa, WhatsApp, Email) - Juntos y centrados
                              Row( 
                                mainAxisAlignment: MainAxisAlignment.center, // Centra los íconos horizontalmente
                                mainAxisSize: MainAxisSize.min, // Ocupa el mínimo espacio
                                children: [
                                  if (latitude != null && longitude != null)
                                    IconButton(
                                      iconSize: 24,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.location_on, color: Colors.blue),
                                      onPressed: () => _launchMap(latitude, longitude),
                                      tooltip: 'Ver mapa',
                                    ),
                                  if (showWhatsapp && requestPhone.isNotEmpty)
                                    IconButton(
                                      iconSize: 24,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                                      onPressed: () async {
                                        final url = 'https://wa.me/${requestPhone.replaceAll('+', '')}';
                                        if (await canLaunchUrl(Uri.parse(url))) {
                                          await launchUrl(Uri.parse(url));
                                        } else {
                                          _showSnackBar('No se pudo abrir WhatsApp.', Colors.red);
                                        }
                                      },
                                      tooltip: 'WhatsApp',
                                    ),
                                  if (showEmail && requestEmail.isNotEmpty)
                                    IconButton(
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
                                ],
                              ),
                              const SizedBox(height: 4), 
                              Text(
                                'Este usuario es miembro desde el $memberSince',
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                                textAlign: TextAlign.center, 
                              ),
                              Text(
                                'Ayudó a ${helpedCount.toString().padLeft(4, '0')} Personas', 
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                                textAlign: TextAlign.center, 
                              ),
                              Text(
                                'Recibió Ayuda de ${receivedHelpCount.toString().padLeft(4, '0')} Personas', 
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                                textAlign: TextAlign.center, 
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), // Espacio reducido antes del Ad Banner

            // Ad Banner
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

  void _showFilterDialog(BuildContext context) {
    showDialog(
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
                  // Opción "Cercano por GPS"
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
                      groupValue: _currentFilterScope,
                      onChanged: (String? value) {
                        setState(() {
                          _currentFilterScope = value!;
                          if (value == 'Cercano' && (_userLatitude == null || _userLongitude == null)) {
                            _determineAndSetUserLocation(); 
                          }
                        });
                      },
                      activeColor: Colors.amber,
                    ),
                  ),
                  if (_currentFilterScope == 'Cercano') 
                    Column(
                      children: [
                        const SizedBox(height: 10),
                        Text('Radio de búsqueda: ${_proximityRadiusKm.toStringAsFixed(0)} km', style: const TextStyle(color: Colors.white70)),
                        Slider(
                          value: _proximityRadiusKm,
                          min: 1.0,
                          max: 100.0, 
                          divisions: 99, 
                          activeColor: Colors.amber,
                          inactiveColor: Colors.grey,
                          onChanged: (double newValue) {
                            setState(() {
                              _proximityRadiusKm = newValue;
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
                      groupValue: _currentFilterScope,
                      onChanged: (String? value) {
                        setState(() {
                          _currentFilterScope = value!;
                        });
                        Navigator.of(dialogContext).pop();
                      },
                      activeColor: Colors.amber,
                    ),
                  ),
                  ListTile(
                    title: const Text('Nacional (Argentina)', style: TextStyle(color: Colors.white70)),
                    leading: Radio<String>(
                      value: 'Nacional',
                      groupValue: _currentFilterScope,
                      onChanged: (String? value) {
                        setState(() {
                          _currentFilterScope = value!;
                        });
                        Navigator.of(dialogContext).pop();
                      },
                      activeColor: Colors.amber,
                    ),
                  ),
                  ListTile(
                    title: const Text('Internacional', style: TextStyle(color: Colors.white70)),
                    leading: Radio<String>(
                      value: 'Internacional',
                      groupValue: _currentFilterScope,
                      onChanged: (String? value) {
                        setState(() {
                          _currentFilterScope = value!;
                        });
                        Navigator.of(dialogContext).pop();
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
                    Navigator.of(dialogContext).pop();
                    // Al cerrar el diálogo, el StreamBuilder en build() se reconstruirá con el nuevo filtro
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo principal negro
      appBar: AppBar(
        // El botón de hamburguesa se mantiene como 'leading'
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white), // Icono de hamburguesa blanco
              onPressed: () {
                Scaffold.of(context).openDrawer(); // Abre el Drawer
              },
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
            );
          },
        ),
        // No usamos 'title' ni 'actions' directos en AppBar, todo va en flexibleSpace
        title: null,
        actions: [],
        
        backgroundColor: Colors.grey[900], // Color del AppBar oscuro
        iconTheme: const IconThemeData(color: Colors.white), // Afecta el color del leading (hamburguesa)
        toolbarHeight: 150, // Altura del AppBar. Ajusta este valor para que el logo y los botones quepan bien sin espacio vacío.
                           // Con logo de 80, fila de botones de unos 48, y padding, 150 debería dar espacio.
        
        // FlexibleSpace para construir el contenido personalizado de la AppBar
        flexibleSpace: SafeArea( // Usamos SafeArea para respetar la barra de estado superior
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end, // Alinea el contenido a la parte inferior del flexibleSpace
            children: [
              // El logo: Centrado en la parte superior del espacio disponible
              Expanded(
                child: Center( // Centra el logo horizontalmente
                  child: Image.asset(
                    'assets/logo.png',
                    height: 80, // Logo más grande (altura 80)
                  ),
                ),
              ),
              // Fila de botones de filtro y añadir: Alineada a la derecha, debajo del logo
              Padding(
                padding: const EdgeInsets.only(right: 16.0, bottom: 8.0), // Padding a la derecha y abajo
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // Alinea los botones a la derecha
                  children: [
                    TextButton(
                      onPressed: () => _showFilterDialog(context),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(_currentFilterScope, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white), // Icono de añadir
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CreateRequestScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[900], // Un gris oscuro para el Drawer
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
                context.go('/home');
              },
            ),
            ListTile(
              leading: Icon(Icons.person, color: Colors.white70),
              title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)), 
              onTap: () {
                Navigator.pop(context); 
                // context.push('/profile'); // Si usas GoRouter, es push para pantallas sin pop
                context.go('/profile'); // Si usas GoRouter para navegación completa
              },
            ),
            ListTile(
              leading: Icon(Icons.add_box, color: Colors.white70),
              title: const Text('Crear Solicitud', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateRequestScreen()),
                );
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
              title: const Text('Buscar Usuarios', style: TextStyle(color: Colors.white)),
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
                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar datos: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No hay solicitudes de ayuda disponibles.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center, 
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Filtro actual: $_currentFilterScope',
                          style: const TextStyle(color: Colors.white54, fontSize: 14),
                          textAlign: TextAlign.center, 
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateRequestScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                          ),
                          child: const Text('Crear mi primera solicitud'),
                        ),
                      ],
                    ),
                  );
                }

                final List<QueryDocumentSnapshot> allHelpRequestDocs = snapshot.data!.docs;

                final List<QueryDocumentSnapshot> filteredHelpRequestDocs = allHelpRequestDocs.where((doc) {
                  final request = doc.data() as Map<String, dynamic>;
                  final String requestProvincia = request['provincia'] ?? '';
                  final String requestCountry = request['country'] ?? '';
                  final double? requestLat = request['latitude'];
                  final double? requestLon = request['longitude'];

                  if (_currentFilterScope == 'Provincial') {
                    const String userProvincia = 'San Juan'; 
                    return requestProvincia == userProvincia;
                  } else if (_currentFilterScope == 'Nacional') {
                    return requestCountry == 'Argentina';
                  } else if (_currentFilterScope == 'Internacional') {
                    return true;
                  } else if (_currentFilterScope == 'Cercano') {
                    if (_userLatitude != null && _userLongitude != null && requestLat != null && requestLon != null) {
                      final distance = _calculateDistance(_userLatitude!, _userLongitude!, requestLat, requestLon);
                      return distance <= _proximityRadiusKm;
                    }
                    return false; 
                  }
                  return false;
                }).toList();


                if (filteredHelpRequestDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No hay solicitudes de ayuda en $_currentFilterScope' + 
                          (_currentFilterScope == 'Cercano' ? ' dentro de ${_proximityRadiusKm.toStringAsFixed(0)} km de $_userLocality.' : '.'),
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
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