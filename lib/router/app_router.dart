import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:eslabon_flutter/screens/main_screen.dart';
import 'package:eslabon_flutter/screens/notifications_screen.dart';
import 'package:eslabon_flutter/screens/rate_helper_screen.dart';
import 'package:eslabon_flutter/screens/rate_requester_screen.dart';
import 'package:eslabon_flutter/screens/rate_offer_screen.dart';
import 'package:eslabon_flutter/screens/request_detail_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
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
        path: '/rate-helper/:requestId',
        builder: (BuildContext context, GoRouterState state) {
          final String? requestId = state.pathParameters['requestId'];
          return RateHelperScreen(requestId: requestId!); 
        },
      ),
      GoRoute(
        path: '/rate-requester/:requesterId',
        builder: (BuildContext context, GoRouterState state) {
          final String? requesterId = state.pathParameters['requesterId'];
          return RateRequesterScreen(requesterId: requesterId!);
        },
      ),
      GoRoute(
        path: '/rate-offer/:requestId/:helperId',
        builder: (BuildContext context, GoRouterState state) {
          final String? requestId = state.pathParameters['requestId'];
          final String? helperId = state.pathParameters['helperId'];
          return RateOfferScreen(requestId: requestId!, helperId: helperId!);
        },
      ),
      GoRoute(
        path: '/request-detail/:requestId',
        builder: (BuildContext context, GoRouterState state) {
          final String? requestId = state.pathParameters['requestId'];
          return RequestDetailScreen(requestId: requestId!);
        },
      ),
    ],
  );
}