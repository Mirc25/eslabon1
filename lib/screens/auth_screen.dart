// lib/screens/auth_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:eslabon_flutter/widgets/custom_text_field.dart';

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

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoginMode = true;
  bool _isLoadingAuth = false;
  String? _errorMessage;

  // Controladores para el registro
  final TextEditingController nameController = TextEditingController();
  final TextEditingController dniController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // Variables para registro
  List<Country> countries = [];
  List<String> provinces = [];
  Country? selectedCountry;
  String? selectedProvince;
  String? phoneDialCode;
  Map<String, dynamic> allProvincesData = {};

  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;
  List<String> _days = List.generate(31, (i) => (i + 1).toString());
  List<String> _months = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  List<String> _years = List.generate(100, (i) => (DateTime.now().year - i).toString());

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  @override
  void dispose() {
    nameController.dispose();
    dniController.dispose();
    addressController.dispose();
    postalCodeController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationData() async {
    try {
      final String countryData = await rootBundle.loadString('lib/data/countries.json');
      final String provinceData = await rootBundle.loadString('lib/data/provinces.json');

      setState(() {
        countries = (json.decode(countryData) as List).map((e) => Country.fromJson(e)).toList();
        allProvincesData = json.decode(provinceData);
      });
    } catch (e) {
      print('Error loading data: $e');
      _showErrorDialog('Error al cargar datos de paÃ­ses/provincias. Intenta de nuevo.');
    }
  }

  void _updateProvincesForCountry(String? countryCode) {
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
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('âœ… Token FCM guardado correctamente: $token');
      } else {
        debugPrint('âš ï¸ No se pudo obtener el token FCM.');
      }
    } catch (e) {
      debugPrint('âŒ Error guardando token FCM: $e');
    }
  }

  Future<void> _login() async {
    setState(() {
      _errorMessage = null;
      _isLoadingAuth = true;
    });
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      await _saveFcmTokenForUser(userCredential.user!);

      if (mounted) {
        context.go('/main');
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No se encontrÃ³ un usuario con ese correo.';
      } else if (e.code == 'wrong-password') {
        message = 'ContraseÃ±a incorrecta.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrÃ³nico es invÃ¡lido.';
      } else {
        message = 'Error de autenticaciÃ³n: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'OcurriÃ³ un error inesperado: $e';
      });
    } finally {
      setState(() {
        _isLoadingAuth = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Por favor, corrige los errores en el formulario para continuar.');
      return;
    }

    if (selectedCountry == null || selectedProvince == null ||
        _selectedDay == null || _selectedMonth == null || _selectedYear == null) {
      _showErrorDialog('Por favor, completa todos los campos obligatorios del formulario.');
      return;
    }

    final int day = int.parse(_selectedDay!);
    final int month = int.parse(_selectedMonth!);
    final int year = int.parse(_selectedYear!);
    final DateTime birthDate = DateTime(year, month, day);
    final DateTime today = DateTime.now();
    final int age = today.year - birthDate.year;

    if (age < 18 || (age == 18 && (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)))) {
      _showErrorDialog('Para registrarte debes ser mayor de 18 aÃ±os.');
      return;
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
        await _saveUserDataAndShowSuccess();
        await _saveFcmTokenForUser(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al registrar: ${e.message}';
      if (e.code == 'email-already-in-use') {
        try {
          final signInCredential = await _auth.signInWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );
          if (signInCredential.user != null && !signInCredential.user!.emailVerified) {
            _showReverifyModal();
          } else {
            _showErrorDialog('Este correo ya estÃ¡ registrado y verificado. Por favor, inicia sesiÃ³n.');
            if (mounted) {
              setState(() {
                _isLoginMode = true;
              });
            }
          }
        } on FirebaseAuthException catch (signInError) {
          if (signInError.code == 'wrong-password') {
            _showErrorDialog('Este correo ya estÃ¡ registrado, pero la contraseÃ±a es incorrecta. Si es tuyo, inicia sesiÃ³n con la contraseÃ±a correcta. De lo contrario, usa otro email.');
          } else {
            _showErrorDialog('Error al intentar iniciar sesiÃ³n con email existente: ${signInError.message}');
          }
        }
      } else if (e.code == 'weak-password') {
        errorMessage = 'La contraseÃ±a es demasiado dÃ©bil.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo electrÃ³nico es invÃ¡lido.';
      } else if (e.code == 'credential-already-in-use') {
        errorMessage = 'Este correo electrÃ³nico ya estÃ¡ asociado a otra cuenta. Intenta iniciar sesiÃ³n o usa otro email.';
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('OcurriÃ³ un error inesperado durante el registro: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingAuth = false;
      });
    }
  }
  
  Future<void> _saveUserDataAndShowSuccess() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'name': nameController.text,
        'lowercaseName': nameController.text.toLowerCase(),
        'dni': dniController.text,
        'birthDay': int.tryParse(_selectedDay!), // ðŸ”„ CORRECCIÃ“N: Guardamos como int
        'birthMonth': int.tryParse(_selectedMonth!), // ðŸ”„ CORRECCIÃ“N: Guardamos como int
        'birthYear': int.tryParse(_selectedYear!), // ðŸ”„ CORRECCIÃ“N: Guardamos como int
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
        'helpedCount': 0,
        'receivedHelpCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': user.emailVerified,
        'phoneVerified': false,
      });
      _showSuccessDialog(emailController.text);
    } else {
      _showErrorDialog('No se pudo guardar la informaciÃ³n del usuario: usuario no autenticado.');
    }
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
                'Â¡Bienvenido/a a Eslabon, una cadena solidaria!',
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
                  context.go('/login');
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
                'Parece que tu correo ya estÃ¡ registrado pero no ha sido verificado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                'Â¿Quieres que te reenviemos el email de verificaciÃ³n?',
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
                      context.go('/login');
                    },
                    child: const Text('Ir a Iniciar SesiÃ³n', style: TextStyle(color: Colors.grey)),
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
          _showErrorDialog('Se ha enviado un nuevo correo de verificaciÃ³n. Por favor, revisa tu bandeja de entrada o SPAM.');
        } else if (user != null && user.emailVerified) {
          _showErrorDialog('Tu correo ya ha sido verificado. Por favor, inicia sesiÃ³n.');
        }
      } else {
        _showErrorDialog('No se pudo reenviar el correo. AsegÃºrate de que el email sea correcto y estÃ©s registrado.');
      }
    } catch (e) {
      _showErrorDialog('Error al reenviar el correo de verificaciÃ³n: ${e.toString()}');
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
              Text(
                _isLoginMode ? 'Iniciar SesiÃ³n' : 'Registrarse',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 30),

              CustomTextField(
                controller: emailController,
                labelText: 'Correo ElectrÃ³nico',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Este campo es obligatorio';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Introduce un email vÃ¡lido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: passwordController,
                labelText: 'ContraseÃ±a',
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Este campo es obligatorio';
                  }
                  if (_isLoginMode == false && value.length < 6) {
                    return 'La contraseÃ±a debe tener al menos 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              if (!_isLoginMode) ...[
                CustomTextField(
                  controller: confirmPasswordController,
                  labelText: 'Repetir ContraseÃ±a',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    if (value != passwordController.text) {
                      return 'Las contraseÃ±as no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: nameController,
                  labelText: 'Nombre completo',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: dniController,
                  labelText: 'DNI',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: addressController,
                  labelText: 'DirecciÃ³n (Lo mÃ¡s Completa Posible)',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: postalCodeController,
                  labelText: 'CÃ³digo postal',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Fecha de Nacimiento',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _selectedDay,
                    decoration: InputDecoration(
                      labelText: 'DÃ­a',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: Colors.black,
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    items: _days.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                    onChanged: (val) => setState(() => _selectedDay = val),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Este campo es obligatorio';
                      }
                      return null;
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    decoration: InputDecoration(
                      labelText: 'Mes',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: Colors.black,
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    items: _months.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                    onChanged: (val) => setState(() => _selectedMonth = val),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Este campo es obligatorio';
                      }
                      return null;
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _selectedYear,
                    decoration: InputDecoration(
                      labelText: 'AÃ±o',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: Colors.black,
                    iconEnabledColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    items: _years.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                    onChanged: (val) => setState(() => _selectedYear = val),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Este campo es obligatorio';
                      }
                      return null;
                    },
                  )),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<Country>(
                  value: selectedCountry,
                  decoration: const InputDecoration(
                    labelText: 'Seleccionar paÃ­s',
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
                      _updateProvincesForCountry(newValue?.code);
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
                CustomTextField(
                  controller: phoneController,
                  labelText: 'TelÃ©fono',
                  keyboardType: TextInputType.phone,
                  hintText: phoneDialCode != null && phoneDialCode!.isNotEmpty ? '$phoneDialCode ' : '',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 24.0),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              _isLoadingAuth
                  ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                  : ElevatedButton(
                      onPressed: _isLoginMode ? _login : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoginMode ? Colors.amber : Colors.white10,
                        foregroundColor: _isLoginMode ? Colors.black : Colors.white,
                        side: _isLoginMode ? null : const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _isLoginMode ? 'Iniciar SesiÃ³n' : 'Registrarse',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
              const SizedBox(height: 16.0),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                    _errorMessage = null;
                    _formKey.currentState?.reset();
                  });
                },
                child: Text(
                  _isLoginMode
                      ? 'Â¿No tienes cuenta? RegÃ­strate'
                      : 'Â¿Ya tienes cuenta? Iniciar SesiÃ³n',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
