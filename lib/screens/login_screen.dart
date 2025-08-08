// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

const _amber = Color(0xFFFFC107);
const _green = Color(0xFF4CAF50);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final user = cred.user;
      if (user == null) {
        _showError('Ocurrió un error al iniciar sesión.'.tr());
        return;
      }

      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed != null && !refreshed.emailVerified) {
        _showUnverifiedDialog();
        return;
      }

      if (!mounted) return;
      context.go('/main');
    } on FirebaseAuthException catch (e) {
      final msg = _mapAuthError(e.code, e.message);
      _showError(msg);
    } catch (e) {
      _showError('Ocurrió un error al iniciar sesión.'.tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(String code, String? message) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.'.tr();
      case 'wrong-password':
        return 'Contraseña incorrecta.'.tr();
      case 'invalid-email':
        return 'El correo electrónico no es válido.'.tr();
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.'.tr();
      default:
        return (message ?? 'Error desconocido').tr();
    }
  }

  void _showError(String text) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Center(child: Image.asset('assets/logo.png', height: 56)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('close'.tr(), style: const TextStyle(color: _amber)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnverifiedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('unverified_email_title'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'unverified_email_body'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final user = _auth.currentUser;
              try {
                await user?.sendEmailVerification();
                if (!mounted) return;
                Navigator.of(context).pop();
                _showError('Se envió un correo de verificación.'.tr());
              } catch (_) {
                if (!mounted) return;
                _showError('No se pudo reenviar el correo. Intenta más tarde.'.tr());
              }
            },
            child: Text('resend_verification'.tr(), style: const TextStyle(color: _amber)),
          ),
          TextButton(
            onPressed: () async {
              final mailto = Uri(scheme: 'mailto');
              if (await ul.canLaunchUrl(mailto)) {
                await ul.launchUrl(mailto, mode: ul.LaunchMode.externalApplication);
              }
            },
            child: Text('open_email_app'.tr(), style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('close'.tr(), style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showError('Introduce un email válido para recuperar tu contraseña.'.tr());
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showError('Te enviamos un correo para restablecer tu contraseña.'.tr());
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'user-not-found'
          ? 'No existe una cuenta con ese correo.'.tr()
          : _mapAuthError(e.code, e.message);
      _showError(msg);
    } catch (_) {
      _showError('No se pudo enviar el correo. Intenta más tarde.'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/eslabon_background.png', fit: BoxFit.cover),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.6))),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: () => context.go('/'),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            tooltip: 'back'.tr(),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Image.asset('assets/logo.png', height: 120),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _TextField(
                              controller: _emailCtrl,
                              label: 'email'.tr(),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Este campo es obligatorio'.tr();
                                }
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                                  return 'El correo electrónico no es válido.'.tr();
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _PasswordField(
                              controller: _passCtrl,
                              label: 'password'.tr(),
                              obscure: _obscure,
                              onToggle: () => setState(() => _obscure = !_obscure),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Este campo es obligatorio'.tr();
                                if (v.length < 6) return 'La contraseña debe tener al menos 6 caracteres'.tr();
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : _sendPasswordReset,
                                child: Text('Olvidaste tu contraseña?'.tr(),
                                    style: const TextStyle(color: _amber)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.black.withOpacity(0.4),
                                  foregroundColor: _amber,
                                  side: const BorderSide(color: _amber, width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: _amber),
                                      )
                                    : Text('login'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading ? null : () => context.go('/register'),
                        child: Text('register'.tr(),
                            style: const TextStyle(color: _amber, fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
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

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
      ),
      validator: validator,
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: Colors.white70),
          tooltip: obscure ? 'show_password'.tr() : 'hide_password'.tr(),
        ),
      ),
      validator: validator,
    );
  }
}

class _LangQuickSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final current = context.locale;
    final other = current.languageCode == 'es' ? const Locale('en') : const Locale('es');
    final label = current.languageCode == 'es' ? 'EN' : 'ES';

    return TextButton(
      onPressed: () async => context.setLocale(other),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
    );
  }
}