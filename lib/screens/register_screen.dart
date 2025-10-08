// lib/screens/register_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class Country {
  final String code;
  final String name;
  final String? dialCode;

  Country({required this.code, required this.name, this.dialCode});

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      code: json['code'],
      name: json['name'],
      dialCode: json['dial_code'] as String?,
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Country> countries = [];
  List<String> provinces = [];
  Country? selectedCountry;
  String? selectedProvince;
  String? phoneDialCode;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController dniController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;
  List<String> _days = List.generate(31, (i) => (i + 1).toString());
  List<String> _months = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  List<String> _years = List.generate(100, (i) => (DateTime.now().year - i).toString());

  Map<String, dynamic> allProvincesData = {};
  bool _isLoadingAuth = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    dniController.dispose();
    addressController.dispose();
    postalCodeController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationData() async {
    try {
      final String countryData = await rootBundle.loadString('lib/data/countries.json');
      final String provinceData = await rootBundle.loadString('lib/data/provinces.json');

      if (!mounted) return;
      setState(() {
        countries = (json.decode(countryData) as List).map((e) => Country.fromJson(e)).toList();
        allProvincesData = json.decode(provinceData);
      });
    } catch (e) {
      if (!mounted) return;
      print('Error loading data: $e');
      _showErrorDialog('Error al cargar datos de países/provincias. Intenta de nuevo.'.tr());
    }
  }

  void _updateProvincesForCountry(String? countryCode) {
    if (!mounted) return;
    setState(() {
      provinces = List<String>.from(allProvincesData[countryCode] ?? []);
      selectedProvince = null;
      phoneDialCode = countries.firstWhere(
        (country) => country.code == countryCode,
        orElse: () => Country(code: '', name: '', dialCode: null),
      ).dialCode;
    });
  }

  Future<void> _saveFcmTokenForUser(User user) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          // Habilitar push por defecto al registrar/guardar token
          'pushNotificationsEnabled': true,
        }, SetOptions(merge: true));
        debugPrint('✅ Token FCM guardado y push habilitado por defecto: $token');
      } else {
        debugPrint('⚠️ No se pudo obtener el token FCM.');
      }
    } catch (e) {
      debugPrint('❌ Error guardando token FCM: $e');
    }
  }

  DropdownButtonFormField<String> _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dropdownColor: Colors.black,
      iconEnabledColor: Colors.white,
      style: const TextStyle(color: Colors.white),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item.tr()))).toList(),
      onChanged: onChanged,
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Este campo es obligatorio'.tr();
        }
        return null;
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isPassword = false, bool isEmail = false, bool isConfirm = false, TextInputType keyboardType = TextInputType.text, String? customLabelText, String? hintText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: customLabelText ?? label,
          hintText: hintText,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Este campo es obligatorio'.tr();
          }
          if (isEmail && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
            return 'Introduce un email válido'.tr();
          }
          if (isPassword && value.length < 6) {
            return 'La contraseña debe tener al menos 6 caracteres'.tr();
          }
          if (isConfirm && value != passwordController.text) {
            return 'Las contraseñas no coinciden'.tr();
          }
          return null;
        },
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Center(child: Image.asset('assets/logo.png', height: 60)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
                child: Text('close'.tr(), style: const TextStyle(color: Colors.amber)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Por favor, corrige los errores en el formulario para continuar.'.tr());
      return;
    }

    if (selectedCountry == null || selectedProvince == null ||
        _selectedDay == null || _selectedMonth == null || _selectedYear == null) {
      _showErrorDialog('Por favor, completa todos los campos obligatorios del formulario.'.tr());
      return;
    }

    if (_selectedDay != null && _selectedMonth != null && _selectedYear != null) {
      final int day = int.parse(_selectedDay!);
      final int month = int.parse(_selectedMonth!);
      final int year = int.parse(_selectedYear!);

      final DateTime birthDate = DateTime(year, month, day);
      final DateTime today = DateTime.now();
      final int age = today.year - birthDate.year;

      if (age < 18 || (age == 18 && (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)))) {
        _showErrorDialog('Para registrarte debes ser mayor de 18 años.'.tr());
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoadingAuth = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final User? user = userCredential.user;
      if (user != null) {
        await user.sendEmailVerification();

        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'name': nameController.text.trim(),
          'lowercaseName': nameController.text.trim().toLowerCase(),
          'profilePicture': null,
          'country': selectedCountry != null ? {
            'code': selectedCountry!.code,
            'name': selectedCountry!.name,
            'dial_code': selectedCountry!.dialCode,
          } : null,
          'province': selectedProvince,
          'birthDay': int.tryParse(_selectedDay!),
          'birthMonth': int.tryParse(_selectedMonth!),
          'birthYear': int.tryParse(_selectedYear!),
          'phone': '${phoneDialCode ?? ''}${phoneController.text.trim()}',
          'gender': null,
          'dni': dniController.text.trim(),
          'address': addressController.text.trim(),
          'zip': postalCodeController.text.trim(),
          'reputation': 0,
          'helpedCount': 0,
          'receivedHelpCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _saveFcmTokenForUser(user);

        if (!mounted) return;
        _showSuccessDialog(emailController.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Este correo ya está registrado. Por favor, inicia sesión.'.tr();
      } else if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es demasiado débil.'.tr();
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrónico no es válido.'.tr();
      } else {
        errorMessage = 'Error al registrar: ${e.message}'.tr();
      }
      if (!mounted) return;
      _showErrorDialog(errorMessage);
      print("Firebase Auth Error: ${e.code} - ${e.message}");
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Ocurrió un error inesperado durante el registro: ${e.toString()}'.tr());
      print("General Error during registration: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAuth = false;
        });
      }
    }
  }

  void _showSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Center(child: Image.asset('assets/logo.png', height: 60)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¡Bienvenido/a a Eslabon, una cadena solidaria!'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Revisa tu email ({}) y tu carpeta de spam para verificar tu cuenta.'.tr(args: [email]),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (!mounted) return;
                  context.go('/main');
                },
                child: Text('accept'.tr(), style: const TextStyle(color: Colors.amber)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(child: Image.asset('assets/logo.png', width: 100)),
              const SizedBox(height: 10),
              Center(child: Text('made_in_argentina'.tr(), style: TextStyle(color: Colors.white))),
              Center(child: Text('powered_by'.tr(), style: TextStyle(color: Colors.white54, fontSize: 12))),
              const SizedBox(height: 30),
              _buildTextField('full_name'.tr(), nameController),
              _buildTextField('dni'.tr(), dniController, keyboardType: TextInputType.number),
              _buildTextField(
                'address'.tr(),
                addressController,
                customLabelText: 'Dirección (Lo más Completa Posible)'.tr(),
              ),
              _buildTextField('postal_code'.tr(), postalCodeController, keyboardType: TextInputType.number),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'birth_date'.tr(),
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              Row(children: [
                Expanded(child: _buildDropdown('day'.tr(), _selectedDay, _days, (val) => setState(() => _selectedDay = val))),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdown('month'.tr(), _selectedMonth, _months, (val) => setState(() => _selectedMonth = val))),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdown('year'.tr(), _selectedYear, _years, (val) => setState(() => _selectedYear = val))),
              ]),
              const SizedBox(height: 12),

              DropdownButtonFormField<Country>(
                value: selectedCountry,
                decoration: InputDecoration(
                  labelText: 'select_country'.tr(),
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                dropdownColor: Colors.black,
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                items: countries.map((country) => DropdownMenuItem<Country>(
                  value: country,
                  child: Text(country.name),
                )).toList(),
                onChanged: (Country? newValue) {
                  setState(() {
                    selectedCountry = newValue;
                    _updateProvincesForCountry(newValue?.code);
                  });
                },
                validator: (val) {
                  if (val == null) {
                    return 'Este campo es obligatorio'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: selectedProvince,
                decoration: InputDecoration(
                  labelText: 'select_province'.tr(),
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                dropdownColor: Colors.black,
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                items: provinces.map((prov) => DropdownMenuItem<String>(
                  value: prov,
                  child: Text(prov),
                )).toList(),
                onChanged: (value) => setState(() => selectedProvince = value),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Este campo es obligatorio'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'phone'.tr(),
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  prefixText: phoneDialCode != null && phoneDialCode!.isNotEmpty ? '$phoneDialCode ' : '',
                  prefixStyle: const TextStyle(color: Colors.white),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Este campo es obligatorio.'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              _buildTextField('email'.tr(), emailController, keyboardType: TextInputType.emailAddress, isEmail: true),
              _buildTextField('password'.tr(), passwordController, isPassword: true),
              _buildTextField('confirm_password'.tr(), confirmPasswordController, isPassword: true, isConfirm: true),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isLoadingAuth ? null : _handleRegister,
                child: _isLoadingAuth
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text('register'.tr()),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  if (!mounted) return;
                  context.go('/login');
                },
                child: Text('already_have_account'.tr(), style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

