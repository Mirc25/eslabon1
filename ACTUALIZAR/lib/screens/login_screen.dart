import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para la autenticación de Firebase
import 'package:go_router/go_router.dart'; // ¡Importa GoRouter aquí!

// Ya no necesitas importar main_screen.dart directamente aquí
// import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscureText = true; // Para ocultar/mostrar contraseña

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = ''; // Limpiar mensaje de error previo
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Una vez que el inicio de sesión es exitoso, Firebase Auth
      // persiste la sesión y el StreamBuilder en AuthGate detectará
      // el cambio de estado y redirigirá a /home.
      // Sin embargo, para una navegación más directa y para asegurar
      // que la pantalla de login se quite de la pila, usamos context.go().
      if (mounted) {
        // Verifica si el correo está verificado, si es un requisito
        if (credential.user != null && credential.user!.emailVerified) {
          context.go('/home'); // ¡Cambiado a GoRouter!
        } else {
          // Si el correo no está verificado, mostrar un mensaje.
          setState(() {
            _errorMessage = 'Debes verificar tu correo electrónico antes de continuar.';
          });
          // Opcional: Desautenticar si no está verificado y no debería continuar
          // await FirebaseAuth.instance.signOut();
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No se encontró un usuario con ese correo electrónico.';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'Contraseña incorrecta.';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'El formato del correo electrónico es inválido.';
        } else if (e.code == 'too-many-requests') {
          _errorMessage = 'Demasiados intentos fallidos. Intenta de nuevo más tarde.';
        } else {
          _errorMessage = e.message ?? 'Ocurrió un error inesperado al iniciar sesión.';
        }
        if (kDebugMode) {
          print('Error de inicio de sesión: $e');
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocurrió un error inesperado: ${e.toString()}';
        if (kDebugMode) {
          print('Error inesperado: $e');
        }
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
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/eslabon_background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Image.asset('assets/logo.png', height: 100),
                      const SizedBox(height: 16),
                      const Text(
                        'Iniciar Sesión',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          labelStyle: const TextStyle(color: Colors.white),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.cyan),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.amber),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.black54,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscureText, // Usa el estado _obscureText
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: const TextStyle(color: Colors.white),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.cyan),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.amber),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.black54,
                          suffixIcon: IconButton( // Icono para mostrar/ocultar contraseña
                            icon: Icon(
                              _obscureText ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu contraseña';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage.isNotEmpty)
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      const SizedBox(height: 20),
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.amber) // Muestra indicador de carga
                          : ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Entrar',
                                style: TextStyle(fontSize: 18, color: Colors.black),
                              ),
                            ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          context.go('/register'); // ¡Cambiado a GoRouter!
                        },
                        child: const Text(
                          '¿No tienes cuenta? Regístrate aquí',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}