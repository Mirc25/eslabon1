import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

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

  @override
  void initState() {
    super.initState();
    loadData();
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

  Future<void> loadData() async {
    try {
      final String countryData = await rootBundle.loadString('lib/data/countries.json');
      final String provinceData = await rootBundle.loadString('lib/data/provinces.json');

      setState(() {
        countries = (json.decode(countryData) as List)
            .map((e) => Country.fromJson(e))
            .toList();
        allProvincesData = json.decode(provinceData);
      });
    } catch (e) {
      print('Error loading data: $e');
      _showErrorDialog('Error al cargar datos de países/provincias. Intenta de nuevo.'.tr());
    }
  }

  void updateProvincesForCountry(String? countryCode) {
    setState(() {
      provinces = List<String>.from(allProvincesData[countryCode] ?? []);
      selectedProvince = null;
      phoneDialCode = countries.firstWhere(
        (country) => country.code == countryCode,
        orElse: () => Country(code: '', name: '', dialCode: null),
      ).dialCode;
    });
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

  Widget _buildTextField(String label, TextEditingController controller, {bool isPassword = false, TextInputType keyboardType = TextInputType.text, String? customLabelText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: customLabelText ?? label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Este campo es obligatorio'.tr();
          }
          if (label == 'Email' && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
            return 'Introduce un email válido'.tr();
          }
          if (label == 'Contraseña' && value.length < 6) {
            return 'La contraseña debe tener al menos 6 caracteres'.tr();
          }
          if (label == 'Repetir Contraseña' && value != passwordController.text) {
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
                onPressed: () => Navigator.of(context).pop(),
                child: Text('close'.tr(), style: const TextStyle(color: Colors.amber)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog(String email) {
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
                  Navigator.pop(context);
                },
                child: Text('accept'.tr(), style: const TextStyle(color: Colors.amber)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReverifyModal() {
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
                'Parece que tu correo ya está registrado pero no ha sido verificado.'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Text(
                '¿Quieres que te reenviemos el email de verificación?'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _handleReverifyEmail();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Reenviar Email'.tr()),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pop(context);
                    },
                    child: Text('Ir a Iniciar Sesión'.tr(), style: const TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleReverifyEmail() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && user.email == emailController.text) {
        await user.reload();
        user = _auth.currentUser;

        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();
          _showErrorDialog('Se ha enviado un nuevo correo de verificación. Por favor, revisa tu bandeja de entrada o SPAM.'.tr());
        } else if (user != null && user.emailVerified) {
          _showErrorDialog('Tu correo ya ha sido verificado. Por favor, inicia sesión.'.tr());
        }
      } else {
        _showErrorDialog('No se pudo reenviar el correo. Asegúrate de que el email sea correcto y estés registrado.'.tr());
      }
    } catch (e) {
      _showErrorDialog('Error al reenviar el correo de verificación: ${e.toString()}'.tr());
      print("Error al reenviar email: $e");
    }
  }

  Future<void> _saveUserDataAndShowSuccess() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'name': nameController.text,
        'dni': dniController.text,
        'birthDay': _selectedDay,
        'birthMonth': _selectedMonth,
        'birthYear': _selectedYear,
        'address': addressController.text,
        'zip': postalCodeController.text,
        'country': selectedCountry != null ? {
          'code': selectedCountry!.code,
          'name': selectedCountry!.name,
          'dial_code': selectedCountry!.dialCode,
        } : null,
        'province': selectedProvince,
        'phone': '${phoneDialCode ?? ''}${phoneController.text}',
        'email': emailController.text,
        'profilePicture': null,
        'reputation': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': user.emailVerified,
        'phoneVerified': false, 
      });
      _showSuccessDialog(emailController.text);
    } else {
      _showErrorDialog('No se pudo guardar la información del usuario: usuario no autenticado.'.tr());
    }
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

      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        if (age <= 18) {
          _showErrorDialog('Para registrarte debes ser mayor de 18 años.'.tr());
          return;
        }
      } else {
        if (age < 18) {
          _showErrorDialog('Para registrarte debes ser mayor de 18 años.'.tr());
          return;
        }
      }
    }

    setState(() {
      _isLoadingAuth = true;
    });

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      if (userCredential.user != null) {
        await userCredential.user!.sendEmailVerification();
        print("Email de verificación enviado.".tr());

        await _saveUserDataAndShowSuccess();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al registrar: ${e.message}'.tr();
      if (e.code == 'email-already-in-use') {
        try {
          UserCredential signInCredential = await _auth.signInWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );
          if (signInCredential.user != null && !signInCredential.user!.emailVerified) {
            _showReverifyModal();
          } else {
            _showErrorDialog('Este correo ya está registrado y verificado. Por favor, inicia sesión.'.tr());
            if (mounted) Navigator.pop(context);
          }
        } on FirebaseAuthException catch (signInError) {
          if (signInError.code == 'wrong-password') {
            _showErrorDialog('Este correo ya está registrado, pero la contraseña es incorrecta. Si es tuyo, inicia sesión con la contraseña correcta. De lo contrario, usa otro email.'.tr());
          } else {
            _showErrorDialog('Error al intentar iniciar sesión con email existente: ${signInError.message}'.tr());
          }
        }
      } else if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es demasiado débil.'.tr();
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrónico no es válido.'.tr();
      } else if (e.code == 'credential-already-in-use') {
        errorMessage = 'Este correo electrónico ya está asociado a otra cuenta (posiblemente por teléfono). Intenta iniciar sesión o usa otro email.'.tr();
      }
      _showErrorDialog(errorMessage);
      print("Firebase Auth Error: ${e.code} - ${e.message}");
    } catch (e) {
      _showErrorDialog('Ocurrió un error inesperado durante el registro: ${e.toString()}'.tr());
      print("General Error during registration: $e");
    } finally {
      setState(() {
        _isLoadingAuth = false;
      });
    }
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
                padding: EdgeInsets.symmetric(vertical: 8.0),
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
                    updateProvincesForCountry(newValue?.code);
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

              _buildTextField('email'.tr(), emailController, keyboardType: TextInputType.emailAddress),
              _buildTextField('password'.tr(), passwordController, isPassword: true),
              _buildTextField('confirm_password'.tr(), confirmPasswordController, isPassword: true),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isLoadingAuth ? null : _handleRegister,
                child: _isLoadingAuth
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('register'.tr()),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('already_have_account'.tr(), style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}