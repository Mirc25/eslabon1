// lib/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/skeleton_list.dart';
import '../services/remote_config_service.dart';
import '../widgets/avatar_optimizado.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  User? _currentUser;
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  // Paginación de chats
  List<DocumentSnapshot> _chats = [];
  DocumentSnapshot? _lastChatDoc;
  bool _isLoadingChats = true;
  bool _hasMoreChats = true;
  int _pageSize = 20;
  // Debounce de búsqueda
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _pageSize = RemoteConfigService().getPageSize(fallback: 20);
    _loadInitialChats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<int> _getUnreadMessagesCount(String chatId) async {
    final QuerySnapshot unreadNotifications = await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('notifications')
        .where('data.chatRoomId', isEqualTo: chatId)
        .where('read', isEqualTo: false)
        .get();
    return unreadNotifications.docs.length;
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _isSearching = true;
      });
      try {
        final QuerySnapshot result = await _firestore
            .collection('users')
            .where('lowercaseName', isGreaterThanOrEqualTo: query.toLowerCase())
            .where('lowercaseName', isLessThan: '${query.toLowerCase()}\uf8ff')
            .limit(10)
            .get();
        final filteredResults = result.docs.where((doc) => doc.id != _currentUser!.uid).toList();
        setState(() {
          _searchResults = filteredResults;
          _isSearching = false;
        });
      } catch (e) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _loadInitialChats() async {
    if (_currentUser == null) return;
    setState(() {
      _isLoadingChats = true;
      _hasMoreChats = true;
      _chats.clear();
      _lastChatDoc = null;
    });
    final QuerySnapshot firstPage = await _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUser!.uid)
        .orderBy('lastMessage.timestamp', descending: true)
        .limit(_pageSize)
        .get();
    setState(() {
      _chats = firstPage.docs;
      _lastChatDoc = _chats.isNotEmpty ? _chats.last : null;
      _isLoadingChats = false;
      _hasMoreChats = firstPage.docs.length == _pageSize;
    });
  }

  Future<void> _loadMoreChats() async {
    if (!_hasMoreChats || _isLoadingChats || _lastChatDoc == null || _currentUser == null) return;
    setState(() => _isLoadingChats = true);
    final QuerySnapshot nextPage = await _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUser!.uid)
        .orderBy('lastMessage.timestamp', descending: true)
        .startAfterDocument(_lastChatDoc!)
        .limit(_pageSize)
        .get();
    setState(() {
      _chats.addAll(nextPage.docs);
      _lastChatDoc = _chats.isNotEmpty ? _chats.last : _lastChatDoc;
      _isLoadingChats = false;
      _hasMoreChats = nextPage.docs.length == _pageSize;
    });
  }

  Future<void> _startChatWithUser(String userId, String userName, String? userAvatar) async {
    try {
      // Verificar si ya existe un chat entre estos usuarios
      final QuerySnapshot existingChats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUser!.uid)
          .get();

      String? existingChatId;
       for (var doc in existingChats.docs) {
         final chatData = doc.data() as Map<String, dynamic>;
         final participants = List<String>.from(chatData['participants'] ?? []);
         if (participants.contains(userId)) {
           existingChatId = doc.id;
           break;
         }
       }

      if (existingChatId != null) {
        // Navegar al chat existente
        context.go('/chat/$existingChatId?partnerId=$userId&partnerName=${Uri.encodeComponent(userName)}&partnerAvatar=${userAvatar ?? ''}');
      } else {
        // Crear nuevo chat
        final DocumentReference newChatRef = await _firestore.collection('chats').add({
          'participants': [_currentUser!.uid, userId],
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': {
            'text': '',
            'senderId': '',
            'timestamp': FieldValue.serverTimestamp(),
          },
        });

        // Navegar al nuevo chat
        context.go('/chat/${newChatRef.id}?partnerId=$userId&partnerName=${Uri.encodeComponent(userName)}&partnerAvatar=${userAvatar ?? ''}');
      }

      // Limpiar búsqueda
      _searchController.clear();
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return CustomBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Text(
              'Debes iniciar sesiÃ³n para ver tus mensajes.'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      );
    }

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'messages'.tr(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/main'),
          ),
        ),
        body: Column(
          children: [
            // Campo de búsqueda
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar usuarios para chatear...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            _searchUsers('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _searchUsers,
              ),
            ),
            
            // Resultados de búsqueda
            if (_searchResults.isNotEmpty)
              Container(
                height: 200,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final userDoc = _searchResults[index];
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final userName = userData['name'] ?? 'Usuario';
                    final userAvatar = userData['profilePicture'];

                    return Card(
                      color: Colors.grey[700],
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: ListTile(
                        leading: AvatarOptimizado(
                          url: (userAvatar != null && userAvatar is String && userAvatar.startsWith('http')) ? userAvatar : null,
                          storagePath: (userAvatar != null && userAvatar is String && !userAvatar.startsWith('http')) ? userAvatar : null,
                          radius: 20,
                          backgroundColor: Colors.grey[600],
                        ),
                        title: Text(
                          userName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Toca para chatear',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chat, color: Colors.amber),
                        onTap: () => _startChatWithUser(userDoc.id, userName, userAvatar),
                      ),
                    );
                  },
                ),
              ),
            
            // Lista de chats existentes (paginada)
            Expanded(
              child: _isLoadingChats && _chats.isEmpty
                  ? const SkeletonList()
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
                          _loadMoreChats();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _chats.length + (_hasMoreChats ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _chats.length) {
                            return const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SkeletonList(itemCount: 1),
                            );
                          }
                          final chatDoc = _chats[index];
                final chatData = chatDoc.data() as Map<String, dynamic>;
                final List participants = chatData['participants'] ?? [];
                final String otherUserId = participants.firstWhere((id) => id != _currentUser!.uid, orElse: () => '');
                final lastMessage = chatData['lastMessage'] as Map<String, dynamic>? ?? {};

                if (otherUserId.isEmpty) {
                  return const SizedBox.shrink();
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(otherUserId).get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    final otherUserName = userData['name'] ?? 'Usuario Desconocido'.tr();
                    final otherUserAvatar = userData['profilePicture'];

                    String lastMessageText = lastMessage['text'] ?? 'Sin mensajes'.tr();
                    Timestamp? lastMessageTimestamp = lastMessage['timestamp'] as Timestamp?;
                    String formattedTime = lastMessageTimestamp != null
                        ? DateFormat('dd MMM, HH:mm').format(lastMessageTimestamp.toDate())
                        : '';

                    return FutureBuilder<int>(
                      future: _getUnreadMessagesCount(chatDoc.id),
                      builder: (context, unreadSnapshot) {
                        final unreadCount = unreadSnapshot.data ?? 0;
                        return Card(
                          color: Colors.grey[850],
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: ListTile(
                            leading: AvatarOptimizado(
                              url: (otherUserAvatar != null && otherUserAvatar is String && otherUserAvatar.startsWith('http')) ? otherUserAvatar : null,
                              storagePath: (otherUserAvatar != null && otherUserAvatar is String && !otherUserAvatar.startsWith('http')) ? otherUserAvatar : null,
                              radius: 20,
                              backgroundColor: Colors.grey[700],
                            ),
                            title: Text(
                              otherUserName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              lastMessageText,
                              style: const TextStyle(color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                            onTap: () {
                              context.go('/chat/${chatDoc.id}?partnerId=$otherUserId&partnerName=${Uri.encodeComponent(otherUserName)}&partnerAvatar=${otherUserAvatar ?? ''}');
                            },
                          ),
                        );
                      },
                    );
                  },
                );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


