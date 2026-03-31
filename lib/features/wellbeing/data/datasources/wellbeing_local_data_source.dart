import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/wellbeing_entry.dart';
import '../../domain/entities/wellbeing_mood.dart';

abstract class WellbeingLocalDataSource {
  Future<List<WellbeingEntry>> getEntries();

  Future<void> saveEntry(WellbeingEntry entry);

  Future<void> saveEntries(List<WellbeingEntry> entries);
}

class WellbeingLocalDataSourceImpl implements WellbeingLocalDataSource {
  static const String _storageKeyBase = 'wellbeing_entries_v1';
  final SharedPreferences sharedPreferences;

  WellbeingLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<List<WellbeingEntry>> getEntries() async {
    final raw = sharedPreferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }

    final entries = <WellbeingEntry>[];
    decoded.forEach((dateKey, payload) {
      if (payload is! Map<String, dynamic>) {
        return;
      }

      final moodValue = payload['mood'] as String?;
      final mood = moodValue == null
          ? null
          : WellbeingMood.fromStorageValue(moodValue);
      if (mood == null) {
        return;
      }

      final date = _fromDateKey(dateKey);
      if (date == null) {
        return;
      }

      final tagsRaw = payload['tags'];
      final tags = <String>[];
      if (tagsRaw is List) {
        for (final tag in tagsRaw) {
          if (tag is String && tag.isNotEmpty) {
            tags.add(tag);
          }
        }
      }
      final noteRaw = payload['note'];
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
    });

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  @override
  Future<void> saveEntry(WellbeingEntry entry) async {
    final raw = sharedPreferences.getString(_storageKey);
    final payload = <String, dynamic>{};

    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        payload.addAll(decoded);
      }
    }

    final dateKey = _dateKey(entry.date);
    payload[dateKey] = {
      'mood': entry.mood.storageValue,
      'tags': entry.tags.toSet().toList(growable: false),
      'note': entry.note?.trim(),
    };

    await sharedPreferences.setString(_storageKey, jsonEncode(payload));
  }

  @override
  Future<void> saveEntries(List<WellbeingEntry> entries) async {
    final payload = <String, dynamic>{};
    for (final entry in entries) {
      payload[_dateKey(entry.date)] = {
        'mood': entry.mood.storageValue,
        'tags': entry.tags.toSet().toList(growable: false),
        'note': entry.note?.trim(),
      };
    }
    await sharedPreferences.setString(_storageKey, jsonEncode(payload));
  }

  String get _storageKey => '${_storageKeyBase}_${_currentScopeId()}';

  String _currentScopeId() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      return userId;
    }
    return 'anonymous';
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
