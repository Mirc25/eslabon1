// lib/reputation_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';

Future<double> getAverageRating({required String userId, required bool fromRequesters}) async {
  if (userId.isEmpty) { // <--- ¡AÑADIDO: Validación de userId!
    print('DEBUG REPUTATION UTILS: userId vacío, devolviendo 0.0 para reputación.');
    return 0.0;
  }

  final String collectionPath = fromRequesters ? 'receivedRatingsAsRequester' : 'receivedRatingsAsHelper';

  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(collectionPath)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return 0.0;
    }

    double totalRating = 0.0;
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      totalRating += (data['rating'] as num? ?? 0).toDouble();
    }

    return totalRating / querySnapshot.docs.length;
  } catch (e) {
    print('Error al obtener la calificación promedio para $userId en $collectionPath: $e');
    // Relanza el error para que el FutureBuilder lo capture, o devuelve un valor predeterminado
    return 0.0; // O puedes lanzar una excepción si prefieres que el FutureBuilder muestre el error
  }
}