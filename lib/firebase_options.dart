import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // Default to Android for mobile platforms
    return android;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDmfEd-MGg4ZCZwr9yEnIPSK5DPBIp3deo',
    appId: '1:697376338964:web:b310fc604941fc9f82a301',
    messagingSenderId: '697376338964',
    projectId: 'pablo-oviedo',
    authDomain: 'pablo-oviedo.firebaseapp.com',
    storageBucket: 'pablo-oviedo.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDmfEd-MGg4ZCZwr9yEnIPSK5DPBIp3deo',
    appId: '1:697376338964:android:b310fc604941fc9f82a301',
    messagingSenderId: '697376338964',
    projectId: 'pablo-oviedo',
    storageBucket: 'pablo-oviedo.firebasestorage.app',
  );
}
