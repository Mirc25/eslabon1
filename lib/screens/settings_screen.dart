// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/custom_background.dart';
import '../widgets/custom_app_bar.dart';
import '../providers/location_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _approximateLocationEnabled = true;
  bool _showPhoneToVerified = false;
  bool _showEmail = false;

  String _selectedLanguage = 'EspaÃ±ol';
  String _selectedSorting = 'MÃ¡s cercanos';
  double _searchRadius = 5.0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _pushNotificationsEnabled = data['pushNotificationsEnabled'] ?? true;
            _emailNotificationsEnabled = data['emailNotificationsEnabled'] ?? true;
            _approximateLocationEnabled = data['approximateLocationEnabled'] ?? true;
            _showPhoneToVerified = data['showPhoneToVerified'] ?? false;
            _showEmail = data['showEmail'] ?? false;
            _selectedLanguage = data['language'] ?? 'EspaÃ±ol';
            _selectedSorting = data['sortingPreference'] ?? 'MÃ¡s cercanos';
            _searchRadius = (data['searchRadius'] as num?)?.toDouble() ?? 5.0;
          });
        }
      }
    } catch (e) {
      print('Error al cargar la configuraciÃ³n del usuario: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserSettings() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    try {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'pushNotificationsEnabled': _pushNotificationsEnabled,
        'emailNotificationsEnabled': _emailNotificationsEnabled,
        'approximateLocationEnabled': _approximateLocationEnabled,
        'showPhoneToVerified': _showPhoneToVerified,
        'showEmail': _showEmail,
        'language': _selectedLanguage,
        'sortingPreference': _selectedSorting,
        'searchRadius': _searchRadius,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ConfiguraciÃ³n guardada con Ã©xito')),
      );
      if (_selectedSorting == 'MÃ¡s cercanos') {
        ref.read(filterScopeProvider.notifier).state = 'Cercano';
        ref.read(proximityRadiusProvider.notifier).state = _searchRadius;
      } else {
         ref.read(filterScopeProvider.notifier).state = _selectedSorting;
      }
    } catch (e) {
      print('Error al guardar la configuraciÃ³n: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar la configuraciÃ³n: $e')),
      );
    }
  }

  Future<void> _changePassword() async {
    final currentUser = _auth.currentUser;
    if (currentUser?.providerData.any((info) => info.providerId == 'password') ?? false) {
      try {
        await _auth.sendPasswordResetEmail(email: currentUser!.email!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se ha enviado un enlace de cambio de contraseÃ±a a tu email.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar el email de cambio de contraseÃ±a: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes cambiar tu contraseÃ±a porque no usaste email y contraseÃ±a para registrarte.')),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'settings'.tr(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SecciÃ³n de Cuenta
                    _buildSectionTitle(context, 'Cuenta'.tr()),
                    if (_auth.currentUser?.providerData.any((info) => info.providerId == 'password') ?? false)
                      _buildSettingsTile(
                        title: 'change_password'.tr(),
                        icon: Icons.lock,
                        onTap: _changePassword,
                      ),

                    // SecciÃ³n de Preferencias
                    _buildSectionTitle(context, 'preferences'.tr()),
                    SwitchListTile(
                      title: Text('activate_push'.tr(), style: TextStyle(color: Colors.white)),
                      value: _pushNotificationsEnabled,
                      onChanged: (bool value) => setState(() => _pushNotificationsEnabled = value),
                      activeColor: Colors.amber,
                      tileColor: Colors.grey[850],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text('activate_email'.tr(), style: TextStyle(color: Colors.white)),
                      value: _emailNotificationsEnabled,
                      onChanged: (bool value) => setState(() => _emailNotificationsEnabled = value),
                      activeColor: Colors.amber,
                      tileColor: Colors.grey[850],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(height: 8),
                    // Cambiar el idioma
                    _buildSettingsTile(
                      title: 'change_language'.tr(),
                      icon: Icons.language,
                      trailing: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          dropdownColor: Colors.black,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedLanguage = newValue;
                                if (newValue == 'EspaÃ±ol') {
                                  context.setLocale(const Locale('es'));
                                } else if (newValue == 'InglÃ©s') {
                                  context.setLocale(const Locale('en'));
                                }
                              });
                            }
                          },
                          items: ['EspaÃ±ol', 'InglÃ©s']
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value.tr()),
                            );
                          }).toList(),
                        ),
                      ),
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),

                    // SecciÃ³n de Privacidad
                    _buildSectionTitle(context, 'privacy'.tr()),
                    SwitchListTile(
                      title: Text('approximate_location'.tr(), style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Muestra tu ubicaciÃ³n en las solicitudes que publiques.', style: TextStyle(color: Colors.white70)),
                      value: _approximateLocationEnabled,
                      onChanged: (bool value) => setState(() => _approximateLocationEnabled = value),
                      activeColor: Colors.amber,
                      tileColor: Colors.grey[850],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text('show_phone_verified_users'.tr(), style: TextStyle(color: Colors.white)),
                      value: _showPhoneToVerified,
                      onChanged: (bool value) => setState(() => _showPhoneToVerified = value),
                      activeColor: Colors.amber,
                      tileColor: Colors.grey[850],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text('show_email'.tr(), style: TextStyle(color: Colors.white)),
                      value: _showEmail,
                      onChanged: (bool value) => setState(() => _showEmail = value),
                      activeColor: Colors.amber,
                      tileColor: Colors.grey[850],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    const SizedBox(height: 24),

                    // SecciÃ³n de ConfiguraciÃ³n avanzada
                    _buildSectionTitle(context, 'advanced_settings'.tr()),
                    _buildSettingsTile(
                      title: 'default_search_radius'.tr(),
                      icon: Icons.map,
                      subtitle: Text('current_radius'.tr() + ' ${_searchRadius.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white70)),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) {
                            return StatefulBuilder(
                              builder: (BuildContext context, StateSetter setState) {
                                return Container(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('select_search_radius'.tr(), style: Theme.of(context).textTheme.titleLarge),
                                      Slider(
                                        value: _searchRadius,
                                        min: 1.0,
                                        max: 100.0,
                                        divisions: 99,
                                        label: '${_searchRadius.toStringAsFixed(1)} km',
                                        onChanged: (newValue) {
                                          setState(() {
                                            _searchRadius = newValue;
                                          });
                                        },
                                      ),
                                      Text('Radio: ${_searchRadius.toStringAsFixed(1)} km'),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text('accept'.tr()),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsTile(
                      title: 'request_priority'.tr(),
                      icon: Icons.sort,
                      subtitle: Text('current_order'.tr() + ' $_selectedSorting', style: const TextStyle(color: Colors.white70)),
                      onTap: () {
                        // LÃ³gica para cambiar la prioridad
                      },
                    ),
                    const SizedBox(height: 24),

                    // SecciÃ³n de Sobre la app
                    _buildSectionTitle(context, 'about_app'.tr()),
                    _buildSettingsTile(
                      title: 'app_version'.tr(),
                      icon: Icons.info_outline,
                      trailing: const Text('1.0.0', style: TextStyle(color: Colors.white70)),
                      onTap: () {},
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsTile(
                      title: 'terms_and_conditions'.tr(),
                      icon: Icons.description,
                      onTap: () => context.push('/terms_and_conditions'),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsTile(
                      title: 'privacy_policy'.tr(),
                      icon: Icons.privacy_tip,
                      onTap: () => _launchUrl('https://www.google.com/'),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsTile(
                      title: 'rate_on_play_store'.tr(),
                      icon: Icons.star_rate,
                      onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.eslabon_flutter'),
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsTile(
                      title: 'send_feedback'.tr(),
                      icon: Icons.feedback,
                      onTap: () {
                        context.push('/report_problem');
                      },
                    ),
                    const SizedBox(height: 24),

                    // BotÃ³n para guardar cambios
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveUserSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('save_changes'.tr()),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    IconData? icon,
    Widget? trailing,
    VoidCallback? onTap,
    Widget? subtitle,
  }) {
    return Card(
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: icon != null ? Icon(icon, color: Colors.white70) : null,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: subtitle,
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        onTap: onTap,
      ),
    );
  }
}
