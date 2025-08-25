// lib/screens/ratings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import 'my_ratings_section.dart';
import 'ranking_section.dart';

class RatingsScreen extends ConsumerStatefulWidget {
  const RatingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends ConsumerState<RatingsScreen> {
  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(
            title: 'my_ratings_title'.tr(),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/main');
                }
              },
            ),
          ),
          body: Column(
            children: [
              TabBar(
                indicatorColor: Colors.amber,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: 'my_ratings_tab'.tr()),
                  Tab(text: 'ranking_tab'.tr()),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    MyRatingsSection(),
                    RankingSection(),
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
