import 'package:eslabon_flutter/router/app_router.dart';
import 'package:eslabon_flutter/services/notification_service.dart';
import 'package:eslabon_flutter/providers/notification_service_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ProviderScope(
      child: MyApp(),
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
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationServiceNotifier = ref.read(notificationServiceProvider.notifier);
      
      // LA LÍNEA CRÍTICA: Acceder a la instancia global de GoRouter desde AppRouter
      notificationServiceNotifier.setRouter(AppRouter.router); 

      final NotificationService notificationService = notificationServiceNotifier.notificationService;
      
      notificationService.initialize(); 

      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          debugPrint("App opened from terminated state by FCM message: ${message.messageId}");
          notificationService.handleMessage(message);
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint("App opened from background by FCM message: ${message.messageId}");
        notificationService.handleMessage(message);
      });

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint("FCM message received in foreground: ${message.messageId}");
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Eslabón',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
    );
  }
}