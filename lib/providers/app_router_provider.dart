import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';

final goRouterProvider = Provider<GoRouter>((ref) => AppRouter.router);
