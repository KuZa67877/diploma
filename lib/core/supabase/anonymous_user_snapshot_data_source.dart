import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../error/failures.dart';
import '../logging/app_logger.dart';
import 'onboarding_profile_snapshot.dart';

abstract class AnonymousUserSnapshotDataSource {
  Future<OnboardingProfileSnapshot?> getSnapshot();
}

class AnonymousUserSnapshotDataSourceImpl
    implements AnonymousUserSnapshotDataSource {
  final FirebaseAuth Function() _authProvider;
  final FirebaseFirestore Function() _firestoreProvider;
  final _logger = AppLogger.instance;

  AnonymousUserSnapshotDataSourceImpl({
    required FirebaseAuth Function() authProvider,
    required FirebaseFirestore Function() firestoreProvider,
  }) : _authProvider = authProvider,
       _firestoreProvider = firestoreProvider;

  @override
  Future<OnboardingProfileSnapshot?> getSnapshot() async {
    final user = _authProvider().currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }

    try {
      final root = _userDoc(user.uid);
      final profileDoc = await root
          .collection('profile')
          .doc('onboarding')
          .get();
      final wellbeingQuery = await root.collection('wellbeing').get();
      final healthSamplesQuery = await root.collection('health_samples').get();
      final connectionsQuery = await root
          .collection('health_connections')
          .where('is_connected', isEqualTo: true)
          .get();

      final wellbeingDates = <DateTime>[];
      for (final doc in wellbeingQuery.docs) {
        final date = _dateOrNull(doc.data()['entry_date']);
        if (date != null) {
          wellbeingDates.add(DateTime(date.year, date.month, date.day));
        }
      }

      final connectedSourceIds = connectionsQuery.docs
          .map((doc) => (doc.data()['source_id'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      final profile = profileDoc.data();
      if (profile == null &&
          wellbeingDates.isEmpty &&
          healthSamplesQuery.docs.isEmpty &&
          connectedSourceIds.isEmpty) {
        return null;
      }

      final map = profile ?? const <String, dynamic>{};
      return OnboardingProfileSnapshot(
        firstName: _stringOrNull(map['first_name']),
        lastName: _stringOrNull(map['last_name']),
        fullName: _stringOrNull(map['full_name']) ?? user.displayName,
        email: user.email,
        age: _intOrNull(map['age']),
        sex: _stringOrNull(map['sex']),
        heightCm: _doubleOrNull(map['height_cm']),
        weightKg: _doubleOrNull(map['weight_kg']),
        systolic: _intOrNull(map['blood_pressure_systolic']),
        diastolic: _intOrNull(map['blood_pressure_diastolic']),
        glucose: _intOrNull(map['glucose']),
        temperatureC: _doubleOrNull(map['temperature_c']),
        recordedAt: _dateOrNull(map['recorded_at']),
        completedAt: _dateOrNull(map['updated_at']),
        symptoms: _stringList(map['symptoms']),
        wellbeingEntriesCount: wellbeingDates.length,
        healthSamplesCount: healthSamplesQuery.docs.length,
        connectedHealthSourceIds: connectedSourceIds,
        wellbeingEntryDates: wellbeingDates,
      );
    } catch (error, stackTrace) {
      _logger.warning(
        'snapshot.remote',
        'Failed to load user snapshot from Firestore',
        payload: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestoreProvider().collection('users').doc(uid);
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _intOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static double? _doubleOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.tryParse(value.toString());
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
