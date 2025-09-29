import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'notifications_nav.dart';
import 'router/app_router.dart';

Future<void> bindNotificationOpenHandlers(GlobalKey<NavigatorState> navKey) async {
  // App cerrada y se abre desde notificación
  try {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage?.data != null) {
      print('🔥 [FCM_OPEN] App abierta desde notificación - Datos: ${initialMessage!.data}');
      final route = routeFor(initialMessage.data);
      print('🔥 [FCM_OPEN] Ruta determinada: $route');
      
      // 🛡️ PROTECCIÓN ANTI-CRASH: Navegación segura con múltiples capas
      _safeNavigate(navKey, route, 'INITIAL_MESSAGE');
    }
  } catch (e) {
    print('🔥 [FCM_OPEN] ❌ ERROR en getInitialMessage: $e');
  }

  // App en background y se toca notificación
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
    try {
      if (m.data.isNotEmpty) {
        print('🔥 [FCM_OPEN] App en background - Notificación tocada - Datos: ${m.data}');
        final route = routeFor(m.data);
        print('🔥 [FCM_OPEN] Ruta determinada: $route');
        
        // 🛡️ PROTECCIÓN ANTI-CRASH: Navegación segura con múltiples capas
        _safeNavigate(navKey, route, 'BACKGROUND_TAP');
      }
    } catch (e) {
      print('🔥 [FCM_OPEN] ❌ ERROR en onMessageOpenedApp: $e');
      // Fallback seguro: ir a home
      _safeNavigate(navKey, '/main', 'ERROR_FALLBACK');
    }
  });
}

// 🛡️ FUNCIÓN DE NAVEGACIÓN ULTRA-ROBUSTA CON MÚLTIPLES MÉTODOS
void _safeNavigate(GlobalKey<NavigatorState> navKey, String route, String source) {
  print('🔥 [SAFE_NAV] === INICIO NAVEGACIÓN ULTRA-ROBUSTA ===');
  print('🔥 [SAFE_NAV] Fuente: $source');
  print('🔥 [SAFE_NAV] Ruta objetivo: $route');
  
  bool navigationSuccessful = false;
  
  // 🚀 MÉTODO 1: Navegación con context directo
  try {
    final context = navKey.currentState?.context;
    if (context != null && context.mounted) {
      print('🔥 [SAFE_NAV] 🚀 MÉTODO 1: Context directo');
      context.go(route);
      navigationSuccessful = true;
      print('🔥 [SAFE_NAV] ✅ NAVEGACIÓN CON CONTEXT EXITOSA');
      return; // Salir si fue exitosa
    } else {
      print('🔥 [SAFE_NAV] ⚠️ Context no disponible');
    }
  } catch (e) {
    print('🔥 [SAFE_NAV] ❌ ERROR en navegación con context: $e');
  }
  
  // 🚀 MÉTODO 2: Navegación con GlobalKey del router
  if (!navigationSuccessful) {
    try {
      final navigatorState = AppRouter.navigatorKey.currentState;
      if (navigatorState != null) {
        print('🔥 [SAFE_NAV] 🔑 MÉTODO 2: GlobalKey del router');
        final context = navigatorState.context;
        if (context.mounted) {
          context.go(route);
          navigationSuccessful = true;
          print('🔥 [SAFE_NAV] ✅ NAVEGACIÓN CON GLOBALKEY EXITOSA');
          return; // Salir si fue exitosa
        }
      } else {
        print('🔥 [SAFE_NAV] ⚠️ NavigatorState no disponible');
      }
    } catch (e) {
      print('🔥 [SAFE_NAV] ❌ ERROR en navegación con GlobalKey: $e');
    }
  }
  
  // 🚀 MÉTODO 3: PostFrameCallback con múltiples intentos
  if (!navigationSuccessful) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigationSuccessful) return;
      
      print('🔥 [SAFE_NAV] 🔄 MÉTODO 3: PostFrameCallback');
      
      // Intentar con context original
      try {
        final context = navKey.currentState?.context;
        if (context != null && context.mounted) {
          context.go(route);
          navigationSuccessful = true;
          print('🔥 [SAFE_NAV] ✅ NAVEGACIÓN POST-FRAME CON CONTEXT EXITOSA');
          return;
        }
      } catch (e) {
        print('🔥 [SAFE_NAV] ❌ ERROR PostFrame con context: $e');
      }
      
      // Intentar con GlobalKey
      try {
        final navigatorState = AppRouter.navigatorKey.currentState;
        if (navigatorState != null) {
          final globalContext = navigatorState.context;
          if (globalContext.mounted) {
            globalContext.go(route);
            navigationSuccessful = true;
            print('🔥 [SAFE_NAV] ✅ NAVEGACIÓN POST-FRAME CON GLOBALKEY EXITOSA');
            return;
          }
        }
      } catch (e) {
        print('🔥 [SAFE_NAV] ❌ ERROR PostFrame con GlobalKey: $e');
      }
      
      // Fallback a home
      try {
        final navigatorState = AppRouter.navigatorKey.currentState;
        if (navigatorState != null) {
          final globalContext = navigatorState.context;
          if (globalContext.mounted) {
            globalContext.go('/main');
            print('🔥 [SAFE_NAV] 🏠 NAVEGACIÓN A HOME EXITOSA (FALLBACK)');
          }
        }
      } catch (e2) {
        print('🔥 [SAFE_NAV] 💥 ERROR CRÍTICO EN FALLBACK: $e2');
      }
    });
  }
  
  // 🚀 MÉTODO 4: Delay con múltiples intentos
  if (!navigationSuccessful) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (navigationSuccessful) return;
      
      print('🔥 [SAFE_NAV] ⏰ MÉTODO 4: Navegación con delay');
      
      // Intentar con GlobalKey
      try {
        final navigatorState = AppRouter.navigatorKey.currentState;
        if (navigatorState != null) {
          final globalContext = navigatorState.context;
          if (globalContext.mounted) {
            globalContext.go(route);
            print('🔥 [SAFE_NAV] ✅ NAVEGACIÓN CON DELAY EXITOSA');
            return;
          }
        }
      } catch (e) {
        print('🔥 [SAFE_NAV] ❌ ERROR en navegación con delay: $e');
      }
      
      // Último intento con context original
      try {
        final context = navKey.currentState?.context;
        if (context != null && context.mounted) {
          context.go(route);
          print('🔥 [SAFE_NAV] ✅ NAVEGACIÓN FINAL CON CONTEXT EXITOSA');
        }
      } catch (e) {
        print('🔥 [SAFE_NAV] 💥 ERROR FINAL: $e');
      }
    });
  }
  
  print('🔥 [SAFE_NAV] === FIN NAVEGACIÓN ULTRA-ROBUSTA ===');
}
