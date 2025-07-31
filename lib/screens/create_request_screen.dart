// lib/screens/create_request_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'package:eslabon_flutter/services/app_services.dart'; // ✅ Importación correcta de AppServices
import 'package:eslabon_flutter/providers/user_provider.dart'; // Para obtener el usuario actual
import 'package:eslabon_flutter/widgets/custom_text_field.dart'; // Si usas tu CustomTextField

// Clase Country (asumida de tu archivo register_screen.dart)
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

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late final AppServices _appServices; // ✅ Declaración correcta

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  String _selectedCategory = 'Salud';
  String _selectedPriority = 'media';

  double? _latitude;
  double? _longitude;
  String? _address; // Dirección legible (calle, número)
  String? _locality; // Localidad
  String? _province; // Provincia
  String? _countryCode; // Código de país

  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];

  List<Country> _countries = [];
  List<String> _provinces = [];
  Country? _selectedCountry;
  String? _selectedProvince;

  bool _isLoadingLocation = false;
  bool _isSavingRequest = false;

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth); // ✅ Inicialización correcta
    _loadLocationData();
    _determineCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationData() async {
    try {
      final String countryData = await rootBundle.loadString('lib/data/countries.json');
      final String provinceData = await rootBundle.loadString('lib/data/provinces.json');

      setState(() {
        _countries = (json.decode(countryData) as List)
            .map((e) => Country.fromJson(e))
            .toList();
        // Asume que Argentina es el país por defecto o lo preselecciona si existe
        _selectedCountry = _countries.firstWhere(
              (country) => country.code == 'AR',
          orElse: () => _countries.isNotEmpty ? _countries.first : Country(code: '', name: 'Seleccionar País'),
        );
        _updateProvincesForCountry(_selectedCountry?.code);
        // Si hay una provincia predefinida o la que el usuario ya tenía
        _selectedProvince = _provinces.isNotEmpty ? _provinces.first : null;
      });
    } catch (e) {
      print("Error loading location data: $e");
      AppServices.showSnackBar(context, 'Error al cargar datos de ubicación: $e', Colors.red); // ✅ Uso correcto
    }
  }

  void _updateProvincesForCountry(String? countryCode) {
    if (countryCode == null) {
      setState(() {
        _provinces = [];
        _selectedProvince = null;
      });
      return;
    }
    // Cargar los datos de provincias desde el archivo JSON
    rootBundle.loadString('lib/data/provinces.json').then((jsonString) {
      final Map<String, dynamic> allProvincesData = json.decode(jsonString);
      setState(() {
        _provinces = List<String>.from(allProvincesData[countryCode] ?? []);
        if (!_provinces.contains(_selectedProvince)) {
          _selectedProvince = _provinces.isNotEmpty ? _provinces.first : null;
        }
      });
    }).catchError((e) {
      print("Error loading provinces for country $countryCode: $e");
      AppServices.showSnackBar(context, 'Error al cargar provincias: $e', Colors.red); // ✅ Uso correcto
    });
  }

  Future<void> _determineCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppServices.showSnackBar(context, 'Permisos de ubicación denegados.', Colors.red); // ✅ Uso correcto
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        AppServices.showSnackBar(context, 'Permisos de ubicación permanentemente denegados. Habilítalos manualmente.', Colors.red); // ✅ Uso correcto
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _address = placemarks.isNotEmpty ? placemarks.first.street : 'Dirección Desconocida';
        _locality = placemarks.isNotEmpty ? placemarks.first.locality : 'Localidad Desconocida';
        _province = placemarks.isNotEmpty ? placemarks.first.administrativeArea : 'Provincia Desconocida';
        _countryCode = placemarks.isNotEmpty ? placemarks.first.isoCountryCode : 'Desconocido';

        // Intentar seleccionar el país y provincia basados en la ubicación
        if (_countryCode != null) {
          _selectedCountry = _countries.firstWhere(
                (country) => country.code == _countryCode,
            orElse: () => _selectedCountry ?? Country(code: '', name: 'Seleccionar País'),
          );
          _updateProvincesForCountry(_selectedCountry?.code);
        }
        if (_province != null && _provinces.contains(_province)) {
          _selectedProvince = _province;
        }
      });
      AppServices.showSnackBar(context, 'Ubicación obtenida: $_locality', Colors.green); // ✅ Uso correcto
    } catch (e) {
      AppServices.showSnackBar(context, 'No se pudo obtener la ubicación: $e', Colors.red); // ✅ Uso correcto
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: source);
    if (video != null) {
      if (_selectedVideos.length < 3) { // Limitar a 3 videos
        final fileSize = await video.length();
        if (fileSize <= 25 * 1024 * 1024) { // 25 MB
          setState(() {
            _selectedVideos.add(File(video.path));
          });
        } else {
          AppServices.showSnackBar(context, 'El video excede el tamaño máximo de 25MB.', Colors.red); // ✅ Uso correcto
        }
      } else {
        AppServices.showSnackBar(context, 'Solo puedes subir hasta 3 videos.', Colors.orange); // ✅ Uso correcto
      }
    }
  }

  Future<List<String>> _uploadFiles(List<File> files, String folder) async {
    List<String> urls = [];
    for (var file in files) {
      try {
        final String fileName = '${_auth.currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        UploadTask uploadTask = _storage.ref().child(folder).child(fileName).putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        urls.add(await snapshot.ref.getDownloadURL());
      } catch (e) {
        print("Error uploading file: $e");
        AppServices.showSnackBar(context, 'Error al subir archivo: $e', Colors.red); // ✅ Uso correcto
      }
    }
    return urls;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      AppServices.showSnackBar(context, 'Por favor, completa todos los campos obligatorios.', Colors.orange); // ✅ Uso correcto
      return;
    }

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      AppServices.showSnackBar(context, 'Debes iniciar sesión para crear una solicitud.', Colors.red); // ✅ Uso correcto
      return;
    }
    if (_latitude == null || _longitude == null) {
      AppServices.showSnackBar(context, 'Por favor, obtén tu ubicación GPS.', Colors.red); // ✅ Uso correcto
      return;
    }
    if (_selectedProvince == null || _selectedProvince!.isEmpty) {
      AppServices.showSnackBar(context, 'Por favor, selecciona una provincia.', Colors.red); // ✅ Uso correcto
      return;
    }
    if (_selectedCountry == null || _selectedCountry!.code.isEmpty) {
      AppServices.showSnackBar(context, 'Por favor, selecciona un país.', Colors.red); // ✅ Uso correcto
      return;
    }

    setState(() {
      _isSavingRequest = true;
    });

    try {
      // Obtener datos del perfil del usuario para la solicitud
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      final String userName = userData?['name'] ?? currentUser.displayName ?? 'Usuario Anónimo';
      final String? userAvatar = userData?['profilePicture'] ?? currentUser.photoURL;
      final String userPhone = userData?['phone'] ?? '';
      final String userEmail = userData?['email'] ?? '';
      final String userAddress = userData?['address'] ?? '';
      final String userDOB = userData?['birthDay'] != null && userData?['birthMonth'] != null && userData?['birthYear'] != null
          ? '${userData!['birthDay']}/${userData['birthMonth']}/${userData['birthYear']}'
          : 'No especificada';


      List<String> imageUrls = await _uploadFiles(_selectedImages, 'request_images');
      List<String> videoUrls = await _uploadFiles(_selectedVideos, 'request_videos');

      await _firestore.collection('solicitudes-de-ayuda').add({
        'userId': currentUser.uid,
        'nombre': userName,
        'avatar': userAvatar,
        'phone': userPhone,
        'email': userEmail,
        'address': userAddress,
        'fecha_nacimiento': userDOB,
        'titulo': _titleController.text,
        'descripcion': _descriptionController.text,
        'detalle': _detailsController.text,
        'categoria': _selectedCategory,
        'prioridad': _selectedPriority,
        'latitude': _latitude,
        'longitude': _longitude,
        'address_text': _address,
        'localidad': _locality,
        'provincia': _selectedProvince,
        'country': _selectedCountry!.name, // Guardar el nombre del país
        'countryCode': _selectedCountry!.code, // Guardar el código del país
        'timestamp': FieldValue.serverTimestamp(),
        'estado': 'activa', // Estado inicial de la solicitud
        'imagenes': imageUrls,
        'videos': videoUrls,
        'offersCount': 0, // Contador de ofertas inicial
        'commentsCount': 0, // Contador de comentarios inicial
        'showWhatsapp': true, // Por defecto, se asume que se muestra
        'showEmail': true, // Por defecto, se asume que se muestra
        'showAddress': false, // Por defecto, no se muestra la dirección completa
      });

      AppServices.showSnackBar(context, 'Solicitud creada con éxito.', Colors.green); // ✅ Uso correcto
      if (mounted) {
        context.pop(); // Regresar a la pantalla anterior
      }
    } on FirebaseException catch (e) {
      AppServices.showSnackBar(context, 'Error al crear solicitud: ${e.message}', Colors.red); // ✅ Uso correcto
    } catch (e) {
      AppServices.showSnackBar(context, 'Ocurrió un error inesperado: $e', Colors.red); // ✅ Uso correcto
    } finally {
      setState(() {
        _isSavingRequest = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar el estado del usuario para asegurar que está logueado
    final user = ref.watch(userProvider).value;

    if (user == null) {
      // Si el usuario no está logueado, redirigir o mostrar un mensaje
      return Scaffold(
        appBar: AppBar(title: const Text('Crear Solicitud')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Debes iniciar sesión para crear una solicitud.', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Ir a Iniciar Sesión'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Nueva Solicitud', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isSavingRequest
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: _titleController,
                labelText: 'Título de la Solicitud',
                hintText: 'Ej: Necesito ayuda con la compra',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa un título.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _descriptionController,
                labelText: 'Descripción Corta',
                hintText: 'Ej: Necesito que me traigan medicamentos de la farmacia',
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa una descripción.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _detailsController,
                labelText: 'Detalles Adicionales (Opcional)',
                hintText: 'Ej: Vivo en el 3er piso, depto B, al lado del ascensor.',
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Categoría',
                _selectedCategory,
                ['Salud', 'Hogar', 'Educación', 'Transporte', 'Alimentos', 'Otros'],
                    (newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Prioridad',
                _selectedPriority,
                ['baja', 'media', 'alta'],
                    (newValue) {
                  setState(() {
                    _selectedPriority = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Country>(
                      value: _selectedCountry,
                      decoration: InputDecoration(
                        labelText: 'País',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      dropdownColor: Colors.grey[800],
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      items: _countries.map((country) => DropdownMenuItem<Country>(
                        value: country,
                        child: Text(country.name),
                      )).toList(),
                      onChanged: (Country? newValue) {
                        setState(() {
                          _selectedCountry = newValue;
                          _updateProvincesForCountry(newValue?.code);
                        });
                      },
                      validator: (value) {
                        if (value == null || value.code.isEmpty) {
                          return 'Selecciona un país';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedProvince,
                      decoration: InputDecoration(
                        labelText: 'Provincia/Estado',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      dropdownColor: Colors.grey[800],
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      items: _provinces.map((prov) => DropdownMenuItem<String>(
                        value: prov,
                        child: Text(prov),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedProvince = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Selecciona una provincia';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLocationSection(),
              const SizedBox(height: 16),
              _buildImageVideoPicker(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSavingRequest
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Crear Solicitud', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dropdownColor: Colors.grey[800],
      iconEnabledColor: Colors.white,
      style: const TextStyle(color: Colors.white),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ubicación de la Solicitud', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: TextEditingController(text: _address ?? 'Obteniendo dirección...'),
                labelText: 'Dirección GPS',
                readOnly: true,
              ),
            ),
            const SizedBox(width: 8),
            _isLoadingLocation
                ? const CircularProgressIndicator(color: Colors.amber)
                : IconButton(
              icon: const Icon(Icons.gps_fixed, color: Colors.amber),
              onPressed: _determineCurrentLocation,
              tooltip: 'Obtener ubicación actual',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Lat: ${_latitude?.toStringAsFixed(6) ?? 'N/A'}, Lon: ${_longitude?.toStringAsFixed(6) ?? 'N/A'}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          'Localidad: ${_locality ?? 'N/A'}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          'Provincia: ${_province ?? 'N/A'}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          'País: ${_countryCode ?? 'N/A'}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildImageVideoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Imágenes (máx 5) y Videos (máx 3)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            ..._selectedImages.map((file) => Chip(
              label: Text('Imagen ${file.path.split('/').last.substring(0, 8)}...'),
              onDeleted: () {
                setState(() {
                  _selectedImages.remove(file);
                });
              },
            )).toList(),
            ..._selectedVideos.map((file) => Chip(
              label: Text('Video ${file.path.split('/').last.substring(0, 8)}...'),
              onDeleted: () {
                setState(() {
                  _selectedVideos.remove(file);
                });
              },
            )).toList(),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton.icon(
              onPressed: _selectedImages.length < 5 ? () => _pickImage(ImageSource.gallery) : null,
              icon: const Icon(Icons.image, color: Colors.black),
              label: const Text('Imagen', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            ),
            ElevatedButton.icon(
              onPressed: _selectedVideos.length < 3 ? () => _pickVideo(ImageSource.gallery) : null,
              icon: const Icon(Icons.videocam, color: Colors.black),
              label: const Text('Video', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            ),
          ],
        ),
      ],
    );
  }
}
