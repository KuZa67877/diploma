import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/data_input_entry.dart';
import '../../domain/entities/symptom_option.dart';
import '../../domain/errors/data_input_failures.dart';
import '../../domain/usecases/get_data_input_config.dart';
import '../../domain/usecases/submit_data_input.dart';
import '../models/data_input_ui_models.dart';

part 'data_input_cubit.freezed.dart';
part 'data_input_state.dart';

class DataInputCubit extends Cubit<DataInputState> {
  final GetDataInputConfig getConfig;
  final SubmitDataInput submitDataInput;

  DataInputCubit({
    required this.getConfig,
    required this.submitDataInput,
  }) : super(const DataInputState.initial());

  Future<void> load() async {
    emit(const DataInputState.loading());

    final result = await getConfig(const NoParams());
    result.fold(
      (failure) => emit(DataInputState.error(message: _mapFailureMessage(failure))),
      (config) {
        emit(
          DataInputState.ready(
            data: DataInputViewData(
              selectedDate: DateTime.now(),
              selectedTime: TimeOfDay.now(),
              symptoms: _mapSymptoms(config.symptoms),
              selectedSymptoms: const {},
              errors: const {},
            ),
          ),
        );
      },
    );
  }

  void setDate(DateTime date) {
    _updateData((data) => data.copyWith(selectedDate: date));
  }

  void setTime(TimeOfDay time) {
    _updateData((data) => data.copyWith(selectedTime: time));
  }

  void toggleSymptom(String key) {
    _updateData((data) {
      final next = Set<String>.from(data.selectedSymptoms);
      if (next.contains(key)) {
        next.remove(key);
      } else {
        next.add(key);
      }
      return data.copyWith(selectedSymptoms: next);
    });
  }

  Future<void> submit({
    required String systolicText,
    required String diastolicText,
    required String glucoseText,
    required String weightText,
    required String temperatureText,
  }) async {
    final data = _currentData();
    if (data == null) return;

    emit(DataInputState.submitting(data: data));

    final entry = DataInputEntry(
      recordedAt: DateTime(
        data.selectedDate.year,
        data.selectedDate.month,
        data.selectedDate.day,
        data.selectedTime.hour,
        data.selectedTime.minute,
      ),
      systolic: _parseInt(systolicText),
      diastolic: _parseInt(diastolicText),
      glucose: _parseInt(glucoseText),
      weight: _parseDouble(weightText),
      temperature: _parseDouble(temperatureText),
      symptoms: data.selectedSymptoms.toList(growable: false),
    );

    final result = await submitDataInput(
      SubmitDataInputParams(entry: entry),
    );

    result.fold(
      (failure) {
        if (failure is DataInputValidationFailure) {
          emit(
            DataInputState.ready(
              data: data.copyWith(errors: Map<String, String>.from(
                failure.fieldErrors,
              )),
            ),
          );
          return;
        }

        emit(DataInputState.error(message: _mapFailureMessage(failure)));
      },
      (_) {
        emit(
          DataInputState.success(
            data: data.copyWith(
              errors: const {},
              selectedSymptoms: const {},
            ),
          ),
        );
      },
    );
  }

  void resetStatus() {
    final data = _currentData();
    if (data == null) return;
    emit(DataInputState.ready(data: data));
  }

  void _updateData(DataInputViewData Function(DataInputViewData data) update) {
    final data = _currentData();
    if (data == null) return;
    emit(DataInputState.ready(data: update(data)));
  }

  DataInputViewData? _currentData() {
    return state.maybeWhen(
      ready: (data) => data,
      submitting: (data) => data,
      success: (data) => data,
      orElse: () => null,
    );
  }

  List<SymptomUiModel> _mapSymptoms(List<SymptomOption> symptoms) {
    return symptoms
        .map((symptom) => SymptomUiModel(id: symptom.id, labelKey: symptom.labelKey))
        .toList(growable: false);
  }

  int? _parseInt(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  double? _parseDouble(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value.replaceAll(',', '.'));
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }
}
