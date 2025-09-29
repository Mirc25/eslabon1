// lib/notifications_nav.dart - SISTEMA DE NAVEGACIÓN MEJORADO
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'router/app_router.dart';

String _abs(String r) => r.startsWith('/') ? r : '/';

String routeFor(Map<String, dynamic> d) {
  print('🧭 [NAV] === INICIO PROCESAMIENTO DE NAVEGACIÓN ===');
  print('🧭 [NAV] Datos completos recibidos: $d');
  
  // 🏆 PRIORIDAD ABSOLUTA: Si es view_ranking, ir directo al ranking sin importar otros datos
  final type = (d['type'] ?? d['notificationType'] ?? '').toString();
  if (type == 'view_ranking') {
    print('🏆 [RANKING] === NOTIFICACIÓN DE RANKING DETECTADA ===');
    print('🏆 [RANKING] FORZANDO NAVEGACIÓN A /ratings?tab=ranking');
    print('🏆 [RANKING] Datos recibidos: $d');
    print('🏆 [RANKING] === NAVEGACIÓN FORZADA AL RANKING ===');
    return _abs('/ratings?tab=ranking');
  }
  
  // Primero intentar obtener la ruta directa desde los datos
  final navigationData = d['data'];
  final directRoute = (navigationData?['route'] ?? d['route'])?.toString();
  
  if (directRoute != null && directRoute.isNotEmpty) {
    print('🧭 [NAV] Ruta directa encontrada: $directRoute');
    final parsed = Uri.tryParse(directRoute);
    if (parsed != null) {
      print('🧭 [NAV] Ruta parseada - path: ${parsed.path}, query: ${parsed.query}');
      print('🧭 [NAV] Parámetros - helperId: ${parsed.queryParameters['helperId']}, requesterId: ${parsed.queryParameters['requesterId']}');
    }
    print('🧭 [NAV] ✅ Usando ruta directa: $directRoute');
    return _abs(directRoute);
  }

  // Si no hay ruta directa, procesar según el tipo
  // final type ya está declarado arriba para el debugging
  final data = d['data'] ?? d;
  
  print('🧭 [NAV] Procesando por tipo: $type');
  print('🧭 [NAV] Datos para procesamiento: $data');
  
  switch (type) {
    case 'chat':
    case 'chat_message':
      final chatId = data['chatRoomId'] ?? data['chatId'] as String?;
      final partnerId = data['chatPartnerId'] ?? data['senderId'] as String?;
      final partnerName = data['chatPartnerName'] ?? data['senderName'] as String?;
      final partnerAvatar = data['senderPhotoUrl'] ?? '';
      if (chatId != null) {
        String route = '/chat/$chatId';
        if (partnerId != null && partnerName != null) {
          route += '?partnerId=$partnerId&partnerName=$partnerName&partnerAvatar=$partnerAvatar';
        }
        return _abs(route);
      }
      break;
      
    case 'offer_received':
      final requestId = data['requestId'] as String?;
      final helperId = data['helperId'] as String?;
      final helperName = data['helperName'] as String?;
      
      print('🧭 [NAV] 🤝 OFFER_RECEIVED - Datos extraídos:');
      print('🧭 [NAV]   - requestId: $requestId');
      print('🧭 [NAV]   - helperId: $helperId');
      print('🧭 [NAV]   - helperName: $helperName');
      print('🧭 [NAV]   - data[route]: ${data['route']}');
      
      // Priorizar ruta embebida desde FCM
      if (data['route'] != null && data['route'].toString().isNotEmpty) {
        final embeddedRoute = data['route'].toString();
        print('🧭 [NAV] ✅ Usando ruta embebida desde FCM: $embeddedRoute');
        return _abs(embeddedRoute);
      }
      
      // Fallback: construir ruta de calificación si tenemos los datos necesarios
      if (requestId != null && helperId != null) {
        String route = '/rate-helper/$requestId?helperId=$helperId';
        if (helperName != null) {
          final encodedName = Uri.encodeComponent(helperName);
          route += '&helperName=$encodedName';
        }
        print('🧭 [NAV] 📝 Fallback a ruta de calificación: $route');
        return _abs(route);
      }
      
      print('🧭 [NAV] ❌ Datos insuficientes para offer_received');
      break;
      
    case 'rate_requester':
    case 'helper_rated': // Helper was rated, now can rate the requester
      final requestId = data['requestId'] as String?;
      final requesterId = data['requesterId'] as String?;
      final requesterName = data['requesterName'] as String?;
      
      print('🧭 [NAV] 📝 RATE_REQUESTER - Datos extraídos:');
      print('🧭 [NAV]   - requestId: $requestId');
      print('🧭 [NAV]   - requesterId: $requesterId');
      print('🧭 [NAV]   - requesterName: $requesterName');
      
      if (requestId != null) {
        String route = '/rate-requester/$requestId';
        if (requesterId != null && requesterName != null) {
          final encodedName = Uri.encodeComponent(requesterName);
          route += '?requesterId=$requesterId&requesterName=$encodedName';
          print('🧭 [NAV] ✅ Ruta completa con parámetros: $route');
        } else {
          print('🧭 [NAV] ⚠️ Faltan parámetros - requesterId: $requesterId, requesterName: $requesterName');
        }
        print('🧭 [NAV] 🎯 NAVEGANDO A: $route');
        return _abs(route);
      } else {
        print('🧭 [NAV] ❌ requestId es null, no se puede navegar');
      }
      break;
      
    case 'rate_helper':
    case 'requester_rated': // Requester was rated, now can rate the helper
      final requestId = data['requestId'] as String?;
      final helperId = data['helperId'] as String?;
      final helperName = data['helperName'] as String?;
      
      print('🧭 [NAV] 🤝 RATE_HELPER - Datos extraídos:');
      print('🧭 [NAV]   - requestId: $requestId');
      print('🧭 [NAV]   - helperId: $helperId');
      print('🧭 [NAV]   - helperName: $helperName');
      
      if (requestId != null) {
        String route = '/rate-helper/$requestId';
        if (helperId != null && helperName != null) {
          final encodedName = Uri.encodeComponent(helperName);
          route += '?helperId=$helperId&helperName=$encodedName';
          print('🧭 [NAV] ✅ Ruta completa con parámetros: $route');
        } else {
          print('🧭 [NAV] ⚠️ Faltan parámetros - helperId: $helperId, helperName: $helperName');
        }
        print('🧭 [NAV] 🎯 NAVEGANDO A: $route');
        return _abs(route);
      } else {
        print('🧭 [NAV] ❌ requestId es null, no se puede navegar');
      }
      break;
    case 'panic_alert':
    case 'general':
      final userId = data['userId'] as String?;
      print('🧭 [NAV] 🚨 PANIC/GENERAL - userId: $userId');
      if (userId != null) {
        print('🧭 [NAV] 🎯 NAVEGANDO A: /user_profile_view/');
        return _abs('/user_profile_view/');
      }
      break;
      
    case 'view_ranking':
      return _abs('/ratings?tab=ranking');
      
    default:
      print('🧭 [NAV] ❓ Tipo de notificación no reconocido: $type');
      print('🧭 [NAV] 📋 Datos disponibles: $data');
      break;
  }

  print('🧭 [NAV] 🏠 No se pudo determinar ruta específica, navegando a /main');
  print('🧭 [NAV] === FIN PROCESAMIENTO DE NAVEGACIÓN ===');
  return '/main';
}

Future<void> openNotificationAndMarkRead(
  BuildContext context,
  dynamic doc,
) async {
  print('🧭 [MARK_READ] === INICIO PROCESAMIENTO DE NOTIFICACIÓN ===');
  
  try {
    final Map<String, dynamic> data =
        (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    
    print('🧭 [MARK_READ] Datos de notificación: $data');
    
    final target = routeFor(data);
    print('🧭 [MARK_READ] Ruta objetivo determinada: $target');
    
    // Marcar como leída
    try {
      await doc.reference.update({'read': true});
      print('🧭 [MARK_READ] ✅ Notificación marcada como leída');
    } catch (e) {
      print('🧭 [MARK_READ] ⚠️ Error al marcar como leída: $e');
    }
    
    // 🛡️ NAVEGACIÓN SEGURA CON MÚLTIPLES CAPAS DE PROTECCIÓN
    _safeNavigateFromNotification(context, target);
    
  } catch (e) {
    print('🧭 [MARK_READ] ❌ ERROR CRÍTICO en procesamiento: $e');
    // Fallback seguro: ir a home
    _safeNavigateFromNotification(context, '/main');
  }
  
  print('🧭 [MARK_READ] === FIN PROCESAMIENTO DE NOTIFICACIÓN ===');
}

// 🛡️ FUNCIÓN DE NAVEGACIÓN ULTRA-ROBUSTA DESDE NOTIFICACIONES
void _safeNavigateFromNotification(BuildContext context, String target) {
  print('🧭 [SAFE_NAV] === INICIO NAVEGACIÓN ULTRA-ROBUSTA DESDE NOTIFICACIÓN ===');
  print('🧭 [SAFE_NAV] Ruta objetivo: $target');
  
  bool navigationSuccessful = false;
  
  // 🚀 MÉTODO 1: Navegación con context directo
  try {
    if (context.mounted) {
      print('🧭 [SAFE_NAV] 🚀 MÉTODO 1: Context directo');
      context.go(target);
      navigationSuccessful = true;
      print('🧭 [SAFE_NAV] ✅ NAVEGACIÓN CON CONTEXT EXITOSA');
      return; // Salir si fue exitosa
    } else {
      print('🧭 [SAFE_NAV] ⚠️ Context no está montado');
    }
  } catch (e) {
    print('🧭 [SAFE_NAV] ❌ ERROR en navegación con context: $e');
  }
  
  // 🚀 MÉTODO 2: Navegación con GlobalKey del router
  if (!navigationSuccessful) {
    try {
      final navigatorState = AppRouter.navigatorKey.currentState;
      if (navigatorState != null) {
        print('🧭 [SAFE_NAV] 🔑 MÉTODO 2: GlobalKey del router');
        final globalContext = navigatorState.context;
        if (globalContext.mounted) {
          globalContext.go(target);
          navigationSuccessful = true;
          print('🧭 [SAFE_NAV] ✅ NAVEGACIÓN CON GLOBALKEY EXITOSA');
          return; // Salir si fue exitosa
        }
      } else {
        print('🧭 [SAFE_NAV] ⚠️ NavigatorState no disponible');
      }
    } catch (e) {
      print('🧭 [SAFE_NAV] ❌ ERROR en navegación con GlobalKey: $e');
    }
  }
  
  // 🚀 MÉTODO 3: PostFrameCallback con múltiples intentos
  if (!navigationSuccessful) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigationSuccessful) return;
      
      print('🧭 [SAFE_NAV] 🔄 MÉTODO 3: PostFrameCallback');
      
      // Intentar con context original
      try {
        if (context.mounted) {
          context.go(target);
          navigationSuccessful = true;
          print('🧭 [SAFE_NAV] ✅ NAVEGACIÓN POST-FRAME CON CONTEXT EXITOSA');
          return;
        }
      } catch (e) {
        print('🧭 [SAFE_NAV] ❌ ERROR PostFrame con context: $e');
      }
      
      // Intentar con GlobalKey
      try {
        final navigatorState = AppRouter.navigatorKey.currentState;
        if (navigatorState != null) {
          final globalContext = navigatorState.context;
          if (globalContext.mounted) {
            globalContext.go(target);
            navigationSuccessful = true;
            print('🧭 [SAFE_NAV] ✅ NAVEGACIÓN POST-FRAME CON GLOBALKEY EXITOSA');
            return;
          }
        }
      } catch (e) {
        print('🧭 [SAFE_NAV] ❌ ERROR PostFrame con GlobalKey: $e');
      }
      
      // Fallback a home
      try {
        final navigatorState = AppRouter.navigatorKey.currentState;
        if (navigatorState != null) {
          final globalContext = navigatorState.context;
          if (globalContext.mounted) {
            globalContext.go('/main');
            print('🧭 [SAFE_NAV] 🏠 NAVEGACIÓN A HOME EXITOSA (FALLBACK)');
          }
        }
      } catch (e2) {
        print('🧭 [SAFE_NAV] 💥 ERROR CRÍTICO EN FALLBACK: $e2');
      }
    });
  }
  
  // 🚀 MÉTODO 4: Delay con múltiples intentos
  if (!navigationSuccessful) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (navigationSuccessful) return;
      
      print('🧭 [SAFE_NAV] ⏰ MÉTODO 4: Navegación con delay');
      
      // Intentar con GlobalKey
      try {
        final navigatorState = AppRouter.navigatorKey.currentState;
        if (navigatorState != null) {
          final globalContext = navigatorState.context;
          if (globalContext.mounted) {
            globalContext.go(target);
            print('🧭 [SAFE_NAV] ✅ NAVEGACIÓN CON DELAY EXITOSA');
            return;
          }
        }
      } catch (e) {
        print('🧭 [SAFE_NAV] ❌ ERROR en navegación con delay: $e');
      }
      
      // Último intento con context original
      try {
        if (context.mounted) {
          context.go(target);
          print('🧭 [SAFE_NAV] ✅ NAVEGACIÓN FINAL CON CONTEXT EXITOSA');
        }
      } catch (e) {
        print('🧭 [SAFE_NAV] 💥 ERROR FINAL: $e');
      }
    });
  }
  
  print('🧭 [SAFE_NAV] === FIN NAVEGACIÓN ULTRA-ROBUSTA DESDE NOTIFICACIÓN ===');
}