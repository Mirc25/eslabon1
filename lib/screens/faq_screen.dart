// lib/screens/faq_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      showAds: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'help_screen_title'.tr(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFaqItem(
                question: 'about_eslabon_q'.tr(),
                answer: 'about_eslabon_a'.tr(),
              ),
              _buildFaqItem(
                question: 'how_to_request_q'.tr(),
                answer: 'how_to_request_a'.tr(),
              ),
              _buildFaqItem(
                question: 'how_to_offer_q'.tr(),
                answer: 'how_to_offer_a'.tr(),
              ),
              _buildFaqItem(
                question: 'communication_q'.tr(),
                answer: 'communication_a'.tr(),
              ),
              _buildFaqItem(
                question: 'reputation_q'.tr(),
                answer: 'reputation_a'.tr(),
              ),
              _buildFaqItem(
                question: 'security_q'.tr(),
                answer: 'security_a'.tr(),
              ),
              _buildFaqItem(
                question: 'panic_alert_q'.tr(),
                answer: 'panic_alert_a'.tr(),
              ),
              _buildFaqItem(
                question: 'troubleshooting_q'.tr(),
                answer: 'troubleshooting_a'.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
