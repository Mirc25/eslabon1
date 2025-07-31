// lib/router/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart'; // Necesario para IconButton en leading

// Importa todas tus pantallas relevantes
import '../screens/auth_gate.dart';
import '../screens/main_screen.dart';
import '../screens/request_detail_screen.dart';
import '../screens/rate_offer_screen.dart'; // Ya existe, no rate_helper_screen
import '../screens/rate_requester_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/help_history_screen.dart'; // Agregada del paso anterior
import '../screens/ranking_screen.dart'; // Agregada del paso anterior
// ... importa otras pantallas si son parte de tus rutas

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/auth_gate', // La primera ruta al iniciar la app
    routes: [
      GoRoute(
        path: '/auth_gate',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScreen(),
      ),
      // Rutas de autenticación
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // Detalle de Solicitud
      GoRoute(
        path: '/request_detail/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          // request_detail_screen.dart SÓLO acepta requestId
          return RequestDetailScreen(requestId: requestId);
        },
      ),
      // Pantalla de Calificar Oferta (Ayudador)
      GoRoute(
        path: '/rate_offer/:requestId/:helperId', // Ambas IDs como path parameters
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          final helperId = state.pathParameters['helperId']!;
          // rate_offer_screen.dart espera requestId y helperId
          return RateOfferScreen(requestId: requestId, helperId: helperId);
        },
      ),
      // Pantalla de Calificar Solicitante
      GoRoute(
        path: '/rate_requester/:requestId', // requestId como path parameter
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          // rate_requester_screen.dart solo espera requestId. Si necesitas userId,
          // lo puedes extraer de la requestData dentro de la pantalla, o pasarlo como query parameter si es necesario.
          // Por ejemplo: context.go('/rate_requester/$requestId?userId=$otherUserId')
          // Y en RateRequesterScreen: final String? userId = state.uri.queryParameters['userId'];
          return RateRequesterScreen(requestId: requestId);
        },
      ),
      // Pantalla de Notificaciones
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      // Pantalla de Chat
      GoRoute(
        path: '/chat/:requestId', // El ChatScreen usa requestId como chatId
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          // ChatScreen espera requestId
          return ChatScreen(requestId: requestId);
        },
      ),
      // Historial de Ayuda
      GoRoute(
        path: '/help_history',
        builder: (context, state) => const HelpHistoryScreen(),
      ),
      // Ranking de Usuarios
      GoRoute(
        path: '/ranking',
        builder: (context, state) => const RankingScreen(),
      ),
      // ... agrega el resto de tus rutas aquí
    ],
    // Puedes agregar un errorBuilder para rutas no encontradas
    errorBuilder: (context, state) => const MainScreen(), // Redirige a la pantalla principal en caso de error
  );
});