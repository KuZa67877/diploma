import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/wellbeing_entry.dart';
import '../../domain/entities/wellbeing_mood.dart';
import '../../domain/usecases/get_wellbeing_entries.dart';
import '../../domain/usecases/save_wellbeing_entry.dart';

class WellbeingState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final DateTime focusedMonth;
  final Map<String, WellbeingEntry> entriesByDate;

  const WellbeingState({
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
    required this.focusedMonth,
    required this.entriesByDate,
  });

  factory WellbeingState.initial() {
    final now = DateTime.now();
    return WellbeingState(
      isLoading: false,
      isSaving: false,
      errorMessage: null,
      focusedMonth: DateTime(now.year, now.month),
      entriesByDate: const {},
    );
  }

  WellbeingState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
    DateTime? focusedMonth,
    Map<String, WellbeingEntry>? entriesByDate,
  }) {
    return WellbeingState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      entriesByDate: entriesByDate ?? this.entriesByDate,
    );
  }

  WellbeingEntry? entryForDate(DateTime date) {
    return entriesByDate[_dateKey(date)];
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSaving,
    errorMessage,
    focusedMonth,
    entriesByDate,
  ];
}

class WellbeingCubit extends Cubit<WellbeingState> {
  final GetWellbeingEntries getWellbeingEntries;
  final SaveWellbeingEntry saveWellbeingEntry;

  WellbeingCubit({
    required this.getWellbeingEntries,
    required this.saveWellbeingEntry,
  }) : super(WellbeingState.initial());

  Future<void> ensureLoaded() async {
    await load();
  }

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    final result = await getWellbeingEntries(const NoParams());
    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: _mapFailureMessage(failure),
          ),
        );
      },
      (entries) {
        final mapped = <String, WellbeingEntry>{};
        for (final entry in entries) {
          mapped[_dateKey(entry.date)] = entry;
        }

        emit(
          state.copyWith(
            isLoading: false,
            clearError: true,
            entriesByDate: mapped,
          ),
        );
      },
    );
  }

  void setFocusedMonth(DateTime month) {
    emit(
      state.copyWith(
        focusedMonth: DateTime(month.year, month.month),
        clearError: true,
      ),
    );
  }

  Future<bool> saveForDate({
    required DateTime date,
    required WellbeingMood mood,
    required Set<String> tags,
    String? note,
    int? stressNow,
    int? fatigue,
    int? wellness,
  }) async {
    final entry = WellbeingEntry(
      date: DateTime(date.year, date.month, date.day),
      mood: mood,
      tags: tags.toList(growable: false),
      note: _normalizeNote(note),
      stressNow: _normalizeScale(stressNow),
      fatigue: _normalizeScale(fatigue),
      wellness: _normalizeScale(wellness),
    );

    emit(state.copyWith(isSaving: true, clearError: true));
    final result = await saveWellbeingEntry(
      SaveWellbeingEntryParams(entry: entry),
    );

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            isSaving: false,
            errorMessage: _mapFailureMessage(failure),
          ),
        );
        return false;
      },
      (_) {
        final next = Map<String, WellbeingEntry>.from(state.entriesByDate);
        next[_dateKey(entry.date)] = entry;
        emit(
          state.copyWith(
            isSaving: false,
            clearError: true,
            entriesByDate: next,
          ),
        );
        return true;
      },
    );
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }

  String? _normalizeNote(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  int? _normalizeScale(int? value) {
    if (value == null || value < 1 || value > 5) {
      return null;
    }
    return value;
  }
}

String _dateKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final year = normalized.year.toString().padLeft(4, '0');
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
