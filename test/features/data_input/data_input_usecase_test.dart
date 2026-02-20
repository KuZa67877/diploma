import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/core/usecases/usecase.dart';
import 'package:medi_ai/features/data_input/domain/entities/data_input_config.dart';
import 'package:medi_ai/features/data_input/domain/entities/data_input_entry.dart';
import 'package:medi_ai/features/data_input/domain/entities/symptom_option.dart';
import 'package:medi_ai/features/data_input/domain/errors/data_input_failures.dart';
import 'package:medi_ai/features/data_input/domain/repositories/data_input_repository.dart';
import 'package:medi_ai/features/data_input/domain/usecases/get_data_input_config.dart';
import 'package:medi_ai/features/data_input/domain/usecases/submit_data_input.dart';

class _FakeRepository implements DataInputRepository {
  bool submitCalled = false;

  @override
  Future<Either<Failure, DataInputConfig>> getConfig() async {
    return Right(
      DataInputConfig(
        symptoms: const [
          SymptomOption(id: 'headache', labelKey: 'headache'),
        ],
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> submitEntry(DataInputEntry entry) async {
    submitCalled = true;
    return const Right(unit);
  }
}

class _FailingRepository implements DataInputRepository {
  @override
  Future<Either<Failure, DataInputConfig>> getConfig() async {
    return const Left(CacheFailure());
  }

  @override
  Future<Either<Failure, Unit>> submitEntry(DataInputEntry entry) async {
    return const Left(CacheFailure());
  }
}

void main() {
  group('GetDataInputConfig', () {
    test('returns config on success', () async {
      final repo = _FakeRepository();
      final useCase = GetDataInputConfig(repo);

      final result = await useCase(const NoParams());

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (value) => value.symptoms.length), 1);
    });

    test('returns failure on error', () async {
      final useCase = GetDataInputConfig(_FailingRepository());

      final result = await useCase(const NoParams());

      expect(result.isLeft(), isTrue);
      expect(result.fold((failure) => failure, (_) => null), isA<CacheFailure>());
    });
  });

  group('SubmitDataInput', () {
    test('returns validation failure on invalid data', () async {
      final repo = _FakeRepository();
      final useCase = SubmitDataInput(repo);

      final result = await useCase(
        SubmitDataInputParams(
          entry: DataInputEntry(
            recordedAt: DateTime(2024),
            systolic: 20,
            diastolic: null,
            glucose: null,
            weight: null,
            temperature: null,
            symptoms: const [],
          ),
        ),
      );

      expect(result.isLeft(), isTrue);
      expect(
        result.fold((failure) => failure, (_) => null),
        isA<DataInputValidationFailure>(),
      );
    });

    test('submits when data is valid', () async {
      final repo = _FakeRepository();
      final useCase = SubmitDataInput(repo);

      final result = await useCase(
        SubmitDataInputParams(
          entry: DataInputEntry(
            recordedAt: DateTime(2024),
            systolic: 120,
            diastolic: 80,
            glucose: 120,
            weight: 70,
            temperature: 36.6,
            symptoms: const [],
          ),
        ),
      );

      expect(result.isRight(), isTrue);
      expect(repo.submitCalled, isTrue);
    });
  });
}
