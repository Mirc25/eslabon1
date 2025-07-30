// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importar Firestore
import 'package:firebase_auth/firebase_auth.dart';     // Importar Firebase Auth
import 'package:intl/intl.dart';                      // Para formatear la fecha/hora de los mensajes

class ChatScreen extends StatefulWidget {
  final String chatId; // El ID de la CONVERSACIÓN (requerido)
  final String? chatPartnerId; // ID del compañero de chat (opcional, pero útil)
  final String? chatPartnerName; // Nombre del compañero de chat (opcional, pero útil)

  const ChatScreen({
    Key? key,
    required this.chatId, 
    this.chatPartnerId, 
    this.chatPartnerName, 
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser; // El usuario actual logueado
  String _displayChatPartnerName = 'Cargando...'; // Nombre para mostrar en el AppBar
  
  final ScrollController _scrollController = ScrollController(); // Para scroll automático al nuevo mensaje

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser; // Obtener el usuario actual al iniciar
    _displayChatPartnerName = widget.chatPartnerName ?? 'Usuario'; // Usar el nombre pasado, si no 'Usuario'
    print('DEBUG: Abriendo chat con ID: ${widget.chatId} con ${widget.chatPartnerName ?? "N/A"} (ID: ${widget.chatPartnerId ?? "N/A"})');

    // Si el nombre del compañero no viene en la navegación y tenemos su ID, intentamos cargarlo.
    if (widget.chatPartnerName == null && widget.chatPartnerId != null) {
      _loadChatPartnerName(widget.chatPartnerId!);
    }

    // Escuchar mensajes entrantes para hacer scroll al final
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(_scrollListener);
    });
  }

  // Listener para hacer scroll al final cuando se añaden nuevos mensajes
  void _scrollListener() {
    // Si el scroll está cerca del final, hacemos scroll automático
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _scrollToBottom();
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

  Future<void> _loadChatPartnerName(String partnerId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(partnerId).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _displayChatPartnerName = userDoc.data()?['nombre'] ?? 'Usuario'; // Asumiendo que el campo es 'nombre'
        });
      }
    } catch (e) {
      print("Error loading chat partner name: $e");
      if (mounted) {
        setState(() {
          _displayChatPartnerName = 'Error';
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final String messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      return; // No enviar mensajes vacíos
    }

    if (_currentUser == null) {
      print('ERROR: Usuario no autenticado para enviar mensaje.');
      // Opcional: mostrar un SnackBar o diálogo al usuario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para enviar mensajes.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      // Guardar el mensaje en la subcolección 'messages' del chat
      await _firestore
          .collection('chats') // Colección principal de chats
          .doc(widget.chatId)  // Documento del chat específico
          .collection('messages') // Subcolección de mensajes
          .add({
        'senderId': _currentUser!.uid,
        'senderName': _currentUser!.displayName ?? 'Anónimo', // Nombre del remitente
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(), // Marca de tiempo del servidor
        // Puedes añadir más campos como 'senderAvatarUrl', 'type' (text/image), etc.
      });

      _messageController.clear(); // Limpiar el campo de texto después de enviar
      _scrollToBottom(); // Hacer scroll al último mensaje
    } on FirebaseException catch (e) {
      print('Firebase Error al enviar mensaje: ${e.code} - ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar mensaje: ${e.message}'), backgroundColor: Colors.red),
      );
    } catch (e) {
      print('Error inesperado al enviar mensaje: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar mensaje: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat con ${_displayChatPartnerName}'),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white), // Color para el ícono de retroceso
      ),
      body: Column(
        children: [
          Expanded(
            // StreamBuilder para escuchar los mensajes en tiempo real
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true) // Ordenar por fecha/hora
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay mensajes aún. ¡Sé el primero en enviar uno!',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // Si hay mensajes, construir la lista
                final List<QueryDocumentSnapshot> messageDocs = snapshot.data!.docs.reversed.toList(); // Invertir para mostrar los más nuevos abajo

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom()); // Asegurar scroll al fondo al cargar mensajes

                return ListView.builder(
                  controller: _scrollController, // Asignar el controlador de scroll
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messageDocs.length,
                  itemBuilder: (context, index) {
                    final message = messageDocs[index].data() as Map<String, dynamic>;
                    final String senderId = message['senderId'] as String? ?? '';
                    final String messageText = message['text'] as String? ?? '';
                    final Timestamp? timestamp = message['timestamp'] as Timestamp?;
                    
                    final bool isMe = senderId == _currentUser?.uid; // Verificar si el mensaje es del usuario actual

                    String formattedTime = '';
                    if (timestamp != null) {
                      final DateTime messageTime = timestamp.toDate();
                      formattedTime = DateFormat('HH:mm').format(messageTime); // Formato de hora
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, // Alinear mensajes
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blueAccent : Colors.grey[700], // Colores de burbuja
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                            bottomLeft: isMe ? Radius.circular(12) : Radius.circular(0),
                            bottomRight: isMe ? Radius.circular(0) : Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              messageText,
                              style: const TextStyle(color: Colors.white, fontSize: 15.0),
                            ),
                            const SizedBox(height: 5.0),
                            Text(
                              formattedTime,
                              style: TextStyle(color: Colors.white70, fontSize: 10.0),
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
          // Campo de texto para escribir mensaje
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      filled: true,
                      fillColor: Colors.grey[800],
                      hintStyle: TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white),
                    maxLines: null, // Permite múltiples líneas
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage, // Llama a la función de enviar mensaje
                  child: const Icon(Icons.send, color: Colors.black),
                  backgroundColor: Colors.amber,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}