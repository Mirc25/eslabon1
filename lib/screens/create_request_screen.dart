// lib/screens/create_request_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:eslabon_flutter/providers/help_requests_provider.dart';
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
import '../widgets/avatar_optimizado.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/services/notification_service.dart';
import 'package:eslabon_flutter/providers/user_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/spinning_image_loader.dart';
import '../widgets/ad_banner_widget.dart';
import '../services/ads_ids.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_background.dart';

class Country {
  final String code;
  final String name;
  final String? dialCode;

  Country({required this.code, required this.name, this.dialCode});

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dialCode: json['dial_code']?.toString(),
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

  String? _userAvatarPath;
  String? _userCountryName;
  String? _userProvinceName;

  double? _requestLatitude;
  double? _requestLongitude;

  String? _selectedCategory;
  String? _selectedPriority;

  final List<String> _categories = ['Personas', 'Animales', 'Objetos', 'Servicios', 'Otros'];
  final List<String> _priorities = ['alta', 'media', 'baja'];

  List<XFile> _selectedImages = []; // ✅ Usar XFile directamente
  List<XFile> _selectedVideos = []; // ✅ Usar XFile directamente
  static const int _maxFileSizeMB = 20;
  final Map<String, double> _videoUploadProgress = {}; // progreso por nombre de archivo
  final Map<String, double> _imageUploadProgress = {}; // progreso por nombre de archivo
  double _overallUploadProgress = 0.0; // 0..1 progreso total
  int _overallTotalItems = 0; // total de archivos a subir
  int _completedUploadItems = 0; // ítems subidos completamente
  bool _showGlobalUploadOverlay = false; // mostrar overlay de subida
  String _globalUploadMessage = 'Subiendo archivos...';

  bool _isLoading = false;
  bool _isDataLoading = true;
  bool _isLocationLoading = false;

  bool _showWhatsapp = false;
  bool _showEmail = false;
  bool _showAddress = false;

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  late AppServices _appServices;
  late NotificationService _notificationService;
  
  // Sistema de caché para URLs de imágenes de perfil
  final Map<String, String> _profilePictureUrlCache = {};
  
  // Evita reentrancia del ImagePicker (already_active)
  bool _isPickingMedia = false;

  @override
  void initState() {
    super.initState();
    _appServices = AppServices(_firestore, _auth);
    _notificationService = NotificationService();
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
      if (mounted) setState(() { _isLocationLoading = false; });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('location_permissions_denied'.tr(), Colors.red);
        print('DEBUG CREATE: Permisos de ubicación denegados.');
        if (mounted) setState(() { _isLocationLoading = false; });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('location_permissions_denied_forever'.tr(), Colors.red);
      print('DEBUG CREATE: Permisos de ubicación permanentemente denegados.');
      if (mounted) setState(() { _isLocationLoading = false; });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _requestLatitude = position.latitude;
          _requestLongitude = position.longitude;
        });
      }
      await _getAddressFromLatLng(position);
      print('DEBUG CREATE: Ubicación GPS obtenida para solicitud: Lat: $_requestLatitude, Lon: $_requestLongitude');

    } on PlatformException catch (e) {
      debugPrint("DEBUG CREATE: Error de plataforma al obtener ubicación GPS: $e");
      _showSnackBar('Error de plataforma al obtener la ubicación. ${e.message}'.tr(), Colors.red);
      _localityController.text = '';
      if (mounted) {
        setState(() {
          _requestLatitude = null;
          _requestLongitude = null;
        });
      }
    } catch (e) {
      debugPrint("DEBUG CREATE: Error general al obtener ubicación GPS: $e");
      _showSnackBar('No se pudo obtener la ubicación actual para la solicitud.'.tr(), Colors.red);
      _localityController.text = '';
      if (mounted) {
        setState(() {
          _requestLatitude = null;
          _requestLongitude = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        if (mounted) {
          setState(() {
            _localityController.text = place.locality?.toString() ?? place.subLocality?.toString() ?? place.name?.toString() ?? '';
            _userProvinceName = place.administrativeArea?.toString() ?? '';
            _userCountryName = place.country?.toString() ?? '';
            _addressDisplayController.text = [place.street, place.subLocality, place.locality, place.administrativeArea, place.country]
                .where((element) => element != null && element.isNotEmpty)
                .join(', ');
          });
        }
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
    if (!mounted) return;
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
            if (mounted) {
              setState(() {
                _nameDisplayController.text = data['name']?.toString() ?? '';
                _emailDisplayController.text = data['email']?.toString() ?? '';
                _phoneNumberDisplayController.text = data['phone']?.toString() ?? '';
                final String? birthDay = (data['birthDay'] as num?)?.toInt().toString();
                final String? birthMonth = (data['birthMonth'] as num?)?.toInt().toString().padLeft(2, '0');
                final String? birthYear = (data['birthYear'] as num?)?.toInt().toString();

                if (birthDay != null && birthMonth != null && birthYear != null) {
                  _dobDisplayController.text = '$birthDay/$birthMonth/$birthYear';
                } else {
                  _dobDisplayController.text = '';
                }

                if (_addressDisplayController.text.isEmpty) {
                  _addressDisplayController.text = data['address']?.toString() ?? '';
                }
                if (_localityController.text.isEmpty) {
                    _localityController.text = data['locality']?.toString() ?? '';
                }

                _userAvatarPath = data['profilePicture']?.toString();
                _userCountryName = data['country_name']?.toString() ?? data['country']?['name']?.toString() ?? 'N/A';
                _userProvinceName = data['province_name']?.toString() ?? data['province']?.toString() ?? 'N/A';
              });
            }
            print('DEBUG CREATE: Datos de usuario cargados.');
          }
        }
      } on FirebaseException catch (e) {
        debugPrint("DEBUG CREATE: Firebase Exception al cargar datos de usuario: ${e.code} - ${e.message}");
        _showSnackBar('Error de Firebase al cargar datos de usuario: ${e.message}'.tr(), Colors.red);
      } catch (e) {
        debugPrint("DEBUG CREATE: Error general al cargar datos de usuario: ${e.toString()}");
        _showSnackBar('Error al cargar datos de usuario: ${e.toString()}'.tr(), Colors.red);
      }
    }
    if (mounted) {
      setState(() {
        _isDataLoading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    if (_isPickingMedia) {
      _showSnackBar('El selector ya está activo, por favor espere.'.tr(), Colors.orange);
      return;
    }
    _isPickingMedia = true;
    try {
      final ImagePicker picker = ImagePicker();
      if (kIsWeb) {
        // Web: usar pickMultiImage
        final List<XFile>? images = await picker.pickMultiImage(
          imageQuality: 70,
          maxWidth: 800,
          maxHeight: 600,
        );
        if (images != null && images.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            int remainingSlots = 5 - _selectedImages.length;
            for (XFile xFile in images) {
              if (remainingSlots <= 0) {
                _showSnackBar('Has alcanzado el límite de 5 imágenes.'.tr(), Colors.orange);
                break;
              }
              _selectedImages.add(xFile);
              remainingSlots--;
            }
          });
        }
      } else {
        // Móvil (Android/iOS): intentar pickMultipleMedia y filtrar imágenes con fallback
        List<XFile>? media;
        try {
          media = await picker.pickMultipleMedia();
        } on PlatformException catch (e) {
          debugPrint('pickMultipleMedia falló: ${e.code} - ${e.message}');
        }

        // Si pickMultipleMedia no devuelve nada, usar pickMultiImage como fallback
        if (media == null || media.isEmpty) {
          try {
            media = await picker.pickMultiImage(
              imageQuality: 70,
              maxWidth: 800,
              maxHeight: 600,
            );
          } on PlatformException catch (e) {
            debugPrint('pickMultiImage fallback falló: ${e.code} - ${e.message}');
          }
        }

        if (media != null && media.isNotEmpty) {
          final List<XFile> imagesOnly = [];
          for (XFile file in media) {
            try {
              if (await _isImageFile(file)) {
                imagesOnly.add(file);
              }
            } catch (e) {
              debugPrint('Detección de imagen falló para ${file.name}: $e');
            }
          }
          if (imagesOnly.isEmpty) {
            _showSnackBar('No se seleccionaron imágenes. Usa el botón de fotos.'.tr(), Colors.orange);
          } else {
            if (!mounted) return;
            setState(() {
              int remainingSlots = 5 - _selectedImages.length;
              for (XFile xFile in imagesOnly) {
                if (remainingSlots <= 0) {
                  _showSnackBar('Has alcanzado el límite de 5 imágenes.'.tr(), Colors.orange);
                  break;
                }
                _selectedImages.add(xFile);
                remainingSlots--;
              }
            });
          }
        } else {
          _showSnackBar('No se seleccionaron fotos.'.tr(), Colors.orange);
        }
      }
    } on PlatformException catch (e) {
      debugPrint('ERROR PICK IMAGES: ${e.code} - ${e.message}');
      _showSnackBar('No se pudo abrir el selector de imágenes: ${e.message}'.tr(), Colors.red);
    } catch (e) {
      debugPrint('ERROR PICK IMAGES (general): ${e.toString()}');
      _showSnackBar('Error al seleccionar imágenes: ${e.toString()}'.tr(), Colors.red);
    } finally {
      _isPickingMedia = false;
    }
  }

  // Heurística robusta para detectar si un XFile es imagen
  Future<bool> _isImageFile(XFile file) async {
    try {
      final String? mt = file.mimeType;
      if (mt != null && mt.startsWith('image/')) return true;

      final String pathLower = file.path.toLowerCase();
      if (pathLower.endsWith('.jpg') ||
          pathLower.endsWith('.jpeg') ||
          pathLower.endsWith('.png') ||
          pathLower.endsWith('.gif') ||
          pathLower.endsWith('.bmp') ||
          pathLower.endsWith('.webp')) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error inspeccionando archivo ${file.name}: $e');
      return false;
    }
  }

  Future<void> _pickVideos() async {
    if (_isPickingMedia) {
      _showSnackBar('El selector ya está activo, por favor espere.'.tr(), Colors.orange);
      return;
    }
    _isPickingMedia = true;
    try {
      final ImagePicker picker = ImagePicker();
      // ✅ Estabilidad: usar selección de un solo video
      final XFile? singleVideo = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 1),
      );

      if (singleVideo != null) {
        int? fileSize;
        try {
          fileSize = await singleVideo.length();
        } catch (e) {
          debugPrint('No se pudo leer tamaño de video ${singleVideo.name}: $e');
        }
        if (fileSize != null && fileSize > (_maxFileSizeMB * 1024 * 1024)) {
          _showSnackBar('El video ${singleVideo.name} excede el tamaño máximo de ${_maxFileSizeMB}MB.'.tr(), Colors.red);
        } else {
          if (!mounted) return;
          setState(() {
            if (_selectedVideos.length < 3) {
              _selectedVideos.add(singleVideo);
            } else {
              _showSnackBar('Has alcanzado el límite de 3 videos.'.tr(), Colors.orange);
            }
          });
        }
      } else {
        _showSnackBar('No se seleccionó ningún video.'.tr(), Colors.orange);
      }
    } on PlatformException catch (e) {
      debugPrint('ERROR PICK VIDEOS: ${e.code} - ${e.message}');
      _showSnackBar('No se pudo abrir el selector de videos: ${e.message}'.tr(), Colors.red);
    } catch (e) {
      debugPrint('ERROR PICK VIDEOS (general): ${e.toString()}');
      _showSnackBar('Error al seleccionar videos: ${e.toString()}'.tr(), Colors.red);
    } finally {
      _isPickingMedia = false;
    }
  }

  Future<void> _captureImageFromCamera() async {
    if (_isPickingMedia) {
      _showSnackBar('El selector ya está activo, por favor espere.'.tr(), Colors.orange);
      return;
    }
    _isPickingMedia = true;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 600,
      );

      if (image != null) {
        if (!mounted) return;
        setState(() {
          if (_selectedImages.length < 5) {
            _selectedImages.add(image);
          } else {
            _showSnackBar('Has alcanzado el límite de 5 imágenes.'.tr(), Colors.orange);
          }
        });
      }
    } on PlatformException catch (e) {
      debugPrint('ERROR CAPTURE IMAGE: ${e.code} - ${e.message}');
      _showSnackBar('No se pudo abrir la cámara: ${e.message}'.tr(), Colors.red);
    } catch (e) {
      debugPrint('ERROR CAPTURE IMAGE (general): ${e.toString()}');
      _showSnackBar('Error al capturar imagen: ${e.toString()}'.tr(), Colors.red);
    } finally {
      _isPickingMedia = false;
    }
  }

  Future<void> _captureVideoFromCamera() async {
    if (_isPickingMedia) {
      _showSnackBar('El selector ya está activo, por favor espere.'.tr(), Colors.orange);
      return;
    }
    _isPickingMedia = true;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 1),
      );

      if (video != null) {
        int? fileSize;
        try {
          fileSize = await video.length();
        } catch (e) {
          debugPrint('No se pudo leer tamaño de video capturado ${video.name}: $e');
        }
        if (fileSize != null && fileSize > (_maxFileSizeMB * 1024 * 1024)) {
          _showSnackBar('El video ${video.name} excede el tamaño máximo de ${_maxFileSizeMB}MB.'.tr(), Colors.red);
        } else {
          if (!mounted) return;
          setState(() {
            if (_selectedVideos.length < 3) {
              _selectedVideos.add(video);
            } else {
              _showSnackBar('Has alcanzado el límite de 3 videos.'.tr(), Colors.orange);
            }
          });
        }
      }
    } on PlatformException catch (e) {
      debugPrint('ERROR CAPTURE VIDEO: ${e.code} - ${e.message}');
      _showSnackBar('No se pudo abrir la cámara de video: ${e.message}'.tr(), Colors.red);
    } catch (e) {
      debugPrint('ERROR CAPTURE VIDEO (general): ${e.toString()}');
      _showSnackBar('Error al capturar video: ${e.toString()}'.tr(), Colors.red);
    } finally {
      _isPickingMedia = false;
    }
  }

  void _removeImage(int index) {
    if (!mounted) return;
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeVideo(int index) {
    if (!mounted) return;
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

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _showGlobalUploadOverlay = true;
      _globalUploadMessage = 'Preparando subida...';
      _overallUploadProgress = 0.0;
      _overallTotalItems = _selectedImages.length + _selectedVideos.length;
    });

    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      _showSnackBar('Debes iniciar sesión para crear una solicitud.'.tr(), Colors.red);
      if(mounted) setState(() { _isLoading = false; });
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      if (userData == null || userData['name'] == null || userData['name'].toString().isEmpty || userData['name'].toString() == 'Usuario anónimo'.tr() || (userData['profilePicture'] == null || userData['profilePicture'].toString().isEmpty)) {
        _showSnackBar("Por favor, completa tu perfil con un nombre y una foto antes de crear una solicitud.".tr(), Colors.orange);
        if(mounted) setState(() { _isLoading = false; });
        return;
      }
      
      // Datos base de la solicitud (sin esperar a subir medios)
      final requesterName = userData['name']?.toString() ?? 'Usuario anónimo'.tr();
      final profileImagePath = userData['profilePicture']?.toString() ?? '';
      final requestDataToSave = {
        'userId': currentUser.uid,
        'requesterName': requesterName,
        'profileImagePath': profileImagePath,
        'phone': _phoneNumberDisplayController.text.trim(),
        'email': _emailDisplayController.text.trim(),
        'address': _addressDisplayController.text.trim(),
        'fecha_nacimiento': _dobDisplayController.text.trim(),
        'titulo': _descriptionController.text.trim(),
        'descripcion': _descriptionController.text.trim(),
        'detalle': _detailsController.text.trim().isEmpty ? 'Sin detalles'.tr() : _detailsController.text.trim(),
        'localidad': _localityController.text.trim(),
        'provincia': _userProvinceName?.toString() ?? 'San Juan'.tr(),
        'country': _userCountryName?.toString() ?? 'Argentina'.tr(),
        'countryCode': _userCountryName?.toString(),
        'categoria': _selectedCategory?.toString(),
        'prioridad': _selectedPriority?.toString(),
        'latitude': _requestLatitude,
        'longitude': _requestLongitude,
        'timestamp': FieldValue.serverTimestamp(),
        'estado': 'activa',
        'imagenes': [],
        'videos': [],
        'offersCount': 0,
        'commentsCount': 0,
        'showWhatsapp': _showWhatsapp,
        'showEmail': _showEmail,
        'showAddress': _showAddress,
        'publishedAt': FieldValue.serverTimestamp(),
        'moderation': {
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      };

      final docRef = await _firestore.collection('solicitudes-de-ayuda').add(requestDataToSave);
      final String docPath = docRef.path;

      print('DEBUG CREATE: Solicitud guardada. Iniciando subidas en segundo plano (docPath=$docPath)');
      _showSnackBar('Solicitud enviada. Estamos subiendo tus medios en segundo plano.'.tr(), Colors.green);
      // Refrescar inmediatamente el listado principal para que aparezca la tarjeta al instante
      try {
        ref.invalidate(rawHelpRequestsStreamProvider);
        ref.invalidate(filteredHelpRequestsProvider);
      } catch (e) {
        debugPrint('WARN: No se pudo invalidar proveedores tras crear solicitud: $e');
      }

      // Inicializar contadores de subida para emitir una notificación de éxito al finalizar
      if (mounted) {
        setState(() {
          _overallTotalItems = _selectedImages.length + _selectedVideos.length;
          _completedUploadItems = 0;
        });
      }

      // No enviamos notificación "en verificación" inmediata; se enviará éxito al finalizar todas las subidas

      // Lanzar subidas en segundo plano a carpetas públicas (requests/, videos/) con metadata docPath
      // Imágenes
      for (final imageSource in _selectedImages) {
        try {
          // Inicializar progreso para evitar quedarse en "guardando" si falla temprano
          if (mounted) {
            setState(() {
              _imageUploadProgress[imageSource.name] = 0.0;
              _updateOverallProgress();
            });
          }
          final String fileName = 'requests/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}_${imageSource.name}';
          final ref = _storage.ref().child(fileName);
          if (kIsWeb) {
            final bytes = await imageSource.readAsBytes();
            final uploadTask = ref.putData(bytes, SettableMetadata(
              contentType: imageSource.mimeType ?? 'image/jpeg',
              customMetadata: { 'docPath': docPath },
            ));
            uploadTask.snapshotEvents.listen((snapshot) {
              if (!mounted) return;
              final int total = snapshot.totalBytes;
              final int transferred = snapshot.bytesTransferred;
              final double progress = total > 0 ? (transferred / total) : 0.0;
              setState(() {
                _imageUploadProgress[imageSource.name] = progress;
                _updateOverallProgress();
              });
            });
            uploadTask.whenComplete(() async {
              if (!mounted) return;
              setState(() {
                _imageUploadProgress.remove(imageSource.name);
                _updateOverallProgress();
              });
              try {
                await docRef.update({'imagenes': FieldValue.arrayUnion([fileName])});
              } catch (e) {
                debugPrint('WARN: No se pudo actualizar imagenes con $fileName: $e');
              }
              _onUploadItemCompleted(docRef.id);
            });
          } else {
            final metadata = SettableMetadata(
              contentType: imageSource.mimeType ?? 'image/jpeg',
              customMetadata: { 'docPath': docPath },
            );
            if (imageSource.path.toLowerCase().startsWith('content://')) {
              final String tempPath = '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}_${imageSource.name}';
              bool savedToTemp = false;
              try {
                await imageSource.saveTo(tempPath);
                savedToTemp = true;
              } catch (e) {
                debugPrint('WARN: saveTo falló para imagen ${imageSource.name}: $e');
              }

              if (savedToTemp) {
                final File tempFile = File(tempPath);
                final uploadTask = ref.putFile(tempFile, metadata);
                uploadTask.whenComplete(() async {
                  try { await tempFile.delete(); } catch (_) {}
                  if (!mounted) return;
                  setState(() {
                    _imageUploadProgress.remove(imageSource.name);
                    _updateOverallProgress();
                  });
                  try {
                    await docRef.update({'imagenes': FieldValue.arrayUnion([fileName])});
                  } catch (e) {
                    debugPrint('WARN: No se pudo actualizar imagenes con $fileName: $e');
                  }
                  _onUploadItemCompleted(docRef.id);
                });
                uploadTask.snapshotEvents.listen((snapshot) {
                  if (!mounted) return;
                  final int total = snapshot.totalBytes;
                  final int transferred = snapshot.bytesTransferred;
                  final double progress = total > 0 ? (transferred / total) : 0.0;
                  setState(() {
                    _imageUploadProgress[imageSource.name] = progress;
                    _updateOverallProgress();
                  });
                }, onError: (error, stack) {
                  debugPrint('ERROR CREATE: snapshotEvents imagen ${imageSource.name} (tempFile): $error');
                  if (mounted) {
                    setState(() {
                      _imageUploadProgress.remove(imageSource.name);
                      _updateOverallProgress();
                    });
                  }
                  _onUploadItemCompleted(docRef.id);
                });
              } else {
                // Fallback: subir como bytes
                try {
                  final bytes = await imageSource.readAsBytes();
                  final uploadTask = ref.putData(bytes, metadata);
                  uploadTask.snapshotEvents.listen((snapshot) {
                    if (!mounted) return;
                    final int total = snapshot.totalBytes;
                    final int transferred = snapshot.bytesTransferred;
                    final double progress = total > 0 ? (transferred / total) : 0.0;
                    setState(() {
                      _imageUploadProgress[imageSource.name] = progress;
                      _updateOverallProgress();
                    });
                  }, onError: (error, stack) {
                    debugPrint('ERROR CREATE: snapshotEvents imagen ${imageSource.name} (putData): $error');
                    if (mounted) {
                      setState(() {
                        _imageUploadProgress.remove(imageSource.name);
                        _updateOverallProgress();
                      });
                    }
                    _onUploadItemCompleted(docRef.id);
                  });
                  uploadTask.whenComplete(() async {
                    if (!mounted) return;
                    setState(() {
                      _imageUploadProgress.remove(imageSource.name);
                      _updateOverallProgress();
                    });
                    try {
                      await docRef.update({'imagenes': FieldValue.arrayUnion([fileName])});
                    } catch (e) {
                      debugPrint('WARN: No se pudo actualizar imagenes con $fileName: $e');
                    }
                    _onUploadItemCompleted(docRef.id);
                  });
                } catch (e) {
                  debugPrint('ERROR CREATE: Fallback putData imagen ${imageSource.name} falló: $e');
                  if (mounted) {
                    setState(() {
                      _imageUploadProgress.remove(imageSource.name);
                      _updateOverallProgress();
                    });
                  }
                  _onUploadItemCompleted(docRef.id);
                }
              }
            } else {
              final uploadTask = ref.putFile(File(imageSource.path), metadata);
                uploadTask.snapshotEvents.listen((snapshot) {
                  if (!mounted) return;
                  final int total = snapshot.totalBytes;
                  final int transferred = snapshot.bytesTransferred;
                  final double progress = total > 0 ? (transferred / total) : 0.0;
                  setState(() {
                    _imageUploadProgress[imageSource.name] = progress;
                    _updateOverallProgress();
                  });
                }, onError: (error, stack) {
                  debugPrint('ERROR CREATE: snapshotEvents imagen ${imageSource.name} (direct): $error');
                  if (mounted) {
                    setState(() {
                      _imageUploadProgress.remove(imageSource.name);
                      _updateOverallProgress();
                    });
                  }
                  _onUploadItemCompleted(docRef.id);
                });
              uploadTask.whenComplete(() async {
                if (!mounted) return;
                setState(() {
                  _imageUploadProgress.remove(imageSource.name);
                  _updateOverallProgress();
                });
                try {
                  await docRef.update({'imagenes': FieldValue.arrayUnion([fileName])});
                } catch (e) {
                  debugPrint('WARN: No se pudo actualizar imagenes con $fileName: $e');
                }
                _onUploadItemCompleted(docRef.id);
              });
            }
          }
        } catch (e) {
          debugPrint('ERROR CREATE: Falla subida imagen bg ${imageSource.name}: $e');
          // Marcar como completado para no dejar el overlay colgado
          if (mounted) {
            setState(() {
              _imageUploadProgress.remove(imageSource.name);
              _updateOverallProgress();
            });
          }
          _onUploadItemCompleted(docRef.id);
          _showSnackBar('Error subiendo imagen: ${imageSource.name}'.tr(), Colors.red);
        }
      }

      // Videos
      for (final videoSource in _selectedVideos) {
        try {
          if (mounted) {
            setState(() { _videoUploadProgress[videoSource.name] = 0.0; _updateOverallProgress(); });
          }
          final String fileName = 'videos/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}_${videoSource.name}';
          final String contentType = videoSource.mimeType?.toString() ?? 'video/mp4';
          final ref = _storage.ref().child(fileName);
          UploadTask uploadTask;
          final metadata = SettableMetadata(contentType: contentType, customMetadata: { 'docPath': docPath });
          if (kIsWeb) {
            final bytes = await videoSource.readAsBytes();
            uploadTask = ref.putData(bytes, metadata);
          } else {
            if (videoSource.path.startsWith('content://')) {
              final String tempPath = '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}_${videoSource.name}';
              bool savedToTemp = false;
              try {
                await videoSource.saveTo(tempPath);
                savedToTemp = true;
              } catch (e) {
                debugPrint('WARN: saveTo falló para video ${videoSource.name} (content://): $e');
              }
              if (savedToTemp) {
                final File tempFile = File(tempPath);
                uploadTask = ref.putFile(tempFile, metadata);
                uploadTask.whenComplete(() async { try { await tempFile.delete(); } catch (_) {} });
              } else {
                // Fallback: copiar por stream a archivo temporal, y si falla, usar ruta directa
                try {
                  final File tempFile = File(tempPath);
                  final IOSink sink = tempFile.openWrite();
                  // Corrige el tipo genérico del stream: Stream<Uint8List> -> Stream<List<int>>
                  await sink.addStream(videoSource.openRead().cast<List<int>>());
                  await sink.close();
                  uploadTask = ref.putFile(tempFile, metadata);
                  uploadTask.whenComplete(() async { try { await tempFile.delete(); } catch (_) {} });
                } catch (e) {
                  debugPrint('ERROR CREATE: Fallback stream copy video ${videoSource.name} falló: $e');
                  // Último recurso seguro en content://: subir como bytes
                  try {
                    final Uint8List bytes = await videoSource.readAsBytes();
                    uploadTask = ref.putData(bytes, metadata);
                  } catch (e2) {
                    debugPrint('ERROR CREATE: readAsBytes falló para video ${videoSource.name}: $e2');
                    // Si también falla, intenta ruta directa (puede no funcionar con content://)
                    uploadTask = ref.putFile(File(videoSource.path), metadata);
                  }
                }
              }
            } else {
              // 📦 Unificar manejo: copiar siempre a archivo temporal para evitar issues con rutas
              final String tempPath = '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}_${videoSource.name}';
              try {
                await videoSource.saveTo(tempPath);
              } catch (e) {
                debugPrint('WARN: saveTo falló para video ${videoSource.name}, usando ruta directa: $e');
              }
              final File tempFile = File(tempPath);
              if (await tempFile.exists()) {
                uploadTask = ref.putFile(tempFile, metadata);
                uploadTask.whenComplete(() async { try { await tempFile.delete(); } catch (_) {} });
              } else {
                // Fallback si la copia falla: intentar ruta directa
                uploadTask = ref.putFile(File(videoSource.path), metadata);
              }
            }
          }
          uploadTask.snapshotEvents.listen((snapshot) {
            if (!mounted) return;
            final int total = snapshot.totalBytes;
            final int transferred = snapshot.bytesTransferred;
            final double progress = total > 0 ? (transferred / total) : 0.0;
            setState(() {
              _videoUploadProgress[videoSource.name] = progress;
              _updateOverallProgress();
            });
          }, onError: (error, stack) {
            debugPrint('ERROR CREATE: snapshotEvents video ${videoSource.name}: $error');
            if (mounted) {
              setState(() {
                _videoUploadProgress.remove(videoSource.name);
                _updateOverallProgress();
              });
            }
            _onUploadItemCompleted(docRef.id);
          });
          uploadTask.whenComplete(() async {
            if (!mounted) return;
            setState(() { _videoUploadProgress.remove(videoSource.name); _updateOverallProgress(); });
            try {
              await docRef.update({'videos': FieldValue.arrayUnion([fileName])});
            } catch (e) {
              debugPrint('WARN: No se pudo actualizar videos con $fileName: $e');
            }
            _onUploadItemCompleted(docRef.id);
          });
        } catch (e) {
          debugPrint('ERROR CREATE: Falla subida video bg ${videoSource.name}: $e');
          // Marcar como completado para no dejar el overlay colgado
          if (mounted) {
            setState(() {
              _videoUploadProgress.remove(videoSource.name);
              _updateOverallProgress();
            });
          }
          _onUploadItemCompleted(docRef.id);
          _showSnackBar('Error subiendo video: ${videoSource.name}'.tr(), Colors.red);
        }
      }

      // Cerrar pantalla para que el usuario continúe usando la app
      if (mounted) {
        setState(() { _showGlobalUploadOverlay = false; });
        Navigator.pop(context);
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
        debugPrint("DEBUG CREATE: Firebase Auth Exception al crear solicitud: ${e.code} - ${e.message}");
        _showSnackBar('Error de autenticación: ${e.message}. Por favor, vuelve a iniciar sesión si el problema persiste.'.tr(), Colors.red);
    } on FirebaseException catch (e) {
      debugPrint("DEBUG CREATE: Firebase Exception al crear solicitud: ${e.code} - ${e.message}");
      _showSnackBar('Error de Firebase: ${e.message}'.tr(), Colors.red);
    } catch (e) {
      debugPrint("DEBUG CREATE: Error general al crear solicitud: ${e.toString()}");
      _showSnackBar('Error al crear la solicitud: ${e.toString()}'.tr(), Colors.red);
    } finally {
      if(mounted) setState(() { 
        _isLoading = false; 
        _showGlobalUploadOverlay = false; 
        _overallUploadProgress = 0.0;
        _globalUploadMessage = 'Subida completa';
      });
    }
  }

  void _updateOverallProgress() {
    // Calcula progreso global considerando imágenes y videos
    final int totalItems = _overallTotalItems == 0 ? (_selectedImages.length + _selectedVideos.length) : _overallTotalItems;
    final double imagesProgressSum = _imageUploadProgress.values.fold(0.0, (a, b) => a + b);
    final double videosProgressSum = _videoUploadProgress.values.fold(0.0, (a, b) => a + b);
    final int itemsInProgress = _imageUploadProgress.length + _videoUploadProgress.length;
    final int completedItems = (totalItems - itemsInProgress).clamp(0, totalItems);
    // completedItems cuentan como 1.0 cada uno
    final double totalProgress = (imagesProgressSum + videosProgressSum + completedItems) / (totalItems == 0 ? 1 : totalItems);
    _overallUploadProgress = totalProgress.clamp(0.0, 1.0);
  }

  void _onUploadItemCompleted(String requestId) {
    _completedUploadItems++;
    final int totalItems = _overallTotalItems == 0 ? (_selectedImages.length + _selectedVideos.length) : _overallTotalItems;
    if (_completedUploadItems >= totalItems && totalItems > 0) {
      _notifyUploadSuccess(requestId);
    }
  }

  Future<void> _notifyUploadSuccess(String requestId) async {
    // Marcar como publicado y aprobado para que aparezca en Main y dispare triggers
    try {
      await _firestore.collection('solicitudes-de-ayuda').doc(requestId).set({
        'moderation': {
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'publishedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Refrescar los listados de Main inmediatamente después de aprobar/publicar
      try {
        ref.invalidate(rawHelpRequestsStreamProvider);
        ref.invalidate(filteredHelpRequestsProvider);
      } catch (e) {
        debugPrint('WARN: No se pudo invalidar proveedores tras publicar: $e');
      }
    } catch (e) {
      debugPrint('WARN: No se pudo marcar la solicitud como approved: $e');
    }

    try {
      await _notificationService.showLocalNotification(
        title: 'Solicitud publicada',
        body: 'Tu solicitud fue cargada con éxito.',
        payloadRoute: '/request/$requestId',
      );
    } catch (e) {
      debugPrint('WARN: Falló notificación local de éxito: $e');
    }

    try {
      final firebase_auth.User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _appServices.addNotification(
          recipientId: currentUser.uid,
          type: 'request_uploaded',
          title: 'Solicitud publicada',
          body: 'Tu solicitud fue cargada con éxito.',
          data: {
            'notificationType': 'request_uploaded',
            'requestId': requestId,
            'route': '/request/$requestId',
          },
        );
      }
    } catch (e) {
      debugPrint('WARN: No se pudo registrar notificación de éxito: $e');
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
      body: CustomBackground(
        child: Stack(
          children: [
            showLoading
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datos del Solicitante'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Center(
                      child: AvatarOptimizado(
                        url: (_userAvatarPath != null && _userAvatarPath!.startsWith('http')) ? _userAvatarPath : null,
                        storagePath: (_userAvatarPath != null && !_userAvatarPath!.startsWith('http')) ? _userAvatarPath : null,
                        radius: 40,
                        backgroundColor: Colors.grey[700],
                        placeholder: const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey,
                          backgroundImage: AssetImage('assets/default_avatar.png'),
                        ),
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
                          onTap: (_selectedImages.length < 5 && !_isPickingMedia) ? _pickImages : null,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white54),
                            ),
                            child: _isPickingMedia
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                : const Icon(Icons.add_a_photo, color: Colors.white70, size: 30),
                          ),
                        ),
                        GestureDetector(
                          onTap: (_selectedImages.length < 5 && !_isPickingMedia) ? _captureImageFromCamera : null,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white54),
                            ),
                            child: _isPickingMedia
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                : const Icon(Icons.photo_camera, color: Colors.white70, size: 30),
                          ),
                        ),
                        ..._selectedImages.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final XFile imageSource = entry.value; // ✅ Usamos XFile

                          Widget imageWidget;
                          if (kIsWeb) {
                            imageWidget = FutureBuilder<Uint8List>(
                              future: imageSource.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                  return Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover);
                                }
                                return const SizedBox(width: 80, height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)));
                              },
                            );
                          } else {
                            // ✅ En móvil: si es content:// (Google Fotos), renderizamos por bytes; si no, por File
                            if (imageSource.path.startsWith('content://')) {
                              imageWidget = FutureBuilder<Uint8List>(
                                future: imageSource.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      cacheWidth: 160,
                                      cacheHeight: 160,
                                    );
                                  }
                                  return const SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                                  );
                                },
                              );
                            } else {
                              imageWidget = Image.file(
                                File(imageSource.path),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                cacheWidth: 160,
                                cacheHeight: 160,
                              );
                            }
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
                          onTap: (_selectedVideos.length < 3 && !_isPickingMedia) ? _pickVideos : null,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white54),
                            ),
                            child: _isPickingMedia
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                : const Icon(Icons.video_call, color: Colors.white70, size: 30),
                          ),
                        ),
                        GestureDetector(
                          onTap: (_selectedVideos.length < 3 && !_isPickingMedia) ? _captureVideoFromCamera : null,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white54),
                            ),
                            child: _isPickingMedia
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                : const Icon(Icons.videocam, color: Colors.white70, size: 30),
                          ),
                        ),
                        ..._selectedVideos.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final XFile videoSource = entry.value; // ✅ Usamos XFile

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
                                  videoSource.name,
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
                              // Overlay de progreso si el video está subiendo
                              if (_videoUploadProgress.containsKey(videoSource.name))
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: CircularProgressIndicator(
                                              value: _videoUploadProgress[videoSource.name],
                                              color: Colors.amber,
                                              strokeWidth: 3,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${((_videoUploadProgress[videoSource.name] ?? 0.0) * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
                    AdBannerWidget(adUnitId: AdsIds.banner),
                    const SizedBox(height: 20),

                    Center(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createRequest,
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
            if (_isPickingMedia)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.amber),
                        const SizedBox(height: 12),
                        Text(
                          'Abriendo el selector, por favor espere...'.tr(),
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_showGlobalUploadOverlay)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      width: 300,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _globalUploadMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _overallUploadProgress > 0.0 ? _overallUploadProgress : null,
                            color: Colors.amber,
                            backgroundColor: Colors.white10,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_overallUploadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}