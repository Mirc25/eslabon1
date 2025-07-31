// lib/providers/app_router_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eslabon_flutter/router/app_router.dart'; // Asegúrate de importar AppRouter

final appRouterProvider = Provider<GoRouter>((ref) => AppRouter(ref));