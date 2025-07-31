// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eslabon_flutter/firebase_options.dart';

import 'package:eslabon_flutter/router/app_router.dart'; // Importa AppRouter (la clase)
import 'package:eslabon_flutter/providers/app_router_provider.dart'; // Importa el provider de GoRouter

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtiene la instancia de GoRouter del provider
    final goRouter = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Eslabón',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
          secondary: Colors.amber,
        ),
      ),
      routerConfig: goRouter, // Usa la instancia de GoRouter directamente
      debugShowCheckedModeBanner: false,
    );
  }
}