// lib/utils/firestore_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> saveRating({
    required String targetUserId,
    required String sourceUserId,
    required double rating,
    required String requestId,
    String? comment,
    String? type,
  }) async {
    try {
      final batch = _firestore.batch();
      final ratingRef = _firestore.collection('ratings').doc();

      batch.set(ratingRef, {
        'targetUserId': targetUserId,
        'sourceUserId': sourceUserId,
        'rating': rating,
        'requestId': requestId,
        'comment': comment,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      });
      // Las actualizaciones de estadísticas de usuario se delegan al backend (Cloud Function).

      await batch.commit();
      print('Rating saved for $targetUserId');
    } catch (e) {
      print('Error saving rating: $e');
      rethrow;
    }
  }
}

