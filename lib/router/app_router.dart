import 'package:eslabon_flutter/screens/login_screen.dart';
import 'package:eslabon_flutter/screens/main_screen.dart'; // Importar MainScreen
import 'package:eslabon_flutter/screens/rate_helper_screen.dart';
import 'package:eslabon_flutter/screens/rate_offer_screen.dart';
import 'package:eslabon_flutter/screens/rate_requester_screen.dart';
import 'package:eslabon_flutter/screens/request_detail_screen.dart';
import 'package:eslabon_flutter/screens/notifications_screen.dart';
import 'package:eslabon_flutter/screens/create_request_screen.dart';
import 'package:eslabon_flutter/screens/profile_screen.dart';
import 'package:eslabon_flutter/screens/my_requests_screen.dart';
import 'package:eslabon_flutter/screens/favorites_screen.dart';
import 'package:eslabon_flutter/screens/chat_list_screen.dart';
import 'package:eslabon_flutter/screens/chat_screen.dart';
import 'package:eslabon_flutter/screens/history_screen.dart';
import 'package:eslabon_flutter/screens/search_users_screen.dart';
import 'package:eslabon_flutter/screens/settings_screen.dart';
import 'package:eslabon_flutter/screens/faq_screen.dart';
import 'package:eslabon_flutter/screens/report_problem_screen.dart';
import 'package:eslabon_flutter/screens/home_screen.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ CORRECCIÓN: GoRouter como variable global de nivel superior
final GoRouter router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  redirect: (context, state) {
    final bool loggedIn = FirebaseAuth.instance.currentUser != null;
    final bool isAuthPath = state.matchedLocation == '/login' || state.matchedLocation == '/';

    if (!loggedIn) {
      return isAuthPath ? null : '/';
    } else {
      if (isAuthPath) {
        return '/main';
      }
      return null;
    }
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/main', builder: (context, state) => MainScreen()), // ✅ CORRECCIÓN: MainScreen() sin 'const'
    GoRoute(path: '/create_request', builder: (context, state) => const CreateRequestScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/my_requests', builder: (context, state) => const MyRequestsScreen()),
    GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen()),
    GoRoute(path: '/messages', builder: (context, state) => const ChatListScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()), // ✅ CORRECCIÓN: const NotificationsScreen()
    GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),
    GoRoute(path: '/search_users', builder: (context, state) => const SearchUsersScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/faq', builder: (context, state) => const FAQScreen()),
    GoRoute(path: '/report_problem', builder: (context, state) => const ReportProblemScreen()),
    GoRoute(
      path: '/request_detail/:requestId',
      builder: (context, state) {
        final requestId = state.pathParameters['requestId']!;
        final requestData = state.extra as Map<String, dynamic>?;
        return RequestDetailScreen(requestId: requestId, requestData: requestData ?? {});
      },
    ),
    GoRoute(
      path: '/rate-offer/:requestId/:helperId',
      builder: (context, state) {
        final requestId = state.pathParameters['requestId']!;
        final helperId = state.pathParameters['helperId']!;
        final requestData = state.extra as Map<String, dynamic>?;
        return RateOfferScreen(
          requestId: requestId,
          helperId: helperId,
          requestData: requestData,
        );
      },
    ),
    GoRoute(
      path: '/rate-helper/:requestId',
      builder: (context, state) {
        final requestId = state.pathParameters['requestId']!;
        final requestData = state.extra as Map<String, dynamic>?;
        return RateHelperScreen(
          requestId: requestId,
          requestData: requestData,
        );
      },
    ),
    GoRoute(
      path: '/rate-requester/:requestId',
      builder: (context, state) {
        final requestId = state.pathParameters['requestId']!;
        final Map<String, dynamic>? extraData = state.extra as Map<String, dynamic>?;
        final String requesterId = extraData?['requesterId'] ?? '';
        final Map<String, dynamic>? requestData = extraData?['requestData'] as Map<String, dynamic>?;
        return RateRequesterScreen(
          requestId: requestId,
          requesterId: requesterId,
          requestData: requestData,
        );
      },
    ),
    GoRoute(
      path: '/chat/:chatId',
      builder: (context, state) {
        final chatId = state.pathParameters['chatId']!;
        final chatPartnerId = state.extra is Map ? (state.extra as Map)['chatPartnerId'] as String? : null;
        final chatPartnerName = state.extra is Map ? (state.extra as Map)['chatPartnerName'] as String? : null;
        return ChatScreen(
          chatId: chatId,
          chatPartnerId: chatPartnerId,
          chatPartnerName: chatPartnerName,
        );
      },
    ),
  ],
);
