// lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart'; 
import 'package:easy_localization/easy_localization.dart';
import '../widgets/spinning_image_loader.dart'; 

// Asegúrate de que esta clase Country sea la misma que en register_screen.dart
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? currentUser;
  DocumentSnapshot? userData;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  String? emailDisplay;
  String? dniDisplay;

  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;
  List<String> _days = List.generate(31, (i) => (i + 1).toString());
  List<String> _months = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
  List<String> _years = List.generate(100, (i) => (DateTime.now().year - i).toString());

  List<Country> countries = [];
  List<String> provinces = [];
  Country? selectedCountry;
  String? selectedProvince;
  String? phoneDialCode;
  Map<String, dynamic> allProvincesData = {};

  bool _isLoading = true;
  String? _profileImageUrl;
  File? _newProfileImage;
  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _determinePosition(); // Se añade la llamada para obtener la ubicación
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    postalCodeController.dispose();
    super.dispose();
  }

  // ✅ NUEVA FUNCIÓN: Obtiene la ubicación del usuario
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Manejar caso de servicio de ubicación deshabilitado
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Manejar caso de permiso denegado
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Manejar caso de permiso denegado permanentemente
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
      });
    } catch (e) {
      print("Error al obtener ubicación: $e");
    }
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      currentUser = _auth.currentUser;
      if (currentUser != null) {
        userData = await _firestore.collection('users').doc(currentUser!.uid).get();

        if (userData!.exists) {
          final data = userData!.data() as Map<String, dynamic>;

          nameController.text = data['name'] ?? '';
          phoneController.text = data['phone']?.replaceAll(data['country']?['dial_code'] ?? '', '') ?? '';
          addressController.text = data['address'] ?? '';
          postalCodeController.text = data['zip'] ?? '';

          emailDisplay = data['email'] ?? '';
          dniDisplay = data['dni'] ?? '';
          
          _userLatitude = data['latitude'] as double?;
          _userLongitude = data['longitude'] as double?;

          if (data['birthDay'] != null && data['birthMonth'] != null && data['birthYear'] != null) {
            _selectedDay = data['birthDay'];
            _selectedMonth = data['birthMonth'];
            _selectedYear = data['birthYear'];
          } else {
            final String? dobString = data['fecha_nacimiento'];
            if (dobString != null && dobString.isNotEmpty) {
              final parts = dobString.split('/');
              if (parts.length == 3) {
                _selectedDay = parts[0];
                _selectedMonth = parts[1];
                _selectedYear = parts[2];
              }
            }
          }

          final String countryData = await rootBundle.loadString('lib/data/countries.json');
          final String provinceData = await rootBundle.loadString('lib/data/provinces.json');

          countries = (json.decode(countryData) as List)
              .map((e) => Country.fromJson(e))
              .toList();
          allProvincesData = json.decode(provinceData);

          if (data['country'] != null && data['country']['code'] != null) {
            selectedCountry = countries.firstWhere(
                  (country) => country.code == data['country']['code'],
              orElse: () => Country(code: '', name: '', dialCode: null),
            );
            updateProvincesForCountry(selectedCountry?.code);
          }
          selectedProvince = data['province'];
          phoneDialCode = selectedCountry?.dialCode;

          _profileImageUrl = data['profilePicture'];
        }
      }
    } catch (e) {
      print("Error loading profile data: $e");
      _showErrorDialog('Error al cargar la información de tu perfil. Intenta de nuevo.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void updateProvincesForCountry(String? countryCode) {
    setState(() {
      provinces = List<String>.from(allProvincesData[countryCode] ?? []);
      if (selectedProvince != null && !provinces.contains(selectedProvince)) {
        selectedProvince = null;
      }
      phoneDialCode = countries.firstWhere(
            (country) => country.code == countryCode,
        orElse: () => Country(code: '', name: '', dialCode: null),
      ).dialCode;
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _newProfileImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (currentUser == null) {
      _showErrorDialog('Debes iniciar sesión para subir una imagen de perfil.');
      return null;
    }
    
    if (_newProfileImage == null) return _profileImageUrl;

    try {
      final String fileName = 'users/${currentUser!.uid}/profile_picture.jpg';
      UploadTask uploadTask = _storage.ref().child(fileName).putFile(_newProfileImage!);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      print("Error uploading image: ${e.code} - ${e.message}");
      _showErrorDialog('Error al subir la imagen de perfil: ${e.message}');
      return null;
    } catch (e) {
      print("Unexpected error uploading image: $e");
      _showErrorDialog('Ocurrió un error inesperado al subir la imagen.');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Por favor, corrige los errores en el formulario para continuar.');
      return;
    }

    if (selectedCountry == null || selectedProvince == null ||
        _selectedDay == null || _selectedMonth == null || _selectedYear == null) {
      _showErrorDialog('Por favor, completa todos los campos obligatorios.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? newProfilePicUrl = await _uploadImage();
      if (newProfilePicUrl == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'name': nameController.text,
        'phone': '${phoneDialCode ?? ''}${phoneController.text}',
        'address': addressController.text,
        'zip': postalCodeController.text,
        'birthDay': _selectedDay,
        'birthMonth': _selectedMonth,
        'birthYear': _selectedYear,
        'country': selectedCountry != null ? {
          'code': selectedCountry!.code,
          'name': selectedCountry!.name,
          'dial_code': selectedCountry!.dialCode,
        } : null,
        'province': selectedProvince,
        'profilePicture': newProfilePicUrl,
        'latitude': _userLatitude,
        'longitude': _userLongitude,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado exitosamente!')),
      );
      await _loadProfileData();
      
      if (mounted) {
        context.pop();
      }

    } on FirebaseException catch (e) {
      print("Error saving profile: $e");
      _showErrorDialog('Error al guardar el perfil: ${e.message}');
    } catch (e) {
      print("Unexpected error saving profile: $e");
      _showErrorDialog('Ocurrió un error inesperado al guardar el perfil.');
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  Widget _buildTextField(String label, TextEditingController controller, {bool isReadOnly = false, TextInputType keyboardType = TextInputType.text, String? initialValue, String? customLabelText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: isReadOnly,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: customLabelText ?? label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          filled: isReadOnly,
          fillColor: isReadOnly ? Colors.grey[800] : Colors.transparent,
        ),
        validator: isReadOnly ? null : (value) {
          if (value == null || value.isEmpty) {
            return 'Este campo es obligatorio'.tr();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('my_profile'.tr(), style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: SpinningImageLoader())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: _newProfileImage != null
                            ? FileImage(_newProfileImage!)
                            : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                            ? NetworkImage(_profileImageUrl!) as ImageProvider<Object>?
                            : const AssetImage('assets/default_avatar.png') as ImageProvider<Object>?),
                        child: _newProfileImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 60, color: Colors.white70)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Colors.amber,
                          radius: 20,
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField('email'.tr(), TextEditingController(text: emailDisplay), isReadOnly: true),
              _buildTextField('dni'.tr(), TextEditingController(text: dniDisplay), isReadOnly: true),
              _buildTextField('full_name'.tr(), nameController),
              _buildTextField(
                'address'.tr(),
                addressController,
                customLabelText: 'address'.tr(),
              ),
              _buildTextField('postal_code'.tr(), postalCodeController, keyboardType: TextInputType.number),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'birth_date'.tr(),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
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
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text('save_changes'.tr()),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}