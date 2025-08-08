// lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB1i60BmSVBxBI5eF5jgEOUaCILsw4ej0k',
    appId: '1:548781604480:web:8baa0998d17858dd96f065',
    messagingSenderId: '548781604480',
    projectId: 'eslabon-app',
    authDomain: 'eslabon-app.firebaseapp.com',
    storageBucket: 'eslabon-app.appspot.com',
    measurementId: 'G-XXXXXXXXXX', // Opcional
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB1i60BmSVBxBI5eF5jgEOUaCILsw4ej0k',
    appId: '1:548781604480:android:ef9578bb6315859396f065',
    messagingSenderId: '548781604480',
    projectId: 'eslabon-app',
    storageBucket: 'eslabon-app.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB1i60BmSVBxBI5eF5jgEOUaCILsw4ej0k',
    appId: '1:548781604480:ios:xxxxxxxxxxxxxxxxxxxxxx',
    messagingSenderId: '548781604480',
    projectId: 'eslabon-app',
    storageBucket: 'eslabon-app.appspot.com',
    iosClientId: 'ios-client-id.apps.googleusercontent.com',
    iosBundleId: 'com.example.eslabonFlutter',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB1i60BmSVBxBI5eF5jgEOUaCILsw4ej0k',
    appId: '1:548781604480:macos:xxxxxxxxxxxxxxxxxxxxxx',
    messagingSenderId: '548781604480',
    projectId: 'eslabon-app',
    storageBucket: 'eslabon-app.appspot.com',
    iosClientId: 'macos-client-id.apps.googleusercontent.com',
    iosBundleId: 'com.example.eslabonFlutter',
  );
}