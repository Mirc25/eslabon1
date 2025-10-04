// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth_gate.dart';
import '../screens/chat_screen.dart';
import '../screens/global_chat_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/main_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/request_detail_screen.dart';
import '../screens/create_request_screen.dart';
import '../screens/rate_requester_screen.dart';
import '../screens/rate_helper_screen.dart';
import '../screens/rating_confirmation_screen.dart';
import '../screens/ratings_screen.dart';
import '../screens/help_history_screen.dart';
import '../screens/user_profile_view_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/my_requests_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/faq_screen.dart';
import '../screens/report_problem_screen.dart';
import '../screens/about_screen.dart';
import '../screens/search_users_screen.dart';

class AppRouter {
  // 🔑 CLAVE GLOBAL DE NAVEGACIÓN PARA ACCESO DESDE CUALQUIER LUGAR
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/auth',
        builder: (BuildContext context, GoRouterState state) => const AuthScreen(),
      ),
      // Rutas explícitas para Login y Registro (usadas por múltiples botones)
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const AuthGate(),
      ),
      GoRoute(
        path: '/main',
        builder: (BuildContext context, GoRouterState state) => const MainScreen(),
      ),
      // Ruta para el perfil propio
      GoRoute(
        path: '/profile',
        builder: (BuildContext context, GoRouterState state) => const ProfileScreen(),
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
          return const GlobalChatScreen();
        },
      ),
      // Ruta para la pantalla de mensajes/chats
      GoRoute(
        path: '/messages',
        builder: (BuildContext context, GoRouterState state) => const ChatListScreen(),
      ),
      // Ruta para "Mis solicitudes"
      GoRoute(
        path: '/my_requests',
        builder: (BuildContext context, GoRouterState state) => const MyRequestsScreen(),
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
            requestId: requestId ?? '',
            requesterId: requesterId ?? '',
            requesterName: requesterName ?? 'Usuario',
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
      // Ruta para confirmación de calificación
      GoRoute(
        name: 'rating_confirmation',
        path: '/rating-confirmation',
        builder: (BuildContext context, GoRouterState state) {
          final Map<String, dynamic> extra = state.extra as Map<String, dynamic>;
          return RatingConfirmationScreen(
            helperName: extra['helperName'] ?? 'Usuario',
            rating: extra['rating'] ?? 5,
            isHelper: extra['isHelper'] ?? true,
          );
        },
      ),
      // (Eliminada) Ruta de pruebas de notificaciones
      // Ruta para el ranking/calificaciones
      GoRoute(
        name: 'ratings',
        path: '/ratings',
        builder: (BuildContext context, GoRouterState state) {
          final String? tab = state.uri.queryParameters['tab'];
          final int initialTabIndex = tab == 'ranking' ? 1 : 0;
          return RatingsScreen(initialTabIndex: initialTabIndex);
        },
      ),
      // Ruta para el historial de ayudas
      GoRoute(
        name: 'history',
        path: '/history',
        builder: (BuildContext context, GoRouterState state) => const HelpHistoryScreen(),
      ),
      // Ruta para ver perfil de usuario
      GoRoute(
        name: 'user_profile_view',
        path: '/user_profile_view/:userId',
        builder: (BuildContext context, GoRouterState state) {
          final String userId = state.pathParameters['userId']!;
          final Map<String, dynamic> extra = state.extra as Map<String, dynamic>? ?? {};
          return UserProfileViewScreen(
            userId: userId,
            userName: extra['userName'] ?? 'Usuario',
            userPhotoUrl: extra['userPhotoUrl'],
            message: extra['message'],
          );
        },
      ),
      // Ruta para configuraciones
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) => const SettingsScreen(),
      ),
      // Ruta para preguntas frecuentes
      GoRoute(
        path: '/faq',
        builder: (BuildContext context, GoRouterState state) => const FAQScreen(),
      ),
      // Ruta para reportar problemas
      GoRoute(
        path: '/report_problem',
        builder: (BuildContext context, GoRouterState state) => const ReportProblemScreen(),
      ),
      // Ruta para información de la aplicación
      GoRoute(
        path: '/about',
        builder: (BuildContext context, GoRouterState state) => const AboutScreen(),
      ),
      // Ruta para búsqueda de usuarios
      GoRoute(
        path: '/search_users',
        builder: (BuildContext context, GoRouterState state) => const SearchUsersScreen(),
      ),
    ],
  );
}