// lib/notifications_nav.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String _abs(String r) => r.startsWith('/') ? r : '/';

String routeFor(Map<String, dynamic> d) {
  print('[NAV] data=$d');
  
  final navigationData = d['data'];
  final navigationPath = (navigationData?['route'] ?? d['route'])?.toString();
  if (navigationPath != null && navigationPath.isNotEmpty) {
    // 🧭 DEBUGGING: Parsing de la ruta
    print('🧭 routeFor(raw): $navigationPath');
    final parsed = Uri.tryParse(navigationPath);
    if (parsed != null) {
      print('🧭 routeFor(parsed): path=${parsed.path} query=${parsed.query}');
      print('🧭 params(helperId)=${parsed.queryParameters['helperId']} requesterId=${parsed.queryParameters['requesterId']}');
    }
    print('[NAV] resolved route=$navigationPath (direct path)');
    return _abs(navigationPath);
  }

  final type = (d['type'] ?? '').toString();
  final data = d['data'] ?? d;
  print('[NAV] type=$type, processing switch...');
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
    // debe llevar a la pantalla de detalles de la solicitud (/request/:requestId).
    case 'offer_received':
      final requestId = data['requestId'] as String?;
      if (requestId != null) {
        return _abs('/request/$requestId'); // Ruta correcta para la pantalla de detalle de solicitud
      }
      break;
      
    case 'rate_requester':
    case 'helper_rated': // Helper was rated, now can rate the requester
      final requestId = data['requestId'] as String?;
      final requesterId = data['requesterId'] as String?;
      final requesterName = data['requesterName'] as String?;
      print('[NAV] rate_requester/helper_rated: requestId=$requestId');
      print('🧭 [RATE_REQUESTER] PARSING: requesterId=$requesterId requesterName=$requesterName');
      if (requestId != null) {
        String route = '/rate-requester/$requestId';
        if (requesterId != null && requesterName != null) {
          route += '?requesterId=$requesterId&requesterName=$requesterName';
        }
        print('🧭 [RATE_REQUESTER] FINAL_ROUTE: $route');
        print('[NAV] resolved route=$route requestId=$requestId as=helper');
        return _abs(route);
      }
      break;
    case 'rate_helper':
    case 'requester_rated': // Requester was rated, now can rate the helper
      final requestId = data['requestId'] as String?;
      final helperId = data['helperId'] as String?;
      final helperName = data['helperName'] as String?;
      print('[NAV] rate_helper/requester_rated: requestId=$requestId');
      print('🧭 [RATE_HELPER] PARSING: helperId=$helperId helperName=$helperName');
      if (requestId != null) {
        String route = '/rate-helper/$requestId';
        if (helperId != null && helperName != null) {
          route += '?helperId=$helperId&helperName=$helperName';
        }
        print('🧭 [RATE_HELPER] FINAL_ROUTE: $route');
        print('[NAV] resolved route=$route requestId=$requestId as=owner');
        return _abs(route);
      }
      break;
    case 'panic_alert':
    case 'general':
      final userId = data['userId'] as String?;
      if (userId != null) return _abs('/user_profile_view/');
      break;
  }

  return '/main';
}

Future<void> openNotificationAndMarkRead(
  BuildContext context,
  dynamic doc,
) async {
  final Map<String, dynamic> data =
      (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
  final target = routeFor(data);
  try {
    await doc.reference.update({'read': true});
  } catch (_) {}
  if (context.mounted) context.go(target);
}
