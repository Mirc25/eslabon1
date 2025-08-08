import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ AÑADIDO: Mensaje de depuración
    debugPrint('Entrando a HomeScreen'); 

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Image.asset(
                  'assets/logo_white.png',
                  width: 160,
                ),
                const SizedBox(height: 32),
                const Text(
                  '¡Bienvenido a Eslabón!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Conectamos personas que necesitan ayuda con quienes quieren ayudar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    debugPrint('HomeScreen: Botón "Empezar" presionado, navegando a /login'); // ✅ AÑADIDO
                    context.go('/login');
                  },
                  child: const Text('Empezar / Iniciar Sesión'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}