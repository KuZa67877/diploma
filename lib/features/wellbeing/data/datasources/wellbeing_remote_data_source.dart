import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/wellbeing_entry.dart';
import '../../domain/entities/wellbeing_mood.dart';

abstract class WellbeingRemoteDataSource {
  Future<List<WellbeingEntry>> getEntries();

  Future<void> saveEntry(WellbeingEntry entry);

  Future<void> saveEntries(List<WellbeingEntry> entries);
}

class WellbeingRemoteDataSourceImpl implements WellbeingRemoteDataSource {
  final FirebaseAuth Function() _authProvider;
  final FirebaseFirestore Function() _firestoreProvider;
  final _logger = AppLogger.instance;

  WellbeingRemoteDataSourceImpl({
    required FirebaseAuth Function() authProvider,
    required FirebaseFirestore Function() firestoreProvider,
  }) : _authProvider = authProvider,
       _firestoreProvider = firestoreProvider;

  @override
  Future<List<WellbeingEntry>> getEntries() async {
    final user = _requireUser();

    final entries = <WellbeingEntry>[];
    final query = await _wellbeingCollection(
      user.uid,
    ).orderBy('entry_date', descending: true).get();

    for (final doc in query.docs) {
      final row = doc.data();
      final moodValue = row['mood'];
      final mood = moodValue is String
          ? WellbeingMood.fromStorageValue(moodValue)
          : null;
      if (mood == null) {
        continue;
      }

      final date = _fromDateKey(row['entry_date']?.toString() ?? '');
      if (date == null) {
        continue;
      }

      final tags = <String>[];
      final rawTags = row['tags'];
      if (rawTags is List) {
        for (final tag in rawTags) {
          if (tag is String && tag.isNotEmpty) {
            tags.add(tag);
          }
        }
      }

      final noteRaw = row['note'];
      final note = noteRaw is String && noteRaw.trim().isNotEmpty
          ? noteRaw.trim()
          : null;

      entries.add(
        WellbeingEntry(
          date: date,
          mood: mood,
          tags: tags.toSet().toList(growable: false),
          note: note,
          stressNow: _toScale(row['stress_now']),
          fatigue: _toScale(row['fatigue']),
          wellness: _toScale(row['wellness']),
        ),
      );
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  @override
  Future<void> saveEntry(WellbeingEntry entry) async {
    final entries = await getEntries();
    final byDate = {for (final item in entries) _dateKey(item.date): item};
    byDate[_dateKey(entry.date)] = entry;
    await saveEntries(byDate.values.toList(growable: false));
  }

  @override
  Future<void> saveEntries(List<WellbeingEntry> entries) async {
    final user = _requireUser();
    final batch = _firestoreProvider().batch();
    final collection = _wellbeingCollection(user.uid);

    _logger.info(
      'wellbeing.remote',
      'Sync wellbeing entries to Firestore',
      payload: {'userId': user.uid, 'entriesCount': entries.length},
    );

    try {
      final existing = await collection.get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }

      for (final entry in entries) {
        final dateKey = _dateKey(entry.date);
        batch.set(collection.doc(dateKey), {
          'entry_date': dateKey,
          'mood': entry.mood.storageValue,
          'tags': entry.tags.toSet().toList(growable: false),
          'note': entry.note?.trim(),
          'stress_now': entry.stressNow,
          'fatigue': entry.fatigue,
          'wellness': entry.wellness,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      await batch.commit();
    } catch (error, stackTrace) {
      _logger.error(
        'wellbeing.remote',
        'Failed to sync wellbeing entries to Firestore',
        payload: {
          'userId': user.uid,
          'entriesCount': entries.length,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      throw ServerFailure('Failed to sync wellbeing entries: $error');
    }
  }

  CollectionReference<Map<String, dynamic>> _wellbeingCollection(String uid) {
    return _firestoreProvider()
        .collection('users')
        .doc(uid)
        .collection('wellbeing');
  }

  User _requireUser() {
    final user = _authProvider().currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }
    return user;
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime? _fromDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  int? _toScale(Object? value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed < 1 || parsed > 5) {
      return null;
    }
    return parsed;
  }
}
