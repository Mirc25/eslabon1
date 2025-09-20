// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:easy_localization/easy_localization.dart';

import 'package:eslabon_flutter/firebase_options.dart';
import 'package:eslabon_flutter/router/app_router.dart';
import 'package:eslabon_flutter/services/notification_service.dart';
import 'package:eslabon_flutter/providers/notification_service_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  try {
    final t = await FirebaseAppCheck.instance.getToken(true);
    print('🔐 [BG] AppCheck token length: ${t?.length}');
  } catch (e) {
    print('❌ [BG] AppCheck getToken error: $e');
  }

  if (message == null) return;
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializar Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 👉 Obtener y loguear el token FCM
  try {
    final token = await FirebaseMessaging.instance.getToken();
    print('🔑 FCM Token: $token');
  } catch (e) {
    print('❌ Error obteniendo FCM token: $e');
  }

  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  final opts = DefaultFirebaseOptions.currentPlatform;
  print('🔥 projectId: ${opts.projectId}');
  print('🔥 appId    : ${opts.appId}');
  print('🔥 package  : com.example.eslabon_flutter');

  try {
    final t = await FirebaseAppCheck.instance.getToken(true);
    print('🔑 AppCheck debug token: $t');
  } catch (e) {
    print('❌ AppCheck getToken error: $e');
  }

  final GoRouter appRouterInstance = AppRouter.router;
  final NotificationService notificationService =
      NotificationService(appRouter: appRouterInstance);

  // ✅ MODIFICACIÓN: Inicializar el servicio de notificaciones
  await notificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWith(
          (ref) => NotificationService(appRouter: AppRouter.router),
        ),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('es'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  Widget build(BuildContext context) {
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
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}