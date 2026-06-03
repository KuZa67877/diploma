import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options_dev.dart';
import '../../firebase_options.dart';
import '../config/app_env.dart';
import '../logging/app_logger.dart';

StreamSubscription<User?>? _authSubscription;
bool _isFirebaseReady = false;

bool get isFirebaseReady => _isFirebaseReady;

Future<bool> initFirebase() async {
  final logger = AppLogger.instance;

  if (!AppEnv.enableFirebaseSync) {
    logger.warning(
      'firebase.init',
      'Firebase sync is disabled by environment flag. Running in local/mock auth mode.',
    );
    _isFirebaseReady = false;
    return false;
  }

  logger.info('firebase.init', 'Initializing Firebase client');
  try {
    await Firebase.initializeApp(
      options: AppEnv.isDevFlavor
          ? DevFirebaseOptions.currentPlatform
          : DefaultFirebaseOptions.currentPlatform,
    );
    _isFirebaseReady = true;
    logger.info('firebase.init', 'Firebase initialized successfully');
  } catch (error, stackTrace) {
    _isFirebaseReady = false;
    logger.warning(
      'firebase.init',
      'Firebase initialization failed. Running in local/mock auth mode.',
      payload: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
    );
    return false;
  }

  _authSubscription?.cancel();
  _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
    logger.info(
      'firebase.auth',
      user == null
          ? 'Auth state changed: signed out'
          : 'Auth state changed: signed in',
      payload: {
        'userId': user?.uid,
        'email': user?.email,
        'hasSession': user != null,
      },
    );
  });

  return true;
}
