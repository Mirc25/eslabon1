// lib/screens/notifications_screen.dart
import '../notifications_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/avatar_optimizado.dart';
import '../widgets/skeleton_list.dart';
import '../services/remote_config_service.dart';

import 'package:eslabon_flutter/widgets/custom_app_bar.dart';
import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/notification_card.dart';
import 'package:eslabon_flutter/providers/user_provider.dart';
import 'package:eslabon_flutter/providers/notification_service_provider.dart';
import 'package:eslabon_flutter/models/user_model.dart';
import '../widgets/ad_banner_widget.dart';
import '../services/ads_ids.dart';

// Clase para representar notificaciones agrupadas de chat
class GroupedChatNotification {
  final String chatPartnerId;
  final String chatPartnerName;
  final String? chatPartnerAvatar;
  final String chatRoomId;
  final int unreadCount;
  final DateTime lastMessageTime;
  final String lastMessageText;

  GroupedChatNotification({
    required this.chatPartnerId,
    required this.chatPartnerName,
    this.chatPartnerAvatar,
    required this.chatRoomId,
    required this.unreadCount,
    required this.lastMessageTime,
    required this.lastMessageText,
  });
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _notifications = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  late final int _pageSize;

  @override
  void initState() {
    super.initState();
    _pageSize = RemoteConfigService().getPageSize();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadInitial() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() { _isLoadingInitial = false; });
      return;
    }
    try {
      final query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      final snap = await query.get();
      setState(() {
        _notifications = snap.docs;
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        _hasMore = snap.docs.length == _pageSize;
        _isLoadingInitial = false;
      });
    } catch (e) {
      debugPrint('Notifications initial load error: $e');
      setState(() { _isLoadingInitial = false; });
    }
  }

  Future<void> _loadMore() async {
    final user = _auth.currentUser;
    if (user == null || _lastDoc == null) return;
    setState(() { _isLoadingMore = true; });
    try {
      final query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize);
      final snap = await query.get();
      setState(() {
        _notifications.addAll(snap.docs);
        _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
        _hasMore = snap.docs.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Notifications load more error: $e');
      setState(() { _isLoadingMore = false; _hasMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = ref.watch(userProvider).value;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('notifications'.tr())),
        body: Center(
          child: Text('Debes iniciar sesión para ver tus notificaciones.'.tr(), style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    final String userId = currentUser.id;

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'notifications'.tr(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () { context.pop(); },
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            AdBannerWidget(adUnitId: AdsIds.banner),
            Expanded(
              child: _isLoadingInitial
                  ? SkeletonList(itemCount: _pageSize)
                  : _buildNotificationsList(context, userId),
            ),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            const SizedBox(height: 8),
            AdBannerWidget(adUnitId: AdsIds.banner),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList(BuildContext context, String userId) {
    if (_notifications.isEmpty) {
      return Center(
        child: Text(
          'No tienes notificaciones en este momento.'.tr(),
          style: const TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Separar notificaciones de chat y otras notificaciones (limitadas por página)
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> chatNotificationsByPartner = {};
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> otherNotifications = [];

    for (var doc in _notifications) {
      final data = doc.data();
      final type = data['type'] ?? '';

      if (type == 'chat_message' || type == 'chat_started' || type == 'chat') {
        final chatPartnerId = data['data']?['chatPartnerId'] ??
            data['data']?['senderId'] ??
            data['senderId'] ??
            data['recipientId'];
        if (chatPartnerId != null) {
          chatNotificationsByPartner.putIfAbsent(chatPartnerId, () => []);
          chatNotificationsByPartner[chatPartnerId]!.add(doc);
        } else {
          otherNotifications.add(doc);
        }
      } else {
        otherNotifications.add(doc);
      }
    }

    final List<GroupedChatNotification> groupedChatNotifications = [];
    for (var entry in chatNotificationsByPartner.entries) {
      final chatPartnerId = entry.key;
      final chatNotifications = entry.value;

      final unreadCount = chatNotifications.where((doc) {
        final data = doc.data();
        return !(data['read'] ?? false);
      }).length;

      if (unreadCount > 0) {
        final latestNotification = chatNotifications.first;
        final latestData = latestNotification.data();

        final partnerName = latestData['data']?['chatPartnerName'] ??
            latestData['data']?['senderName'] ??
            'Usuario desconocido';

        groupedChatNotifications.add(GroupedChatNotification(
          chatPartnerId: chatPartnerId,
          chatPartnerName: 'Chat $partnerName',
          chatPartnerAvatar: latestData['data']?['senderAvatar'],
          chatRoomId: latestData['data']?['chatRoomId'] ?? '',
          unreadCount: unreadCount,
          lastMessageTime: (latestData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          lastMessageText: unreadCount > 1
              ? '$unreadCount mensajes nuevos'
              : latestData['body'] ?? 'Nuevo mensaje',
        ));
      }
    }

    groupedChatNotifications.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    final totalItems = groupedChatNotifications.length + otherNotifications.length + (_hasMore ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Indicador de "cargar más"
        if (_hasMore && index == totalItems - 1) {
          return Center(
            child: Text('Desplázate para cargar más...'.tr(), style: const TextStyle(color: Colors.white54)),
          );
        }

        if (index < groupedChatNotifications.length) {
          final groupedNotification = groupedChatNotifications[index];
          return _buildGroupedChatNotificationCard(context, groupedNotification, userId);
        } else {
          final otherIndex = index - groupedChatNotifications.length;
          final doc = otherNotifications[otherIndex];
          final notificationData = doc.data();
          final String notificationId = doc.id;

          return NotificationCard(
            notificationId: notificationId,
            notificationData: notificationData,
            onTap: () { openNotificationAndMarkRead(context, doc); },
          );
        }
      },
    );
  }

  Widget _buildGroupedChatNotificationCard(BuildContext context, GroupedChatNotification groupedNotification, String userId) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: Colors.grey[700],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          // Marcar todas las notificaciones de este chat como leídas
          await _markChatNotificationsAsRead(userId, groupedNotification.chatPartnerId);
          
          // Navegar al chat
          if (context.mounted) {
            context.go('/chat/${groupedNotification.chatRoomId}?partnerId=${groupedNotification.chatPartnerId}&partnerName=${Uri.encodeComponent(groupedNotification.chatPartnerName)}&partnerAvatar=${groupedNotification.chatPartnerAvatar ?? ''}');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar del usuario o icono de chat
              AvatarOptimizado(
                url: (groupedNotification.chatPartnerAvatar != null && groupedNotification.chatPartnerAvatar!.startsWith('http')) ? groupedNotification.chatPartnerAvatar : null,
                storagePath: (groupedNotification.chatPartnerAvatar != null && !groupedNotification.chatPartnerAvatar!.startsWith('http')) ? groupedNotification.chatPartnerAvatar : null,
                radius: 25,
                backgroundColor: Colors.amber,
                placeholder: const CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            groupedNotification.chatPartnerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Contador de mensajes no leídos
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${groupedNotification.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      groupedNotification.lastMessageText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        DateFormat('dd/MM HH:mm').format(groupedNotification.lastMessageTime),
                        style: const TextStyle(fontSize: 10, color: Colors.white54),
                      ),
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

  Future<void> _markChatNotificationsAsRead(String userId, String chatPartnerId) async {
    try {
      final QuerySnapshot chatNotifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('data.chatPartnerId', isEqualTo: chatPartnerId)
          .where('read', isEqualTo: false)
          .get();

      if (chatNotifications.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in chatNotifications.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
        debugPrint('DEBUG NOTIFICATIONS: Notificaciones de chat marcadas como leídas para $chatPartnerId');
      }
    } catch (e) {
      debugPrint('Error al marcar notificaciones de chat como leídas: $e');
    }
  }
}
