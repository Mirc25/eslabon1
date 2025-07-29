import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // smsCodeController ya no es necesario, pero lo dejamos si no causa problemas.

  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;
  List<String> _days = List.generate(31, (i) => (i + 1).toString());
  List<String> _months = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  List<String> _years = List.generate(100, (i) => (DateTime.now().year - i).toString());

  Map<String, dynamic> allProvincesData = {};

  // Variables de verificación de teléfono eliminadas o simplificadas
  // String? _verificationId; // Ya no es necesaria
  bool _codeSent = false; // Se mantendrá en false, no se usa para mostrar campos
  // bool _phoneVerified = false; // No se usará para validación de registro
  bool _isLoadingAuth = false;
  // bool _isLoadingPhoneVerify = false; // Ya no es necesaria

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
    // smsCodeController.dispose(); // Si lo quitas, descomenta esto
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
      _showErrorDialog('Error al cargar datos de países/provincias. Intenta de nuevo.');
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
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Este campo es obligatorio';
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
            return 'Este campo es obligatorio';
          }
          if (label == 'Email' && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
            return 'Introduce un email válido';
          }
          if (label == 'Contraseña' && value.length < 6) {
            return 'La contraseña debe tener al menos 6 caracteres';
          }
          if (label == 'Repetir Contraseña' && value != passwordController.text) {
            return 'Las contraseñas no coinciden';
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
                child: const Text('Cerrar', style: TextStyle(color: Colors.amber)),
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
              const Text(
                '¡Bienvenido/a a Eslabon, una cadena solidaria!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Revisa tu email ($email) y tu carpeta de spam para verificar tu cuenta.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pop(context);
                },
                child: const Text('Entendido', style: TextStyle(color: Colors.amber)),
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
              const Text(
                'Parece que tu correo ya está registrado pero no ha sido verificado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                '¿Quieres que te reenviemos el email de verificación?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
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
                    child: const Text('Reenviar Email'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pop(context);
                    },
                    child: const Text('Ir a Iniciar Sesión', style: TextStyle(color: Colors.grey)),
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
          _showErrorDialog('Se ha enviado un nuevo correo de verificación. Por favor, revisa tu bandeja de entrada o SPAM.');
        } else if (user != null && user.emailVerified) {
          _showErrorDialog('Tu correo ya ha sido verificado. Por favor, inicia sesión.');
        }
      } else {
        _showErrorDialog('No se pudo reenviar el correo. Asegúrate de que el email sea correcto y estés registrado.');
      }
    } catch (e) {
      _showErrorDialog('Error al reenviar el correo de verificación: ${e.toString()}');
      print("Error al reenviar email: $e");
    }
  }

  // --- Lógica de verificación de teléfono ELIMINADA ---
  // Los métodos _initiatePhoneVerification y _signInWithPhoneCredential
  // han sido eliminados ya que no se usará la verificación por SMS.

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
        'phoneVerified': false, // Siempre false, ya que no hay verificación por teléfono
      });
      _showSuccessDialog(emailController.text);
    } else {
      _showErrorDialog('No se pudo guardar la información del usuario: usuario no autenticado.');
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Por favor, corrige los errores en el formulario para continuar.');
      return;
    }

    if (selectedCountry == null || selectedProvince == null ||
        _selectedDay == null || _selectedMonth == null || _selectedYear == null) {
      _showErrorDialog('Por favor, completa todos los campos obligatorios del formulario.');
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
          _showErrorDialog('Para registrarte debes ser mayor de 18 años.');
          return;
        }
      } else {
        if (age < 18) {
          _showErrorDialog('Para registrarte debes ser mayor de 18 años.');
          return;
        }
      }
    }

    // Validación de teléfono verificado eliminada.
    // if (!_phoneVerified) {
    //   _showErrorDialog('Por favor, verifica tu número de teléfono antes de registrarte.');
    //   return;
    // }

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
        print("Email de verificación enviado.");

        // Lógica de vinculación de teléfono eliminada, ya que no hay verificación por SMS.
        // if (userCredential.user!.phoneNumber == null || userCredential.user!.phoneNumber!.isEmpty) { ... }

        await _saveUserDataAndShowSuccess();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al registrar: ${e.message}';
      if (e.code == 'email-already-in-use') {
        try {
          UserCredential signInCredential = await _auth.signInWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );
          if (signInCredential.user != null && !signInCredential.user!.emailVerified) {
            _showReverifyModal();
          } else {
            _showErrorDialog('Este correo ya está registrado y verificado. Por favor, inicia sesión.');
            if (mounted) Navigator.pop(context);
          }
        } on FirebaseAuthException catch (signInError) {
          if (signInError.code == 'wrong-password') {
            _showErrorDialog('Este correo ya está registrado, pero la contraseña es incorrecta. Si es tuyo, inicia sesión con la contraseña correcta. De lo contrario, usa otro email.');
          } else {
            _showErrorDialog('Error al intentar iniciar sesión con email existente: ${signInError.message}');
          }
        }
      } else if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es demasiado débil.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrónico no es válido.';
      } else if (e.code == 'credential-already-in-use') {
        errorMessage = 'Este correo electrónico ya está asociado a otra cuenta (posiblemente por teléfono). Intenta iniciar sesión o usa otro email.';
      }
      _showErrorDialog(errorMessage);
      print("Firebase Auth Error: ${e.code} - ${e.message}");
    } catch (e) {
      _showErrorDialog('Ocurrió un error inesperado durante el registro: ${e.toString()}');
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
              const Center(child: Text('Hecho en Argentina', style: TextStyle(color: Colors.white))),
              const Center(child: Text('Powered by Oviedo', style: TextStyle(color: Colors.white54, fontSize: 12))),
              const SizedBox(height: 30),
              _buildTextField('Nombre completo', nameController),
              _buildTextField('DNI', dniController, keyboardType: TextInputType.number),
              _buildTextField(
                'Dirección',
                addressController,
                customLabelText: 'Dirección (Lo más Completa Posible)',
              ),
              _buildTextField('Código postal', postalCodeController, keyboardType: TextInputType.number),
              const SizedBox(height: 12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Fecha de Nacimiento',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
              Row(children: [
                Expanded(child: _buildDropdown('Día', _selectedDay, _days, (val) => setState(() => _selectedDay = val))),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdown('Mes', _selectedMonth, _months, (val) => setState(() => _selectedMonth = val))),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdown('Año', _selectedYear, _years, (val) => setState(() => _selectedYear = val))),
              ]),
              const SizedBox(height: 12),

              DropdownButtonFormField<Country>(
                value: selectedCountry,
                decoration: const InputDecoration(
                  labelText: 'Seleccionar país',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    // _phoneVerified = false; // Ya no es necesaria
                    // _codeSent = false; // Ya no es necesaria
                    // smsCodeController.clear(); // Ya no es necesaria
                  });
                },
                validator: (val) {
                  if (val == null) {
                    return 'Este campo es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: selectedProvince,
                decoration: const InputDecoration(
                  labelText: 'Seleccionar provincia/estado',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    return 'Este campo es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Campo de teléfono: Ahora es un campo de texto normal sin verificación.
              TextFormField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  prefixText: phoneDialCode != null && phoneDialCode!.isNotEmpty ? '$phoneDialCode ' : '',
                  prefixStyle: const TextStyle(color: Colors.white),
                  // suffixIcon ya no es necesario
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Este campo es obligatorio.';
                  }
                  return null;
                },
                // onChanged ya no necesita resetear estados de verificación
              ),
              const SizedBox(height: 12),

              // La sección para el código SMS y el botón "Verificar Código SMS" ha sido ELIMINADA.

              _buildTextField('Email', emailController, keyboardType: TextInputType.emailAddress),
              _buildTextField('Contraseña', passwordController, isPassword: true),
              _buildTextField('Repetir Contraseña', confirmPasswordController, isPassword: true),
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
                    : const Text('Registrarse'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('¿Ya tenés cuenta? Iniciar sesión', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}