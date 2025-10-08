// lib/services/notification_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notifications_nav.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  late GoRouter _router;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static final Set<String> _dedupeCache = <String>{};
  static String? _activeChatId;
  static String? _lastChatNotificationId;
  static DateTime? _lastChatNotificationTime;
  static bool _isAppInForeground = false;
  static bool _onMainScreen = false;

  static void setActiveChatId(String? chatId) => _activeChatId = chatId;
  static void setAppInForeground(bool inForeground) => _isAppInForeground = inForeground;
  static void setOnMainScreen(bool onMain) => _onMainScreen = onMain;

  // 📣 Notificación local sencilla para eventos del cliente (p.ej., solicitud publicada)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payloadRoute,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'eslabon_channel',
        'Eslabón Notificaciones',
        channelDescription: 'Canal por defecto para notificaciones locales',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
      final int notifId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
      await _flutterLocalNotificationsPlugin.show(
        notifId,
        title,
        body,
        platformDetails,
        payload: payloadRoute,
      );
      print('🔔 [LOCAL] Notificación mostrada: $title - $body (payload: '+(payloadRoute??'null')+')');
    } catch (e) {
      print('🔔 [LOCAL] Error mostrando notificación: $e');
    }
  }

  // 🧪 MÉTODO DE PRUEBA: Simular navegación de notificación sin FCM
  Future<void> testNotificationNavigation({
    required String notificationType,
    required String requestId,
    String? helperId,
    String? requesterId,
    String? helperName,
    String? requesterName,
  }) async {
    print('🧪 === TESTING NOTIFICATION NAVIGATION ===');
    print('🧪 Type: $notificationType');
    print('🧪 RequestId: $requestId');
    print('🧪 HelperId: $helperId');
    print('🧪 RequesterId: $requesterId');
    
    // Crear datos simulados como los que vendrían de FCM
    final Map<String, dynamic> testData = {
      'notificationType': notificationType,
      'requestId': requestId,
      'type': notificationType, // Fallback
    };
    
    if (helperId != null) testData['helperId'] = helperId;
    if (requesterId != null) testData['requesterId'] = requesterId;
    if (helperName != null) testData['helperName'] = helperName;
    if (requesterName != null) testData['requesterName'] = requesterName;
    
    // Generar ruta usando el mismo método que usa FCM
    final String route = routeFor(testData);
    print('🧪 Generated route: $route');
    
    if (route.isNotEmpty) {
      print('🧪 Testing navigation to: $route');
      
      // Usar el mismo método de timing que _handleNavigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('🧪 🚀 EXECUTING TEST NAVIGATION POST-FRAME: $route');
        try {
          _router.go(route);
          print('🧪 ✅ TEST NAVIGATION SUCCESSFUL');
        } catch (e) {
          print('🧪 ❌ TEST NAVIGATION FAILED: $e');
        }
      });
    } else {
      print('🧪 ❌ Could not generate route for test');
    }
    
    print('🧪 === END TESTING NOTIFICATION NAVIGATION ===');
  }

  // Método público que será llamado desde el handler global en main.dart
  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Handling a background message via public method: ${message.messageId}');
    await _handleMessage(message);
  }

  Future<void> initialize(GoRouter router) async {
    _router = router;
    await _restoreDedupeCache();
    await _initLocalNotifications();

    // Solicitar permiso FCM con flags explícitos
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      print('📲 Permiso FCM solicitado (alert/badge/sound)');
    } catch (e) {
      print('📲 ⚠️ Error solicitando permiso FCM: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // 📨 DEBUGGING: Capturar exactamente lo que llega al teléfono
      print('📨 === FCM onMessage RECEIVED ===');
      print('📨 Message ID: ${message.messageId}');
      print('📨 FCM.data: ${message.data}');
      print('📨 FCM.route: ${message.data['route']}');
      print('📨 FCM.type: ${message.data['type']}');
      print('📨 FCM.notificationType: ${message.data['notificationType']}');
      print('📨 FCM.requestId: ${message.data['requestId']}');
      print('📨 FCM.helperId: ${message.data['helperId']}');
      print('📨 FCM.requesterId: ${message.data['requesterId']}');
      print('📨 === END FCM onMessage ===');
      
      // Normalizar ids y tipo para suprimir correctamente en foreground
      final String? chatRoomId = (message.data['chatRoomId'] ?? message.data['chatId'])?.toString();
      final String? notificationType = (message.data['notificationType'] ?? message.data['type'])?.toString();

      // En primer plano: suprimir solo chats del hilo activo; mostrar demás tipos
      if (_isAppInForeground && (notificationType == 'chat_message' || notificationType == 'chat') && _activeChatId == chatRoomId) {
        debugPrint('Mensaje de chat en chat activo, se ignora en foreground.');
        return;
      }

      // En primer plano: NO suprimir notificaciones de ayuda cercanas en MainScreen
      // Permitimos que "help_nearby" se muestre incluso si el usuario está en Main
      // Mantenemos supresión solo para notificaciones de tipo "help" generales si se requiere
      if (_isAppInForeground && _onMainScreen && notificationType == 'help') {
        debugPrint('Notificación de ayuda general suprimida en foreground porque el usuario está en MainScreen.');
        return;
      }
      await _handleMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      print('🚀 === onMessageOpenedApp TRIGGERED ===');
      print('🚀 Timestamp: ${DateTime.now()}');
      print('🚀 Message ID: ${message.messageId}');
      
      // 📨 DEBUGGING: Capturar exactamente lo que llega al teléfono (onMessageOpenedApp)
      print('📨 === FCM onMessageOpenedApp RECEIVED ===');
      print('📨 Message ID: ${message.messageId}');
      print('📨 FCM.data: ${message.data}');
      print('📨 FCM.route: ${message.data['route']}');
      print('📨 FCM.type: ${message.data['type']}');
      print('📨 FCM.notificationType: ${message.data['notificationType']}');
      print('📨 FCM.requestId: ${message.data['requestId']}');
      print('📨 FCM.helperId: ${message.data['helperId']}');
      print('📨 FCM.requesterId: ${message.data['requesterId']}');
      print('📨 === END FCM onMessageOpenedApp ===');
      
      print('[FCM] onMessageOpenedApp data=${message.data}');
      print('[FCM] route=${message.data['route']} requestId=${message.data['requestId'] ?? message.data['solicitudId']} type=${message.data['type']}');
      
      print('🚀 Calling _handleNavigation...');
      await _handleNavigation(message);
      print('🚀 === onMessageOpenedApp COMPLETED ===');
    });
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Solicitar permiso para mostrar notificaciones (Android 13+)
    try {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      // En Android 13+, solicitar permiso mediante la API específica del plugin
      final granted = await androidPlugin?.requestNotificationsPermission();
      print('🔔 Permiso de notificaciones solicitado (Android): ${granted == true}');
    } catch (e) {
      print('🔔 ⚠️ Error solicitando permiso de notificaciones: $e');
    }

    // Crear el canal por defecto para FCM indicado en AndroidManifest (eslabon_channel)
    try {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
        'eslabon_channel',
        'Eslabón Notificaciones',
        description: 'Canal por defecto para notificaciones FCM',
        importance: Importance.high,
      );
      await androidPlugin?.createNotificationChannel(defaultChannel);
      print('🔔 Canal de notificaciones "eslabon_channel" creado/asegurado');
    } catch (e) {
      print('🔔 ⚠️ Error creando canal de notificaciones por defecto: $e');
    }

    // Crear/asegurar canal específico usado por FCM para chat
    try {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
        'chat_notifications',
        'Chat',
        description: 'Notificaciones de chat privadas',
        importance: Importance.high,
      );
      await androidPlugin?.createNotificationChannel(chatChannel);
      print('🔔 Canal de notificaciones "chat_notifications" creado/asegurado');
    } catch (e) {
      print('🔔 ⚠️ Error creando canal de chat: $e');
    }
  }

  Future<void> _handleNotificationTap(NotificationResponse response) async {
    print('🔔 === DEBUGGING LOCAL NOTIFICATION TAP ===');
    print('🔔 Response completo: ${response.toString()}');
    print('🔔 Payload: ${response.payload}');
    print('🔔 Action ID: ${response.actionId}');
    print('🔔 Notification ID: ${response.id}');
    
    // 📨 DEBUGGING: Capturar datos de notificación local
    print('📨 LOCAL.payload: ${response.payload}');
    if (response.payload != null && response.payload!.contains('?')) {
      final uri = Uri.tryParse(response.payload!);
      if (uri != null) {
        print('📨 LOCAL.parsed_route: ${uri.path}');
        print('📨 LOCAL.query_params: ${uri.queryParameters}');
        print('📨 LOCAL.helperId: ${uri.queryParameters['helperId']}');
        print('📨 LOCAL.requesterId: ${uri.queryParameters['requesterId']}');
      }
    }
    
    if (response.payload != null) {
      try {
        final route = response.payload!;
        print('🔔 ✅ NAVEGANDO A (LOCAL): $route');
        
        // Extraer chatId de la ruta si es un chat
        if (route.startsWith('/chat/')) {
          final chatId = route.split('/chat/')[1];
          await _markChatNotificationsAsRead(chatId);
        }
        
        if (route == '/main' || route == '/') {
          _router.go('/main');
        } else {
          _router.go('/main');
          Future.microtask(() => _router.push(route));
        }
        print('🔔 ✅ NAVEGACIÓN LOCAL EXITOSA');
      } catch (e) {
        print('🔔 ❌ ERROR EN NAVEGACIÓN LOCAL: $e');
      }
    } else {
      print('🔔 ❌ NO HAY PAYLOAD en notificación local');
    }
    print('🔔 === FIN DEBUGGING LOCAL NOTIFICATION TAP ===');
  }

  Future<void> _markChatNotificationsAsRead(String chatId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      debugPrint('🗑️ Marcando notificaciones del chat como leídas: $chatId');
      
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .where('type', isEqualTo: 'chat_message')
          .where('chatId', isEqualTo: chatId)
          .where('read', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        await doc.reference.update({'read': true});
      }
      
      debugPrint('✅ ${notifications.docs.length} notificaciones marcadas como leídas');
    } catch (e) {
      debugPrint('❌ Error marking chat notifications as read: $e');
    }
  }

  Future<void> _handleNavigation(RemoteMessage message) async {
    print('🔔 === DEBUGGING NOTIFICATION TAP ===');
    print('🔔 Message data completo: ${message.data}');
    print('🔔 Message notification: ${message.notification?.toMap()}');
    
    // Usar la función routeFor() centralizada para determinar la ruta correcta
    final String route = routeFor(message.data);
    
    print('🔔 Route final (desde routeFor): $route');
    
    if (route.isNotEmpty) {
      print('🔔 ✅ PREPARANDO NAVEGACIÓN A: $route');
      
      // 🛡️ PROTECCIÓN ANTI-CRASH: Múltiples capas de seguridad
      bool navigationSuccessful = false;
      
      // 🚀 CAPA 1: PostFrameCallback con protección extra
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigationSuccessful) return; // Ya navegó exitosamente
        
        print('🔔 🚀 EJECUTANDO NAVEGACIÓN POST-FRAME: $route');
        try {
          // Verificar que el router esté disponible
          if (_router.routerDelegate.currentConfiguration.isNotEmpty) {
            if (route == '/main' || route == '/') {
              _router.go('/main');
            } else {
              _router.go('/main');
              Future.microtask(() => _router.push(route));
            }
            navigationSuccessful = true;
            print('🔔 ✅ NAVEGACIÓN EXITOSA POST-FRAME');
          } else {
            throw Exception('Router no está listo');
          }
        } catch (e) {
          print('🔔 ❌ ERROR EN NAVEGACIÓN POST-FRAME: $e');
          // Fallback seguro: ir a home
          try {
            _router.go('/main');
            navigationSuccessful = true;
            print('🔔 🏠 NAVEGACIÓN A HOME EXITOSA (FALLBACK POST-FRAME)');
          } catch (e2) {
            print('🔔 💥 ERROR CRÍTICO EN FALLBACK POST-FRAME: $e2');
          }
        }
      });
      
      // 🚀 CAPA 2: Navegación con delay como backup
      Future.delayed(const Duration(milliseconds: 200), () {
        if (navigationSuccessful) return; // Ya navegó exitosamente
        
        print('🔔 🔄 INTENTANDO NAVEGACIÓN CON DELAY: $route');
        try {
          if (route == '/main' || route == '/') {
            _router.go('/main');
          } else {
            _router.go('/main');
            Future.microtask(() => _router.push(route));
          }
          navigationSuccessful = true;
          print('🔔 ✅ NAVEGACIÓN CON DELAY EXITOSA');
        } catch (e) {
          print('🔔 ⚠️ NAVEGACIÓN CON DELAY FALLÓ: $e');
          // Último intento: ir a home
          try {
            _router.go('/main');
            navigationSuccessful = true;
            print('🔔 🏠 NAVEGACIÓN A HOME EXITOSA (FALLBACK DELAY)');
          } catch (e2) {
            print('🔔 💥 ERROR CRÍTICO EN FALLBACK DELAY: $e2');
          }
        }
      });
      
    } else {
      print('🔔 ❌ NO SE PUDO DETERMINAR RUTA - ni route, ni navigationPath, ni fallback funcionaron');
      print('🔔 Datos disponibles para debug:');
      
      final allKeys = message.data.keys.toList();
      print('🔔 Todas las keys: $allKeys');
      
      for (String key in allKeys) {
        print('🔔 $key: ${message.data[key]}');
      }
      
      // Ir a home como último recurso con protección anti-crash
      print('🔔 🏠 Navegando a home como último recurso');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _router.go('/');
          print('🔔 🏠 NAVEGACIÓN A HOME EXITOSA (ÚLTIMO RECURSO)');
        } catch (e) {
          print('🔔 💥 ERROR CRÍTICO EN ÚLTIMO RECURSO: $e');
        }
      });
    }
    print('🔔 === FIN DEBUGGING NOTIFICATION TAP ===');
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    final String dedupeKey = _getDedupeKey(message);

    if (await _isDuplicate(dedupeKey)) {
      debugPrint('Mensaje duplicado, se descarta. Clave: $dedupeKey');
      return;
    }

    _dedupeCache.add(dedupeKey);
    _saveDedupeKey(dedupeKey);
    
    final String? chatRoomId = message.data['chatRoomId']?.toString();
    if (chatRoomId != null) {
      final now = DateTime.now();
      if (_lastChatNotificationId == chatRoomId && now.difference(_lastChatNotificationTime!).inSeconds < 5) {
        debugPrint('Ráfaga de mensajes de chat en curso, se suprime la notificación.');
        return;
      }
      _lastChatNotificationId = chatRoomId;
      _lastChatNotificationTime = now;
    }

    await _showNotification(message);
    debugPrint('Mensaje recibido y procesado. Clave: $dedupeKey');
  }

  Future<void> _showNotification(RemoteMessage message) async {
    print('🔔 === DEBUGGING SHOW NOTIFICATION ===');
    print('🔔 Message data completo: ${message.data}');
    print('🔔 Message notification: ${message.notification?.toMap()}');
    
    // Evitar duplicados: si la app está en segundo plano y el payload incluye
    // una sección "notification", Android ya mostrará la notificación del sistema.
    // En ese caso, NO mostramos una notificación local adicional.
    final bool systemWillShowNotification = (message.notification != null) && !NotificationService._isAppInForeground;
    if (systemWillShowNotification) {
      print('🔔 ⚠️ Sistema mostrará la notificación (background + notification payload). Se omite local.');
      return;
    }
    
    // Usar title y body de notification si están disponibles, sino usar los de data
    final String? title = message.notification?.title ?? message.data['title'];
    final String? body = message.notification?.body ?? message.data['body'];
    final String? route = message.data['route'] as String?;
    // final String? senderAvatarUrl = message.data['senderPhotoUrl'] as String?; // No usar URL como icono

    print('🔔 Title extraído: $title');
    print('🔔 Body extraído: $body');
    print('🔔 Route extraída para payload: $route');
    // print('🔔 Sender avatar URL: $senderAvatarUrl');

    if (title != null && body != null) {
      print('🔔 ✅ CREANDO NOTIFICACIÓN LOCAL con payload: $route');
      // Elegir canal según tipo: chat vs general (ayuda, rating, etc.)
      final String notificationType = (message.data['notificationType'] ?? message.data['type'] ?? '').toString();
      final bool isChat = notificationType == 'chat' || notificationType == 'chat_message';
      final String channelId = isChat ? 'chat_notifications' : 'eslabon_channel';
      final String channelName = isChat ? 'Chat' : 'Eslabón Notificaciones';
      final String channelDescription = isChat ? 'Notificaciones de chat privadas' : 'Notificaciones generales de Eslabón';

      // Importante: el icono debe ser un recurso local (no URL).
      // Usamos el launcher por defecto y dejamos la imagen remota para futuro via largeIcon descargado.
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        // Unificar canal según tipo de notificación
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        // Acento negro para cumplir con estética solicitada en notificaciones generales
        color: isChat ? null : Colors.black,
      );

      final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
      // ID único por notificación para evitar sobrescritura
      final int notifId = (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch) & 0x7FFFFFFF;
      await _flutterLocalNotificationsPlugin.show(
        notifId,
        title,
        body,
        platformDetails,
        payload: route,
      );
      print('🔔 ✅ NOTIFICACIÓN LOCAL MOSTRADA EXITOSAMENTE');
    } else {
      print('🔔 ❌ NO SE PUDO MOSTRAR NOTIFICACIÓN - Title: $title, Body: $body');
    }
    print('🔔 === FIN DEBUGGING SHOW NOTIFICATION ===');
  }

  String _getDedupeKey(RemoteMessage message) {
    if (message.data.containsKey('dedupeKey')) {
      return message.data['dedupeKey'].toString();
    }
    final String? chatRoomId = message.data['chatRoomId']?.toString();
    final String? messageId = message.messageId;
    if (chatRoomId != null && messageId != null) {
      return '$chatRoomId-$messageId';
    }
    return message.messageId ?? '';
  }

  Future<bool> _isDuplicate(String dedupeKey) async {
    if (_dedupeCache.contains(dedupeKey)) {
      return true;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool existsInPrefs = prefs.getBool('esl_dk_$dedupeKey') ?? false;
    if (existsInPrefs) {
      _dedupeCache.add(dedupeKey);
      return true;
    }
    return false;
  }
  
  Future<void> _saveDedupeKey(String dedupeKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('esl_dk_$dedupeKey', true);
    Timer(const Duration(minutes: 10), () async {
      await prefs.remove('esl_dk_$dedupeKey');
      _dedupeCache.remove(dedupeKey);
    });
  }

  Future<void> _restoreDedupeCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    _dedupeCache.clear();
    for (var key in allKeys) {
      if (key.startsWith('esl_dk_')) {
        _dedupeCache.add(key.substring(7));
      }
    }
  }

  Future<String?> getDeviceToken() async => _messaging.getToken();

  /// Fallback para generar rutas basadas en tipo de notificación e IDs
  String? _routeFromTypeAndIds(Map<String, dynamic> data) {
    final String? notificationType = data['notificationType']?.toString() ?? data['type']?.toString();
    final String? requestId = data['requestId']?.toString();
    final String? helperId = data['helperId']?.toString();
    final String? requesterId = data['requesterId']?.toString();
    
    print('🔧 [FALLBACK] Generando ruta desde tipo: $notificationType');
    print('🔧 [FALLBACK] requestId: $requestId, helperId: $helperId, requesterId: $requesterId');
    
    switch (notificationType) {
      case 'offer_received':
        if (requestId != null && helperId != null) {
          String route = '/rate-helper/$requestId?helperId=$helperId';
          print('🔧 [FALLBACK] ✅ Ruta generada para offer_received: $route');
          return route;
        } else if (requestId != null) {
          // Fallback sin helperId
          String route = '/request/$requestId';
          print('🔧 [FALLBACK] ⚠️ Fallback sin helperId: $route');
          return route;
        }
        break;
      case 'rate_helper':
      case 'helper_rated':
        if (requestId != null && helperId != null) {
          print('🔧 [FALLBACK] ✅ Ruta generada: /rate-helper/$requestId?helperId=$helperId');
          return '/rate-helper/$requestId?helperId=$helperId';
        }
        break;
      case 'rate_requester':
      case 'requester_rated':
        if (requestId != null && requesterId != null) {
          print('🔧 [FALLBACK] ✅ Ruta generada: /rate-requester/$requestId?requesterId=$requesterId');
          return '/rate-requester/$requestId?requesterId=$requesterId';
        }
        break;
    }
    
    print('🔧 [FALLBACK] ❌ No se pudo generar ruta para tipo: $notificationType');
    return null;
  }
}