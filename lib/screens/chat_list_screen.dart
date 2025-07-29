import 'package:flutter/material.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Mensajes', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Aquí verás tus conversaciones con otros usuarios.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              SizedBox(height: 20),
              // Aquí iría la lista de chats
              Icon(Icons.message, size: 80, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}