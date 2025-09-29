import 'dart:async'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eslabon_flutter/models/user_model.dart'; 

// Provider para el usuario actual
final userProvider = AsyncNotifierProvider<UserNotifier, User?>(() {
  return UserNotifier();
});

class UserNotifier extends AsyncNotifier<User?> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  StreamSubscription? _userSubscription;

  @override
  Future<User?> build() async {
    // Configurar el listener para cambios de autenticación
    _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) {
      if (firebaseUser == null) {
        state = const AsyncValue.data(null);
        _userSubscription?.cancel();
      } else {
        _userSubscription = _firestore.collection('users').doc(firebaseUser.uid).snapshots().listen((doc) {
          if (doc.exists) {
            state = AsyncValue.data(User.fromFirestore(doc));
          } else {
            state = const AsyncValue.data(null);
          }
        });
      }
    });

    // Retornar el estado inicial
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return null;
    }

    final doc = await _firestore.collection('users').doc(currentUser.uid).get();
    if (doc.exists) {
      return User.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateLastGlobalChatRead() async {
    final currentUser = state.value;
    if (currentUser != null) {
      try {
        await _firestore.collection('users').doc(currentUser.id).update({
          'lastGlobalChatRead': FieldValue.serverTimestamp(),
        });
        state = AsyncValue.data(currentUser.copyWith(lastGlobalChatRead: DateTime.now()));
      } catch (e) {
        print('Error updating last global chat read: $e');
      }
    }
  }


}

