// lib/screens/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _saveFcmTokenForUser(User user) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Token FCM guardado correctamente en AuthGate: $token');
      } else {
        debugPrint('⚠️ No se pudo obtener el token FCM en AuthGate.');
      }
    } catch (e) {
      debugPrint('❌ Error guardando token FCM en AuthGate: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.amber),
            ),
          );
        }

        if (snapshot.hasData) {
          _saveFcmTokenForUser(snapshot.data!);
          Future.microtask(() => context.go('/main'));
          return const SizedBox.shrink();
        }

        // Si el usuario no ha iniciado sesión, redirigir a la pantalla de inicio (Home)
        Future.microtask(() => context.go('/home'));
        return const SizedBox.shrink();
      },
    );
  }
}