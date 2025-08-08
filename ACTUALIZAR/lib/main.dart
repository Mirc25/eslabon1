import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Importa Firebase Core
import 'package:go_router/go_router.dart'; // Importa go_router
import 'package:firebase_auth/firebase_auth.dart'; // Importa Firebase Auth

// Importa tus pantallas
import 'package:eslabon_flutter/screens/auth_gate.dart';
import 'package:eslabon_flutter/screens/login_screen.dart';
import 'package:eslabon_flutter/screens/register_screen.dart';
import 'package:eslabon_flutter/screens/home_screen.dart'; // Tu pantalla principal (MainScreen)
import 'package:eslabon_flutter/screens/profile_screen.dart';
import 'package:eslabon_flutter/screens/main_screen.dart'; // Asegúrate de que esta es tu pantalla principal

// Asegúrate de tener tu archivo firebase_options.dart generado
// Puedes generarlo ejecutando: flutterfire configure
import 'firebase_options.dart';

// Configuración de GoRouter
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        // La ruta raíz siempre va al AuthGate para verificar el estado de autenticación
        return const AuthGate();
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: '/register',
      builder: (BuildContext context, GoRouterState state) {
        return const RegisterScreen();
      },
    ),
    GoRoute(
      path: '/home',
      // Aquí deberías usar tu MainScreen, que es la que tiene el Drawer
      builder: (BuildContext context, GoRouterState state) {
        return const MainScreen(); // Asegúrate de que MainScreen es tu pantalla principal
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (BuildContext context, GoRouterState state) {
        return const ProfileScreen();
      },
    ),
    // Puedes añadir más rutas para las nuevas pantallas aquí si lo deseas,
    // aunque por ahora las estás manejando con Navigator.push en el Drawer.
    // Si quieres usar GoRouter para todas las navegaciones, deberías definirlas aquí.
  ],
);

void main() async {
  // Asegura que los widgets de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase de forma asíncrona
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Eslabón',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Puedes personalizar tu tema aquí para que coincida con tus colores oscuros
        brightness: Brightness.dark, // Tema oscuro por defecto
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.grey, // Un gris oscuro para la AppBar
          foregroundColor: Colors.white, // Color del texto y los iconos en la AppBar
        ),
        // Puedes añadir más personalizaciones de tema aquí
      ),
      routerConfig: _router, // Usa la configuración de GoRouter
    );
  }
}