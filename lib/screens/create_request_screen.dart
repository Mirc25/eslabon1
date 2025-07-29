import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // NECESARIO para PlatformException
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Importa tu CustomBackground
import 'package:eslabon_flutter/widgets/custom_background.dart';
// Asegúrate de que esta ruta sea correcta para tu AppServices
import 'package:eslabon_flutter/services/app_services.dart';


class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({Key? key}) : super(key: key);

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _localityController = TextEditingController();
  final TextEditingController _phoneNumberDisplayController = TextEditingController();
  final TextEditingController _addressDisplayController = TextEditingController(); // Para dirección de texto
  final TextEditingController _dobDisplayController = TextEditingController(); // Para fecha de nacimiento

  final TextEditingController _nameDisplayController = TextEditingController();
  final TextEditingController _emailDisplayController = TextEditingController();
  String? _userAvatarUrl;
  String? _userCountryName;
  String? _userProvinceName;

  // Variables para almacenar la latitud y longitud de la solicitud
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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Asegúrate de que tu bucket sea este o ajústalo
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(bucket: 'eslabon-app.firebasestorage.app');

  late AppServices _appServices; // Declaración para inicialización tardía

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth); // Inicializar AppServices
    _loadUserData();
    _determinePosition(); // Llamar a la obtención de posición al inicio
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
    _dobDisplayController.dispose(); // Liberar controlador de DOB
    super.dispose();
  }

  // Utilizar _appServices.showSnackBar para consistencia
  void _showSnackBar(String message, Color color) {
    _appServices.showSnackBar(context, message, color);
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLocationLoading = true;
    });
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Los servicios de ubicación están deshabilitados. Actívalos para precargar la ubicación.', Colors.orange);
      print('DEBUG CREATE: Los servicios de ubicación están deshabilitados.');
      setState(() { _isLocationLoading = false; });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Permisos de ubicación denegados. No se puede precargar la ubicación.', Colors.red);
        print('DEBUG CREATE: Permisos de ubicación denegados.');
        setState(() { _isLocationLoading = false; });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Permisos de ubicación permanentemente denegados. Habilítalos manualmente en la configuración.', Colors.red);
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
      _showSnackBar('Error de plataforma al obtener la ubicación. ${e.message}', Colors.red);
      _localityController.text = '';
      setState(() {
        _requestLatitude = null;
        _requestLongitude = null;
      });
    } catch (e) {
      debugPrint("DEBUG CREATE: Error general al obtener ubicación GPS: $e");
      _showSnackBar('No se pudo obtener la ubicación actual para la solicitud.', Colors.red);
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
          // Combinar campos relevantes para una dirección completa
          _addressDisplayController.text = [place.street, place.subLocality, place.locality, place.administrativeArea, place.country]
              .where((element) => element != null && element.isNotEmpty)
              .join(', ');
        });
        print('DEBUG CREATE: Dirección obtenida de Lat/Lng: Localidad: ${_localityController.text}, Provincia: $_userProvinceName, País: $_userCountryName, Dirección Completa: ${_addressDisplayController.text}');
        _showSnackBar('Dirección precargada exitosamente.', Colors.green);
      }
    } on PlatformException catch (e) {
      debugPrint("DEBUG CREATE: Error de plataforma al obtener dirección de lat/lng: $e");
      _showSnackBar('Error de plataforma al obtener la dirección.', Colors.red);
    } catch (e) {
      debugPrint("DEBUG CREATE: Error general al obtener dirección de lat/lng: $e");
      _showSnackBar('Error al obtener la dirección de la ubicación.', Colors.red);
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isDataLoading = true;
    });
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            _nameDisplayController.text = data['name'] ?? '';
            _emailDisplayController.text = data['email'] ?? '';
            _phoneNumberDisplayController.text = data['phone'] ?? '';
            _dobDisplayController.text = data['fecha_nacimiento'] ?? ''; // Asumiendo campo 'fecha_nacimiento'

            // Solo precarga si la ubicación no ha sido ya obtenida por GPS
            if (_addressDisplayController.text.isEmpty) {
              _addressDisplayController.text = data['address'] ?? '';
            }
            if (_localityController.text.isEmpty) {
                _localityController.text = data['locality'] ?? '';
            }

            _userAvatarUrl = data['profilePicture'];
            // Prioriza los campos directamente guardados o fallback a la estructura anidada
            _userCountryName = data['country_name'] ?? data['country']?['name'] ?? 'N/A';
            _userProvinceName = data['province_name'] ?? data['province'] ?? 'N/A';

            print('DEBUG CREATE: Datos de usuario cargados.');
          }
        }
      } on FirebaseException catch (e) {
        debugPrint("DEBUG CREATE: Firebase Exception al cargar datos de usuario: ${e.code} - ${e.message}");
        _showSnackBar('Error de Firebase al cargar datos de usuario: ${e.message}', Colors.red);
      } catch (e) {
        debugPrint("DEBUG CREATE: Error general al cargar datos de usuario: $e");
        _showSnackBar('Error al cargar datos de usuario: ${e.toString()}', Colors.red);
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
            _showSnackBar('Has alcanzado el límite de 5 imágenes.', Colors.orange);
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
            _showSnackBar('El video ${file.name} excede el tamaño máximo de ${_maxFileSizeMB}MB.', Colors.red);
            continue;
          }
          videosToAdd.add(file);
        } else if (file.mimeType != null && file.mimeType!.startsWith('image/')) {
          _showSnackBar('Por favor, selecciona solo videos, o usa el botón de imágenes para fotos.', Colors.orange);
          continue;
        }
      }

      setState(() {
        int remainingSlots = 3 - _selectedVideos.length;
        for (XFile videoFile in videosToAdd) {
          if (remainingSlots <= 0) {
            _showSnackBar('Has alcanzado el límite de 3 videos.', Colors.orange);
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
      _showSnackBar('Por favor, completa todos los campos requeridos.', Colors.orange);
      return;
    }
    if (_selectedCategory == null || _selectedPriority == null) {
      _showSnackBar('Por favor, selecciona una categoría y una prioridad.', Colors.orange);
      return;
    }
    if (_requestLatitude == null || _requestLongitude == null) {
      _showSnackBar('No se pudo obtener la ubicación para la solicitud. Asegúrate de permisos y conexión.', Colors.red);
      print('DEBUG CREATE: Intento de crear solicitud sin latitud/longitud.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showSnackBar('Debes iniciar sesión para crear una solicitud.', Colors.red);
      setState(() { _isLoading = false; });
      return;
    }

    try {
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

      String userName = _nameDisplayController.text.trim();
      String userEmail = _emailDisplayController.text.trim();
      String userAvatar = _userAvatarUrl ?? "assets/default_avatar.png";
      String userPhone = _phoneNumberDisplayController.text.trim();
      String userAddress = _addressDisplayController.text.trim(); // Dirección completa
      String userLocality = _localityController.text.trim();
      String userProvince = _userProvinceName ?? 'San Juan'; // Default a San Juan si no se obtiene
      String userCountry = _userCountryName ?? 'Argentina'; // Default a Argentina si no se obtiene
      String userDOB = _dobDisplayController.text.trim(); // Fecha de nacimiento

      await _firestore.collection('solicitudes-de-ayuda').add({
        "userId": currentUser.uid,
        "nombre": userName,
        "descripcion": _descriptionController.text.trim(),
        "detalle": _detailsController.text.trim(),
        "localidad": userLocality,
        "provincia": userProvince,
        "country": userCountry,
        "categoria": _selectedCategory,
        "avatar": userAvatar,
        "imagenes": imageUrls,
        "videos": videoUrls,
        "recibido": 0,
        "otorgo": 0,
        "timestamp": FieldValue.serverTimestamp(),
        "prioridad": _selectedPriority,
        "phone": userPhone,
        "email": userEmail,
        "address": userAddress,
        "fecha_nacimiento": userDOB,
        "showWhatsapp": _showWhatsapp,
        "showEmail": _showEmail,
        "showAddress": _showAddress,
        "estado": "activa",
        "latitude": _requestLatitude,
        "longitude": _requestLongitude,
      });

      print('DEBUG CREATE: Solicitud guardada en Firestore con Lat: $_requestLatitude, Lon: $_requestLongitude');
      _showSnackBar('¡Solicitud creada con éxito!', Colors.green);
      Navigator.pop(context); // Vuelve a la pantalla principal
    } on FirebaseException catch (e) {
      debugPrint("DEBUG CREATE: Firebase Exception al crear solicitud: ${e.code} - ${e.message}");
      _showSnackBar('Error de Firebase: ${e.message}', Colors.red);
    } catch (e) {
      debugPrint("DEBUG CREATE: Error general al crear solicitud: ${e.toString()}");
      _showSnackBar('Error al crear la solicitud: ${e.toString()}', Colors.red);
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
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2))
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
            return 'Este campo es obligatorio';
          }
          return null;
        } : null,
      ),
    );
  }

  // --- WIDGETS PARA PUBLICIDAD Y OFRECER AYUDA ---

  Widget _buildAdSpace(String title, {String? imageUrl, String? videoUrl}) {
    // Si tienes VideoPlayer o Chewie, los usarías aquí.
    // Para simplificar, usamos un Container con texto placeholder.
    // Si es una imagen, puedes usar Image.network(imageUrl, fit: BoxFit.cover)
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      height: 150, // Altura típica para un banner de video/imagen
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, color: Colors.amber, size: 40),
            const SizedBox(height: 8),
            Text(
              'Espacio Publicitario: $title',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (imageUrl != null) // Si tienes una imagen de ad
              Text('Ad Image: $imageUrl', style: const TextStyle(color: Colors.grey, fontSize: 10)),
            if (videoUrl != null) // Si tienes un video de ad
              Text('Ad Video: $videoUrl', style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // --- FIN DE WIDGETS PARA PUBLICIDAD Y OFRECER AYUDA ---

  @override
  Widget build(BuildContext context) {
    final bool showLoading = _isDataLoading || _isLocationLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nueva Solicitud', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // ✅ CORRECCIÓN FINAL: Usar CustomBackground con 'child' como argumento nombrado
      body: CustomBackground(
        child: showLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.amber),
                    SizedBox(height: 20),
                    Text('Cargando datos del perfil y ubicación...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Sección de Datos del Solicitante ---
                      const Text('Datos del Solicitante', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                      _buildPreloadedTextField('Nombre Completo', _nameDisplayController),
                      _buildPreloadedTextField('Correo Electrónico', _emailDisplayController),
                      _buildPreloadedTextField('Número de Teléfono', _phoneNumberDisplayController),
                      _buildPreloadedTextField('Fecha de Nacimiento', _dobDisplayController),

                      _buildPreloadedTextField('País', TextEditingController(text: _userCountryName ?? 'N/A')),
                      _buildPreloadedTextField('Provincia', TextEditingController(text: _userProvinceName ?? 'N/A')),
                      _buildPreloadedTextField(
                        'Localidad (Precargada)',
                        _localityController,
                        showRefresh: true,
                        onRefresh: _determinePosition,
                      ),
                      _buildPreloadedTextField('Dirección Completa (Precargada)', _addressDisplayController),

                      const SizedBox(height: 20),

                      // --- Sección de Preferencias de Contacto ---
                      const Text('Preferencias de Contacto', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text('Mostrar mi número de WhatsApp', style: TextStyle(color: Colors.white70)),
                        subtitle: const Text('Visible para los que vean tu solicitud', style: TextStyle(color: Colors.grey)),
                        value: _showWhatsapp,
                        onChanged: (bool value) {
                          setState(() {
                            _showWhatsapp = value;
                          });
                        },
                        activeColor: Colors.amber,
                      ),
                      SwitchListTile(
                        title: const Text('Mostrar mi correo electrónico', style: TextStyle(color: Colors.white70)),
                        subtitle: const Text('Visible para los que vean tu solicitud', style: TextStyle(color: Colors.grey)),
                        value: _showEmail,
                        onChanged: (bool value) {
                          setState(() {
                            _showEmail = value;
                          });
                        },
                        activeColor: Colors.amber,
                      ),
                      SwitchListTile(
                        title: const Text('Mostrar mi dirección completa', style: TextStyle(color: Colors.white70)),
                        subtitle: const Text('La dirección completa será visible (localidad/provincia siempre visible)', style: TextStyle(color: Colors.grey)),
                        value: _showAddress,
                        onChanged: (bool value) {
                          setState(() {
                            _showAddress = value;
                          });
                        },
                        activeColor: Colors.amber,
                      ),
                      const SizedBox(height: 20),

                      // --- Sección de Detalles de la Solicitud ---
                      const Text('Detalles de la Solicitud', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _buildEditableTextField('Descripción Corta (Título del Pedido)', _descriptionController, hintText: 'Ej. Ayuda urgente por comida'),
                      _buildEditableTextField('Detalles Completos del Pedido', _detailsController, maxLines: 3, hintText: 'Ej. Madre con 3 hijos sin recursos necesita alimentos no perecederos...'),

                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          filled: true,
                          fillColor: Colors.black54,
                        ),
                        dropdownColor: Colors.grey[800],
                        style: const TextStyle(color: Colors.white),
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(value: category, child: Text(category));
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, selecciona una categoría.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: const InputDecoration(
                          labelText: 'Prioridad',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          filled: true,
                          fillColor: Colors.black54,
                        ),
                        dropdownColor: Colors.grey[800],
                        style: const TextStyle(color: Colors.white),
                        items: _priorities.map((String priority) {
                          return DropdownMenuItem<String>(value: priority, child: Text(priority));
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedPriority = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, selecciona una prioridad.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // --- Sección de Imágenes y Videos ---
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
                        'Videos (${_selectedVideos.length}/3 - Max $_maxFileSizeMB MB cada uno)',
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

                      // --- Espacios para Publicidad ---
                      const Text('Publicidad Destacada', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      _buildAdSpace('Anuncio Patrocinado 1'),
                      _buildAdSpace('Anuncio Patrocinado 2'),
                      const SizedBox(height: 20),

                      // --- Botón de Publicar Solicitud ---
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
                              : const Text(
                                  'Publicar Solicitud',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
      // --- Botón Flotante para Ofrecer Ayuda ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Lógica para el botón "Ofrecer Ayuda"
          // Puedes navegar a una nueva pantalla o mostrar un diálogo
          _showSnackBar('Has presionado "Ofrecer Ayuda"!', Colors.blue);
          // Ejemplo de navegación:
          // Navigator.push(context, MaterialPageRoute(builder: (context) => OfferHelpScreen()));
        },
        label: const Text('Ofrecer Ayuda', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.handshake, color: Colors.white),
        backgroundColor: Colors.teal,
        // Puedes cambiar la posición con floatingActionButtonLocation
        // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // Ubicación más común y menos intrusiva
    );
  }
}