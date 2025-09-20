// lib/notifications_nav.dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String _abs(String r) => r.startsWith('/') ? r : '/';

String routeFor(Map<String, dynamic> d) {
  final navigationData = d['data'];
  final navigationPath = (navigationData?['route'] ?? d['route'])?.toString();
  if (navigationPath != null && navigationPath.isNotEmpty) {
    return _abs(navigationPath);
  }

  final type = (d['type'] ?? '').toString();
  final data = d['data'] ?? d;
  switch (type) {
    case 'chat':
      final chatId = data['chatRoomId'] as String?;
      if (chatId != null) return _abs('/chat/');
      break;
    case 'offer_received':
    case 'rate_requester':
      final requestId = data['requestId'] as String?;
      if (requestId != null) return _abs('/rate-requester/');
      break;
    case 'rate_helper':
      final requestId = data['requestId'] as String?;
      if (requestId != null) return _abs('/rate-helper/');
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
