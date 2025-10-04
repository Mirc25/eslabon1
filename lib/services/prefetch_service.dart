import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'remote_config_service.dart';

class PrefetchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> prefetchInitialData() async {
    try {
      final int pageSize = RemoteConfigService().getPageSize();
      final User? user = _auth.currentUser;
      if (user == null) return;

      // Prefetch lista de chats (primera página)
      await _firestore
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .orderBy('lastMessage.timestamp', descending: true)
          .limit(pageSize)
          .get(const GetOptions(source: Source.server));

      // Prefetch notificaciones no leídas (primera página)
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(pageSize)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      // Silencioso por performance
    }
  }
}