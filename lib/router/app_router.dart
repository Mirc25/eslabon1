// lib/router/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Necesario para Ref
import 'package:flutter/material.dart'; // Necesario para MaterialPage, etc.

// Importa todas tus pantallas relevantes
import '../screens/auth_gate.dart';
import '../screens/main_screen.dart';
import '../screens/request_detail_screen.dart';
import '../screens/rate_offer_screen.dart';
import '../screens/rate_requester_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/help_history_screen.dart';
import '../screens/ranking_screen.dart';
import '../screens/create_request_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/my_requests_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/search_users_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/faq_screen.dart';
import '../screens/report_problem_screen.dart';

// Función que crea y retorna la instancia de GoRouter
GoRouter createAppRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/auth_gate',
    routes: [
      GoRoute(
        path: '/auth_gate',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/request_detail/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          final requestData = state.extra as Map<String, dynamic>?;
          return RequestDetailScreen(requestId: requestId, requestData: requestData);
        },
      ),
      GoRoute(
        path: '/rate_offer/:requestId/:helperId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          final helperId = state.pathParameters['helperId']!;
          return RateOfferScreen(requestId: requestId, helperId: helperId);
        },
      ),
      GoRoute(
        path: '/rate_requester/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          return RateRequesterScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/chat/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          return ChatScreen(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/help_history',
        builder: (context, state) => const HelpHistoryScreen(),
      ),
      GoRoute(
        path: '/ranking',
        builder: (context, state) => const RankingScreen(),
      ),
      GoRoute(
        path: '/create_request',
        builder: (context, state) => const CreateRequestScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/my_requests',
        builder: (context, state) => const MyRequestsScreen(),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/chat_list',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/search_users',
        builder: (context, state) => const SearchUsersScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/faq',
        builder: (context, state) => const FaqScreen(),
      ),
      GoRoute(
        path: '/report_problem',
        builder: (context, state) => const ReportProblemScreen(),
      ),
    ],
    errorBuilder: (context, state) => const MainScreen(),
  );
}