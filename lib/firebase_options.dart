import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Placeholder Firebase options.
///
/// Chạy `flutterfire configure` để sinh lại file này bằng cấu hình Firebase thật.
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
        throw UnsupportedError('PocketStory hiện chỉ cấu hình sẵn cho Android/iOS.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyANH4VmFtlLCXMkD-Bazio9BNzp2Qe54TI',
    appId: '1:666747090716:android:c9b07d23bd81f9e5af6cd9',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'pocketstory-demo',
    authDomain: 'pocketstory-demo.firebaseapp.com',
    storageBucket: 'pocketstory-demo.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyANH4VmFtlLCXMkD-Bazio9BNzp2Qe54TI',
    appId: '1:666747090716:android:c9b07d23bd81f9e5af6cd9',
    messagingSenderId: '666747090716',
    projectId: 'pocketstory-6d696',
    storageBucket: 'pocketstory-6d696.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBLFhd3Et57iEu0iBlkAyHAMaihp6JmJcA',
    appId: '1:666747090716:ios:c2ae2fdc8f8aa23aaf6cd9',
    messagingSenderId: '666747090716',
    projectId: 'pocketstory-6d696',
    storageBucket: 'pocketstory-6d696.firebasestorage.app',
    iosBundleId: 'com.example.pocketstory',
  );
  static const FirebaseOptions macos = ios;
}
