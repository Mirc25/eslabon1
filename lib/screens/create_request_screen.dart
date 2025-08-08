// lib/screens/create_request_screen.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/providers/user_provider.dart';
import 'package:eslabon_flutter/widgets/custom_text_field.dart';
import '../widgets/spinning_image_loader.dart';
import 'package:eslabon_flutter/widgets/banner_ad_widget.dart';

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

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _localityController = TextEditingController();
  final TextEditingController _phoneNumberDisplayController = TextEditingController();
  final TextEditingController _addressDisplayController = TextEditingController();
  final TextEditingController _dobDisplayController = TextEditingController();

  final TextEditingController _nameDisplayController = TextEditingController();
  final TextEditingController _emailDisplayController = TextEditingController();
  String? _userAvatarUrl;
  String? _userCountryName;
  String? _userProvinceName;

  double? _requestLatitude;
  double? _requestLongitude;

  String? _selectedCategory;
  String? _selectedPriority;

  final List<String> _categories = ['Personas', 'Animales', 'Objetos', 'Servicios', 'Otros'];
  final List<String> _priorities = ['alta', 'media', 'baja'];

  List<dynamic> _selectedImages = [];
  List<dynamic> _selectedVideos = [];
  static const int _maxFileSizeMB = 20;

  bool _isLoading = false;
  bool _isDataLoading = true;
  bool _isLocationLoading = false;

  bool _showWhatsapp = true;
  bool _showEmail = false;
  bool _showAddress = false;

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'eslabon-app.firebasestorage.app',
  );
  late AppServices _appServices;

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
    _loadUserData();
    _determinePosition();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _detailsController.dispose();
    _localityController.dispose();
    _phoneNumberDisplayController.dispose();
    _addressDisplayController.dispose();
    _nameDisplayController.dispose();
    _emailDisplayController.dispose();
    _dobDisplayController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    AppServices.showSnackBar(context, message, color);
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLocationLoading = true;
    });
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('location_services_disabled'.tr(), Colors.orange);
      print('DEBUG CREATE: Los servicios de ubicación están deshabilitados.');
      setState(() { _isLocationLoading = false; });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('location_permissions_denied'.tr(), Colors.red);
        print('DEBUG CREATE: Permisos de ubicación denegados.');
        setState(() { _isLocationLoading = false; });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('location_permissions_denied_forever'.tr(), Colors.red);
      print('DEBUG CREATE: Permisos de ubicación permanentemente denegados.');
      setState(() { _isLocationLoading = false; });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 10));
      setState(() {
        _requestLatitude = position.latitude;
        _requestLongitude = position.longitude;
      });
      await _getAddressFromLatLng(position);
      print('DEBUG CREATE: Ubicación GPS obtenida para solicitud: Lat: $_requestLatitude, Lon: $_requestLongitude');

    } on PlatformException catch (e) {
      debugPrint("DEBUG CREATE: Error de plataforma al obtener ubicación GPS: $e");
      _showSnackBar('Error de plataforma al obtener la ubicación. ${e.message}'.tr(), Colors.red);
      _localityController.text = '';
      setState(() {
        _requestLatitude = null;
        _requestLongitude = null;
      });
    } catch (e) {
      debugPrint("DEBUG CREATE: Error general al obtener ubicación GPS: $e");
      _showSnackBar('No se pudo obtener la ubicación actual para la solicitud.'.tr(), Colors.red);
      _localityController.text = '';
      setState(() {
        _requestLatitude = null;
        _requestLongitude = null;
      });
    } finally {
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _localityController.text = place.locality ?? place.subLocality ?? place.name ?? '';
          _userProvinceName = place.administrativeArea ?? '';
          _userCountryName = place.country ?? '';
          _addressDisplayController.text = [place.street, place.subLocality, place.locality, place.administrativeArea, place.country]
              .where((element) => element != null && element.isNotEmpty)
              .join(', ');
        });
        print('DEBUG CREATE: Dirección obtenida de Lat/Lng: Localidad: ${_localityController.text}, Provincia: $_userProvinceName, País: $_userCountryName, Dirección Completa: ${_addressDisplayController.text}');
        _showSnackBar('Dirección precargada exitosamente.'.tr(), Colors.green);
      }
    } on PlatformException catch (e) {
      debugPrint("DEBUG CREATE: Error de plataforma al obtener dirección de lat/lng: $e");
      _showSnackBar('Error de plataforma al obtener la dirección.'.tr(), Colors.red);
    } catch (e) {
      debugPrint("DEBUG CREATE: Error general al obtener dirección de lat/lng: $e");
      _showSnackBar('Error al obtener la dirección de la ubicación.'.tr(), Colors.red);
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isDataLoading = true;
    });
    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            _nameDisplayController.text = data['name'] ?? '';
            _emailDisplayController.text = data['email'] ?? '';
            _phoneNumberDisplayController.text = data['phone'] ?? '';
            
            if (data['birthDay'] != null && data['birthMonth'] != null && data['birthYear'] != null) {
                _dobDisplayController.text = '${data['birthDay']}/${data['birthMonth']}/${data['birthYear']}';
            } else {
                _dobDisplayController.text = '';
            }

            if (_addressDisplayController.text.isEmpty) {
              _addressDisplayController.text = data['address'] ?? '';
            }
            if (_localityController.text.isEmpty) {
                _localityController.text = data['locality'] ?? '';
            }

            _userAvatarUrl = data['profilePicture'];
            _userCountryName = data['country_name'] ?? data['country']?['name'] ?? 'N/A';
            _userProvinceName = data['province_name'] ?? data['province'] ?? 'N/A';

            print('DEBUG CREATE: Datos de usuario cargados.');
          }
        }
      } on FirebaseException catch (e) {
        debugPrint("DEBUG CREATE: Firebase Exception al cargar datos de usuario: ${e.code} - ${e.message}");
        _showSnackBar('Error de Firebase al cargar datos de usuario: ${e.message}'.tr(), Colors.red);
      } catch (e) {
        debugPrint("DEBUG CREATE: Error general al cargar datos de usuario: $e");
        _showSnackBar('Error al cargar datos de usuario: ${e.toString()}'.tr(), Colors.red);
      }
    }
    setState(() {
      _isDataLoading = false;
    });
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 800,
      maxHeight: 600,
    );

    if (images != null && images.isNotEmpty) {
      setState(() {
        int remainingSlots = 5 - _selectedImages.length;
        for (XFile xFile in images) {
          if (remainingSlots <= 0) {
            _showSnackBar('Has alcanzado el límite de 5 imágenes.'.tr(), Colors.orange);
            break;
          }
          if (kIsWeb) {
            _selectedImages.add(xFile);
          } else {
            _selectedImages.add(File(xFile.path));
          }
          remainingSlots--;
        }
      });
    }
  }

  Future<void> _pickVideos() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? media = await picker.pickMultipleMedia();

    if (media != null && media.isNotEmpty) {
      List<XFile> videosToAdd = [];
      for (XFile file in media) {
        if (file.mimeType != null && file.mimeType!.startsWith('video/')) {
          final fileSize = await file.length();
          if (fileSize > (_maxFileSizeMB * 1024 * 1024)) {
            _showSnackBar('El video ${file.name} excede el tamaño máximo de ${_maxFileSizeMB}MB.'.tr(), Colors.red);
            continue;
          }
          videosToAdd.add(file);
        } else if (file.mimeType != null && file.mimeType!.startsWith('image/')) {
          _showSnackBar('Por favor, selecciona solo videos, o usa el botón de imágenes para fotos.'.tr(), Colors.orange);
          continue;
        }
      }

      setState(() {
        int remainingSlots = 3 - _selectedVideos.length;
        for (XFile videoFile in videosToAdd) {
          if (remainingSlots <= 0) {
            _showSnackBar('Has alcanzado el límite de 3 videos.'.tr(), Colors.orange);
            break;
          }
          if (kIsWeb) {
            _selectedVideos.add(videoFile);
          } else {
            _selectedVideos.add(File(videoFile.path));
          }
          remainingSlots--;
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeVideo(int index) {
    setState(() {
      _selectedVideos.removeAt(index);
    });
  }

  Future<void> _createRequest() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Por favor, completa todos los campos requeridos.'.tr(), Colors.orange);
      return;
    }
    if (_selectedCategory == null || _selectedPriority == null) {
      _showSnackBar('Por favor, selecciona una categoría y una prioridad.'.tr(), Colors.orange);
      return;
    }
    if (_requestLatitude == null || _requestLongitude == null) {
      _showSnackBar('No se pudo obtener la ubicación para la solicitud. Asegúrate de permisos y conexión.'.tr(), Colors.red);
      print('DEBUG CREATE: Intento de crear solicitud sin latitud/longitud.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      _showSnackBar('Debes iniciar sesión para crear una solicitud.'.tr(), Colors.red);
      setState(() { _isLoading = false; });
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      if (userData == null || userData['name'] == null || userData['name'].isEmpty || userData['name'] == 'Usuario anónimo'.tr() || (userData['profilePicture'] == null || userData['profilePicture'].isEmpty)) {
        _showSnackBar("Por favor, completa tu perfil con un nombre y una foto antes de crear una solicitud.".tr(), Colors.orange);
        setState(() { _isLoading = false; });
        return;
      }
      
      List<String> imageUrls = [];
      for (dynamic imageSource in _selectedImages) {
        String fileName = 'requests/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}_${imageSource is XFile ? imageSource.name : (imageSource as File).path.split('/').last}';
        UploadTask uploadTask;

        if (kIsWeb && imageSource is XFile) {
          Uint8List bytes = await imageSource.readAsBytes();
          uploadTask = _storage.ref().child(fileName).putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else if (imageSource is File) {
          uploadTask = _storage.ref().child(fileName).putFile(imageSource);
        } else {
          continue;
        }
        TaskSnapshot snapshot = await uploadTask;
        imageUrls.add(await snapshot.ref.getDownloadURL());
        print('DEBUG CREATE: Imagen subida: ${imageUrls.last}');
      }

      List<String> videoUrls = [];
      for (dynamic videoSource in _selectedVideos) {
        String fileName = 'videos/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}_${videoSource is XFile ? videoSource.name : (videoSource as File).path.split('/').last}';
        UploadTask uploadTask;

        String contentType = 'video/mp4';
        if (videoSource is XFile) {
          contentType = videoSource.mimeType ?? 'video/mp4';
        }

        if (kIsWeb && videoSource is XFile) {
          Uint8List bytes = await videoSource.readAsBytes();
          uploadTask = _storage.ref().child(fileName).putData(bytes, SettableMetadata(contentType: contentType));
        } else if (videoSource is File) {
          uploadTask = _storage.ref().child(fileName).putFile(videoSource, SettableMetadata(contentType: contentType));
        } else {
          continue;
        }
        TaskSnapshot snapshot = await uploadTask;
        videoUrls.add(await snapshot.ref.getDownloadURL());
        print('DEBUG CREATE: Video subido: ${videoUrls.last}');
      }
      
      final requesterName = userData['name'] ?? 'Usuario anónimo'.tr();
      final profileImageUrl = userData['profilePicture'] ?? '';

      final requestDataToSave = {
        'userId': currentUser.uid,
        'requesterName': requesterName,
        'profileImageUrl': profileImageUrl,
        'phone': _phoneNumberDisplayController.text.trim(),
        'email': _emailDisplayController.text.trim(),
        'address': _addressDisplayController.text.trim(),
        'fecha_nacimiento': _dobDisplayController.text.trim(),
        'titulo': _descriptionController.text.trim(),
        'descripcion': _descriptionController.text.trim(),
        'detalle': _detailsController.text.trim().isEmpty ? 'Sin detalles'.tr() : _detailsController.text.trim(),
        'localidad': _localityController.text.trim(),
        'provincia': _userProvinceName ?? 'San Juan'.tr(),
        'country': _userCountryName ?? 'Argentina'.tr(),
        'countryCode': _userCountryName,
        'categoria': _selectedCategory,
        'prioridad': _selectedPriority,
        'latitude': _requestLatitude,
        'longitude': _requestLongitude,
        'timestamp': FieldValue.serverTimestamp(),
        'estado': 'activa',
        'imagenes': imageUrls,
        'videos': videoUrls,
        'offersCount': 0,
        'commentsCount': 0,
        'showWhatsapp': _showWhatsapp,
        'showEmail': _showEmail,
        'showAddress': _showAddress,
      };

      await _firestore.collection('solicitudes-de-ayuda').add(requestDataToSave);

      print('DEBUG CREATE: Solicitud guardada en Firestore con Lat: $_requestLatitude, Lon: $_requestLongitude');
      _showSnackBar('¡Solicitud creada con éxito!'.tr(), Colors.green);
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      debugPrint("DEBUG CREATE: Firebase Exception al crear solicitud: ${e.code} - ${e.message}");
      _showSnackBar('Error de Firebase: ${e.message}'.tr(), Colors.red);
    } catch (e) {
      debugPrint("DEBUG CREATE: Error general al crear solicitud: ${e.toString()}");
      _showSnackBar('Error al crear la solicitud: ${e.toString()}'.tr(), Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildPreloadedTextField(String label, TextEditingController controller, {String? customLabelText, bool showRefresh = false, Function()? onRefresh}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(color: Colors.white70),
        decoration: InputDecoration(
          labelText: customLabelText ?? label,
          labelStyle: const TextStyle(color: Colors.grey),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
          filled: true,
          fillColor: Colors.grey[850],
          suffixIcon: showRefresh
              ? IconButton(
                  icon: _isLocationLoading
                      ? const SizedBox(width: 20, height: 20, child: SpinningImageLoader())
                      : const Icon(Icons.refresh, color: Colors.blueAccent),
                  onPressed: _isLocationLoading ? null : onRefresh,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildEditableTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? hintText, bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey),
          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
          filled: true,
          fillColor: Colors.black54,
        ),
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return 'Este campo es obligatorio'.tr();
          }
          return null;
        } : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showLoading = _isDataLoading || _isLocationLoading;
    final user = ref.watch(userProvider).value;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('create_request'.tr())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Debes iniciar sesión para crear una solicitud.'.tr(), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: Text('Ir a Iniciar Sesión'.tr()),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('create_request'.tr(), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: showLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SpinningImageLoader(),
                  const SizedBox(height: 20),
                  Text('Cargando datos del perfil y ubicación...'.tr(), style: const TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/eslabon_background.png',
                  fit: BoxFit.cover,
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Datos del Solicitante'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey[700],
                            backgroundImage: (_userAvatarUrl != null && _userAvatarUrl!.startsWith('http'))
                                ? NetworkImage(_userAvatarUrl!)
                                : const AssetImage('assets/default_avatar.png') as ImageProvider,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildPreloadedTextField('Nombre Completo'.tr(), _nameDisplayController),
                        _buildPreloadedTextField('Correo Electrónico'.tr(), _emailDisplayController),
                        _buildPreloadedTextField('Número de Teléfono'.tr(), _phoneNumberDisplayController),
                        _buildPreloadedTextField('Fecha de Nacimiento'.tr(), _dobDisplayController),

                        _buildPreloadedTextField('País'.tr(), TextEditingController(text: _userCountryName ?? 'N/A')),
                        _buildPreloadedTextField('Provincia'.tr(), TextEditingController(text: _userProvinceName ?? 'N/A')),
                        _buildPreloadedTextField(
                          'Localidad (Precargada)'.tr(),
                          _localityController,
                          showRefresh: true,
                          onRefresh: _determinePosition,
                        ),
                        _buildPreloadedTextField('Dirección Completa (Precargada)'.tr(), _addressDisplayController),

                        const SizedBox(height: 20),

                        Text('Preferencias de Contacto'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: Text('Mostrar mi número de WhatsApp'.tr(), style: const TextStyle(color: Colors.white70)),
                          subtitle: Text('Visible para los que vean tu solicitud'.tr(), style: const TextStyle(color: Colors.grey)),
                          value: _showWhatsapp,
                          onChanged: (bool value) {
                            setState(() {
                              _showWhatsapp = value;
                            });
                          },
                          activeColor: Colors.amber,
                        ),
                        SwitchListTile(
                          title: Text('Mostrar mi correo electrónico'.tr(), style: const TextStyle(color: Colors.white70)),
                          subtitle: Text('Visible para los que vean tu solicitud'.tr(), style: const TextStyle(color: Colors.grey)),
                          value: _showEmail,
                          onChanged: (bool value) {
                            setState(() {
                              _showEmail = value;
                            });
                          },
                          activeColor: Colors.amber,
                        ),
                        SwitchListTile(
                          title: Text('Mostrar mi dirección completa'.tr(), style: const TextStyle(color: Colors.white70)),
                          subtitle: Text('La dirección completa será visible (localidad/provincia siempre visible)'.tr(), style: const TextStyle(color: Colors.grey)),
                          value: _showAddress,
                          onChanged: (bool value) {
                            setState(() {
                              _showAddress = value;
                            });
                          },
                          activeColor: Colors.amber,
                        ),
                        const SizedBox(height: 20),

                        Text('Detalles de la Solicitud'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _buildEditableTextField('Descripción Corta (Título del Pedido)'.tr(), _descriptionController, hintText: 'Ej. Ayuda urgente por comida'.tr()),
                        _buildEditableTextField('Detalles Completos del Pedido'.tr(), _detailsController, maxLines: 3, hintText: 'Ej. Madre con 3 hijos sin recursos necesita alimentos no perecederos...'.tr()),

                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Categoría'.tr(),
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                            filled: true,
                            fillColor: Colors.black54,
                          ),
                          dropdownColor: Colors.grey[800],
                          style: const TextStyle(color: Colors.white),
                          items: _categories.map((String category) {
                            return DropdownMenuItem<String>(value: category, child: Text(category.tr()));
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, selecciona una categoría.'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedPriority,
                          decoration: InputDecoration(
                            labelText: 'Prioridad'.tr(),
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                            filled: true,
                            fillColor: Colors.black54,
                          ),
                          dropdownColor: Colors.grey[800],
                          style: const TextStyle(color: Colors.white),
                          items: _priorities.map((String priority) {
                            return DropdownMenuItem<String>(value: priority, child: Text(priority.tr()));
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedPriority = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, selecciona una prioridad.'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Imágenes (${_selectedImages.length}/5)',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            GestureDetector(
                              onTap: _selectedImages.length < 5 ? _pickImages : null,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white54),
                                ),
                                child: const Icon(Icons.add_a_photo, color: Colors.white70, size: 30),
                              ),
                            ),
                            ..._selectedImages.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final dynamic imageSource = entry.value;

                              Widget imageWidget;
                              if (kIsWeb) {
                                imageWidget = FutureBuilder<Uint8List>(
                                  future: (imageSource as XFile).readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                      return Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover);
                                    }
                                    return const SizedBox(width: 80, height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)));
                                  },
                                );
                              } else {
                                imageWidget = Image.file(imageSource as File, width: 80, height: 80, fit: BoxFit.cover);
                              }

                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imageWidget,
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Videos (${_selectedVideos.length}/3 - Max 20 MB cada uno)'.tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            GestureDetector(
                              onTap: _selectedVideos.length < 3 ? _pickVideos : null,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white54),
                                ),
                                child: const Icon(Icons.video_call, color: Colors.white70, size: 30),
                              ),
                            ),
                            ..._selectedVideos.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final dynamic videoSource = entry.value;

                              Widget videoPreviewWidget = Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white54),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.videocam, color: Colors.white70, size: 30),
                                    Text(
                                      videoSource is XFile ? videoSource.name : (videoSource as File).path.split('/').last,
                                      style: const TextStyle(color: Colors.grey, fontSize: 8),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );

                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: videoPreviewWidget,
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () => _removeVideo(index),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                        const SizedBox(height: 30),

                        Text('Publicidad Destacada'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        
                        const BannerAdWidget(),

                        const SizedBox(height: 20),

                        Center(
                          child: ElevatedButton(
                            onPressed: _createRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.black)
                                : Text(
                                    'Publicar Solicitud'.tr(),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}