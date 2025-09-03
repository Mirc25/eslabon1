import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importa tus pantallas
import 'package:eslabon_flutter/screens/auth_gate.dart';
import 'package:eslabon_flutter/screens/auth_screen.dart';
import 'package:eslabon_flutter/screens/main_screen.dart';
import 'package:eslabon_flutter/screens/create_request_screen.dart';
import 'package:eslabon_flutter/screens/profile_screen.dart';
import 'package:eslabon_flutter/screens/my_requests_screen.dart';
import 'package:eslabon_flutter/screens/favorites_screen.dart';
import 'package:eslabon_flutter/screens/chat_list_screen.dart';
import 'package:eslabon_flutter/screens/notifications_screen.dart';
import 'package:eslabon_flutter/screens/history_screen.dart';
import 'package:eslabon_flutter/screens/search_users_screen.dart';
import 'package:eslabon_flutter/screens/settings_screen.dart';
import 'package:eslabon_flutter/screens/faq_screen.dart';
import 'package:eslabon_flutter/screens/report_problem_screen.dart';
import 'package:eslabon_flutter/screens/request_detail_screen.dart';
import 'package:eslabon_flutter/screens/chat_screen.dart';
import 'package:eslabon_flutter/screens/rate_helper_screen.dart';
import 'package:eslabon_flutter/screens/rate_requester_screen.dart';
import 'package:eslabon_flutter/screens/ranking_screen.dart';
import 'package:eslabon_flutter/screens/push_notification_test_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'auth_gate',
        builder: (BuildContext context, GoRouterState state) {
          return const AuthGate();
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (BuildContext context, GoRouterState state) {
          return const AuthScreen();
        },
      ),
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (BuildContext context, GoRouterState state) {
          return const MainScreen();
        },
      ),
      GoRoute(
        path: '/create_request',
        name: 'create_request',
        builder: (BuildContext context, GoRouterState state) {
          return const CreateRequestScreen();
        },
      ),
      GoRoute(
        path: '/request_detail/:requestId',
        name: 'request_detail',
        builder: (BuildContext context, GoRouterState state) {
          final String requestId = state.pathParameters['requestId']!;
          final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
          return RequestDetailScreen(
            requestId: requestId,
            requestData: extra,
          );
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (BuildContext context, GoRouterState state) {
          return const ProfileScreen();
        },
      ),
      GoRoute(
        path: '/my_requests',
        name: 'my_requests',
        builder: (BuildContext context, GoRouterState state) {
          return const MyRequestsScreen();
        },
      ),
      GoRoute(
        path: '/favorites',
        name: 'favorites',
        builder: (BuildContext context, GoRouterState state) {
          return const FavoritesScreen();
        },
      ),
      GoRoute(
        path: '/messages',
        name: 'messages',
        builder: (BuildContext context, GoRouterState state) {
          return const ChatListScreen();
        },
      ),
      GoRoute(
        path: '/chat/:chatId',
        name: 'chat_screen',
        builder: (BuildContext context, GoRouterState state) {
          final String chatId = state.pathParameters['chatId']!;
          final Map<String, dynamic> extra = (state.extra as Map<String, dynamic>?) ?? {};
          return ChatScreen(
            chatId: chatId,
            chatPartnerId: extra['chatPartnerId'] as String,
            chatPartnerName: extra['chatPartnerName'] as String,
            chatPartnerAvatar: extra['chatPartnerAvatar'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (BuildContext context, GoRouterState state) {
          return const NotificationsScreen();
        },
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (BuildContext context, GoRouterState state) {
          return const HistoryScreen();
        },
      ),
      GoRoute(
        path: '/search_users',
        name: 'search_users',
        builder: (BuildContext context, GoRouterState state) {
          return const SearchUsersScreen();
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsScreen();
        },
      ),
      GoRoute(
        path: '/faq',
        name: 'faq',
        builder: (BuildContext context, GoRouterState state) {
          return const FAQScreen();
        },
      ),
      GoRoute(
        path: '/report_problem',
        name: 'report_problem',
        builder: (BuildContext context, GoRouterState state) {
          return const ReportProblemScreen();
        },
      ),
      GoRoute(
        path: '/rate-helper/:requestId',
        name: 'rate-helper',
        builder: (BuildContext context, GoRouterState state) {
          final String requestId = state.pathParameters['requestId']!;
          final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
          return RateHelperScreen(
            requestId: requestId,
            helperId: extra?['helperId'] as String? ?? '',
            helperName: extra?['helperName'] as String? ?? 'Ayudador Desconocido',
            requestData: extra?['requestData'] as Map<String, dynamic>?,
          );
        },
      ),
      GoRoute(
        path: '/rate-requester/:requestId',
        name: 'rate-requester',
        builder: (BuildContext context, GoRouterState state) {
          final String requestId = state.pathParameters['requestId']!;
          final Map<String, dynamic>? extra = state.extra as Map<String, dynamic>?;
          return RateRequesterScreen(
            requestId: requestId,
            requesterId: extra?['requesterId'] as String?,
            requesterName: extra?['requesterName'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/ranking',
        name: 'ranking',
        builder: (BuildContext context, GoRouterState state) {
          return const RankingScreen();
        },
      ),
      GoRoute(
        path: '/push-notification-test',
        name: 'push_notification_test',
        builder: (BuildContext context, GoRouterState state) {
          return const PushNotificationTestScreen();
        },
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final bool loggedIn = FirebaseAuth.instance.currentUser != null;
      final bool goingToAuth = state.fullPath == '/login';
      final bool goingToHome = state.fullPath == '/home' || state.fullPath == '/';

      if (!loggedIn && !goingToAuth) {
        return '/login';
      }
      if (loggedIn && goingToHome) {
        return '/main';
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error de Navegación')),
      body: Center(
        child: Text(
          'La ruta "${state.uri.toString()}" no fue encontrada. Error: ${state.error}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    ),
  );
}
