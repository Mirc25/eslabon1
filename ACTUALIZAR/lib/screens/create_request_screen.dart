import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
  final TextEditingController _addressDisplayController = TextEditingController();

  final TextEditingController _nameDisplayController = TextEditingController();
  final TextEditingController _emailDisplayController = TextEditingController();
  String? _userAvatarUrl;
  String? _userCountryName;
  String? _userProvinceName;

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
  // ¡CORRECCIÓN CRÍTICA AQUÍ! Usar instanceFor con tu bucket 'firebasestorage.app'
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'eslabon-app.firebasestorage.app', // ¡Usamos el bucket que SÍ configuramos con CORS exitosamente!
  );

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLocationLoading = true;
    });
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Los servicios de ubicación están deshabilitados.', Colors.orange);
      setState(() { _isLocationLoading = false; });
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Permisos de ubicación denegados.', Colors.red);
        setState(() { _isLocationLoading = false; });
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Permisos de ubicación permanentemente denegados. Habilítalos manualmente.', Colors.red);
      setState(() { _isLocationLoading = false; });
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _getAddressFromLatLng(position);
    } catch (e) {
      debugPrint("Error al obtener ubicación: $e");
      _showSnackBar('No se pudo obtener la ubicación actual.', Colors.red);
      _localityController.text = '';
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
          _addressDisplayController.text = "${place.street ?? ''} ${place.name ?? ''}";
        });
        _showSnackBar('Ubicación precargada exitosamente.', Colors.green);
      }
    } catch (e) {
      debugPrint("Error al obtener dirección de lat/lng: $e");
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
            if (_addressDisplayController.text.isEmpty) {
              _addressDisplayController.text = data['address'] ?? '';
            }
            if (_localityController.text.isEmpty) {
                _localityController.text = data['locality'] ?? '';
            }

            String? rawPhone = data['phone'];
            String? dialCode = data['country']?['dial_code'];
            if (rawPhone != null && dialCode != null && rawPhone.startsWith(dialCode)) {
              _phoneNumberDisplayController.text = rawPhone.replaceFirst(dialCode, '').trim();
            } else {
              _phoneNumberDisplayController.text = rawPhone ?? '';
            }

            _userAvatarUrl = data['profilePicture'];
            if (_userCountryName == null || _userCountryName == 'N/A') {
              _userCountryName = data['country']?['name'] ?? 'N/A';
            }
            if (_userProvinceName == null || _userProvinceName == 'N/A') {
              _userProvinceName = data['province'] ?? 'N/A';
            }
          }
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos de usuario: ${e.toString()}')),
        );
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

    setState(() {
      _isLoading = true;
    });

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showSnackBar('Debes iniciar sesión para crear una solicitud.', Colors.red);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Usaremos _storage.ref() directamente, que ahora apunta al bucket firebasestorage.app
      // ¡Asegúrate de que tus reglas CORS estén aplicadas a eslabon-app.firebasestorage.app!

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
      }

      List<String> videoUrls = [];
      for (dynamic videoSource in _selectedVideos) {
        String fileName = 'videos/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}_${videoSource is XFile ? videoSource.name : (videoSource as File).path.split('/').last}';
        UploadTask uploadTask;

        String contentType = 'video/mp4';

        if (kIsWeb && videoSource is XFile) {
          Uint8List bytes = await videoSource.readAsBytes();
          contentType = videoSource.mimeType ?? 'video/mp4';
          uploadTask = _storage.ref().child(fileName).putData(bytes, SettableMetadata(contentType: contentType));
        } else if (videoSource is File) {
          uploadTask = _storage.ref().child(fileName).putFile(videoSource, SettableMetadata(contentType: contentType));
        } else {
          continue;
        }
        TaskSnapshot snapshot = await uploadTask;
        videoUrls.add(await snapshot.ref.getDownloadURL());
      }

      // Tomamos los datos del usuario de los controladores de display (precargados)
      String userName = _nameDisplayController.text.trim();
      String userEmail = _emailDisplayController.text.trim();
      String userAvatar = _userAvatarUrl ?? "assets/default_avatar.png";
      String userPhone = _phoneNumberDisplayController.text.trim();
      String userAddress = _addressDisplayController.text.trim();
      String userLocality = _localityController.text.trim();
      String userProvince = _userProvinceName ?? 'San Juan';
      String userCountry = _userCountryName ?? 'Argentina';

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
        "recibio": 0,
        "otorgo": 0,
        "timestamp": FieldValue.serverTimestamp(),
        "prioridad": _selectedPriority,
        "phone": userPhone,
        "email": userEmail,
        "address": userAddress,
        "showWhatsapp": _showWhatsapp,
        "showEmail": _showEmail,
        "showAddress": _showAddress,
        "estado": "activa",
      });

      _showSnackBar('¡Solicitud creada con éxito!', Colors.green);
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      debugPrint("Firebase Exception al crear solicitud: ${e.code} - ${e.message}");
      _showSnackBar('Error de Firebase: ${e.message}', Colors.red);
    } catch (e) {
      debugPrint("Error general al crear solicitud: ${e.toString()}");
      _showSnackBar('Error al crear la solicitud: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Widget para campos de texto precargados/de solo lectura
  Widget _buildPreloadedTextField(String label, TextEditingController controller, {String? customLabelText}) {
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
        ),
      ),
    );
  }

  // Widget para campos de texto editables por el usuario para la solicitud
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
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final bool showLoading = _isDataLoading || _isLocationLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nueva Solicitud', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: showLoading
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
                        _buildPreloadedTextField('País', TextEditingController(text: _userCountryName ?? 'N/A')),
                        _buildPreloadedTextField('Provincia', TextEditingController(text: _userProvinceName ?? 'N/A')),
                        _buildPreloadedTextField('Dirección (Precargada)', _addressDisplayController, customLabelText: 'Dirección (Precargada)'),
                        _buildPreloadedTextField('Número de Teléfono (Precargado)', _phoneNumberDisplayController, customLabelText: 'Número de Teléfono'),

                        _buildEditableTextField('Localidad de la Solicitud', _localityController, hintText: 'Ej. Chimbas', isRequired: true),
                        const SizedBox(height: 20),

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

                        // Sección de Imágenes
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
                                child: Icon(Icons.add_a_photo, color: Colors.white70, size: 30),
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

                        // Sección de Videos
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
                                child: Icon(Icons.video_call, color: Colors.white70, size: 30),
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
              ],
            ),
    );
  }
}