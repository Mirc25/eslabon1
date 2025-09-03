import 'package:flutter/material.dart';

class PushNotificationTestScreen extends StatelessWidget {
  const PushNotificationTestScreen({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Notificaciones'),
      ),
      body: const Center(
        child: Text('Esta es la pantalla de prueba de notificaciones. Funciona si puedes ver este texto.'),
      ),
    );
  }
}
