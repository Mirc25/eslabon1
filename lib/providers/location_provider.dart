// lib/providers/location_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Modelo para la ubicación del usuario
class UserLocationData {
  final double? latitude;
  final double? longitude;
  final String locality;
  final String statusMessage; // Mensaje de estado (cargando, error, etc.)

  UserLocationData({
    this.latitude,
    this.longitude,
    required this.locality,
    required this.statusMessage,
  });

  UserLocationData copyWith({
    double? latitude,
    double? longitude,
    String? locality,
    String? statusMessage,
  }) {
    return UserLocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locality: locality ?? this.locality,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

// StateNotifier para gestionar la ubicación del usuario
class UserLocationNotifier extends StateNotifier<UserLocationData> {
  UserLocationNotifier() : super(UserLocationData(locality: 'Cargando ubicación...', statusMessage: 'Cargando...')) {
    // Inicia la carga de la ubicación, pero no bloquea el constructor.
    // Esto permite que el UI se construya sin esperar.
    Future.microtask(() => determineAndSetUserLocation());
  }

  Future<void> determineAndSetUserLocation() async {
    state = state.copyWith(statusMessage: 'Obteniendo ubicación...');
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(locality: 'Ubicación deshabilitada', statusMessage: 'Los servicios de ubicación están deshabilitados.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(locality: 'Permiso denegado', statusMessage: 'Permisos de ubicación denegados.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(locality: 'Permiso denegado permanentemente', statusMessage: 'Permisos de ubicación permanentemente denegados. Habilítalos manualmente.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 10));
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      String localityName = 'Desconocida';
      if (placemarks.isNotEmpty) {
        localityName = placemarks.first.locality ?? placemarks.first.subLocality ?? placemarks.first.name ?? 'Desconocida';
      }
      state = UserLocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        locality: localityName,
        statusMessage: 'Ubicación obtenida: $localityName',
      );
    } catch (e) {
      state = state.copyWith(
        latitude: null,
        longitude: null,
        locality: 'No disponible',
        statusMessage: 'No se pudo obtener tu ubicación actual: $e',
      );
      print('DEBUG: Error al obtener ubicación en UserLocationNotifier: $e');
    }
  }
}

// Proveedor para la ubicación del usuario
final userLocationProvider = StateNotifierProvider<UserLocationNotifier, UserLocationData>((ref) {
  return UserLocationNotifier();
});

// Proveedor para el filtro de alcance
final filterScopeProvider = StateProvider<String>((ref) => 'Cercano'); // 'Cercano', 'Provincial', 'Nacional', 'Internacional'

// Proveedor para el radio de proximidad (solo para filtro 'Cercano')
final proximityRadiusProvider = StateProvider<double>((ref) => 3.0); // en kilómetros