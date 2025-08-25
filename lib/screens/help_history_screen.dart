// lib/screens/help_history_screen.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:eslabon_flutter/widgets/custom_background.dart';
import 'package:eslabon_flutter/widgets/custom_app_bar.dart';

class HelpHistoryScreen extends StatefulWidget {
  const HelpHistoryScreen({super.key});

  @override
  State<HelpHistoryScreen> createState() => _HelpHistoryScreenState();
}

class _HelpHistoryScreenState extends State<HelpHistoryScreen> {
  late final String currentUserId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    currentUserId = user?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      showAds: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'history'.tr(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const SizedBox(height: 8),
              TabBar(
                tabs: [
                  Tab(text: 'as_helper'.tr()),     // “Como ayudante”
                  Tab(text: 'as_requester'.tr()),  // “Como solicitante”
                ],
                isScrollable: false,
                indicatorColor: Colors.greenAccent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    HelpHistoryAsHelper(userId: currentUserId),
                    HelpHistoryAsRequester(userId: currentUserId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---- Tab 1: Historial como ayudante
class HelpHistoryAsHelper extends StatelessWidget {
  final String userId;
  const HelpHistoryAsHelper({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // TODO: Reemplazar por tu lista/stream real de “ayudas brindadas”
    return _EmptyState(
      title: 'as_helper'.tr(),
      subtitle: userId.isEmpty
          ? tr('no_user_logged_in')
          : tr('no_history_yet'),
    );
  }
}

/// ---- Tab 2: Historial como solicitante
class HelpHistoryAsRequester extends StatelessWidget {
  final String userId;
  const HelpHistoryAsRequester({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // TODO: Reemplazar por tu lista/stream real de “ayudas solicitadas”
    return _EmptyState(
      title: 'as_requester'.tr(),
      subtitle: userId.isEmpty
          ? tr('no_user_logged_in')
          : tr('no_history_yet'),
    );
  }
}

/// ---- Widget simple para estado vacío
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

