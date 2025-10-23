// lib/screens/create_request_screen.dart
import 'dart:async';
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
import 'package:video_compress/video_compress.dart'; // Mantenido para compresión de imagen en isolate
import '../widgets/avatar_optimizado.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:eslabon_flutter/services/app_services.dart';
import 'package:eslabon_flutter/services/notification_service.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/spinning_image_loader.dart';
import '../widgets/ad_banner_widget.dart';
import '../services/ads_ids.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_background.dart';

// --- (Clase Country igual) ---
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

// =========================================================================
// FUNCIÓN DE COMPRESIÓN DE IMAGEN PARA ISOLATE (NIVEL SUPERIOR)
// =========================================================================
Future<Map<String, dynamic>?> _compressImageIsolate(String path) async {
  try {
    final File originalFile = File(path);
    if (!originalFile.existsSync()) return null;

    final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      originalFile.path,
      quality: VideoQuality.LowQuality,
      deleteOrigin: false,
      includeAudio: false,
      frameRate: 1, 
    );
    
    if (mediaInfo?.path != null) {
      final File compressedFile = File(mediaInfo!.path!);
      final int newSize = await compressedFile.length();
      
      return {
        'path': mediaInfo.path!,
        'name': 'compressed_image_${originalFile.uri.pathSegments.last}',
        'mimeType': 'image/jpeg', 
        'length': newSize,
      };
    }
  } catch (e) {
    debugPrint('ERROR AL COMPRIMIR IMAGEN EN ISOLATE: $e');
  }
  return null;
}
// =========================================================================


// --- (Clase CreateRequestScreen) ---
class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> with WidgetsBindingObserver {
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

  List<XFile> _selectedImages = []; // ✅ Lista de imágenes seleccionadas
  
  static const int _maxFileSizeMB = 20; // Límite general para imágenes
  
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
  // Caché de archivos temporales para previsualización de imágenes content://
  final Map<String, String> _previewTempPaths = {};

  // Función mejorada para previsualización (móvil)
  Future<String?> _ensureTempFileForContentImage(XFile image) async {
    // Si no es un content:// o ya tiene un path directo (ej. de cámara), lo usamos
    if (!image.path.toLowerCase().startsWith('content://')) return image.path;

    final String key = image.path;
    final String? existing = _previewTempPaths[key];
    if (existing != null && existing.isNotEmpty && File(existing).existsSync()) return existing;

    final String tempPath = '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}_${image.name}';

    // 1) Intentar guardado directo (método más rápido si funciona)
    try {
      await image.saveTo(tempPath);
      _previewTempPaths[key] = tempPath;
      return tempPath;
    } catch (e) {
      debugPrint('WARN: saveTo preview falló para ${image.name}: $e. Intentando streaming...');
    }

    // 2) Fallback: copiar por streaming para content:// (Google Fotos)
    try {
      final outFile = File(tempPath);
      // Aseguramos que el archivo no exista ya
      if (await outFile.exists()) await outFile.delete();
      final IOSink sink = outFile.openWrite();
      // Corrige el tipo del stream: Stream<Uint8List> -> Stream<List<int>>
      await sink.addStream(image.openRead().cast<List<int>>());
      await sink.flush();
      await sink.close();

      if (await outFile.length() > 0) { // Comprobar que se copió algo
        _previewTempPaths[key] = tempPath;
        return tempPath;
      }
      debugPrint('ERROR: streaming preview falló para ${image.name}: Archivo vacío.');
    } catch (e) {
      debugPrint('ERROR: streaming preview falló para ${image.name}: $e');
    }

    // 3) Último recurso: sin archivo temporal (no se puede previsualizar)
    return null;
  }
  
  // Evita reentrancia del ImagePicker (already_active)
  bool _isPickingMedia = false;
  // Evita múltiples pops al finalizar subidas
  bool _didNavigateAway = false;
  // Estado del ciclo de vida para evitar navegación/overlays durante inactive/paused
  bool _isLifecycleInactive = false;
  // Demorar cierre cuando la app vuelve a resumed
  bool _deferClose = false;
  // Timers de subida lenta por item
  final Map<String, Timer> _uploadStallTimers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appServices = AppServices(_firestore, _auth);
    _notificationService = NotificationService();
    _loadUserData();
    _determinePosition();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _descriptionController.dispose();
    _detailsController.dispose();
    _localityController.dispose();
    _phoneNumberDisplayController.dispose();
    _addressDisplayController.dispose();
    _nameDisplayController.dispose();
    _emailDisplayController.dispose();
    _dobDisplayController.dispose();
    // Limpieza de timers
    _uploadStallTimers.values.forEach((timer) => timer.cancel());
    _uploadStallTimers.clear();
    // Limpieza de archivos temporales de previsualización (no esenciales pero buenas prácticas)
    _previewTempPaths.values.forEach((path) {
      try { File(path).deleteSync(recursive: true); } catch (_) {}
    });
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isLifecycleInactive = (state == AppLifecycleState.inactive || state == AppLifecycleState.paused);
    if (state == AppLifecycleState.resumed) {
      if (_deferClose && mounted && !_didNavigateAway) {
        _deferClose = false;
        _safePop();
      }
    }
  }

  void _safePop() {
    if (!mounted || _didNavigateAway || _isLifecycleInactive) return;
    _didNavigateAway = true;
    Navigator.of(context).pop();
  }

  // ✅ FUNCIÓN DE NAVEGACIÓN ESTABLE AL FINALIZAR
  void _safeNavigateToDetails(String? requestId) {
    if (!mounted || _didNavigateAway) return;
    _didNavigateAway = true;
    
    final route = requestId != null ? '/request/$requestId' : '/main';

    // Ejecutar la navegación después de que el frame actual se haya renderizado y estabilizado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
            context.go(route);
        }
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted || _didNavigateAway || _isLifecycleInactive) return;
    AppServices.showSnackBar(context, message, color);
  }

  // --- (Métodos _determinePosition, _getAddressFromLatLng, _loadUserData sin cambios esenciales) ---

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
      
      List<XFile>? media;
      if (kIsWeb) {
        // Web: usar pickMultiImage con calidad optimizada
        media = await picker.pickMultiImage(
          imageQuality: 60,
          maxWidth: 700,
          maxHeight: 500,
        );
      } else {
        // Móvil (Android/iOS): intentar pickMultipleMedia y filtrar
        try {
          media = await picker.pickMultipleMedia();
        } on PlatformException catch (e) {
          debugPrint('pickMultipleMedia falló: ${e.code} - ${e.message}. Usando fallback...');
        }
        // Fallback si pickMultipleMedia no devuelve nada (común en algunas versiones/dispositivos)
        if (media == null || media.isEmpty) {
          try {
            media = await picker.pickMultiImage(
              imageQuality: 60,
              maxWidth: 700,
              maxHeight: 500,
            );
          } on PlatformException catch (e) {
            debugPrint('pickMultiImage fallback falló: ${e.code} - ${e.message}');
          }
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
          _showSnackBar('No se seleccionaron imágenes.'.tr(), Colors.orange);
        } else if (imagesOnly.length > 10) {
          _showSnackBar('Máximo 10 imágenes por vez. Selecciona menos imágenes.'.tr(), Colors.red);
        } else {
          // Validar tamaño antes de agregar
          final List<XFile> filteredBySize = [];
          for (final xFile in imagesOnly) {
            try {
              // kIsWeb no puede obtener length, se confía en el picker para optimizar
              if (!kIsWeb) { 
                final int size = await xFile.length();
                if (size > (_maxFileSizeMB * 1024 * 1024)) {
                  _showSnackBar('La imagen ${xFile.name} excede el tamaño máximo de ${_maxFileSizeMB}MB.'.tr(), Colors.red);
                  continue;
                }
              }
            } catch (e) {
              debugPrint('No se pudo leer tamaño de imagen ${xFile.name}: $e');
              // Si no podemos leer tamaño, la aceptamos pero con cautela
            }
            filteredBySize.add(xFile);
          }
          
          if (!mounted) return;
          // Mostrar indicador de carga
          setState(() {
            _showGlobalUploadOverlay = true;
            _globalUploadMessage = 'Procesando imágenes...'.tr();
          });
          
          // Procesar imágenes en lotes para evitar crash por memoria
          final List<XFile> compressedImages = [];
          const int batchSize = 3; // Procesar máximo 3 imágenes a la vez
          
          for (int i = 0; i < filteredBySize.length; i += batchSize) {
            final batch = filteredBySize.skip(i).take(batchSize).toList();
            final List<Future<XFile>> batchTasks = [];
            
            for (final xFile in batch) {
              batchTasks.add(
                compute<String, Map<String, dynamic>?>(
                  _compressImageIsolate, 
                  xFile.path,
                ).then((result) {
                  if (result != null) {
                    return XFile(
                      result['path'] as String, 
                      name: result['name'] as String?, 
                      mimeType: result['mimeType'] as String?, 
                      length: result['length'] as int?,
                    );
                  }
                  return xFile; // Devolver original como fallback
                })
              );
            }
            
            final List<XFile> batchResults = await Future.wait(batchTasks);
            compressedImages.addAll(batchResults);
            
            // Pequeña pausa entre lotes para liberar memoria
            await Future.delayed(const Duration(milliseconds: 100));
            
            // Actualizar mensaje de progreso
            if (mounted) {
              setState(() {
                _globalUploadMessage = 'Procesando imágenes... ${compressedImages.length}/${filteredBySize.length}'.tr();
              });
            }
          }

          // Ocultar indicador de carga y añadir imágenes (UN SOLO setState CRÍTICO)
          if (mounted) {
            final int maxImagesToAddAtOnce = 8;
            final List<XFile> limitedImages = compressedImages.take(maxImagesToAddAtOnce).toList();
            
            setState(() {
              _showGlobalUploadOverlay = false; // Ocultar overlay
              _globalUploadMessage = 'Subiendo archivos...'; // Resetear mensaje

              int remainingSlots = 8 - _selectedImages.length;
              for (XFile xFile in limitedImages) {
                if (remainingSlots <= 0) {
                  _showSnackBar('Has alcanzado el límite de 8 imágenes.'.tr(), Colors.orange);
                  break;
                }
                _selectedImages.add(xFile);
                remainingSlots--;
              }
              
              // Si hay más imágenes que no se agregaron, mostrar mensaje
              if (filteredBySize.length > limitedImages.length) {
                _showSnackBar('Solo se pudieron agregar ${limitedImages.length} imágenes (límite alcanzado o error al procesar el resto).'.tr(), Colors.orange);
              }
            });
          }
        }
      } else {
        _showSnackBar('No se seleccionaron fotos.'.tr(), Colors.orange);
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
        imageQuality: 60,
        maxWidth: 800,
        maxHeight: 600,
      );

      if (image != null) {
        bool tooBig = false;
        try {
          if (!kIsWeb) {
            final int size = await image.length();
            tooBig = size > (_maxFileSizeMB * 1024 * 1024);
          }
        } catch (e) {
          debugPrint('No se pudo leer tamaño de imagen capturada ${image.name}: $e');
        }
        if (tooBig) {
          _showSnackBar('La imagen ${image.name} excede el tamaño máximo de ${_maxFileSizeMB}MB.'.tr(), Colors.red);
        } else {
          if (!mounted) return;
          // Mostrar indicador de carga
          setState(() {
            _showGlobalUploadOverlay = true;
            _globalUploadMessage = 'Procesando imagen...'.tr();
          });
          
          // Usar compute para la compresión de la imagen
          final Map<String, dynamic>? result = await compute<String, Map<String, dynamic>?>(
            _compressImageIsolate, 
            image.path,
          );
          
          XFile? compressedImage;
          if (result != null) {
            compressedImage = XFile(
              result['path'] as String, 
              name: result['name'] as String?, 
              mimeType: result['mimeType'] as String?, 
              length: result['length'] as int?,
            );
          } else {
            compressedImage = image; // Usar original como fallback
          }

          // Ocultar indicador de carga y añadir imagen (UN SOLO setState CRÍTICO)
          if (mounted) {
             setState(() {
              _showGlobalUploadOverlay = false; // Ocultar overlay
              _globalUploadMessage = 'Subiendo archivos...'; // Resetear mensaje

              if (compressedImage != null) {
                if (_selectedImages.length < 5) {
                  _selectedImages.add(compressedImage!);
                } else {
                  _showSnackBar('Has alcanzado el límite de 8 imágenes.'.tr(), Colors.orange);
                }
              }
            });
          }
        }
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


  void _removeImage(int index) {
    if (!mounted) return;
    setState(() {
      final XFile removed = _selectedImages.removeAt(index);
      // Intentar limpiar archivo temporal de previsualización si existiera
      final String? tempPath = _previewTempPaths.remove(removed.path);
      if (tempPath != null && tempPath.isNotEmpty) {
        try { File(tempPath).deleteSync(recursive: true); } catch (_) {}
      }
    });
  }


  // Helper para crear un archivo temporal en móvil/desktop para subida
  Future<File?> _createTempFileForUpload(XFile source) async {
    if (kIsWeb) return null; // Web no usa File

    // Usamos el path directo del XFile (que ahora es el path comprimido si aplica)
    final String sourcePath = source.path;
    final File sourceFile = File(sourcePath);

    // Si la ruta del XFile ya apunta a un archivo accesible (como un temporal o un archivo de cámara),
    // no necesitamos copiarlo de nuevo por streaming.
    if (sourceFile.existsSync() && !sourcePath.toLowerCase().startsWith('content://')) {
      return sourceFile;
    }

    final String tempPath = '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}_${source.name}';
    final File tempFile = File(tempPath);

    // 1. Intentar saveTo (más rápido y nativo)
    try {
      await source.saveTo(tempPath);
      if (await tempFile.exists() && await tempFile.length() > 0) {
        debugPrint('DEBUG CREATE: Archivo temporal creado con saveTo para ${source.name}');
        return tempFile;
      }
    } catch (e) {
      debugPrint('WARN: saveTo falló para ${source.name}: $e. Intentando streaming...');
    }

    // 2. Fallback: copiar por streaming (más robusto para content://)
    try {
      if (await tempFile.exists()) await tempFile.delete(); // Limpiar intento fallido anterior
      final IOSink sink = tempFile.openWrite();
      // Corrige el tipo genérico del stream: Stream<Uint8List> -> Stream<List<int>>
      await sink.addStream(source.openRead().cast<List<int>>());
      await sink.flush();
      await sink.close();

      if (await tempFile.exists() && await tempFile.length() > 0) {
        debugPrint('DEBUG CREATE: Archivo temporal creado con streaming para ${source.name}');
        return tempFile;
      }
    } catch (e) {
      debugPrint('ERROR: Fallback streaming falló para ${source.name}: $e');
    }

    return null;
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
      _overallTotalItems = _selectedImages.length; // Solo imágenes
    });

    final firebase_auth.User? currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      _showSnackBar('Debes iniciar sesión para crear una solicitud.'.tr(), Colors.red);
      if(mounted) setState(() { _isLoading = false; _showGlobalUploadOverlay = false; });
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      if (userData == null || userData['name'] == null || userData['name'].toString().isEmpty || userData['name'].toString() == 'Usuario anónimo'.tr() || (userData['profilePicture'] == null || userData['profilePicture'].toString().isEmpty)) {
        _showSnackBar("Por favor, completa tu perfil con un nombre y una foto antes de crear una solicitud.".tr(), Colors.orange);
        if(mounted) setState(() { _isLoading = false; _showGlobalUploadOverlay = false; });
        return;
      }
      
      // Datos base de la solicitud
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
        'imageUrls': [], // Se llenará con las URLs de las imágenes
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
      final String requestId = docRef.id;
      final String docPath = docRef.path; // Definición correcta del docPath para el upload

      print('DEBUG CREATE: Solicitud guardada. Iniciando subidas en segundo plano (requestId=$requestId)');
      _showSnackBar('Solicitud enviada. Estamos subiendo tus medios en segundo plano.'.tr(), Colors.green);
      // Refrescar inmediatamente el listado principal
      try {
        ref.invalidate(rawHelpRequestsStreamProvider);
        ref.invalidate(filteredHelpRequestsProvider);
      } catch (e) {
        debugPrint('WARN: No se pudo invalidar proveedores tras crear solicitud: $e');
      }

      // Inicializar contadores de subida para emitir una notificación de éxito al finalizar
      if (mounted && !_didNavigateAway) {
        setState(() {
          _overallTotalItems = _selectedImages.length;
          _completedUploadItems = 0;
        });
      }

      // Si no hay imágenes, notificar éxito inmediatamente
      if (_selectedImages.isEmpty) {
        _notifyUploadSuccess(requestId);
      }

      // Lanzar subidas en paralelo y esperar su finalización
      final List<Future<void>> uploadTasksFutures = [];

      // Imágenes
      for (final imageSource in _selectedImages) {
        uploadTasksFutures.add(
          _uploadImage(imageSource, currentUser, docPath, docRef) // FIX: Pasar docPath correctamente
        );
      }

      // Esperar a que todas las subidas finalicen.
      Future.wait(uploadTasksFutures).then((_) {
        debugPrint('DEBUG CREATE: Todas las subidas de medios han finalizado.');
        // FIX CRÍTICO: Navegar a la pantalla de detalle de forma robusta
        _safeNavigateToDetails(requestId); 
      }).catchError((e) {
        debugPrint('ERROR CREATE: Una o más subidas de medios fallaron: $e');
        // Navegar incluso si falla alguna subida (para que el usuario no se quede atascado)
        _safeNavigateToDetails(requestId);
      });


      // Cerrar pantalla solo si no hay medios a subir; de lo contrario, esperar a completarlos
      if (mounted && !_didNavigateAway) {
        setState(() { _showGlobalUploadOverlay = false; });
        final int totalItems = _overallTotalItems == 0 ? _selectedImages.length : _overallTotalItems;
        if (totalItems == 0 && !_didNavigateAway) {
          if (_isLifecycleInactive) {
            _deferClose = true;
          } else {
             _safeNavigateToDetails(requestId); // Navegación para el caso sin imágenes
          }
        }
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
      // Nota: El overlay y _isLoading se desactivarán en _onUploadItemCompleted cuando totalItems > 0
      if (mounted && !_didNavigateAway && _overallTotalItems == 0) {
        setState(() { 
          _isLoading = false; 
          _showGlobalUploadOverlay = false; 
          _overallUploadProgress = 0.0;
          _globalUploadMessage = 'Subida completa';
        });
      }
    }
  }

  // Nuevo método para subir una imagen de forma estable
  Future<void> _uploadImage(XFile imageSource, firebase_auth.User currentUser, String docPath, DocumentReference docRef) async {
    File? tempFile;
    try {
      // 1. Inicializar progreso
      if (mounted && !_didNavigateAway) {
        setState(() {
          _imageUploadProgress[imageSource.name] = 0.0;
          _updateOverallProgress();
        });
      }

      final String fileName = 'requests/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}_${imageSource.name}';
      final Reference ref = _storage.ref().child(fileName);
      final metadata = SettableMetadata(
        contentType: imageSource.mimeType ?? 'image/jpeg',
        customMetadata: { 'docPath': docPath },
      );

      UploadTask uploadTask;
      bool hadError = false;

      if (kIsWeb) {
        final bytes = await imageSource.readAsBytes();
        uploadTask = ref.putData(bytes, metadata);
      } else {
        // Móvil/Desktop: Usar archivo temporal para estabilidad (content:// o archivos grandes)
        tempFile = await _createTempFileForUpload(imageSource);
        if (tempFile != null) {
          uploadTask = ref.putFile(tempFile, metadata);
        } else {
          // Si falló crear el temporal (error grave o ruta no accesible), lo intentamos con putData como último recurso.
          // Esto es arriesgado con imágenes grandes.
          debugPrint('WARN: Fallback a putData para imagen ${imageSource.name}. Riesgo de OOM.');
          final bytes = await imageSource.readAsBytes();
          uploadTask = ref.putData(bytes, metadata);
        }
      }

      uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted || _didNavigateAway) return;
        final int total = snapshot.totalBytes;
        final int transferred = snapshot.bytesTransferred;
        final double progress = total > 0 ? (transferred / total) : 0.0;
        setState(() {
          _imageUploadProgress[imageSource.name] = progress;
          _updateOverallProgress();
        });
      }, onError: (error, stack) {
        hadError = true;
        debugPrint('ERROR CREATE: snapshotEvents imagen ${imageSource.name}: $error');
        if (mounted && !_didNavigateAway) {
          setState(() {
            _imageUploadProgress.remove(imageSource.name);
            _updateOverallProgress();
          });
        }
      });

      await uploadTask.whenComplete(() async {
        if (!mounted || _didNavigateAway) return;
        setState(() {
          _imageUploadProgress.remove(imageSource.name);
          _updateOverallProgress();
        });
        try {
          final bool success = uploadTask.snapshot.state == TaskState.success;
          if (!hadError && success) {
            final String downloadUrl = await ref.getDownloadURL();
            await docRef.update({'imageUrls': FieldValue.arrayUnion([downloadUrl])});
          } else {
            debugPrint('WARN: Imagen ${imageSource.name} no se añadirá: hadError=$hadError, state=${uploadTask.snapshot.state}');
          }
        } catch (e) {
          debugPrint('WARN: No se pudo actualizar imageUrls con $fileName: $e');
        }
        _onUploadItemCompleted(docRef.id);
      });
      
    } catch (e) {
      debugPrint('ERROR CREATE: Falla subida imagen bg ${imageSource.name}: $e');
      _showSnackBar('Error subiendo imagen: ${imageSource.name}'.tr(), Colors.red);
      if (mounted && !_didNavigateAway) {
        setState(() {
          _imageUploadProgress.remove(imageSource.name);
          _updateOverallProgress();
        });
      }
      _onUploadItemCompleted(docRef.id);
    } finally {
      // Limpiar archivo temporal si fue creado
      if (tempFile != null) {
        try { await tempFile.delete(); } catch (_) {}
      }
    }
  }


  void _updateOverallProgress() {
    // Calcula progreso global considerando solo imágenes
    final int totalItems = _overallTotalItems == 0 ? _selectedImages.length : _overallTotalItems;
    final double imagesProgressSum = _imageUploadProgress.values.fold(0.0, (a, b) => a + b);
    // completedItems cuenta los ítems que ya terminaron (ej: se terminaron de subir 2/5 imágenes)
    final int itemsInProgress = _imageUploadProgress.length;
    final int completedItems = (totalItems - itemsInProgress).clamp(0, totalItems);
    // completedItems cuentan como 1.0 cada uno
    final double totalProgress = (imagesProgressSum + completedItems) / (totalItems == 0 ? 1 : totalItems);
    _overallUploadProgress = totalProgress.clamp(0.0, 1.0);
  }

  void _onUploadItemCompleted(String requestId) {
    // Se usa la variable de estado para contar los completados de forma asíncrona
    _completedUploadItems++;
    final int totalItems = _overallTotalItems == 0 ? _selectedImages.length : _overallTotalItems;
    
    // Si no hay ítems totales (ej. error temprano o lista vacía), salir
    if (totalItems == 0) return;

    if (_completedUploadItems >= totalItems) {
      _notifyUploadSuccess(requestId);
      // Al completar todas las subidas, cerrar la pantalla si aún estamos montados
      if (mounted && !_didNavigateAway) {
        setState(() { 
          _showGlobalUploadOverlay = false; 
          _isLoading = false;
        });
        if (_isLifecycleInactive) {
          _deferClose = true;
        } else {
          // FIX CRÍTICO: Navegar de forma robusta
          _safeNavigateToDetails(requestId);
        }
      }
    } else {
      // Actualizar el overlay con el nuevo mensaje de progreso
      if (mounted) {
        setState(() {
          _globalUploadMessage = 'Subiendo ${_completedUploadItems + 1} de $totalItems archivos...';
        });
      }
    }
  }

  Future<void> _notifyUploadSuccess(String requestId) async {
    // Opción A: ya se marcó como visible/aprobado al crear; aquí solo refrescamos y notificamos
    try {
      ref.invalidate(rawHelpRequestsStreamProvider);
      ref.invalidate(filteredHelpRequestsProvider);
    } catch (e) {
      debugPrint('WARN: No se pudo invalidar proveedores tras publicar: $e');
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
// --- (Widgets _buildPreloadedTextField, _buildEditableTextField sin cambios) ---

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

// --- (Método build con la lógica del overlay y previsualización de imágenes) ---

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
      appBar: CustomAppBar(
        title: 'create_request'.tr(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
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
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10, width: 1),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 10.0,
                        runSpacing: 10.0,
                        alignment: WrapAlignment.start,
                        children: [
                        GestureDetector(
                          onTap: (_selectedImages.length < 8 && !_isPickingMedia) ? _pickImages : null,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: (_isPickingMedia && _selectedImages.isEmpty)
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_a_photo, color: Colors.amber, size: 32),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Galería',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        GestureDetector(
                          onTap: (_selectedImages.length < 5 && !_isPickingMedia) ? _captureImageFromCamera : null,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: (_isPickingMedia && _selectedImages.isEmpty)
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.photo_camera, color: Colors.amber, size: 32),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Cámara',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
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
                                if (!mounted || _didNavigateAway) {
                                  return const SizedBox.shrink();
                                }
                                if (snapshot.hasError) {
                                  return Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[700],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 30)),
                                  );
                                }
                                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      snapshot.data!,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 90,
                                        height: 90,
                                        color: Colors.grey[700],
                                        child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 30)),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                                );
                              },
                            );
                          } else {
  // ✅ En móvil: si es content:// o no tiene path directo, usa archivo temporal de previsualización
                            imageWidget = FutureBuilder<String?>(
                              future: _ensureTempFileForContentImage(imageSource),
                              builder: (context, tempSnap) {
                                if (!mounted || _didNavigateAway) {
                                  return const SizedBox.shrink();
                                }
                                final String? tempPath = tempSnap.data;
                                final bool canShowFile = tempSnap.connectionState == ConnectionState.done && tempPath != null && tempPath.isNotEmpty && File(tempPath).existsSync();
                                
                                if (canShowFile) {
                                  // Usamos Image.file con el path temporal o el path directo
                                  final file = File(tempPath!);
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      file,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      cacheWidth: 150,
                                      cacheHeight: 150,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[700],
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 30)),
                                      ),
                                    ),
                                  );
                                }
                                
                                // Placeholder si aún está cargando o no se pudo obtener el archivo
                                if (tempSnap.connectionState == ConnectionState.waiting) {
                                  return const SizedBox(
                                    width: 90,
                                    height: 90,
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                                  );
                                }
                                
                                // Fallback: mostrar placeholder de error si no se pudo acceder
                                return Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[700],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 30)),
                                );
                              },
                            );
                          }

                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: imageWidget,
                                ),
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
                ),
                
                const SizedBox(height: 30),

                if (!_isPickingMedia && !_showGlobalUploadOverlay) 
                  ...[
                      Text('Publicidad Destacada'.tr(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      AdBannerWidget(adUnitId: AdsIds.banner),
                      const SizedBox(height: 20),
                  ],

                Center(
                  child: ElevatedButton(
                    onPressed: (_isLoading || _selectedImages.isEmpty) ? null : _createRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: (_isLoading)
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
          // Overlay de carga general (ahora solo para procesamiento o subida final)
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
                          // Muestra el progreso de la subida o un indicador indefinido si es procesamiento
                          LinearProgressIndicator(
                            value: _isPickingMedia ? null : (_overallUploadProgress > 0.0 ? _overallUploadProgress : null),
                            color: Colors.amber,
                            backgroundColor: Colors.white10,
                          ),
                          const SizedBox(height: 8),
                          if (!_isPickingMedia)
                            Text(
                              '${(_overallUploadProgress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          if (_isPickingMedia)
                             Text(
                              'Procesamiento en curso...'.tr(),
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