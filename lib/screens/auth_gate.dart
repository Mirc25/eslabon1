import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart'; // Asegúrate de que esta importación esté presente

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Muestra un indicador de carga mientras se verifica el estado de autenticación
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.amber),
            ),
          );
        }

        // Si el usuario no ha iniciado sesión, redirige a la pantalla de inicio de sesión
        if (!snapshot.hasData) {
          Future.microtask(() => context.go('/login'));
          return const SizedBox.shrink(); // O un placeholder vacío
        }

        // Si el usuario ha iniciado sesión, redirige a la pantalla principal (home)
        Future.microtask(() => context.go('/home'));
        return const SizedBox.shrink(); // O un placeholder vacío
      },
    );
  }
}