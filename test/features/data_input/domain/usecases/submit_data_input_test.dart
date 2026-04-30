import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/data_input/domain/entities/data_input_config.dart';
import 'package:medi_ai/features/data_input/domain/entities/data_input_entry.dart';
import 'package:medi_ai/features/data_input/domain/entities/symptom_option.dart';
import 'package:medi_ai/features/data_input/domain/errors/data_input_failures.dart';
import 'package:medi_ai/features/data_input/domain/repositories/data_input_repository.dart';
import 'package:medi_ai/features/data_input/domain/usecases/submit_data_input.dart';

void main() {
  group('SubmitDataInput', () {
    test('returns field validation errors without calling repository', () async {
      final repository = _FakeDataInputRepository();
      final useCase = SubmitDataInput(repository);
      final entry = DataInputEntry(
        recordedAt: DateTime.utc(2026, 4, 30, 9),
        systolic: 240,
        diastolic: 90,
        glucose: 40,
        weight: 72,
        temperature: 43.1,
        symptoms: const <String>['fatigue'],
      );

      final result = await useCase(SubmitDataInputParams(entry: entry));

      expect(repository.submitCalls, 0);
      expect(result.isLeft(), isTrue);

      final failure = result.fold((value) => value, (_) => null);
      expect(failure, isA<DataInputValidationFailure>());
      expect(
        (failure! as DataInputValidationFailure).fieldErrors,
        const <String, String>{
          'bloodPressure': 'systolicError',
          'glucose': 'glucoseError',
          'temperature': 'temperatureError',
        },
      );
    });

    test('delegates valid entry to repository', () async {
      final repository = _FakeDataInputRepository();
      final useCase = SubmitDataInput(repository);
      final entry = DataInputEntry(
        recordedAt: DateTime.utc(2026, 4, 30, 9),
        firstName: 'Alex',
        systolic: 118,
        diastolic: 76,
        glucose: 95,
        weight: 72,
        temperature: 36.6,
        symptoms: const <String>[],
      );

      final result = await useCase(SubmitDataInputParams(entry: entry));

      expect(result.isRight(), isTrue);
      expect(repository.submitCalls, 1);
      expect(repository.lastEntry, entry);
    });
  });
}

class _FakeDataInputRepository implements DataInputRepository {
  int submitCalls = 0;
  DataInputEntry? lastEntry;

  @override
  Future<Either<Failure, DataInputConfig>> getConfig() async {
    return Right(
      const DataInputConfig(
        symptoms: <SymptomOption>[],
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> submitEntry(DataInputEntry entry) async {
    submitCalls += 1;
    lastEntry = entry;
    return const Right(unit);
  }
}
