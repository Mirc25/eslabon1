// lib/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:eslabon_flutter/screens/main_screen.dart';
import 'package:eslabon_flutter/screens/create_request_screen.dart';
import 'package:eslabon_flutter/screens/request_detail_screen.dart';
import 'package:eslabon_flutter/screens/notifications_screen.dart';
import 'package:eslabon_flutter/screens/chat_screen.dart';
import 'package:eslabon_flutter/screens/rate_helper_screen.dart';
import 'package:eslabon_flutter/screens/rate_requester_screen.dart';

class AppRouter {
  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const MainScreen();
        },
      ),
      GoRoute(
        path: '/create-request', // Ruta definida con GUION MEDIO
        builder: (BuildContext context, GoRouterState state) {
          return const CreateRequestScreen();
        },
      ),
      GoRoute(
        path: '/request-detail/:id',
        builder: (BuildContext context, GoRouterState state) {
          final requestId = state.pathParameters['id'];
          final Map<String, dynamic>? requestData = state.extra as Map<String, dynamic>?;
          return RequestDetailScreen(
            requestId: requestId!,
            requestData: requestData,
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (BuildContext context, GoRouterState state) {
          return const NotificationsScreen();
        },
      ),
      GoRoute(
        path: '/chat/:chatIdParam',
        builder: (BuildContext context, GoRouterState state) {
          final chatId = state.pathParameters['chatIdParam'];
          final Map<String, dynamic>? extraData = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            chatId: chatId!,
            chatPartnerId: extraData?['chatPartnerId'],
            chatPartnerName: extraData?['chatPartnerName'],
          );
        },
      ),
      GoRoute(
        path: '/rate-helper/:requestId',
        builder: (BuildContext context, GoRouterState state) {
          final requestId = state.pathParameters['requestId'];
          final Map<String, dynamic>? extraData = state.extra as Map<String, dynamic>?;

          final String? helperId = extraData?['helperId'];
          final String? helperName = extraData?['helperName'];
          final Map<String, dynamic>? requestData = extraData?['requestData'];

          if (requestId == null || helperId == null || helperName == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Datos incompletos para calificar al ayudante.')),
            );
          }

          return RateHelperScreen(
            requestId: requestId,
            helperId: helperId,
            helperName: helperName,
            requestData: requestData,
          );
        },
      ),
      GoRoute(
        path: '/rate-requester/:requestId',
        builder: (BuildContext context, GoRouterState state) {
          final requestId = state.pathParameters['requestId'];
          final Map<String, dynamic>? extraData = state.extra as Map<String, dynamic>?;

          final String? requesterId = extraData?['requesterId'];
          final String? requesterName = extraData?['requesterName'];

          if (requestId == null || requesterId == null || requesterName == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Datos incompletos para calificar al solicitante.')),
            );
          }

          return RateRequesterScreen(
            requestId: requestId,
            requesterId: requesterId,
            requesterName: requesterName,
          );
        },
      ),
    ],
  );
}