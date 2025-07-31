// lib/providers/app_router_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return AppRouter.router;
});
