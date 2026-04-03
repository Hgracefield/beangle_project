import 'package:beangle_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static String? _errorMessage;

  static bool get isReady => Firebase.apps.isNotEmpty;
  static String? get errorMessage => _errorMessage;

  static Future<void> ensureInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      _errorMessage = null;
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _errorMessage = null;
    } catch (error, stackTrace) {
      _errorMessage = error.toString();
      debugPrint('Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
