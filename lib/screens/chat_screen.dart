// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../services/app_services.dart';
import '../services/inapp_notification_service.dart';
import '../services/notification_service.dart'; // Importado

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatPartnerId;
  final String chatPartnerName;
  final String? chatPartnerAvatar;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.chatPartnerId,
    required this.chatPartnerName,
    this.chatPartnerAvatar,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AppServices _appServices;

  User? _currentUser;
  String? _currentUserName;
  String? _currentUserAvatarPath;
  String? _chatPartnerAvatarUrl;
  String? _currentUserAvatarUrl;

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
    _currentUser = _auth.currentUser;
    _updateUserPresence(widget.chatId);
    _loadCurrentUserData();
    _loadChatPartnerAvatarUrl();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _markChatNotificationsAsRead();
    NotificationService.setActiveChatId(widget.chatId);
  }

  @override
  void dispose() {
    _updateUserPresence(null);
    _messageController.dispose();
    _scrollController.dispose();
    NotificationService.setActiveChatId(null);
    super.dispose();
  }

  Future<void> _markChatNotificationsAsRead() async {
    if (_currentUser == null) return;
    try {
      final QuerySnapshot notificationsToMark = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('notifications')
          .where('data.chatRoomId', isEqualTo: widget.chatId)
          .where('read', isEqualTo: false)
          .get();

      if (notificationsToMark.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in notificationsToMark.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
        print('DEBUG CHAT: Notificaciones de chat marcadas como leídas.');
      }
    } catch (e) {
      print('Error al marcar notificaciones como leídas: $e');
    }
  }

  Future<void> _updateUserPresence(String? chatId) async {
    if (_currentUser == null) return;
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'currentChatId': chatId,
      });
      print('DEBUG CHAT: User presence updated. currentChatId: $chatId');
    } catch (e) {
      print('Error updating user presence: $e');
    }
  }

  Future<void> _loadCurrentUserData() async {
    if (_currentUser != null) {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = userData['name'];
          _currentUserAvatarPath = userData['profilePicture'];
        });
        if (_currentUserAvatarPath != null) {
          final url = await _storage.ref().child(_currentUserAvatarPath!).getDownloadURL();
          setState(() {
            _currentUserAvatarUrl = url;
          });
        }
      }
    }
  }

  Future<void> _loadChatPartnerAvatarUrl() async {
    if (widget.chatPartnerAvatar != null && widget.chatPartnerAvatar!.isNotEmpty) {
      try {
        if (widget.chatPartnerAvatar!.startsWith('http')) {
          setState(() {
            _chatPartnerAvatarUrl = widget.chatPartnerAvatar!;
          });
        } else {
          final url = await _storage.ref().child(widget.chatPartnerAvatar!).getDownloadURL();
          setState(() {
            _chatPartnerAvatarUrl = url;
          });
        }
      } catch (e) {
        print('Error loading chat partner avatar URL: $e');
        setState(() {
          _chatPartnerAvatarUrl = null;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUser == null) {
      return;
    }

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final chatDocRef = _firestore.collection('chats').doc(widget.chatId);
      // Guardar el mensaje en la subcolecciÃ³n de mensajes
      await chatDocRef.collection('messages').add({
        'senderId': _currentUser!.uid,
        'receiverId': widget.chatPartnerId,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      });
      // Actualizar el Ãºltimo mensaje en el documento principal del chat
      await chatDocRef.update({
        'lastMessage': {
          'text': messageText,
          'timestamp': FieldValue.serverTimestamp(),
          'senderId': _currentUser!.uid,
        },
      });

      // Se agregó la llamada al servicio de notificación in-app.
      await InAppNotificationService.createChatNotification(
        recipientUid: widget.chatPartnerId,
        chatId: widget.chatId,
        senderUid: _currentUser!.uid,
        senderName: _currentUserName ?? 'Usuario',
        messageText: messageText,
        senderAvatar: _currentUserAvatarUrl,
      );
    } catch (e) {
      print('Error sending message: $e');
      AppServices.showSnackBar(context, 'Error al enviar mensaje.', Colors.red);
    }

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const CustomBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Text(
              'Debes iniciar sesión para chatear.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      );
    }

    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: widget.chatPartnerName,
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
          actions: [
            CircleAvatar(
              backgroundImage: (_chatPartnerAvatarUrl != null)
                  ? NetworkImage(_chatPartnerAvatarUrl!)
                  : const AssetImage('assets/default_avatar.png') as ImageProvider,
              backgroundColor: Colors.grey[700],
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('¡Empieza la conversación!', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  final messages = snapshot.data!.docs;
                  return ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index].data() as Map<String, dynamic>;
                      final bool isMe = message['senderId'] == _currentUser!.uid;

                      return _buildMessageBubble(
                        message['text'] as String,
                        message['timestamp'],
                        isMe,
                        isMe ? _currentUserAvatarUrl : _chatPartnerAvatarUrl,
                      );
                    },
                  );
                },
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
                        hintText: 'Escribe un mensaje...',
                        hintStyle: TextStyle(color: Colors.white54),
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
    );
  }

  Widget _buildMessageBubble(String text, dynamic timestampData, bool isMe, String? avatarUrl) {
    final Alignment alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final Color color = isMe ? Colors.amber : Colors.grey[700]!;
    final Color textColor = isMe ? Colors.black : Colors.white;
    final BorderRadius borderRadius = BorderRadius.circular(20);

    final Timestamp? timestamp = timestampData is Timestamp ? timestampData : null;
    final String formattedTime = timestamp != null ? DateFormat('HH:mm').format(timestamp.toDate()) : '';

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              CircleAvatar(
                radius: 16,
                backgroundImage: avatarUrl != null && avatarUrl.startsWith('http')
                    ? NetworkImage(avatarUrl)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
                backgroundColor: Colors.grey[700],
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
                  Text(
                    text,
                    style: TextStyle(color: textColor),
                  ),
                  const SizedBox(height: 4),
                  if (formattedTime.isNotEmpty)
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
              CircleAvatar(
                radius: 16,
                backgroundImage: avatarUrl != null && avatarUrl.startsWith('http')
                    ? NetworkImage(avatarUrl)
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
                backgroundColor: Colors.grey[700],
              ),
          ],
        ),
      ),
    );
  }
}