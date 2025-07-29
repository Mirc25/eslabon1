// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:eslabon_flutter/widgets/custom_text_field.dart'; // CAMBIO: Ruta corregida para CustomTextField

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        context.go('/home'); // Navega a la ruta principal
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No se encontró un usuario con ese correo.';
      } else if (e.code == 'wrong-password') {
        message = 'Contraseña incorrecta.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico es inválido.';
      } else {
        message = 'Error de autenticación: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocurrió un error inesperado: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 80), // Espacio para el AppBar si existiera
                Image.asset('assets/logo.png', height: 120),
                const SizedBox(height: 20),
                const Text(
                  'Iniciar Sesión',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 30),
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Correo Electrónico',
                  keyboardType: TextInputType.emailAddress,
                ),
                CustomTextField(
                  controller: _passwordController,
                  labelText: 'Contraseña',
                  isPassword: true,
                ),
                const SizedBox(height: 24.0),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.amber)
                    : ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Iniciar Sesión',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                const SizedBox(height: 16.0),
                TextButton(
                  onPressed: () {
                    if (mounted) {
                      context.go('/register'); // Navega a la pantalla de registro
                    }
                  },
                  child: const Text(
                    '¿No tienes cuenta? Regístrate',
                    style: TextStyle(color: Colors.white70),
                  ),
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