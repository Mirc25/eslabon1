// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:eslabon_flutter/services/ads_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eslabon_flutter/services/remote_config_service.dart';
import 'package:eslabon_flutter/services/prefetch_service.dart';

import 'package:eslabon_flutter/firebase_options.dart';
import 'package:eslabon_flutter/router/app_router.dart';
import 'package:eslabon_flutter/services/notification_service.dart';
import 'package:eslabon_flutter/providers/notification_service_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().handleBackgroundMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Persistencia offline y cache Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Refrescar y guardar el token FCM al inicio si el usuario ya está autenticado
  try {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        debugPrint('✅ FCM token actualizado al inicio: $token');
      } else {
        debugPrint('⚠️ No se pudo obtener el token FCM al inicio.');
      }
    }
  } catch (e) {
    debugPrint('❌ Error actualizando FCM token al inicio: $e');
  }

  // Remote Config: toggles de rendimiento
  await RemoteConfigService().init();

  // Diferir SDKs pesados tras primer frame para no bloquear TTI
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    AdsService.enableTestAdsForQA();
    await AdsService.init();
  });
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  );

  _printAvatarOptimizationSummary();

  final GoRouter appRouterInstance = AppRouter.router;
  final NotificationService notificationService = NotificationService();
  await notificationService.initialize(appRouterInstance);

  // Prefetch silencioso de primera página (según toggles)
  if (RemoteConfigService().getPrefetchEnabled()) {
    PrefetchService.prefetchInitialData();
  }

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
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

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Inicialmente la app está en primer plano
    NotificationService.setAppInForeground(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // App en primer plano
        NotificationService.setAppInForeground(true);
        debugPrint('App en primer plano');
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App en segundo plano o cerrada
        NotificationService.setAppInForeground(false);
        debugPrint('App en segundo plano');
        break;
      case AppLifecycleState.hidden:
        // App oculta
        NotificationService.setAppInForeground(false);
        debugPrint('App oculta');
        break;
    }
  }

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

void _printAvatarOptimizationSummary() {
  const int replacedOccurrences = 7; // ChatScreen(AppBar + 2 burbujas), GlobalChat(1), ChatList(2), Notifications(1)
  const List<String> modifiedScreens = [
    'ChatScreen (AppBar y burbujas)',
    'GlobalChatScreen',
    'ChatListScreen',
    'NotificationsScreen',
  ];
  const String depsSummary = 'cached_network_image ^3.4.1, flutter_cache_manager ^3.3.1';
  debugPrint(
      'Resumen AvatarOptimizado -> ocurrencias reemplazadas: $replacedOccurrences; pantallas: ${modifiedScreens.join(', ')}; dependencias: $depsSummary');
}