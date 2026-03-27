// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'firebase_options_local.dart'; // <- aquí está FirebaseLocal

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: FirebaseLocal.webApiKey,
        appId: FirebaseLocal.webAppId,
        messagingSenderId: FirebaseLocal.messagingSenderId,
        projectId: FirebaseLocal.projectId,
        authDomain: FirebaseLocal.authDomain,
        storageBucket: FirebaseLocal.storageBucket,
        measurementId: FirebaseLocal.measurementId,
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: FirebaseLocal.androidApiKey,
        appId: FirebaseLocal.androidAppId,
        messagingSenderId: FirebaseLocal.messagingSenderId,
        projectId: FirebaseLocal.projectId,
        storageBucket: FirebaseLocal.storageBucket,
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: FirebaseLocal.iosApiKey,
        appId: FirebaseLocal.iosAppId,
        messagingSenderId: FirebaseLocal.messagingSenderId,
        projectId: FirebaseLocal.projectId,
        storageBucket: FirebaseLocal.storageBucket,
        iosBundleId: FirebaseLocal.iosBundleId,
      );

  static FirebaseOptions get macos => FirebaseOptions(
        apiKey: FirebaseLocal.macosApiKey,
        appId: FirebaseLocal.macosAppId,
        messagingSenderId: FirebaseLocal.messagingSenderId,
        projectId: FirebaseLocal.projectId,
        storageBucket: FirebaseLocal.storageBucket,
        iosBundleId: FirebaseLocal.macosBundleId,
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: FirebaseLocal.windowsApiKey,
        appId: FirebaseLocal.windowsAppId,
        messagingSenderId: FirebaseLocal.messagingSenderId,
        projectId: FirebaseLocal.projectId,
        authDomain: FirebaseLocal.authDomain,
        storageBucket: FirebaseLocal.storageBucket,
        measurementId: FirebaseLocal.measurementId,
      );
}
