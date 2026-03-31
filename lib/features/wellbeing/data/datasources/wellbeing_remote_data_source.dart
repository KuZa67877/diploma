import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/supabase/supabase_subject_resolver.dart';
import '../../domain/entities/wellbeing_entry.dart';
import '../../domain/entities/wellbeing_mood.dart';

abstract class WellbeingRemoteDataSource {
  Future<List<WellbeingEntry>> getEntries();

  Future<void> saveEntry(WellbeingEntry entry);

  Future<void> saveEntries(List<WellbeingEntry> entries);
}

class WellbeingRemoteDataSourceImpl implements WellbeingRemoteDataSource {
  static const String _legacyMetadataKey = 'wellbeing_entries';

  final SupabaseClient Function() _clientProvider;
  final SupabaseSubjectResolver _subjectResolver;
  final _logger = AppLogger.instance;

  WellbeingRemoteDataSourceImpl({
    required SupabaseClient Function() clientProvider,
    required SupabaseSubjectResolver subjectResolver,
  }) : _clientProvider = clientProvider,
       _subjectResolver = subjectResolver;

  @override
  Future<List<WellbeingEntry>> getEntries() async {
    final user = _requireUser();
    final subjectId = await _subjectResolver.resolveSubjectId();

    final entries = <WellbeingEntry>[];
    List<Map<String, dynamic>> rows = const [];
    try {
      final fetched = await _clientProvider()
          .from('wellbeing_entries')
          .select('entry_date, mood, tags, note')
          .eq('subject_id', subjectId)
          .order('entry_date', ascending: false);
      rows = fetched;
    } catch (error, stackTrace) {
      _logger.warning(
        'wellbeing.remote',
        'Failed loading wellbeing entries from table, using legacy metadata fallback',
        payload: {
          'subjectId': subjectId,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }

    for (final row in rows) {
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
        ),
      );
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    if (entries.isNotEmpty) {
      return entries;
    }

    // Legacy fallback from user_metadata for migration.
    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final raw = metadata[_legacyMetadataKey];
    if (raw is! Map) {
      return const [];
    }
    final legacyEntries = <WellbeingEntry>[];
    raw.forEach((dateKey, payload) {
      if (dateKey is! String || payload is! Map) {
        return;
      }
      final moodValue = payload['mood'];
      final mood = moodValue is String
          ? WellbeingMood.fromStorageValue(moodValue)
          : null;
      if (mood == null) {
        return;
      }
      final date = _fromDateKey(dateKey);
      if (date == null) {
        return;
      }
      final rawTags = payload['tags'];
      final tags = rawTags is List
          ? rawTags
                .whereType<String>()
                .where((item) => item.trim().isNotEmpty)
                .toSet()
                .toList(growable: false)
          : const <String>[];
      final noteRaw = payload['note'];
      final note = noteRaw is String && noteRaw.trim().isNotEmpty
          ? noteRaw.trim()
          : null;
      legacyEntries.add(
        WellbeingEntry(date: date, mood: mood, tags: tags, note: note),
      );
    });
    legacyEntries.sort((a, b) => b.date.compareTo(a.date));
    if (legacyEntries.isNotEmpty) {
      try {
        await saveEntries(legacyEntries);
      } catch (_) {
        // No-op, migration is best-effort.
      }
    }
    return legacyEntries;
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
    final subjectId = await _subjectResolver.resolveSubjectId();
    final rows = entries
        .map(
          (entry) => {
            'subject_id': subjectId,
            'entry_date': _dateKey(entry.date),
            'mood': entry.mood.storageValue,
            'tags': entry.tags.toSet().toList(growable: false),
            'note': entry.note?.trim(),
          },
        )
        .toList(growable: false);

    _logger.info(
      'wellbeing.remote',
      'Sync wellbeing entries to Supabase table wellbeing_entries',
      payload: {'subjectId': subjectId, 'entriesCount': entries.length},
    );

    try {
      if (rows.isEmpty) {
        await _clientProvider()
            .from('wellbeing_entries')
            .delete()
            .eq('subject_id', subjectId);
        return;
      }

      await _clientProvider()
          .from('wellbeing_entries')
          .upsert(rows, onConflict: 'subject_id,entry_date');
    } catch (error, stackTrace) {
      try {
        await _saveLegacyToMetadata(user, entries);
      } catch (_) {
        // no-op, original table error handled below
      }
      _logger.error(
        'wellbeing.remote',
        'Failed to sync wellbeing entries to Supabase table',
        payload: {
          'userId': user.id,
          'subjectId': subjectId,
          'entriesCount': entries.length,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      throw ServerFailure('Failed to sync wellbeing entries: $error');
    }
  }

  Future<void> _saveLegacyToMetadata(
    User user,
    List<WellbeingEntry> entries,
  ) async {
    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    metadata[_legacyMetadataKey] = {
      for (final entry in entries)
        _dateKey(entry.date): {
          'mood': entry.mood.storageValue,
          'tags': entry.tags.toSet().toList(growable: false),
          'note': entry.note?.trim(),
        },
    };
    await _clientProvider().auth.updateUser(UserAttributes(data: metadata));
  }

  User _requireUser() {
    final user = _clientProvider().auth.currentUser;
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
}
