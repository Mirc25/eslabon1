import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Configuración', style: TextStyle(color: Colors.white)),
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
                'Aquí podrás ajustar las preferencias de tu aplicación.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              SizedBox(height: 20),
              // Aquí irían las opciones de configuración
              Icon(Icons.settings_applications, size: 80, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}