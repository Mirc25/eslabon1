import 'package:eslabon_flutter/router/app_router.dart'; // Importar la variable global router
import 'package:eslabon_flutter/services/notification_service.dart';
import 'package:eslabon_flutter/providers/notification_service_provider.dart'; // Importar el proveedor
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart'; // Importar Firebase Core
import 'package:firebase_messaging/firebase_messaging.dart'; // Importar Firebase Messaging

// Función de nivel superior para mensajes en segundo plano
// Debe estar fuera de cualquier clase
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inicializar Firebase en el handler de background si no está ya inicializado
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");

  // Para manejar la navegación desde background, es más complejo.
  // Generalmente se usa un GlobalKey para el Navigator o se reabre la app a una ruta específica.
  // Por ahora, solo se loguea.
  // Si necesitas navegar, tendrías que pasar el router de alguna manera,
  // por ejemplo, usando un GlobalKey para el Navigator.
  // NotificationService(router).handleMessage(message); // Esto no funcionaría directamente aquí sin un contexto de widget.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar Firebase aquí
  await Firebase.initializeApp();

  // Registrar el manejador de mensajes en segundo plano
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
  // No necesitamos late final AppRouter _appRouter; ya que usamos la variable global 'router'

  @override
  void initState() {
    super.initState();

    // ✅ CORRECCIÓN: Inicializar NotificationService usando Riverpod
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Acceder al notifier del proveedor para actualizar el router
      final notificationServiceNotifier = ref.read(notificationServiceProvider.notifier);
      notificationServiceNotifier.setRouter(router); // Pasar la instancia global de GoRouter

      // Obtener la instancia de NotificationService del proveedor (ya con el router asignado)
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.initialize(); // Llamar al método de instancia initialize

      // Manejar mensajes cuando la app se abre desde un estado terminado
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          notificationService.handleMessage(message);
        }
      });

      // Manejar mensajes cuando la app se abre desde segundo plano
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        notificationService.handleMessage(message);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // El usuario se obtiene a través de Firebase Auth, no es necesario aquí para MaterialApp.router
    // final user = FirebaseAuth.instance.currentUser;

    return MaterialApp.router(
      title: 'Eslabón',
      debugShowCheckedModeBanner: false,
      routerConfig: router, // Usar la instancia global de GoRouter
    );
  }
}
