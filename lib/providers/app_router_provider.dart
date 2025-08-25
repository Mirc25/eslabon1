import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:eslabon_flutter/router/app_router.dart';

final appRouterGoProvider = Provider<GoRouter>((ref) {
  return router; // âœ… CORREGIDO: Referencia al objeto 'router' global.
});
