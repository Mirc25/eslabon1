// debug_token_helper.dart
// Mini-proyecto para obtener el token de App Check rápidamente

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Activar App Check en modo debug
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  
  // Obtener y mostrar el token
  try {
    final token = await FirebaseAppCheck.instance.getToken(true);
    print('🔑 TOKEN DE DEPURACIÓN: $token');
    print('📋 Copia este token y pégalo en Firebase Console');
  } catch (e) {
    print('❌ Error obteniendo token: $e');
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Token Helper',
      home: Scaffold(
        appBar: AppBar(title: Text('Token Helper')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Revisa la consola para el token'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final token = await FirebaseAppCheck.instance.getToken(true);
                    print('🔑 TOKEN: $token');
                  } catch (e) {
                    print('❌ Error: $e');
                  }
                },
                child: Text('Obtener Token'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
