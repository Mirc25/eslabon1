// lib/screens/global_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:intl/intl.dart';
import 'dart:math' show cos, asin, sqrt, sin, atan2, pi;
import 'package:easy_localization/easy_localization.dart';
import 'package:eslabon_flutter/providers/user_provider.dart';
import 'package:eslabon_flutter/providers/location_provider.dart';
import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/widgets/custom_app_bar.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/spinning_image_loader.dart';
import 'package:eslabon_flutter/models/user_model.dart';
import 'package:eslabon_flutter/screens/bad_params_screen.dart';
import 'package:eslabon_flutter/widgets/avatar_optimizado.dart';

class GlobalChatScreen extends ConsumerStatefulWidget {
  const GlobalChatScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends ConsumerState<GlobalChatScreen> with TickerProviderStateMixin {
  // Reactivar el mapa en chat global
  static const bool kEnableGlobalMap = true;
  GoogleMapController? _mapController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final AppServices _appServices;

  double _searchRadius = 5.0;
  final List<String> _channels = ['Cercano', 'Provincial', 'Nacional', 'Internacional'];
  String _selectedChannel = 'Cercano';

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, firebase_auth.FirebaseAuth.instance);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(userProvider.notifier).updateLastGlobalChatRead();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    var latDistance = (lat2 - lat1) * (pi / 180);
    var lonDistance = (lon2 - lon1) * (pi / 180);
    var a = sin(latDistance / 2) * sin(latDistance / 2) +
            cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
                sin(lonDistance / 2) * sin(lonDistance / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> _sendMessage() async {
    final user = ref.read(userProvider).value;
    final userLocation = ref.read(userLocationProvider);
    final authUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;

    if (_messageController.text.trim().isEmpty || user == null || authUid == null) {
      if (mounted && authUid == null) {
        AppServices.showSnackBar(context, 'Debes iniciar sesión para enviar mensajes.', Colors.red);
      }
      return;
    }

    final messageText = _messageController.text.trim();
    final docRef = _firestore.collection('global_chat_messages').doc();

    final messageData = {
      'userId': authUid,
      'userName': user.name,
      'userAvatarUrl': user.profilePicture,
      'text': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'latitude': userLocation.latitude,
      'longitude': userLocation.longitude,
      'province': user.province,
      'country': user.country['name'],
      'channel': _selectedChannel,
    };

    try {
      // DEBUG: registrar los IDs para diagnosticar permisos
      // ignore: avoid_print
      print('GlobalChat: sending as authUid=' + authUid + ' profileId=' + user.id);
      await docRef.set(messageData);
      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // Moderación deshabilitada: envío directo sin revisión para mayor rapidez
    } catch (e) {
      if (mounted) {
        String msg = 'Error al enviar el mensaje';
        try {
          // Capturar códigos de Firebase para mayor claridad
          // ignore: unused_catch_clause
          final fe = e as FirebaseException; // cloud_firestore FirebaseException
          msg = 'Error al enviar mensaje (${fe.code}): ${fe.message}';
        } catch (_) {
          msg = 'Error al enviar el mensaje: $e';
        }
        AppServices.showSnackBar(context, msg, Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = ref.watch(userProvider).value;
    final userLocation = ref.watch(userLocationProvider);

    if (user == null) {
      return CustomBackground(
        child: Scaffold(
          appBar: CustomAppBar(
            title: 'Chat Global'.tr(),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: Center(
            child: Text(
              'Debes iniciar sesión para usar el chat global.'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final String userCountry = user.country['name']?.toString() ?? 'N/A';
    final String userProvince = user.province?.toString() ?? 'N/A';

    return DefaultTabController(
      length: 4,
      child: CustomBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight + 48),
            child: Column(
              children: [
                CustomAppBar(
                  title: 'Chat Global'.tr(),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/main');
                      }
                    },
                  ),
                ),
                Container(
                  color: Theme.of(context).primaryColor,
                  child: TabBar(
                    indicatorColor: Colors.amber,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    onTap: (index) {
                      setState(() {
                        _selectedChannel = _channels[index];
                      });
                      ref.read(userProvider.notifier).updateLastGlobalChatRead();
                    },
                    tabs: [
                      Tab(text: 'Cercano'.tr()),
                      Tab(text: 'Provincial'.tr()),
                      Tab(text: 'Nacional'.tr()),
                      Tab(text: 'Internacional'.tr()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              if (_selectedChannel == 'Cercano')
                SizedBox(
                  height: 200,
                  child: !kEnableGlobalMap
                      ? Center(child: Text('Mapa desactivado temporalmente'.tr(), style: const TextStyle(color: Colors.white70)))
                      : userLocation.latitude == null
                          ? Center(child: Text('No se puede mostrar el mapa sin ubicación.'.tr(), style: const TextStyle(color: Colors.white70)))
                          : Stack(
                              children: [
                                GoogleMap(
                                  onMapCreated: _onMapCreated,
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(userLocation.latitude!, userLocation.longitude!),
                                    zoom: 10,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId('userLocation'),
                                      position: LatLng(userLocation.latitude!, userLocation.longitude!),
                                    ),
                                  },
                                  circles: {
                                    Circle(
                                      circleId: const CircleId('searchRadius'),
                                      center: LatLng(userLocation.latitude!, userLocation.longitude!),
                                      radius: _searchRadius * 1000,
                                      fillColor: Colors.amber.withOpacity(0.2),
                                      strokeColor: Colors.amber,
                                      strokeWidth: 2,
                                    ),
                                  },
                                ),
                                Positioned(
                                  bottom: 10,
                                  left: 10,
                                  right: 10,
                                  child: Card(
                                color: Colors.black54,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Radio de alcance: ${_searchRadius.toInt()} km'.tr(), style: const TextStyle(color: Colors.white)),
                                      Slider(
                                        value: _searchRadius,
                                        min: 1.0,
                                        max: 200.0,
                                        divisions: 199,
                                        label: '${_searchRadius.toInt()} km',
                                        onChanged: (double value) {
                                          setState(() {
                                            _searchRadius = value;
                                          });
                                        },
                                        activeColor: Colors.amber,
                                        inactiveColor: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildChatList(user, userLocation, 'Cercano', radius: _searchRadius),
                    _buildChatList(user, userLocation, 'Provincial', provinceFilter: userProvince),
                    _buildChatList(user, userLocation, 'Nacional', countryFilter: userCountry),
                    _buildChatList(user, userLocation, 'Internacional'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...'.tr(),
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.grey[800],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: _sendMessage,
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatList(User user, UserLocationData userLocation, String filterType, {double? radius, String? provinceFilter, String? countryFilter}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('global_chat_messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: SpinningImageLoader());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'.tr(), style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('Aún no hay mensajes en este canal. Sé el primero en saludar.'.tr(), style: const TextStyle(color: Colors.white70)));
        }

        final allMessages = snapshot.data!.docs;
        List<DocumentSnapshot> filteredMessages;

        if (filterType == 'Cercano' && radius != null && userLocation.latitude != null && userLocation.longitude != null) {
          filteredMessages = allMessages.where((doc) {
            final lat = (doc['latitude'] as num?)?.toDouble();
            final lon = (doc['longitude'] as num?)?.toDouble();
            if (lat == null || lon == null) return false;
            return _calculateDistance(userLocation.latitude!, userLocation.longitude!, lat, lon) <= radius;
          }).toList();
        } else if (filterType == 'Provincial' && provinceFilter != null) {
            filteredMessages = allMessages.where((doc) => doc['province']?.toString() == provinceFilter).toList();
        } else if (filterType == 'Nacional' && countryFilter != null) {
            filteredMessages = allMessages.where((doc) => doc['country']?.toString() == countryFilter).toList();
        } else {
          filteredMessages = allMessages;
        }

        if (filteredMessages.isEmpty) {
          return Center(child: Text('No hay mensajes que coincidan con este filtro.'.tr(), style: const TextStyle(color: Colors.white70)));
        }

        return ListView.builder(
          reverse: true,
          controller: _scrollController,
          itemCount: filteredMessages.length,
          itemBuilder: (context, index) {
            final message = filteredMessages[index].data() as Map<String, dynamic>;
            final bool isMe = message['userId']?.toString() == user.id;

            return _buildMessageBubble(
              message['text']?.toString() ?? '',
              message['timestamp'] as Timestamp,
              message['userName']?.toString() ?? 'Usuario Anónimo',
              message['userAvatarUrl']?.toString(),
              isMe,
              () {
                final String targetUserId = message['userId']?.toString() ?? '';
                final String targetUserName = message['userName']?.toString() ?? 'Usuario';
                final String? targetAvatar = message['userAvatarUrl']?.toString();
                _startPrivateChatFromGlobal(targetUserId, targetUserName, targetAvatar);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _startPrivateChatFromGlobal(String userId, String userName, String? userAvatar) async {
    try {
      final String? currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) {
        AppServices.showSnackBar(context, 'Debes iniciar sesión para chatear.', Colors.red);
        return;
      }

      if (userId.isEmpty || userId == currentUid) {
        return; // Evitar chats consigo mismo o usuario inválido
      }

      // Buscar chat existente entre ambos usuarios
      final QuerySnapshot existingChats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUid)
          .get();

      String? chatId;
      for (final doc in existingChats.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        if (participants.contains(userId)) {
          chatId = doc.id;
          break;
        }
      }

      if (chatId == null) {
        // Crear nuevo chat
        final DocumentReference newChatRef = await _firestore.collection('chats').add({
          'participants': [currentUid, userId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': {
            'text': '',
            'senderId': '',
            'timestamp': FieldValue.serverTimestamp(),
          },
        });
        chatId = newChatRef.id;
      }

      // Navegar al chat privado usando push para respetar la pila
      final String encodedName = Uri.encodeComponent(userName);
      context.push('/chat/$chatId?partnerId=$userId&partnerName=$encodedName&partnerAvatar=${userAvatar ?? ''}');
    } catch (e) {
      // ignore: avoid_print
      print('GlobalChat: error iniciando chat privado: $e');
      AppServices.showSnackBar(context, 'No se pudo abrir el chat privado.', Colors.red);
    }
  }

  Widget _buildMessageBubble(String text, Timestamp timestamp, String userName, String? avatarUrl, bool isMe, VoidCallback onUserTap) {
    final Alignment alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final Color color = isMe ? Colors.amber : Colors.grey[700]!;
    final Color textColor = isMe ? Colors.black : Colors.white;
    final BorderRadius borderRadius = BorderRadius.circular(20);

    final String formattedTime = DateFormat('HH:mm').format(timestamp.toDate());

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              GestureDetector(
                onTap: onUserTap,
                child: AvatarOptimizado(
                  url: (avatarUrl != null && avatarUrl.startsWith('http')) ? avatarUrl : null,
                  storagePath: (avatarUrl != null && !avatarUrl.startsWith('http')) ? avatarUrl : null,
                  radius: 16,
                  backgroundColor: Colors.grey[700],
                ),
              ),
            if (!isMe) const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              decoration: BoxDecoration(
                color: color,
                borderRadius: borderRadius.copyWith(
                  topLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                  topRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onUserTap,
                    child: Text(
                      userName,
                      style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.black : Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: TextStyle(color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 8),
            if (isMe)
              GestureDetector(
                onTap: onUserTap,
                child: AvatarOptimizado(
                  url: (avatarUrl != null && avatarUrl.startsWith('http')) ? avatarUrl : null,
                  storagePath: (avatarUrl != null && !avatarUrl.startsWith('http')) ? avatarUrl : null,
                  radius: 16,
                  backgroundColor: Colors.grey[700],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
