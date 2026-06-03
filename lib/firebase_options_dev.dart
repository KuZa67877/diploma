// File generated from Firebase CLI app registrations for the dev flavor.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DevFirebaseOptions {
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
        throw UnsupportedError(
          'DevFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DevFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DevFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAKAtTExmid3gx8Dj4Sujq3lGUibIAci3Y',
    appId: '1:28348437666:web:a0a44d8b05549ed3ed73fb',
    messagingSenderId: '28348437666',
    projectId: 'mediai-a4ebf',
    authDomain: 'mediai-a4ebf.firebaseapp.com',
    storageBucket: 'mediai-a4ebf.firebasestorage.app',
    measurementId: 'G-YB2ZN9R719',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDL2C_pa2dt0d1dK-8JmwTVLBCMOVjprGw',
    appId: '1:28348437666:android:7510afa704130637ed73fb',
    messagingSenderId: '28348437666',
    projectId: 'mediai-a4ebf',
    storageBucket: 'mediai-a4ebf.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDCd5Va85auCoqlgn6rJTl5VMjGRmKjOdM',
    appId: '1:28348437666:ios:f0ea4fab52ce418ced73fb',
    messagingSenderId: '28348437666',
    projectId: 'mediai-a4ebf',
    storageBucket: 'mediai-a4ebf.firebasestorage.app',
    iosBundleId: 'com.kuzminykhhh.mediai.dev',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDCd5Va85auCoqlgn6rJTl5VMjGRmKjOdM',
    appId: '1:28348437666:ios:bc2eac702ee4de37ed73fb',
    messagingSenderId: '28348437666',
    projectId: 'mediai-a4ebf',
    storageBucket: 'mediai-a4ebf.firebasestorage.app',
    iosBundleId: 'com.example.mediAi',
  );
}
