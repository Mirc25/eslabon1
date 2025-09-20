// lib/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/spinning_image_loader.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
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
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('chats')
              .where('participants', arrayContains: _currentUser!.uid)
              .orderBy('lastMessage.timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: SpinningImageLoader());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'no_messages'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
              );
            }

            final chats = snapshot.data!.docs;
            return ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chatDoc = chats[index];
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
                            leading: CircleAvatar(
                              backgroundImage: otherUserAvatar != null && otherUserAvatar.startsWith('http')
                                  ? NetworkImage(otherUserAvatar)
                                  : const AssetImage('assets/default_avatar.png') as ImageProvider,
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
                              context.pushNamed('chat_screen',
                                pathParameters: {'chatId': chatDoc.id},
                                extra: {
                                  'chatPartnerId': otherUserId,
                                  'chatPartnerName': otherUserName,
                                  'chatPartnerAvatar': otherUserAvatar,
                                },
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}


