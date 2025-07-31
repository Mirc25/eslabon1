// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class ChatScreen extends StatefulWidget {
  final String chatPartnerId;
  final String chatPartnerName;

  // ✅ CORREGIDO: Constructor con parámetros nombrados requeridos
  const ChatScreen({
    Key? key,
    required this.chatPartnerId,
    required this.chatPartnerName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _chatRoomId = '';

  @override
  void initState() {
    super.initState();
    _createChatRoomId();
  }

  // Genera un ID de sala de chat consistente basado en los IDs de los participantes
  void _createChatRoomId() {
    final String currentUserId = _auth.currentUser!.uid;
    // Ordena los IDs para asegurar que el chatRoomId sea el mismo para ambos usuarios
    final List<String> participants = [currentUserId, widget.chatPartnerId];
    participants.sort();
    _chatRoomId = participants.join('_');
  }

  // Envía un mensaje a Firestore
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserName = _auth.currentUser!.displayName ?? 'Usuario Anónimo';

    try {
      await _firestore
          .collection('chat_rooms')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'senderName': currentUserName,
        'receiverId': widget.chatPartnerId, // El ID del otro participante
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(), // Marca de tiempo del servidor
      });
      _messageController.clear(); // Limpia el campo de texto después de enviar
    } catch (e) {
      print("Error sending message: $e");
      // Opcional: Mostrar un SnackBar al usuario si el mensaje no se pudo enviar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar mensaje: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo oscuro
      appBar: AppBar(
        title: Text('Chat con ${widget.chatPartnerName}', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900], // Color de AppBar oscuro
        iconTheme: const IconThemeData(color: Colors.white), // Íconos blancos
      ),
      body: Column(
        children: [
          Expanded(
            // StreamBuilder para escuchar mensajes en tiempo real
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chat_rooms')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true) // Ordena por los más recientes primero
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }

                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Envía el primer mensaje para iniciar la conversación.',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true, // Muestra los mensajes más recientes abajo
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final bool isMe = message['senderId'] == _auth.currentUser!.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueAccent : Colors.grey[700], // Diferente color para mis mensajes
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['senderName'] ?? 'Anónimo',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message['message'],
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            if (message['timestamp'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  DateFormat('HH:mm').format((message['timestamp'] as Timestamp).toDate()),
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
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
          // Área de entrada de texto para enviar mensajes
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
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.amber,
                  child: const Icon(Icons.send, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
