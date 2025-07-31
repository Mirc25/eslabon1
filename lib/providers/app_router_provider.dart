// lib/providers/app_router_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Importa GoRouter directamente
import '../router/app_router.dart'; // Importa la función createAppRouter

// appRouterProvider ahora provee una instancia de GoRouter
final appRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter(ref);
});