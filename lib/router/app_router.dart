import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:eslabon_flutter/screens/main_screen.dart';
import 'package:eslabon_flutter/screens/notifications_screen.dart';
import 'package:eslabon_flutter/screens/rate_helper_screen.dart';
import 'package:eslabon_flutter/screens/rate_requester_screen.dart';
import 'package:eslabon_flutter/screens/rate_offer_screen.dart';
import 'package:eslabon_flutter/screens/request_detail_screen.dart';
import 'package:eslabon_flutter/screens/create_request_screen.dart';
import 'package:eslabon_flutter/screens/login_screen.dart';
import 'package:eslabon_flutter/screens/auth_gate.dart';
import 'package:eslabon_flutter/screens/home_screen.dart';
import 'package:eslabon_flutter/screens/register_screen.dart';
import 'package:eslabon_flutter/screens/my_requests_screen.dart';
import 'package:eslabon_flutter/screens/favorites_screen.dart';
import 'package:eslabon_flutter/screens/chat_list_screen.dart';
import 'package:eslabon_flutter/screens/chat_screen.dart';
import 'package:eslabon_flutter/screens/history_screen.dart';
import 'package:eslabon_flutter/screens/search_users_screen.dart';
import 'package:eslabon_flutter/screens/settings_screen.dart';
import 'package:eslabon_flutter/screens/faq_screen.dart';
import 'package:eslabon_flutter/screens/report_problem_screen.dart';
import 'package:eslabon_flutter/screens/profile_screen.dart';


class AppRouter {
  static final GoRouter router = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/',

    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const AuthGate();
        },
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) {
          return const RegisterScreen();
        },
      ),
      GoRoute(
        path: '/home',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen();
        },
      ),
      GoRoute(
        path: '/main',
        builder: (BuildContext context, GoRouterState state) {
          return const MainScreen();
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (BuildContext context, GoRouterState state) {
          return const NotificationsScreen();
        },
      ),
      GoRoute(
        path: '/rate-helper/:requestId', // ✅ RUTA: Para que el solicitante califique al ayudador
        name: 'rate-helper', // ✅ Nombre de la ruta
        builder: (BuildContext context, GoRouterState state) {
          final String? requestId = state.pathParameters['requestId'];
          final Map<String, dynamic>? extraData = state.extra as Map<String, dynamic>?;

          final String? helperId = extraData?['helperId'] as String?;
          final String? helperName = extraData?['helperName'] as String?;
          final Map<String, dynamic>? requestData = extraData?['requestData'] as Map<String, dynamic>?;

          debugPrint('DEBUG ROUTER /rate-helper: requestId: $requestId');
          debugPrint('DEBUG ROUTER /rate-helper: extraData: $extraData');
          debugPrint('DEBUG ROUTER /rate-helper: helperId: $helperId');
          debugPrint('DEBUG ROUTER /rate-helper: helperName: $helperName');
          debugPrint('DEBUG ROUTER /rate-helper: requestData: $requestData');


          if (requestId == null || helperId == null || helperName == null) {
            debugPrint('DEBUG ROUTER /rate-helper: Datos incompletos, mostrando error.');
            return Scaffold(
              appBar: AppBar(title: const Text('Error de Calificación')),
              body: const Center(
                child: Text(
                  'Datos incompletos para calificar al ayudante. ID de solicitud, ayudante o nombre faltantes.',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
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
        path: '/rate-requester/:requestId', // ✅ RUTA: Para que el ayudador califique al solicitante
        name: 'rate-requester', // ✅ Nombre de la ruta
        builder: (BuildContext context, GoRouterState state) {
          final String? requestId = state.pathParameters['requestId'];
          final Map<String, dynamic>? extraData = state.extra as Map<String, dynamic>?;
          final String? requesterId = extraData?['requesterId'] as String?;
          final String? requesterName = extraData?['requesterName'] as String?;

          debugPrint('DEBUG ROUTER /rate-requester: requestId: $requestId');
          debugPrint('DEBUG ROUTER /rate-requester: extraData: $extraData');
          debugPrint('DEBUG ROUTER /rate-requester: requesterId: $requesterId');
          debugPrint('DEBUG ROUTER /rate-requester: requesterName: $requesterName');


          if (requestId == null || requesterId == null || requesterName == null) {
             debugPrint('DEBUG ROUTER /rate-requester: Datos incompletos, mostrando error.');
             return Scaffold(
              appBar: AppBar(title: const Text('Error de Calificación')),
              body: const Center(
                child: Text(
                  'Datos incompletos para calificar al solicitante. ID de solicitud, solicitante o nombre faltantes.',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RateRequesterScreen(
            requestId: requestId,
          );
        },
      ),
      GoRoute(
        path: '/rate-offer/:requestId/:helperId', // ✅ RUTA: Para calificar una oferta (Ayudador)
        name: 'rate-offer', // ✅ Nombre de la ruta
        builder: (BuildContext context, GoRouterState state) {
          final String? requestId = state.pathParameters['requestId'];
          final String? helperId = state.pathParameters['helperId'];
          final Map<String, dynamic>? requestData = state.extra as Map<String, dynamic>?;

          debugPrint('DEBUG ROUTER /rate-offer: requestId: $requestId');
          debugPrint('DEBUG ROUTER /rate-offer: helperId: $helperId');
          debugPrint('DEBUG ROUTER /rate-offer: requestData: $requestData');

          if (requestId == null || helperId == null) {
            debugPrint('DEBUG ROUTER /rate-offer: Datos incompletos, mostrando error.');
            return const Center(child: Text('Error: IDs de solicitud o ayudante faltantes.'));
          }

          return RateOfferScreen(
            requestId: requestId,
            helperId: helperId,
            requestData: requestData,
          );
        },
      ),
      GoRoute(
        path: '/request_detail/:requestId',
        name: 'request_detail',
        builder: (BuildContext context, GoRouterState state) {
          final String? requestId = state.pathParameters['requestId'];
          final Map<String, dynamic>? requestData = state.extra as Map<String, dynamic>?;
          if (requestId == null) {
            return const Center(child: Text('Error: ID de solicitud faltante.'));
          }
          return RequestDetailScreen(
            requestId: requestId,
            requestData: requestData,
          );
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
        path: '/profile',
        builder: (BuildContext context, GoRouterState state) {
          return const ProfileScreen();
        },
      ),
      GoRoute(
        path: '/my_requests',
        builder: (BuildContext context, GoRouterState state) {
          return const MyRequestsScreen();
        },
      ),
      GoRoute(
        path: '/favorites',
        builder: (BuildContext context, GoRouterState state) {
          return const FavoritesScreen();
        },
      ),
      GoRoute(
        path: '/messages', // Esta es la ruta para ChatListScreen
        builder: (BuildContext context, GoRouterState state) {
          return const ChatListScreen();
        },
      ),
      GoRoute(
        path: '/chat/:chatPartnerId',
        name: 'chat_screen',
        builder: (BuildContext context, GoRouterState state) {
          final String? chatPartnerId = state.pathParameters['chatPartnerId'];
          final Map<String, dynamic>? extraData = state.extra as Map<String, dynamic>?;
          final String? chatPartnerName = extraData?['chatPartnerName'] as String?;

          debugPrint('DEBUG ROUTER /chat: chatPartnerId: $chatPartnerId');
          debugPrint('DEBUG ROUTER /chat: extraData: $extraData');
          debugPrint('DEBUG ROUTER /chat: chatPartnerName: $chatPartnerName');

          if (chatPartnerId == null || chatPartnerName == null) {
            debugPrint('DEBUG ROUTER /chat: Datos incompletos, mostrando error.');
            return Scaffold(
              appBar: AppBar(title: const Text('Error de Chat')),
              body: const Center(
                child: Text(
                  'Datos de chat incompletos. ID o nombre del compañero faltante.',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ChatScreen(
            chatPartnerId: chatPartnerId,
            chatPartnerName: chatPartnerName,
          );
        },
      ),
      GoRoute(
        path: '/history',
        builder: (BuildContext context, GoRouterState state) {
          return const HistoryScreen();
        },
      ),
      GoRoute(
        path: '/search_users',
        builder: (BuildContext context, GoRouterState state) {
          return const SearchUsersScreen();
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsScreen();
        },
      ),
      GoRoute(
        path: '/faq',
        builder: (BuildContext context, GoRouterState state) {
          return const FAQScreen();
        },
      ),
      GoRoute(
        path: '/report_problem',
        builder: (BuildContext context, GoRouterState state) {
          return const ReportProblemScreen();
        },
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final bool loggedIn = FirebaseAuth.instance.currentUser != null;
      final bool goingToLogin = state.fullPath == '/login';
      final bool goingToRegister = state.fullPath == '/register';
      final bool goingToHome = state.fullPath == '/home';
      final bool goingToRoot = state.fullPath == '/';

      if (!loggedIn && !(goingToLogin || goingToRegister || goingToHome || goingToRoot)) {
        return '/login';
      }
      if (loggedIn && (goingToLogin || goingToRegister || goingToHome || goingToRoot)) {
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
