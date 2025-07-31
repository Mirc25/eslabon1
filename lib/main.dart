// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Importa Riverpod
import 'package:eslabon_flutter/firebase_options.dart';

import 'package:eslabon_flutter/router/app_router.dart'; // Importa AppRouter
import 'package:eslabon_flutter/providers/app_router_provider.dart'; // Importa el nuevo provider de AppRouter

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope( // Envuelve la aplicación con ProviderScope
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget { // Cambiado a ConsumerWidget
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Agrega WidgetRef ref
    final goRouter = ref.watch(appRouterProvider); // Obtiene la instancia de GoRouter del provider

    return MaterialApp.router(
      title: 'Eslabón',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Puedes definir un esquema de color más completo
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
          secondary: Colors.amber, // Color de acento
        ),
      ),
      routerConfig: goRouter, // Usa la instancia de GoRouter directamente
      debugShowCheckedModeBanner: false,
    );
  }
}