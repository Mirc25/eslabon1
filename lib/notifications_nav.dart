// lib/notifications_nav.dart - SISTEMA DE NAVEGACIÓN MEJORADO
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- IMPORTADO
import 'package:firebase_auth/firebase_auth.dart';     // <--- IMPORTADO
import 'router/app_router.dart';

String _abs(String r) => r.startsWith('/') ? r : '/';

// Helper function to safely extract properties from the main map or the nested navigationData map
dynamic _getProp(Map<String, dynamic> data, String key) {
  final nestedData = data['navigationData'] as Map<String, dynamic>?;
  return data[key] ?? nestedData?[key];
}

String routeFor(Map<String, dynamic> d) {
  print('🧭 [NAV] === INICIO PROCESAMIENTO DE NAVEGACIÓN ===');
  print('🧭 [NAV] Datos completos recibidos: $d');
  
  final baseData = d['data'] as Map<String, dynamic>? ?? d;
  final type = (baseData['type'] ?? baseData['notificationType'] ?? '').toString();
  
  if (type == 'view_ranking') {
    print('🏆 [RANKING] === NOTIFICACIÓN DE RANKING DETECTADA ===');
    return _abs('/ratings?tab=ranking');
  }
  
  // Primero intentar obtener la ruta directa desde los datos
  final directRoute = (_getProp(baseData, 'route'))?.toString();
  
  if (directRoute != null && directRoute.isNotEmpty) {
    print('🧭 [NAV] ✅ Usando ruta directa: $directRoute');
    return _abs(directRoute);
  }

  print('🧭 [NAV] Procesando por tipo: $type');
  
  dynamic _extract(String key) => _getProp(baseData, key);

  switch (type) {
    case 'chat':
    case 'chat_message':
      final chatId = _extract('chatRoomId') as String? ?? _extract('chatId') as String?;
      final partnerId = _extract('chatPartnerId') as String? ?? _extract('senderId') as String?;
      final partnerName = _extract('chatPartnerName') as String? ?? _extract('senderName') as String?;
      final partnerAvatar = _extract('senderPhotoUrl') as String? ?? '';
      
      if (chatId != null) {
        String route = '/chat/$chatId';
        if (partnerId != null && partnerName is String) {
          final encodedName = Uri.encodeComponent(partnerName);
          final encodedAvatar = Uri.encodeComponent(partnerAvatar); 
          route += '?partnerId=$partnerId&partnerName=$encodedName&partnerAvatar=$encodedAvatar';
        }
        return _abs(route);
      }
      break;
      
    case 'offer_received':
      final requestId = _extract('requestId') as String?;
      if (requestId != null) {
        String route = '/request/$requestId';
        print('🧭 [NAV] 📝 Fallback a ruta de detalles de solicitud: $route');
        return _abs(route);
      }
      break;
      
    case 'rate_requester':
    case 'helper_rated': 
      final requestId = _extract('requestId') as String?;
      final requesterId = _extract('requesterId') as String?;
      final requesterName = _extract('requesterName') as String?;
      
      if (requestId != null) {
        String route = '/rate-requester/$requestId';
        if (requesterId != null && requesterName is String) {
          final encodedName = Uri.encodeComponent(requesterName);
          route += '?requesterId=$requesterId&requesterName=$encodedName';
        } else {
          route = '/request/$requestId';
        }
        print('🧭 [NAV] 🎯 NAVEGANDO A: $route');
        return _abs(route);
      }
      break;
      
    case 'rate_helper':
    case 'requester_rated':
      final requestId = _extract('requestId') as String?;
      final helperId = _extract('helperId') as String?;
      final helperName = _extract('helperName') as String?;
      
      if (requestId != null) {
        String route = '/rate-helper/$requestId';
        if (helperId != null && helperName is String) {
          final encodedName = Uri.encodeComponent(helperName);
          route += '?helperId=$helperId&helperName=$encodedName';
        } else {
          route = '/request/$requestId';
        }
        print('🧭 [NAV] 🎯 NAVEGANDO A: $route');
        return _abs(route);
      }
      break;
    
    default:
      break;
  }

  print('🧭 [NAV] 🏠 No se pudo determinar ruta específica, navegando a /main');
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
    
    final String notificationType = (data['data']?['notificationType'] ?? data['type'] ?? '').toString();
    final String requestId = (data['data']?['requestId'] ?? data['requestId'] ?? '').toString();
    
    String target = routeFor(data);
    
    // 🚀 LÓGICA CLAVE: VERIFICAR ESTADO EN VIVO PARA NOTIFICACIONES DE AYUDA PENDIENTES
    if (notificationType == 'offer_received' && requestId.isNotEmpty) {
      print('🧭 [MARK_READ] Detectada notif. de oferta, verificando estado actual en Firestore...');
      final requestDoc = await FirebaseFirestore.instance.collection('solicitudes-de-ayuda').doc(requestId).get();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (requestDoc.exists && currentUser != null) {
        final requestData = requestDoc.data()!;
        final String requestStatus = requestData['estado']?.toString() ?? 'activa';
        final String requestOwnerId = requestData['userId']?.toString() ?? '';

        if (currentUser.uid == requestOwnerId && requestStatus == 'aceptada') {
          // Si la solicitud ya fue aceptada, buscamos si tiene un rating pendiente.
          
          final acceptedOfferSnapshot = await FirebaseFirestore.instance
              .collection('solicitudes-de-ayuda').doc(requestId)
              .collection('offers').where('status', isEqualTo: 'accepted').limit(1).get();

          if (acceptedOfferSnapshot.docs.isNotEmpty) {
            final acceptedOffer = acceptedOfferSnapshot.docs.first.data();
            final helperId = acceptedOffer['helperId']?.toString();
            final helperName = acceptedOffer['helperName']?.toString();

            if (helperId != null && helperName != null) {
                 // 1. Verificar si ya calificó al ayudador (el solicitante)
                 final existingRating = await FirebaseFirestore.instance
                    .collection('ratings')
                    .where('requestId', isEqualTo: requestId)
                    .where('sourceUserId', isEqualTo: currentUser.uid)
                    .where('targetUserId', isEqualTo: helperId)
                    .where('type', isEqualTo: 'helper_rating')
                    .limit(1)
                    .get();

                if (existingRating.docs.isEmpty) {
                     // 🎯 NO ha calificado: Redirigir a la pantalla de calificación
                    target = '/rate-helper/$requestId?helperId=$helperId&helperName=${Uri.encodeComponent(helperName)}';
                    print('🧭 [MARK_READ] 🎯 Redirigiendo a Calificación (estado: aceptada, no calificado)');
                } else {
                     // 🎯 YA calificó: Redirigir al detalle, donde verá el botón 'Finalizar Ayuda'
                    target = '/request/$requestId';
                    print('🧭 [MARK_READ] 🎯 Redirigiendo a Detalle (estado: aceptada, ya calificado)');
                }
            }
          }
        }
      }
    }
    
    // Marcar como leída y navegar (el resto del proceso es el mismo)
    try {
      await doc.reference.update({'read': true});
      print('🧭 [MARK_READ] ✅ Notificación marcada como leída');
    } catch (e) {
      print('🧭 [MARK_READ] ⚠️ Error al marcar como leída: $e');
    }
    
    _safeNavigateFromNotification(context, target);
  } catch (e) {
    print('🧭 [MARK_READ] ❌ ERROR CRÍTICO en procesamiento: $e');
    _safeNavigateFromNotification(context, '/main');
  }
  
  print('🧭 [MARK_READ] === FIN PROCESAMIENTO DE NOTIFICACIÓN ===');
}

// ... _safeNavigateFromNotification se mantiene sin cambios
void _safeNavigateFromNotification(BuildContext context, String target) {
  print('🧭 [SAFE_NAV] === INICIO NAVEGACIÓN ULTRA-ROBUSTA DESDE NOTIFICACIÓN ===');
  print('🧭 [SAFE_NAV] Ruta objetivo: $target');
  
  bool navigationSuccessful = false;
  
  try {
    if (context.mounted) {
      print('🧭 [SAFE_NAV] 🚀 MÉTODO 1: Context directo');
      context.go(target);
      navigationSuccessful = true;
      print('🧭 [SAFE_NAV] ✅ NAVEGACIÓN CON CONTEXT EXITOSA');
      return; 
    } else {
      print('🧭 [SAFE_NAV] ⚠️ Context no está montado');
    }
  } catch (e) {
    print('🧭 [SAFE_NAV] ❌ ERROR en navegación con context: $e');
  }
  
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
          return; 
        }
      } else {
        print('🧭 [SAFE_NAV] ⚠️ NavigatorState no disponible');
      }
    } catch (e) {
      print('🧭 [SAFE_NAV] ❌ ERROR en navegación con GlobalKey: $e');
    }
  }
  
  if (!navigationSuccessful) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigationSuccessful) return;
      
      print('🧭 [SAFE_NAV] 🔄 MÉTODO 3: PostFrameCallback');
      
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
  
  if (!navigationSuccessful) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (navigationSuccessful) return;
      
      print('🧭 [SAFE_NAV] ⏰ MÉTODO 4: Navegación con delay');
      
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