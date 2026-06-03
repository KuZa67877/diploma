import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/data_input_entry.dart';

abstract class DataInputRemoteDataSource {
  Future<void> saveEntry(DataInputEntry entry);
}

class DataInputRemoteDataSourceImpl implements DataInputRemoteDataSource {
  final FirebaseAuth Function() _authProvider;
  final FirebaseFirestore Function() _firestoreProvider;
  final _logger = AppLogger.instance;

  DataInputRemoteDataSourceImpl({
    required FirebaseAuth Function() authProvider,
    required FirebaseFirestore Function() firestoreProvider,
  }) : _authProvider = authProvider,
       _firestoreProvider = firestoreProvider;

  @override
  Future<void> saveEntry(DataInputEntry entry) async {
    final user = _authProvider().currentUser;
    if (user == null) {
      _logger.warning(
        'data_input.remote',
        'Skip remote save: no active auth user in session',
      );
      throw const AuthFailure('No active session. Please sign in again.');
    }

    final payload = _toPayload(entry);
    _logger.info(
      'data_input.request',
      'Saving onboarding data to Firestore',
      payload: {'userId': user.uid},
    );

    try {
      await _firestoreProvider()
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('onboarding')
          .set(payload, SetOptions(merge: true));
      _logger.info(
        'data_input.response',
        'Onboarding data saved to Firestore',
        payload: {'userId': user.uid},
      );
    } catch (error, stackTrace) {
      _logger.error(
        'data_input.response',
        'Failed to save onboarding data to Firestore',
        payload: {
          'userId': user.uid,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      throw ServerFailure('Failed to save onboarding profile: $error');
    }
  }

  Map<String, dynamic> _toPayload(DataInputEntry entry) {
    return {
      'recorded_at': entry.recordedAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'first_name': entry.firstName,
      'last_name': entry.lastName,
      'height_cm': entry.height,
      'weight_kg': entry.weight,
      'age': entry.age,
      'sex': entry.sex,
      'blood_pressure_systolic': entry.systolic,
      'blood_pressure_diastolic': entry.diastolic,
      'glucose': entry.glucose,
      'temperature_c': entry.temperature,
      'symptoms': entry.symptoms,
    };
  }
}
