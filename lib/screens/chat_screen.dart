import 'package:flutter/material.dart';
// Asegúrate de tener los imports necesarios para tu pantalla de chat
// Por ejemplo:
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String chatId; // El ID de la CONVERSACIÓN
  final String? chatPartnerId; // Opcional, si se pasa como extra
  final String? chatPartnerName; // Opcional, si se pasa como extra

  const ChatScreen({
    Key? key,
    required this.chatId, // Ahora requerido
    this.chatPartnerId, // Hecho opcional
    this.chatPartnerName, // Hecho opcional
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Aquí iría tu lógica de chat, controladores de texto, streams de Firestore, etc.
  // Ejemplo básico para que compile:
  // final TextEditingController _messageController = TextEditingController();
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance;

  String _displayChatPartnerName = 'Cargando...'; // Variable para el nombre mostrado

  @override
  void initState() {
    super.initState();
    // Puedes acceder a widget.chatPartnerId y widget.chatPartnerName aquí
    // Si chatPartnerName es nulo, intenta cargarlo o muestra un placeholder
    _displayChatPartnerName = widget.chatPartnerName ?? 'Usuario';
    print('DEBUG: Abriendo chat con ID: ${widget.chatId} con ${widget.chatPartnerName ?? "N/A"} (ID: ${widget.chatPartnerId ?? "N/A"})');

    // Aquí podrías añadir lógica para cargar el nombre si no se proporcionó
    // if (widget.chatPartnerName == null && widget.chatPartnerId != null) {
    //   _loadChatPartnerName(widget.chatPartnerId!);
    // }
  }

  // Future<void> _loadChatPartnerName(String partnerId) async {
  //   try {
  //     final userDoc = await FirebaseFirestore.instance.collection('users').doc(partnerId).get();
  //     if (userDoc.exists) {
  //       setState(() {
  //         _displayChatPartnerName = userDoc.data()?['name'] ?? 'Usuario';
  //       });
  //     }
  //   } catch (e) {
  //     print("Error loading chat partner name: $e");
  //     setState(() {
  //       _displayChatPartnerName = 'Error';
  //     });
  //   }
  // }


  @override
  void dispose() {
    // _messageController.dispose(); // Si usas un controlador
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat con ${_displayChatPartnerName}'), // Usando el nombre
        backgroundColor: Colors.grey[900],
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Text(
                    'Aquí se mostrarían los mensajes del chat con ${_displayChatPartnerName} (ID de chat: ${widget.chatId})',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      // controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: () {
                      // Lógica para enviar mensaje
                      print('DEBUG: Mensaje enviado');
                    },
                    child: Icon(Icons.send),
                    backgroundColor: Colors.amber,
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