import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for NGMY project
/// Project ID: ngmy-733bb
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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAQmqpEj0T9bjC8YASu5kdmbDJjFylV6gc',
    appId: '1:523447401669:web:5d594e022f30529a8804ac',
    messagingSenderId: '523447401669',
    projectId: 'ngmy-733bb',
    authDomain: 'ngmy-733bb.firebaseapp.com',
    databaseURL: 'https://ngmy-733bb-default-rtdb.firebaseio.com',
    storageBucket: 'ngmy-733bb.firebasestorage.app',
    measurementId: 'G-QNXFHJVPNR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBKGX40FgflyigM0hPKzfp7LYlZKGU4wAc',
    appId: '1:36182036977:android:c373a6e18fccb3841f7450',
    messagingSenderId: '36182036977',
    projectId: 'ngmy1-c5f01',
    storageBucket: 'ngmy1-c5f01.firebasestorage.app',
    databaseURL: 'https://ngmy1-c5f01-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBZh8RQxJxZKLVWvpN9_K9pQqLJt5_w5bY',
    appId: '1:523447401669:ios:abc123def456ghi789',
    messagingSenderId: '523447401669',
    projectId: 'ngmy-733bb',
    storageBucket: 'ngmy-733bb.firebasestorage.app',
    databaseURL: 'https://ngmy-733bb-default-rtdb.firebaseio.com',
    iosBundleId: 'com.ngmy.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBZh8RQxJxZKLVWvpN9_K9pQqLJt5_w5bY',
    appId: '1:523447401669:macos:abc123def456ghi789',
    messagingSenderId: '523447401669',
    projectId: 'ngmy-733bb',
    storageBucket: 'ngmy-733bb.firebasestorage.app',
    databaseURL: 'https://ngmy-733bb-default-rtdb.firebaseio.com',
    iosBundleId: 'com.ngmy.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAQmqpEj0T9bjC8YASu5kdmbDJjFylV6gc',
    appId: '1:523447401669:web:5d594e022f30529a8804ac',
    messagingSenderId: '523447401669',
    projectId: 'ngmy-733bb',
    authDomain: 'ngmy-733bb.firebaseapp.com',
    databaseURL: 'https://ngmy-733bb-default-rtdb.firebaseio.com',
    storageBucket: 'ngmy-733bb.firebasestorage.app',
    measurementId: 'G-QNXFHJVPNR',
  );
}
