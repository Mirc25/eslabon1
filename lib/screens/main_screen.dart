// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math' show cos, asin, sqrt, sin, atan2, pi;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/user_reputation_widget.dart';
import 'package:eslabon_flutter/providers/user_provider.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/providers/location_provider.dart';
import 'package:eslabon_flutter/providers/help_requests_provider.dart';
import 'package:eslabon_flutter/widgets/spinning_image_loader.dart';
import 'package:eslabon_flutter/models/user_model.dart';
import 'package:eslabon_flutter/widgets/banner_ad_widget.dart';
import '../widgets/custom_app_bar.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with TickerProviderStateMixin {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late final AppServices _appServices;

  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _notifiedRequestIds = {};
  final Map<String, String> _profilePictureUrlCache = {}; // ✅ Añadido: Cache para las URLs de las fotos de perfil

  final List<String> _categories = ['Todas', 'Personas', 'Animales', 'Objetos', 'Servicios', 'Otros'];
  String _selectedCategory = 'Todas';

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_blinkController);
  }

  @override
  void dispose() {
    _commentControllers.forEach((key, controller) => controller.dispose());
    _blinkController.dispose();
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
      print('DEBUG NOTIFY: No se puede chequear notificaciones cercanas sin ubicación del usuario.'.tr());
      return;
    }

    Future.microtask(() {
      for (var doc in allRequests) {
        final request = doc.data() as Map<String, dynamic>;
        final String requestId = doc.id;
        final double? requestLat = (request['latitude'] as num?)?.toDouble();
        final double? requestLon = (request['longitude'] as num?)?.toDouble();

        if (requestLat != null && requestLon != null) {
          final distance = _calculateDistance(userLocation.latitude!, userLocation.longitude!, requestLat, requestLon);
          if (distance <= proximityRadiusKm && !_notifiedRequestIds.contains(requestId)) {
            _notifiedRequestIds.add(requestId);
            print('DEBUG NOTIFY: Se ha detectado una nueva solicitud cercana, pero la notificación emergente fue deshabilitada. ID: $requestId - Distancia: ${distance.toStringAsFixed(1)} km');
          }
        }
      }
    });
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
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

  Future<void> _addComment(String requestId, String commentText) async {
    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null || commentText.trim().isEmpty) {
      _showSnackBar('Debes iniciar sesión para comentar y el comentario no puede estar vacío.'.tr(), Colors.red);
      return;
    }

    try {
      await _appServices.addComment(context, requestId, commentText);
    } catch (e) {
      _showSnackBar('Error al enviar el comentario.'.tr(), Colors.red);
    }
  }

  void _showCommentsModal(String requestId, firebase_auth.User? currentUser) {
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
                  title: Text('comments_count_plural'.tr(), style: const TextStyle(color: Colors.white)),
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
                              hintText: 'enter_message_hint'.tr(),
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

  Widget _buildCommentsButtonInCard(String requestId, firebase_auth.User? currentUser) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('solicitudes-de-ayuda')
          .doc(requestId)
          .collection('comments')
          .snapshots(),
      builder: (context, commentSnapshot) {
        if (commentSnapshot.hasError) {
          return const Row(children: [Icon(Icons.comment, color: Colors.red, size: 24), SizedBox(width: 4), Text('Error', style: TextStyle(fontSize: 10, color: Colors.red))]);
        }
        if (commentSnapshot.connectionState == ConnectionState.waiting) {
          return const Row(children: [Icon(Icons.comment, color: Colors.grey, size: 24), SizedBox(width: 4), Text('...', style: TextStyle(fontSize: 10, color: Colors.grey))]);
        }

        final int commentsCount = commentSnapshot.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () => _showCommentsModal(requestId, currentUser),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.comment, color: Colors.white, size: 24),
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

  Widget _buildHelpCard(BuildContext context, Map<String, dynamic> request, String requestId, firebase_auth.User? currentUser, {String? distanceText}) {
    final Map<String, dynamic> requestData = request;

    final String requesterUserId = requestData['userId']?.toString() ?? '';
    final String requesterName = requestData['requesterName']?.toString() ?? 'Usuario Anónimo'.tr();
    final String requestDescription = requestData['descripcion']?.toString() ?? 'Sin descripción'.tr();
    final String requestDetail = requestData['detalle']?.toString() ?? 'Sin detalles'.tr();

    final dynamic timestampData = requestData['timestamp'];
    final Timestamp timestamp = timestampData is Timestamp ? timestampData : Timestamp.now();

    final DateTime requestTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration remainingTime = requestTime.add(const Duration(hours: 24)).difference(now);

    String timeRemainingText;
    if (remainingTime.isNegative) {
      timeRemainingText = 'expired'.tr();
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
    }

    dynamic rawImages = requestData['imagenes'];
    String? imageUrlPath = '';
    if (rawImages != null) {
      if (rawImages is List && rawImages.isNotEmpty) {
        imageUrlPath = rawImages.first?.toString();
      } else if (rawImages is String) {
        imageUrlPath = rawImages;
      }
    }

    final double? latitude = (requestData['latitude'] as num?)?.toDouble();
    final double? longitude = (requestData['longitude'] as num?)?.toDouble();

    final bool hasDetails = requestDetail.isNotEmpty && requestDetail != 'Sin detalles';

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(requesterUserId).snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final String? profilePicturePath = userData?['profilePicture']?.toString();
        final String requestPhone = userData?['phone']?.toString() ?? 'N/A';
        final bool showWhatsapp = (requestData['showWhatsapp'] as bool?) ?? false;

        final dynamic memberSinceTimestamp = userData?['createdAt'];
        String memberSince = memberSinceTimestamp != null ? DateFormat('dd/MM/yyyy').format((memberSinceTimestamp as Timestamp).toDate()) : 'N/A';
        final int helpedCount = (userData?['helpedCount'] as num? ?? 0).toInt();
        final int receivedHelpCount = (userData?['receivedHelpCount'] as num? ?? 0).toInt();

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
                              FutureBuilder<String>(
                                future: profilePicturePath != null
                                    ? _storage.ref().child(profilePicturePath).getDownloadURL()
                                    : Future.value(''),
                                builder: (context, urlSnapshot) {
                                  final String? finalImageUrl = urlSnapshot.data;
                                  return CircleAvatar(
                                    radius: 20,
                                    backgroundImage: (finalImageUrl != null && finalImageUrl.isNotEmpty)
                                        ? NetworkImage(finalImageUrl)
                                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                    backgroundColor: Colors.grey[700],
                                  );
                                },
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
                                      requestData['localidad']?.toString() ?? 'Desconocida'.tr(),
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Categoría: ${requestData['categoria']?.toString() ?? 'N/A'}',
                                      style: const TextStyle(
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
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  if (currentUser == null) {
                                    _showSnackBar('Debes iniciar sesión para ofrecer ayuda.'.tr(), Colors.red);
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
                                child: Text('help'.tr(), style: const TextStyle(fontSize: 12, color: Colors.black)),
                              ),
                              const SizedBox(width: 8),
                              _buildCommentsButtonInCard(requestId, currentUser),
                              
                              const SizedBox(width: 16),
                              
                              if (latitude != null && longitude != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: IconButton(
                                    iconSize: 24,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.location_on, color: Colors.blue),
                                    onPressed: () => _appServices.launchMap(context, latitude, longitude),
                                    tooltip: 'maps'.tr(),
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
                                    tooltip: 'whatsapp'.tr(),
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
                                '${'priority'.tr()} ${requestData['prioridad']?.toString() ?? 'N/A'}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${'expires_in'.tr()} $timeRemainingText',
                          style: TextStyle(
                              color: remainingTime.isNegative ? Colors.red : Colors.white70,
                              fontSize: 10),
                        ),
                        if (distanceText != null)
                          Text(
                            distanceText,
                            style: const TextStyle(fontSize: 10, color: Colors.white70),
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
                        child: imageUrlPath != null && imageUrlPath.isNotEmpty
                            ? FutureBuilder<String>(
                                future: _storage.ref().child(imageUrlPath).getDownloadURL(),
                                builder: (context, urlSnapshot) {
                                  if (urlSnapshot.connectionState == ConnectionState.done && urlSnapshot.hasData) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        urlSnapshot.data!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[700],
                                          child: const Icon(Icons.broken_image, color: Colors.white54, size: 40),
                                        ),
                                      ),
                                    );
                                  }
                                  return Container(
                                    color: Colors.grey[700],
                                    child: const Center(child: CircularProgressIndicator(color: Colors.amber)),
                                  );
                                },
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
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    requestDescription,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasDetails)
                                  IconButton(
                                    iconSize: 24,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.amber),
                                    tooltip: 'view_details'.tr(),
                                    onPressed: () {
                                      _showDetailsDialog(context, requestDescription, requestDetail);
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                const ImageIcon(AssetImage('assets/time.png'), size: 12.0, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text(
                                  'member_since'.tr() + ' $memberSince',
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                  textAlign: TextAlign.start,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.handshake_outlined, size: 12.0, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text(
                                  'helped_count_plural'.tr(args: [helpedCount.toString()]),
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                  textAlign: TextAlign.start,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.favorite_outline, size: 12.0, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text(
                                  'received_help_count_plural'.tr(args: [receivedHelpCount.toString()]),
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                  textAlign: TextAlign.start,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFilterDialog(BuildContext dialogContext, String currentFilterScope, double proximityRadiusKm) async {
    String _dialogSelectedFilterScope = currentFilterScope;
    double _dialogProximityRadiusKm = proximityRadiusKm;
    String _dialogSelectedCategory = _selectedCategory;

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: dialogContext,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            final userLocation = ref.watch(userLocationProvider);
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text('filter_requests'.tr(), style: const TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('filter_by_scope'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('nearby_gps'.tr(), style: const TextStyle(color: Colors.white70)),
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
                        },
                        activeColor: Colors.amber,
                      ),
                    ),
                    if (_dialogSelectedFilterScope == 'Cercano')
                      Column(
                        children: [
                          const SizedBox(height: 10),
                          Text('proximity_radius'.tr() + ' ${_dialogProximityRadiusKm.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white70)),
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
                              label: Text('retry_location'.tr(), style: const TextStyle(color: Colors.blueAccent)),
                            ),
                        ],
                      ),
                    ListTile(
                      title: Text('provincial'.tr(), style: const TextStyle(color: Colors.white70)),
                      leading: Radio<String>(
                        value: 'Provincial',
                        groupValue: _dialogSelectedFilterScope,
                        onChanged: (String? value) {
                          stfSetState(() {
                            _dialogSelectedFilterScope = value!;
                          });
                        },
                        activeColor: Colors.amber,
                      ),
                    ),
                    ListTile(
                      title: Text('national'.tr(), style: const TextStyle(color: Colors.white70)),
                      leading: Radio<String>(
                        value: 'Nacional',
                        groupValue: _dialogSelectedFilterScope,
                        onChanged: (String? value) {
                          stfSetState(() {
                            _dialogSelectedFilterScope = value!;
                          });
                        },
                        activeColor: Colors.amber,
                      ),
                    ),
                    ListTile(
                      title: Text('international'.tr(), style: const TextStyle(color: Colors.white70)),
                      leading: Radio<String>(
                        value: 'Internacional',
                        groupValue: _dialogSelectedFilterScope,
                        onChanged: (String? value) {
                          stfSetState(() {
                            _dialogSelectedFilterScope = value!;
                          });
                        },
                        activeColor: Colors.amber,
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    Text('filter_by_category'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0,
                      children: _categories.map((category) {
                        return ChoiceChip(
                          label: Text(category.tr()),
                          selected: _dialogSelectedCategory == category,
                          selectedColor: Colors.amber,
                          backgroundColor: Colors.grey[700],
                          labelStyle: TextStyle(color: _dialogSelectedCategory == category ? Colors.black : Colors.white),
                          onSelected: (bool selected) {
                            stfSetState(() {
                              _dialogSelectedCategory = selected ? category : 'Todas';
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('cancel'.tr(), style: const TextStyle(color: Colors.white70)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('apply'.tr(), style: const TextStyle(color: Colors.amber)),
                  onPressed: () {
                    Navigator.of(context).pop({
                      'filterScope': _dialogSelectedFilterScope,
                      'proximityRadius': _dialogProximityRadiusKm,
                      'selectedCategory': _dialogSelectedCategory,
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
      ref.read(filterScopeProvider.notifier).state = result['filterScope']?.toString() ?? 'Cercano';
      ref.read(proximityRadiusProvider.notifier).state = (result['proximityRadius'] as num?)?.toDouble() ?? 3.0;
      setState(() {
        _selectedCategory = result['selectedCategory']?.toString() ?? 'Todas';
      });
      print('DEBUG DIALOG: Filtro aplicado desde diálogo a MainScreen: ${result['filterScope']} con radio: ${result['proximityRadius']} y categoría: $_selectedCategory');
    } else {
      print('DEBUG DIALOG: Diálogo de filtro cancelado o sin resultado.');
    }
  }

  void _showPanicAlertConfirmation() {
    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showSnackBar('Debes iniciar sesión para enviar una alerta de pánico.'.tr(), Colors.red);
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text('¡Atención! Estás a punto de enviar una alerta de pánico'.tr(), style: const TextStyle(color: Colors.white)),
          content: Text(
            'Al aceptar, se enviará a todos los usuarios cercanos a 1 kilómetro un aviso de que necesitas ayuda y se les enviarán tus datos para que se comuniquen contigo o vayan hasta tu ubicación.'.tr(),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('cancel'.tr(), style: const TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _appServices.sendPanicAlert(context);
              },
              child: Text('accept'.tr(), style: const TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final User? currentUser = ref.watch(userProvider).value;
    final String currentFilterScope = ref.watch(filterScopeProvider);
    final double proximityRadiusKm = ref.watch(proximityRadiusProvider);
    final UserLocationData userLocation = ref.watch(userLocationProvider);
    final AsyncValue<List<QueryDocumentSnapshot>> filteredRequestsAsyncValue = ref.watch(filteredHelpRequestsProvider);
    
    final globalChatButton = StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('global_chat_messages').orderBy('timestamp', descending: true).limit(1).snapshots(),
      builder: (context, snapshot) {
        if (currentUser == null) {
          return const SizedBox.shrink();
        }

        final bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty
          ? (currentUser.lastGlobalChatRead == null || (snapshot.data!.docs.first['timestamp'] as Timestamp).toDate().isAfter(currentUser.lastGlobalChatRead!))
          : false;

        return hasUnread
            ? FadeTransition(
                opacity: _blinkAnimation,
                child: IconButton(
                  icon: const Icon(FontAwesomeIcons.globe, color: Colors.green, size: 24),
                  onPressed: () {
                    context.push('/global_chat');
                    ref.read(userProvider.notifier).updateLastGlobalChatRead();
                  },
                ),
              )
            : IconButton(
                icon: const Icon(FontAwesomeIcons.globe, color: Colors.white, size: 24),
                onPressed: () => context.push('/global_chat'),
              );
      },
    );

    print('DEBUG BUILD: Pantalla principal reconstruida. Filtro actual: $currentFilterScope');
    print('DEBUG BUILD: Ubicación de usuario: Lat: ${userLocation.latitude}, Lon: ${userLocation.longitude}, Localidad: ${userLocation.locality}, Radio: ${proximityRadiusKm.toStringAsFixed(1)}km');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 60,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(
                builder: (BuildContext context) {
                  return IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 30),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                    tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                  );
                },
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  globalChatButton, // Botón del chat global
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showFilterDialog(context, currentFilterScope, proximityRadiusKm),
                    icon: const Icon(Icons.filter_list, color: Colors.white, size: 24),
                    label: Text(
                      _selectedCategory == 'Todas'
                          ? (currentFilterScope == 'Cercano' ? 'a ${proximityRadiusKm.toStringAsFixed(1)}km' : currentFilterScope.tr())
                          : _selectedCategory.tr(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: _auth.currentUser != null
                        ? _firestore.collection('users').doc(_auth.currentUser!.uid).collection('notifications').where('read', isEqualTo: false).snapshots()
                        : const Stream.empty(),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data?.docs.length ?? 0;
                      return Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none, color: Colors.white, size: 30),
                            onPressed: () {
                              if (_auth.currentUser == null) {
                                _showSnackBar('Debes iniciar sesión para ver tus notificaciones.'.tr(), Colors.red);
                                return;
                              }
                              context.push('/notifications');
                            },
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Center(
                  child: Image.asset(
                    'assets/logo.png',
                    height: 40,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'cadena_solidaria'.tr(),
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  'made_in_argentina'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  'powered_by'.tr(),
                  style: const TextStyle(color: Colors.grey, fontSize: 9),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
      body: CustomBackground(
        child: Column(
          children: [
            Expanded(
              child: filteredRequestsAsyncValue.when(
                data: (allHelpRequestDocs) {
                  _checkAndNotifyNearbyRequest(allHelpRequestDocs, userLocation, proximityRadiusKm);

                  final filteredByCategory = allHelpRequestDocs.where((doc) {
                    final request = doc.data() as Map<String, dynamic>;
                    final String requestCategory = request['categoria']?.toString() ?? '';
                    if (_selectedCategory == 'Todas') {
                      return true;
                    }
                    return requestCategory == _selectedCategory;
                  }).toList();

                  if (filteredByCategory.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'No hay solicitudes de ayuda disponibles para el filtro: '
                            '${currentFilterScope.tr()}' +
                            (currentFilterScope == 'Cercano' && userLocation.locality.isNotEmpty
                              ? ' dentro de ${proximityRadiusKm.toStringAsFixed(1)} km de ${userLocation.locality}.'
                              : '.'),
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
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
                            child: Text('Cambiar Filtro'.tr()),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(filteredHelpRequestsProvider);
                    },
                    child: ListView.builder(
                      itemCount: filteredByCategory.length,
                      itemBuilder: (context, index) {
                        final doc = filteredByCategory[index];
                        final requestData = doc.data() as Map<String, dynamic>;
                        final double? requestLat = (requestData['latitude'] as num?)?.toDouble();
                        final double? requestLon = (requestData['longitude'] as num?)?.toDouble();

                        String? distanceText;
                        if (userLocation.latitude != null && userLocation.longitude != null && requestLat != null && requestLon != null) {
                          final distance = _calculateDistance(userLocation.latitude!, userLocation.longitude!, requestLat, requestLon);
                          distanceText = 'a ${distance.toStringAsFixed(1)} km'.tr();
                        }
                        
                        final bool shouldShowAd = (index + 1) % 3 == 0;
                        return Column(
                          children: [
                            _buildHelpCard(context, requestData, doc.id, _auth.currentUser, distanceText: distanceText),
                            if (shouldShowAd)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: BannerAdWidget(),
                              ),
                          ],
                        );
                      },
                    ),
                  );
                },
                loading: () {
                  return const Center(child: SpinningImageLoader());
                },
                error: (err, stack) {
                  return Center(child: Text('Error al cargar datos: $err', style: const TextStyle(color: Colors.red)));
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.pushNamed('create_request');
        },
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            StreamBuilder<DocumentSnapshot>(
              stream: _auth.currentUser != null
                  ? _firestore.collection('users').doc(_auth.currentUser!.uid).snapshots()
                  : const Stream.empty(),
              builder: (context, snapshot) {
                final userData = snapshot.hasData && snapshot.data!.exists ? snapshot.data!.data() as Map<String, dynamic>? : null;
                final String? profilePicturePath = userData?['profilePicture']?.toString();
                final String userName = userData?['name']?.toString() ?? _auth.currentUser?.displayName ?? 'Usuario'.tr();
                final String userEmail = _auth.currentUser?.email ?? 'email@example.com';

                return Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ✅ CORRECCIÓN: Lógica para la imagen del perfil con caché.
                        if (profilePicturePath != null && _profilePictureUrlCache.containsKey(profilePicturePath))
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(_profilePictureUrlCache[profilePicturePath]!),
                            backgroundColor: Colors.grey[700],
                          )
                        else
                          FutureBuilder<String>(
                            future: profilePicturePath != null
                                ? _storage.ref().child(profilePicturePath).getDownloadURL()
                                : Future.value(''),
                            builder: (context, urlSnapshot) {
                              if (urlSnapshot.connectionState == ConnectionState.done && urlSnapshot.hasData) {
                                final String? finalImageUrl = urlSnapshot.data;
                                if (finalImageUrl != null && finalImageUrl.isNotEmpty) {
                                  _profilePictureUrlCache[profilePicturePath!] = finalImageUrl;
                                  return CircleAvatar(
                                    radius: 40,
                                    backgroundImage: NetworkImage(finalImageUrl),
                                    backgroundColor: Colors.grey[700],
                                  );
                                }
                              }
                              return CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey[700],
                                backgroundImage: const AssetImage('assets/default_avatar.png'),
                              );
                            },
                          ),
                        const SizedBox(height: 10),
                        Text(
                          userName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userEmail,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.white70),
              title: Text('home'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.go('/main');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white70),
              title: Text('my_profile'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_box, color: Colors.white70),
              title: Text('create_request'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('create_request');
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt, color: Colors.white70),
              title: Text('my_requests'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.push('/my_requests');
                  },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
              title: Text('messages'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.push('/messages');
                  },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none, color: Colors.white70),
              title: Text('notifications'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.push('/notifications');
                  },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.white70),
              title: Text('my_ratings'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('ratings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.white70),
              title: Text('history'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.push('/history');
                  },
            ),
            ListTile(
              leading: const Icon(Icons.search, color: Colors.white70),
              title: Text('search_users'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.push('/search_users');
                  },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white70),
              title: Text('settings'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.white70),
              title: Text('help_and_faq'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                context.push('/faq');
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined, color: Colors.white70),
              title: Text('report_problem'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                    Navigator.pop(context);
                    context.push('/report_problem');
                  },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.white70),
              title: Text('about'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(
                  'Eslabón, cadena de favores solidaria. Desarrollado por Oviedo. Hecho con ❤️ en Argentina.'.tr(),
                  Colors.blueAccent,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: Text('logout'.tr(), style: const TextStyle(color: Colors.white)),
              onTap: () async {
                await _auth.signOut();
                if (mounted) {
                  context.go('/login');
                }
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  String currentLang = context.locale.languageCode;
                  context.setLocale(Locale(currentLang == 'es' ? 'en' : 'es'));
                },
                icon: const Icon(Icons.language, color: Colors.white54),
                label: Text(
                  context.locale.languageCode == 'es' ? 'English' : 'Español',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}