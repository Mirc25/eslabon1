// lib/utils/firestore_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utilidades de moderación para consultas y documentos
class ModerationUtils {
  /// Aplica filtro de `moderation.status == 'approved'` a una consulta
  static Query<Map<String, dynamic>> onlyApproved(
      Query<Map<String, dynamic>> query) {
    return query.where('moderation.status', isEqualTo: 'approved');
  }

  /// Marca un documento como `pending` al crear/editar
  static Future<void> markPending(DocumentReference<Map<String, dynamic>> ref) {
    return ref.set({
      'moderation': {
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  /// Helper para ver estados
  static bool isApproved(DocumentSnapshot<Map<String, dynamic>> snap) {
    final status = snap.data()?['moderation']?['status'] as String?;
    return status == 'approved';
  }

  static bool isRejected(DocumentSnapshot<Map<String, dynamic>> snap) {
    final status = snap.data()?['moderation']?['status'] as String?;
    return status == 'rejected';
  }
}

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

