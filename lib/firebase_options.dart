// File generated to configure Firebase for project 'task-management-d6054'
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCeNyI5AgkYDy6tuqvTdxuJnNlm2d4Gtf8',
    appId: '1:810139656227:android:7e5c1d9d2e960cf8839196',
    messagingSenderId: '810139656227',
    projectId: 'task-management-d6054',
    storageBucket: 'task-management-d6054.firebasestorage.app',
    databaseURL: 'https://task-management-d6054-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCeNyI5AgkYDy6tuqvTdxuJnNlm2d4Gtf8',
    appId: '1:810139656227:android:7e5c1d9d2e960cf8839196',
    messagingSenderId: '810139656227',
    projectId: 'task-management-d6054',
    storageBucket: 'task-management-d6054.firebasestorage.app',
    databaseURL: 'https://task-management-d6054-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCeNyI5AgkYDy6tuqvTdxuJnNlm2d4Gtf8',
    appId: '1:810139656227:android:7e5c1d9d2e960cf8839196',
    messagingSenderId: '810139656227',
    projectId: 'task-management-d6054',
    storageBucket: 'task-management-d6054.firebasestorage.app',
    databaseURL: 'https://task-management-d6054-default-rtdb.firebaseio.com',
  );
}
