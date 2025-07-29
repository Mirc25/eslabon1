import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ DEFINICIÓN: Proveedor para el usuario autenticado de Firebase
final userProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Puedes añadir otro proveedor para el perfil de usuario si lo guardas en Firestore
// final userProfileProvider = StreamProvider.family<UserProfile, String>((ref, userId) {
//   return FirebaseFirestore.instance.collection('users').doc(userId).snapshots().map((doc) => UserProfile.fromMap(doc.data()!));
// });
