// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/main_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/create_request_screen.dart';
import '../screens/my_requests_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/history_screen.dart';
import '../screens/search_users_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/faq_screen.dart';
import '../screens/report_problem_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/request_detail_screen.dart';
import '../screens/rate_helper_screen.dart';
import '../screens/rate_requester_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/ranking_screen.dart';
import '../screens/user_profile_view_screen.dart';
import '../screens/ratings_screen.dart';
import '../screens/user_rating_details_screen.dart';
import '../screens/global_chat_screen.dart';
import '../screens/auth_gate.dart';
import '../screens/confirm_help_received_screen.dart';
import '../screens/my_offers_screen.dart';
import '../screens/about_screen.dart';
import '../screens/bad_params_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
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
      path: '/main',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/create_request',
      name: 'create_request',
      builder: (context, state) => const CreateRequestScreen(),
    ),
    GoRoute(
      path: '/my_requests',
      builder: (context, state) => const MyRequestsScreen(),
    ),
    GoRoute(
      path: '/messages',
      builder: (context, state) => const ChatListScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
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
      builder: (context, state) => const FAQScreen(),
    ),
    GoRoute(
      path: '/report_problem',
      builder: (context, state) => const ReportProblemScreen(),
    ),
    GoRoute(
      path: '/terms_and_conditions',
      builder: (context, state) => const TermsScreen(),
    ),
    GoRoute(
      path: '/request_detail/:requestId',
      name: 'request_detail',
      builder: (context, state) {
        final requestId = state.pathParameters['requestId'];
        final extraData = state.extra as Map<String, dynamic>?;

        if (requestId == null) {
          return const BadParamsScreen(message: 'request_detail: Falta requestId.');
        }
        return RequestDetailScreen(requestId: requestId, requestData: extraData);
      },
    ),
    GoRoute(
      path: '/rate-helper/:requestId',
      name: 'rate-helper',
      builder: (context, state) {
        final requestId = state.pathParameters['requestId'];
        final extraData = state.extra as Map<String, dynamic>;
        final helperId = extraData['helperId'] as String?;
        final helperName = extraData['helperName'] as String?;
        final requestData = extraData['requestData'] as Map<String, dynamic>?;

        if (requestId == null || helperId == null || helperName == null) {
          return const BadParamsScreen(message: 'rate-helper: Faltan parámetros (requestId, helperId o helperName).');
        }

        return RateHelperScreen(requestId: requestId, helperId: helperId, helperName: helperName, requestData: requestData);
      },
    ),
    GoRoute(
      path: '/rate-requester/:requestId',
      name: 'rate-requester',
      builder: (context, state) {
        final requestId = state.pathParameters['requestId'];
        final extraData = state.extra as Map<String, dynamic>?;
        final requesterId = extraData?['requesterId'] as String?;
        final requesterName = extraData?['requesterName'] as String?;

        if (requestId == null || requesterId == null || requesterName == null) {
          return const BadParamsScreen(message: 'rate-requester: Faltan parámetros (requestId, requesterId o requesterName).');
        }
        return RateRequesterScreen(requestId: requestId, requesterId: requesterId, requesterName: requesterName);
      },
    ),
    GoRoute(
      path: '/chat/:chatId',
      name: 'chat',
      builder: (context, state) {
        final chatId = state.pathParameters['chatId'];
        final extraData = state.extra as Map<String, dynamic>? ?? {};
        final chatPartnerId = extraData['chatPartnerId'] as String?;
        final chatPartnerName = extraData['chatPartnerName'] as String?;
        final chatPartnerAvatar = extraData['chatPartnerAvatar'] as String?;

        if (chatId == null || chatPartnerId == null || chatPartnerName == null) {
          return const BadParamsScreen(message: 'chat: Faltan parámetros (chatId, chatPartnerId o chatPartnerName).');
        }
        return ChatScreen(
          chatId: chatId,
          chatPartnerId: chatPartnerId,
          chatPartnerName: chatPartnerName,
          chatPartnerAvatar: chatPartnerAvatar,
        );
      },
    ),
    GoRoute(
      path: '/ranking',
      builder: (context, state) => const RankingScreen(),
    ),
    GoRoute(
      path: '/user_profile_view/:userId',
      name: 'user_profile_view',
      builder: (context, state) {
        final userId = state.pathParameters['userId'];
        final extraData = state.extra as Map<String, dynamic>?;
        final userName = extraData?['userName'] as String?;
        final userPhotoUrl = extraData?['userPhotoUrl'] as String?;
        final message = extraData?['message'] as String?;

        if (userId == null) {
          return const BadParamsScreen(message: 'user_profile_view: Falta userId.');
        }
        return UserProfileViewScreen(
          userId: userId,
          userName: userName,
          userPhotoUrl: userPhotoUrl,
          message: message,
        );
      },
    ),
    GoRoute(
      path: '/ratings',
      name: 'ratings',
      builder: (context, state) => const RatingsScreen(),
    ),
    GoRoute(
      path: '/user_rating_details/:userId',
      name: 'user_rating_details',
      builder: (context, state) {
        final userId = state.pathParameters['userId'];
        final userName = state.extra as String?;
        if (userId == null) {
          return const BadParamsScreen(message: 'user_rating_details: Falta userId.');
        }
        return UserRatingDetailsScreen(userId: userId, userName: userName);
      },
    ),
    GoRoute(
      path: '/global_chat',
      name: 'global_chat',
      builder: (context, state) => const GlobalChatScreen(),
    ),
    GoRoute(
      path: '/my_offers',
      name: 'my_offers',
      builder: (context, state) => const MyOffersScreen(),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/confirm-help-received',
      name: 'confirm-help-received',
      builder: (context, state) {
        final requestData = state.extra as Map<String, dynamic>?;
        if (requestData == null) {
          return const BadParamsScreen(message: 'confirm-help-received: Falta requestData.');
        }
        return ConfirmHelpReceivedScreen(requestData: requestData);
      },
    ),
  ],
);

final appRouterProvider = Provider<GoRouter>((ref) {
  return router;
});