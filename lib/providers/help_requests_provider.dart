// lib/providers/help_requests_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' show cos, asin, sqrt, sin, atan2, pi;

import 'package:eslabon_flutter/providers/location_provider.dart'; // Importa el proveedor de ubicación

// Proveedor para el stream crudo de solicitudes de ayuda activas
final rawHelpRequestsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  return FirebaseFirestore.instance
      .collection('solicitudes-de-ayuda')
      .where('estado', isEqualTo: 'activa')
      .orderBy('timestamp', descending: true)
      .snapshots();
});

// Proveedor para las solicitudes de ayuda filtradas
final filteredHelpRequestsProvider = StreamProvider<List<QueryDocumentSnapshot>>((ref) {
  final AsyncValue<QuerySnapshot> rawRequests = ref.watch(rawHelpRequestsStreamProvider);
  final String currentFilterScope = ref.watch(filterScopeProvider);
  final double proximityRadiusKm = ref.watch(proximityRadiusProvider);
  final UserLocationData userLocation = ref.watch(userLocationProvider);

  return rawRequests.when(
    data: (snapshot) {
      final List<QueryDocumentSnapshot> allHelpRequestDocs = snapshot.docs;
      print('DEBUG FILTER_PROVIDER: Total de solicitudes cargadas de Firestore (antes de filtrar): ${allHelpRequestDocs.length}');

      final List<QueryDocumentSnapshot> filteredList = allHelpRequestDocs.where((doc) {
        final request = doc.data() as Map<String, dynamic>;
        final String requestProvincia = request['provincia'] ?? '';
        final String requestCountry = request['country'] ?? '';
        final double? requestLat = request['latitude'];
        final double? requestLon = request['longitude'];

        bool isNearbyLocal = false;
        if (userLocation.latitude != null && userLocation.longitude != null && requestLat != null && requestLon != null) {
          final distance = _calculateDistance(userLocation.latitude!, userLocation.longitude!, requestLat, requestLon);
          isNearbyLocal = distance <= proximityRadiusKm;
        }

        bool passesFilter = false;
        if (currentFilterScope == 'Cercano') {
          passesFilter = isNearbyLocal;
        } else if (currentFilterScope == 'Provincial') {
          const String userProvincia = 'San Juan'; // Asumo 'San Juan' como provincia fija del usuario
          passesFilter = (requestProvincia == userProvincia);
        } else if (currentFilterScope == 'Nacional') {
          passesFilter = (requestCountry == 'Argentina'); // Asumo 'Argentina' como país fijo
        } else if (currentFilterScope == 'Internacional') {
          passesFilter = true; // Todos pasan el filtro internacional
        }
        return passesFilter;
      }).toList();

      print('DEBUG FILTER_PROVIDER: Total de solicitudes filtradas a mostrar: ${filteredList.length}');
      return Stream.value(filteredList); // Devuelve un stream con la lista filtrada
    },
    loading: () => const Stream.empty(), // Devuelve un stream vacío mientras carga
    error: (err, stack) {
      print('DEBUG FILTER_PROVIDER ERROR: Error al cargar o filtrar solicitudes: $err');
      return Stream.error(err); // Propaga el error
    },
  );
});

// Función de cálculo de distancia (Haversine)
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0; // Radius of Earth in kilometers

  var latDistance = _degreesToRadians(lat2 - lat1);
  var lonDistance = _degreesToRadians(lon2 - lon1);

  var a = sin(latDistance / 2) * sin(latDistance / 2) +
          cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
              sin(lonDistance / 2) * sin(lonDistance / 2);
  var c = 2 * atan2(sqrt(a), sqrt(1 - a));
  double distance = R * c;

  return distance;
}

double _degreesToRadians(double degrees) {
  return degrees * (pi / 180);
}

