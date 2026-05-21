import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyDS1RrXfbGefV9LnR0yWkBfAogkGRkgkaY',
    appId: '1:662655416954:web:51e8c9b83fc1feb9d419c3',
    messagingSenderId: '662655416954',
    projectId: 'pos-dapoer-manahan',
    authDomain: 'pos-dapoer-manahan.firebaseapp.com',
    storageBucket: 'pos-dapoer-manahan.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDS1RrXfbGefV9LnR0yWkBfAogkGRkgkaY',
    appId: '1:662655416954:android:51e8c9b83fc1feb9d419c3',
    messagingSenderId: '662655416954',
    projectId: 'pos-dapoer-manahan',
    storageBucket: 'pos-dapoer-manahan.firebasestorage.app',
  );
}
