// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth_gate.dart';
import '../screens/chat_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/main_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/request_detail_screen.dart';
import '../screens/create_request_screen.dart';
import '../screens/rate_requester_screen.dart';
import '../screens/rate_helper_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/auth',
        builder: (BuildContext context, GoRouterState state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const AuthGate(),
      ),
      GoRoute(
        path: '/main',
        builder: (BuildContext context, GoRouterState state) => const MainScreen(),
      ),
      GoRoute(
        name: 'chat_screen',
        path: '/chat/:chatId',
        builder: (BuildContext context, GoRouterState state) {
          final String chatId = state.pathParameters['chatId']!;
          final String chatPartnerId = state.uri.queryParameters['partnerId'] ?? 'unknown';
          final String chatPartnerName = state.uri.queryParameters['partnerName'] ?? 'Usuario';
          final String? chatPartnerAvatar = state.uri.queryParameters['partnerAvatar'];
          return ChatScreen(
            chatId: chatId,
            chatPartnerId: chatPartnerId,
            chatPartnerName: chatPartnerName,
            chatPartnerAvatar: chatPartnerAvatar,
          );
        },
      ),
      // Ruta para el chat global
      GoRoute(
        name: 'global_chat',
        path: '/global_chat',
        builder: (BuildContext context, GoRouterState state) {
          return const ChatScreen(
            chatId: 'global_chat',
            chatPartnerId: 'global',
            chatPartnerName: 'Chat Global',
            chatPartnerAvatar: null,
          );
        },
      ),
      // Ruta para la pantalla de mensajes/chats
      GoRoute(
        path: '/messages',
        builder: (BuildContext context, GoRouterState state) => const ChatListScreen(),
      ),
      // Ruta para crear solicitud de ayuda
      GoRoute(
        name: 'create_request',
        path: '/create_request',
        builder: (BuildContext context, GoRouterState state) => const CreateRequestScreen(),
      ),
      // Ruta agregada para la pantalla de notificaciones
      GoRoute(
        path: '/notifications',
        builder: (BuildContext context, GoRouterState state) => const NotificationsScreen(),
      ),
      // Ruta para la pantalla de detalles de solicitud
      GoRoute(
        name: 'request_detail',
        path: '/request/:requestId',
        builder: (BuildContext context, GoRouterState state) {
          final String requestId = state.pathParameters['requestId']!;
          final Map<String, dynamic>? requestData = state.extra as Map<String, dynamic>?;
          return RequestDetailScreen(
            requestId: requestId,
            requestData: requestData,
          );
        },
      ),
      // Ruta para calificar al solicitante
      GoRoute(
        name: 'rate_requester',
        path: '/rate-requester/:requestId',
        builder: (BuildContext context, GoRouterState state) {
          final String requestId = state.pathParameters['requestId']!;
          final String? requesterId = state.uri.queryParameters['requesterId'];
          final String? requesterName = state.uri.queryParameters['requesterName'];
          
          print('🔍 [ROUTER] === RATE_REQUESTER ROUTE DEBUGGING ===');
          print('🔍 [ROUTER] Full URI: ${state.uri}');
          print('🔍 [ROUTER] Path parameters: ${state.pathParameters}');
          print('🔍 [ROUTER] Query parameters: ${state.uri.queryParameters}');
          print('🔍 [ROUTER] Extracted requestId: $requestId');
          print('🔍 [ROUTER] Extracted requesterId: $requesterId');
          print('🔍 [ROUTER] Extracted requesterName: $requesterName');
          print('🔍 [ROUTER] === END RATE_REQUESTER ROUTE DEBUGGING ===');
          
          return RateRequesterScreen(
            requestId: requestId,
            requesterId: requesterId,
            requesterName: requesterName,
          );
        },
      ),
      // Ruta para calificar al ayudador
      GoRoute(
        name: 'rate_helper',
        path: '/rate-helper/:requestId',
        builder: (BuildContext context, GoRouterState state) {
          final String requestId = state.pathParameters['requestId']!;
          final String? helperId = state.uri.queryParameters['helperId'];
          final String? helperName = state.uri.queryParameters['helperName'];
          
          print('🔍 [ROUTER] === RATE_HELPER ROUTE DEBUGGING ===');
          print('🔍 [ROUTER] Full URI: ${state.uri}');
          print('🔍 [ROUTER] Path parameters: ${state.pathParameters}');
          print('🔍 [ROUTER] Query parameters: ${state.uri.queryParameters}');
          print('🔍 [ROUTER] Extracted requestId: $requestId');
          print('🔍 [ROUTER] Extracted helperId: $helperId');
          print('🔍 [ROUTER] Extracted helperName: $helperName');
          print('🔍 [ROUTER] === END RATE_HELPER ROUTE DEBUGGING ===');
          
          return RateHelperScreen(
            requestId: requestId,
            helperId: helperId ?? '',
            helperName: helperName ?? 'Ayudador',
          );
        },
      ),
    ],
  );
}