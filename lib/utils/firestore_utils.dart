import 'package:cloud_firestore/cloud_firestore.dart';
// Eliminada la importación de notification_model.dart ya que no maneja notificaciones directamente aquí
// import 'package:eslabon_flutter/models/notification_model.dart'; // No necesaria aquí

class FirestoreUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ ELIMINADO: createNotificationDocument fue eliminado.
  // Las notificaciones deben ser creadas usando AppServices.addNotification.

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

      await _updateUserAverageRating(batch, targetUserId, rating);

      await batch.commit();
      print('Rating saved and user average updated for $targetUserId');
    } catch (e) {
      print('Error saving rating: $e');
      rethrow;
    }
  }

  static Future<void> _updateUserAverageRating(WriteBatch batch, String userId, double newRating) async {
    final userRef = _firestore.collection('users').doc(userId);

    final userDoc = await userRef.get();
    if (userDoc.exists) {
      final currentRatingCount = (userDoc.data()?['ratingCount'] ?? 0).toDouble();
      final currentRatingSum = (userDoc.data()?['ratingSum'] ?? 0).toDouble();

      final updatedRatingCount = currentRatingCount + 1;
      final updatedRatingSum = currentRatingSum + newRating;
      final newAverageRating = updatedRatingSum / updatedRatingCount;

      batch.update(userRef, {
        'ratingCount': updatedRatingCount,
        'ratingSum': updatedRatingSum,
        'averageRating': newAverageRating,
      });
    } else {
      batch.set(userRef, {
        'ratingCount': 1,
        'ratingSum': newRating,
        'averageRating': newRating,
      }, SetOptions(merge: true));
    }
  }
}