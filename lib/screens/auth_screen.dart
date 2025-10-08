// lib/screens/auth_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:eslabon_flutter/widgets/custom_text_field.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ FIX CRÍTICO: Importación de traducción agregada

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
      // NOTE: Assuming assets/countries.json and assets/provinces.json exist
      final String countryData = await rootBundle.loadString('assets/countries.json');
      final String provinceData = await rootBundle.loadString('assets/provinces.json');

      setState(() {
        countries = (json.decode(countryData) as List).map((e) => Country.fromJson(e)).toList();
        allProvincesData = json.decode(provinceData);
      });
    } catch (e) {
      print('Error loading data: $e');
      _showErrorDialog('Error al cargar datos de países/provincias. Intenta de nuevo.'.tr());
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
        // Usamos .set(merge: true) para no sobrescribir datos existentes
        await _firestore.collection('users').doc(user.uid).set({ 
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          // Habilitar push por defecto al iniciar sesión/guardar token
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
  
  // 🚀 FUNCIÓN CLAVE: Guarda datos y maneja el estado de la aplicación
  Future<void> _saveUserDataAndNavigate(User user) async {
    try {
      final userProfileData = {
        'uid': user.uid,
        'email': user.email,
        'name': nameController.text.trim(),
        'lowercaseName': nameController.text.trim().toLowerCase(),
        'dni': dniController.text.trim(),
        'birthDay': int.tryParse(_selectedDay!),
        'birthMonth': int.tryParse(_selectedMonth!),
        'birthYear': int.tryParse(_selectedYear!),
        'address': addressController.text.trim(),
        'zip': postalCodeController.text.trim(),
        'country': selectedCountry != null ? {
          'code': selectedCountry!.code,
          'name': selectedCountry!.name,
          'dial_code': selectedCountry!.dialCode,
        } : null,
        'province': selectedProvince,
        'phone': '${phoneDialCode ?? ''}${phoneController.text.trim()}',
        'profilePicture': null,
        'reputation': 0,
        'helpedCount': 0,
        'receivedHelpCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': user.emailVerified,
        'phoneVerified': false,
      };

      // 1. INTENTO DE ESCRITURA EN FIRESTORE (Punto de fallo anterior)
      await _firestore.collection('users').doc(user.uid).set(
        userProfileData, 
        SetOptions(merge: true)
      );
      
      // 2. Guardar FCM Token
      await _saveFcmTokenForUser(user);

      // 3. NAVEGACIÓN EXITOSA
      if (mounted) {
        _showSuccessDialog(user.email ?? ''); // Muestra el modal de éxito/verificación de email
      }
    } on FirebaseException catch (e) {
      // ⚠️ Captura el error de Firestore (que puede ser un 403 por Reglas/App Check)
      print("❌ Firestore Write Error after Auth: ${e.code} - ${e.message}");
      _showErrorDialog('Error al guardar tu perfil en la base de datos. Por favor, verifica las Reglas de Seguridad (Error: ${e.code}).'.tr());
      // Forzamos el signOut para que la próxima vez el usuario intente de nuevo el registro completo
      await _auth.signOut(); 
    } catch (e) {
      print("❌ General Error during profile save: $e");
      _showErrorDialog('Ocurrió un error inesperado al finalizar tu registro.'.tr());
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
      
      // Intentamos guardar el token FCM después de un login exitoso
      await _saveFcmTokenForUser(userCredential.user!);

      if (mounted) {
        context.go('/main');
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No se encontró un usuario con ese correo.'.tr();
      } else if (e.code == 'wrong-password') {
        message = 'Contraseña incorrecta.'.tr();
      } else if (e.code == 'invalid-email') {
        message = 'El correo electrónico no es válido.'.tr();
      } else {
        message = 'Error de autenticación: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocurrió un error inesperado: $e'.tr();
      });
    } finally {
      setState(() {
        _isLoadingAuth = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Por favor, corrige los errores en el formulario para continuar.'.tr());
      return;
    }

    if (selectedCountry == null || selectedProvince == null ||
        _selectedDay == null || _selectedMonth == null || _selectedYear == null) {
      _showErrorDialog('Por favor, completa todos los campos obligatorios del formulario.'.tr());
      return;
    }

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
        // 1. Enviar verificación de email inmediatamente (para que el usuario sepa que debe verificar)
        await user.sendEmailVerification(); 
        
        // 2. Guardar datos en Firestore y navegar (el paso que fallaba)
        await _saveUserDataAndNavigate(user); 
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Error al registrar: ${e.message}';
      if (e.code == 'email-already-in-use') {
        // Lógica de recuperación para cuentas existentes no verificadas
        try {
          final signInCredential = await _auth.signInWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );
          if (signInCredential.user != null && !signInCredential.user!.emailVerified) {
            _showReverifyModal();
            return;
          } else {
            _showErrorDialog('Este correo ya está registrado y verificado. Por favor, inicia sesión.'.tr());
            if (mounted) {
              setState(() {
                _isLoginMode = true;
              });
            }
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
        errorMessage = 'El formato del correo electrónico es inválido.'.tr();
      } else if (e.code == 'credential-already-in-use') {
        errorMessage = 'Este correo electrónico ya está asociado a otra cuenta. Intenta iniciar sesión o usa otro email.'.tr();
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('Ocurrió un error inesperado durante el registro: ${e.toString()}'.tr());
    } finally {
      setState(() {
        _isLoadingAuth = false;
      });
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
                '¡Bienvenido/a a Eslabon, una cadena solidaria!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Revisa tu email ($email) y tu carpeta de spam para verificar tu cuenta.'.tr(),
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
                      context.go('/login');
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
          return 'Este campo es obligatorio'.tr();
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
                _isLoginMode ? 'Iniciar Sesión' : 'Registrarse',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 30),

              CustomTextField(
                controller: emailController,
                labelText: 'Correo Electrónico'.tr(),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Este campo es obligatorio'.tr();
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Introduce un email válido'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: passwordController,
                labelText: 'Contraseña'.tr(),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Este campo es obligatorio'.tr();
                  }
                  if (_isLoginMode == false && value.length < 6) {
                    return 'La contraseña debe tener al menos 6 caracteres'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              if (!_isLoginMode) ...[
                CustomTextField(
                  controller: confirmPasswordController,
                  labelText: 'Repetir Contraseña'.tr(),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio'.tr();
                    }
                    if (value != passwordController.text) {
                      return 'Las contraseñas no coinciden'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: nameController,
                  labelText: 'Nombre completo'.tr(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: dniController,
                  labelText: 'DNI'.tr(),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: addressController,
                  labelText: 'Dirección (Lo más Completa Posible)'.tr(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: postalCodeController,
                  labelText: 'Código postal'.tr(),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Fecha de Nacimiento'.tr(),
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _selectedDay,
                    decoration: InputDecoration(
                      labelText: 'Día'.tr(),
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
                        return 'Este campo es obligatorio'.tr();
                      }
                      return null;
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    decoration: InputDecoration(
                      labelText: 'Mes'.tr(),
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
                        return 'Este campo es obligatorio'.tr();
                      }
                      return null;
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _selectedYear,
                    decoration: InputDecoration(
                      labelText: 'Año'.tr(),
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
                        return 'Este campo es obligatorio'.tr();
                      }
                      return null;
                    },
                  )),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<Country>(
                  value: selectedCountry,
                  decoration: InputDecoration(
                    labelText: 'Seleccionar país'.tr(),
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
                    labelText: 'Seleccionar provincia/estado'.tr(),
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
                CustomTextField(
                  controller: phoneController,
                  labelText: 'Teléfono'.tr(),
                  keyboardType: TextInputType.phone,
                  hintText: phoneDialCode != null && phoneDialCode!.isNotEmpty ? '$phoneDialCode ' : '',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio.'.tr();
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
                        _isLoginMode ? 'Iniciar Sesión'.tr() : 'Registrarse'.tr(),
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
                      ? '¿No tienes cuenta? Regístrate'.tr()
                      : '¿Ya tienes cuenta? Iniciar Sesión'.tr(),
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