import 'package:dartz/dartz.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/wellbeing/data/datasources/wellbeing_local_data_source.dart';
import 'package:medi_ai/features/wellbeing/data/datasources/wellbeing_remote_data_source.dart';
import 'package:medi_ai/features/wellbeing/data/repositories/wellbeing_repository_impl.dart';
import 'package:medi_ai/features/wellbeing/domain/entities/wellbeing_entry.dart';
import 'package:medi_ai/features/wellbeing/domain/entities/wellbeing_mood.dart';

void main() {
  group('WellbeingRepositoryImpl', () {
    tearDown(dotenv.clean);

    test('merges remote and local entries by date preferring local values', () async {
      _configureSupabase();
      final local = _FakeWellbeingLocalDataSource(
        entries: <WellbeingEntry>[
          _entry(
            DateTime(2026, 4, 30),
            mood: WellbeingMood.good,
            note: 'local wins',
          ),
          _entry(DateTime(2026, 4, 28), mood: WellbeingMood.low),
        ],
      );
      final remote = _FakeWellbeingRemoteDataSource(
        entries: <WellbeingEntry>[
          _entry(
            DateTime(2026, 4, 30),
            mood: WellbeingMood.veryLow,
            note: 'remote loses',
          ),
          _entry(DateTime(2026, 4, 29), mood: WellbeingMood.neutral),
        ],
      );
      final repository = WellbeingRepositoryImpl(
        localDataSource: local,
        remoteDataSource: remote,
      );

      final result = await repository.getEntries();
      final entries = result.fold((_) => <WellbeingEntry>[], (value) => value);

      expect(entries.length, 3);
      expect(entries[0].date, DateTime(2026, 4, 30));
      expect(entries[0].mood, WellbeingMood.good);
      expect(entries[0].note, 'local wins');
      expect(entries[1].date, DateTime(2026, 4, 29));
      expect(entries[2].date, DateTime(2026, 4, 28));
      expect(local.lastSavedEntries, entries);
      expect(remote.lastSavedEntries, entries);
    });

    test('returns local entries when remote auth fails', () async {
      _configureSupabase();
      final localEntries = <WellbeingEntry>[
        _entry(DateTime(2026, 4, 30), mood: WellbeingMood.great),
      ];
      final local = _FakeWellbeingLocalDataSource(entries: localEntries);
      final remote = _FakeWellbeingRemoteDataSource(
        getEntriesFailure: const AuthFailure('session expired'),
      );
      final repository = WellbeingRepositoryImpl(
        localDataSource: local,
        remoteDataSource: remote,
      );

      final result = await repository.getEntries();

      expect(result, Right<Failure, List<WellbeingEntry>>(localEntries));
      expect(local.lastSavedEntries, isNull);
      expect(remote.lastSavedEntries, isNull);
    });

    test('clears stale local cache when remote source of truth is empty', () async {
      _configureSupabase();
      final local = _FakeWellbeingLocalDataSource(
        entries: <WellbeingEntry>[
          _entry(DateTime(2026, 4, 30), mood: WellbeingMood.good),
        ],
      );
      final remote = _FakeWellbeingRemoteDataSource(entries: const <WellbeingEntry>[]);
      final repository = WellbeingRepositoryImpl(
        localDataSource: local,
        remoteDataSource: remote,
      );

      final result = await repository.getEntries();
      final entries = result.fold((_) => <WellbeingEntry>[], (value) => value);

      expect(entries, isEmpty);
      expect(local.lastSavedEntries, isEmpty);
    });
  });
}

void _configureSupabase() {
  dotenv.testLoad(
    fileInput: 'SUPABASE_URL=https://example.supabase.co\n'
        'SUPABASE_ANON_KEY=test-key',
  );
}

WellbeingEntry _entry(
  DateTime date, {
  required WellbeingMood mood,
  String? note,
}) {
  return WellbeingEntry(
    date: date,
    mood: mood,
    tags: const <String>['focus'],
    note: note,
    stressNow: 3,
    fatigue: 2,
    wellness: 4,
  );
}

class _FakeWellbeingLocalDataSource implements WellbeingLocalDataSource {
  List<WellbeingEntry> entries;
  List<WellbeingEntry>? lastSavedEntries;

  _FakeWellbeingLocalDataSource({required this.entries});

  @override
  Future<List<WellbeingEntry>> getEntries() async => entries;

  @override
  Future<void> saveEntries(List<WellbeingEntry> entries) async {
    this.entries = entries;
    lastSavedEntries = entries;
  }

  @override
  Future<void> saveEntry(WellbeingEntry entry) async {
    entries = <WellbeingEntry>[entry, ...entries];
  }
}

class _FakeWellbeingRemoteDataSource implements WellbeingRemoteDataSource {
  final Failure? getEntriesFailure;
  List<WellbeingEntry> entries;
  List<WellbeingEntry>? lastSavedEntries;

  _FakeWellbeingRemoteDataSource({
    this.getEntriesFailure,
    this.entries = const <WellbeingEntry>[],
  });

  @override
  Future<List<WellbeingEntry>> getEntries() async {
    final failure = getEntriesFailure;
    if (failure != null) {
      throw failure;
    }
    return entries;
  }

  @override
  Future<void> saveEntries(List<WellbeingEntry> entries) async {
    this.entries = entries;
    lastSavedEntries = entries;
  }

  @override
  Future<void> saveEntry(WellbeingEntry entry) async {
    entries = <WellbeingEntry>[entry, ...entries];
  }
}
