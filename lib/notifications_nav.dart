// lib/notifications_nav.dart - SISTEMA DE NAVEGACIÓN MEJORADO
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      
    // FIX CRÍTICO: La notificación 'offer_received' (oferta de ayuda)
    // debe llevar a la pantalla de detalles de la solicitud (/request/:requestId), NO a una pantalla de calificación.
    case 'offer_received':
      final requestId = data['requestId'] as String?;
      print('[NAV] offer_received: requestId=$requestId');
      if (requestId != null) {
        // Ruta corregida a /request/:requestId (Detalles de la solicitud)
        String route = '/request/$requestId';
        print('[NAV] resolved route=$route requestId=$requestId as=requester');
        return _abs(route);
      }
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
  
  // Navegar
  if (context.mounted) {
    print('🧭 [MARK_READ] 🚀 Navegando a: $target');
    context.go(target);
  } else {
    print('🧭 [MARK_READ] ❌ Context no está montado, no se puede navegar');
  }
  
  print('🧭 [MARK_READ] === FIN PROCESAMIENTO DE NOTIFICACIÓN ===');
}