// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

// Importa tu widget de fondo personalizado
import '../widgets/custom_background.dart';
// Importa tu CustomAppBar
import '../widgets/custom_app_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String requestId; // ID del pedido asociado al chat

  const ChatScreen({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _otherUserName = 'Cargando...';
  String? _otherUserPhotoUrl; // No usado directamente en el UI actual, pero útil
  String? _otherUserId; // Almacena el ID del otro usuario una vez determinado

  User? get currentUser => _auth.currentUser; // Obtener el usuario actual

  @override
  void initState() {
    super.initState();
    _fetchChatParticipantsAndOtherUserDetails();
    // Desplazarse al final de la lista de mensajes cuando se construye la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  // Función para obtener los participantes del chat y los detalles del otro usuario
  Future<void> _fetchChatParticipantsAndOtherUserDetails() async {
    if (currentUser == null) {
      _otherUserName = 'Error de autenticación';
      if (mounted) setState(() {});
      return;
    }

    try {
      final chatDoc = await _firestore.collection('chats').doc(widget.requestId).get();
      if (chatDoc.exists && chatDoc.data() != null) {
        final List<dynamic> participants = chatDoc.data()!['participants'] ?? [];
        _otherUserId = participants.firstWhere(
          (id) => id != currentUser!.uid,
          orElse: () => null,
        );

        if (_otherUserId != null) {
          final otherUserDoc = await _firestore.collection('users').doc(_otherUserId).get();
          if (otherUserDoc.exists && otherUserDoc.data() != null) {
            _otherUserName = otherUserDoc.data()!['name'] ?? 'Usuario';
            _otherUserPhotoUrl = otherUserDoc.data()!['photoUrl'];
          } else {
            _otherUserName = 'Usuario Desconocido';
          }
        } else {
          _otherUserName = 'Error: No se encontró otro participante';
        }
      } else {
        _otherUserName = 'Chat no encontrado';
      }
    } catch (e) {
      _otherUserName = 'Error al cargar chat';
      print('Error fetching chat participants: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  // Desplaza el ListView al final para mostrar los mensajes más recientes
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Envía un mensaje al chat
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || currentUser == null || _otherUserId == null) {
      return;
    }

    final String messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      String senderName = currentUser!.displayName ?? 'Usuario';
      if (currentUser!.displayName == null || currentUser!.displayName!.isEmpty) {
        try {
          final userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
          if (userDoc.exists && userDoc.data() != null) {
            senderName = userDoc.data()!['name'] ?? 'Usuario';
          }
        } catch (e) {
          print('Error fetching sender name: $e');
        }
      }

      await _firestore
          .collection('chats')
          .doc(widget.requestId)
          .collection('messages')
          .add({
        'senderId': currentUser!.uid,
        'senderName': senderName,
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error al enviar mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar mensaje: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Error: Usuario no autenticado.')),
      );
    }

    return CustomBackground(
      showLogo: false, // No mostrar el logo en el chat
      showAds: false, // No mostrar publicidad en el chat
      child: Scaffold(
        backgroundColor: Colors.transparent, // Permite que el fondo personalizado sea visible
        appBar: CustomAppBar(
          title: _otherUserName,
          leading: IconButton( // Botón de regreso explícito
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .doc(widget.requestId)
                    .collection('messages')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Envía tu primer mensaje.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final data = message.data() as Map<String, dynamic>;
                      final bool isMe = data['senderId'] == currentUser!.uid;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(12.0),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            // Colores de burbuja con transparencia para ver el fondo
                            color: isMe
                                ? Theme.of(context).primaryColor.withOpacity(0.7)
                                : Colors.grey.shade300.withOpacity(0.7),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: isMe ? const Radius.circular(15) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['senderName'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                data['message'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (data['timestamp'] != null)
                                Text(
                                  (data['timestamp'] as Timestamp).toDate().toLocal().toString().substring(11, 16),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Área de entrada de texto
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: TextStyle(color: Colors.grey[700]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    mini: true,
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
}