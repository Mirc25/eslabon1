// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart' as ul;
import 'package:go_router/go_router.dart';

const _amber = Color(0xFFFFC107);
const _green = Color(0xFF4CAF50);

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
  });

  Future<void> _contact() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'pablooviedo58@gmail.com',
    );
    if (await ul.canLaunchUrl(uri)) {
      await ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/eslabon_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.6))),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _LanguageSwitcher(),
                        ],
                      ),
                      const Spacer(),
                      Image.asset('assets/logo.png', height: 120),
                      const SizedBox(height: 16),
                      Text(
                        'made_in_argentina'.tr(),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'powered_by'.tr(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      _OutlinedButton(label: 'login'.tr(), onPressed: () => context.go('/login')),
                      const SizedBox(height: 12),
                      _OutlinedButton(label: 'register'.tr(), onPressed: () => context.go('/register')),
                      const Spacer(),
                      TextButton(
                        onPressed: _contact,
                        child: Text(
                          'contact_us'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _amber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Opacity(
                        opacity: 0.5,
                        child: Text('v1.0.0.1',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSwitcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final current = context.locale;
    return DropdownButtonHideUnderline(
      child: DropdownButton<Locale>(
        value: current,
        dropdownColor: Colors.black,
        iconEnabledColor: Colors.white70,
        items: [
          DropdownMenuItem(value: const Locale('es'), child: Text('spanish'.tr())),
          DropdownMenuItem(value: const Locale('en'), child: Text('english'.tr())),
        ],
        onChanged: (loc) async {
          if (loc != null) await context.setLocale(loc);
        },
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _amber, width: 2),
          foregroundColor: _amber,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.black.withOpacity(0.4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
