import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        
        // Usar WidgetsBinding.instance.addPostFrameCallback para navegar después del build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (user == null) {
            context.go('/auth');
          } else {
            context.go('/main');
          }
        });
        
        // Mostrar una pantalla de carga mientras se navega
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
