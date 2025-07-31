import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:eslabon_flutter/firebase_options.dart';
import 'package:eslabon_flutter/router/app_router.dart';
import 'package:eslabon_flutter/services/notification_service.dart';
import 'package:eslabon_flutter/providers/notification_service_provider.dart';

// Handler para mensajes de FCM en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ CORREGIDO: Pasa la instancia de GoRouter directamente al constructor de NotificationService
  final GoRouter appRouterInstance = AppRouter.router; // Obtiene la instancia estática del router
  final NotificationService notificationService = NotificationService(appRouter: appRouterInstance);

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWith(
          (ref) => NotificationServiceNotifier(notificationService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  // ✅ ELIMINADO: _router ya no es necesario aquí como State, se pasa directamente en main()
  // late GoRouter _router;

  @override
  void initState() {
    super.initState();
    // ✅ ELIMINADO: Ya no se necesita llamar setRouter aquí
    // _router = AppRouter.router;
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   ref.read(notificationServiceProvider.notifier).setRouter(_router);
    // });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CORREGIDO: Obtiene la instancia del router directamente de AppRouter.router
    final GoRouter router = AppRouter.router;

    return MaterialApp.router(
      title: 'Eslabón',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple,
          secondary: Colors.amber,
          surface: Colors.grey[900]!,
          background: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white54),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.amber,
          textTheme: ButtonTextTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      routerConfig: router, // Usa la instancia del router
    );
  }
}
