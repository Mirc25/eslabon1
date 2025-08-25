// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Generado por flutterfire configure
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'router/app_router.dart'; // expone: final GoRouter router
import 'services/notification_service.dart';
import 'providers/notification_service_provider.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Inicializa EasyLocalization
    await EasyLocalization.ensureInitialized();

    // Inicializa Firebase con tus opciones generadas (android/ios/web)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Inicializa Google Mobile Ads
    await MobileAds.instance.initialize();

    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('es'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        child: const ProviderScope(child: EslabonApp()),
      ),
    );
  }, (error, stack) {
    debugPrint('❌ Error en el arranque: $error');
    debugPrintStack(stackTrace: stack);
  });
}

class EslabonApp extends ConsumerStatefulWidget {
  const EslabonApp({super.key});

  @override
  ConsumerState<EslabonApp> createState() => _EslabonAppState();
}

class _EslabonAppState extends ConsumerState<EslabonApp> {
  @override
  void initState() {
    super.initState();
    // Inicializa y escucha las notificaciones cuando la app arranca
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Eslabón',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      routerConfig: router,
    );
  }
}