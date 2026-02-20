import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/data_input/domain/entities/data_input_config.dart';
import 'package:medi_ai/features/data_input/domain/entities/data_input_entry.dart';
import 'package:medi_ai/features/data_input/domain/entities/symptom_option.dart';
import 'package:medi_ai/features/data_input/domain/repositories/data_input_repository.dart';
import 'package:medi_ai/features/data_input/domain/usecases/get_data_input_config.dart';
import 'package:medi_ai/features/data_input/domain/usecases/submit_data_input.dart';
import 'package:medi_ai/features/data_input/presentation/bloc/data_input_cubit.dart';

class _FakeRepository implements DataInputRepository {
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
  group('DataInputCubit', () {
    test('loads config and emits ready state', () async {
      final cubit = DataInputCubit(
        getConfig: GetDataInputConfig(_FakeRepository()),
        submitDataInput: SubmitDataInput(_FakeRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(
          ready: (data) => data.symptoms.isNotEmpty,
          orElse: () => false,
        ),
        isTrue,
      );

      await cubit.close();
    });

    test('emits error on load failure', () async {
      final cubit = DataInputCubit(
        getConfig: GetDataInputConfig(_FailingRepository()),
        submitDataInput: SubmitDataInput(_FailingRepository()),
      );

      await cubit.load();

      expect(
        cubit.state.maybeWhen(error: (message) => message.isNotEmpty, orElse: () => false),
        isTrue,
      );

      await cubit.close();
    });

    test('returns validation error on invalid submit', () async {
      final cubit = DataInputCubit(
        getConfig: GetDataInputConfig(_FakeRepository()),
        submitDataInput: SubmitDataInput(_FakeRepository()),
      );

      await cubit.load();
      await cubit.submit(
        systolicText: '20',
        diastolicText: '',
        glucoseText: '',
        weightText: '',
        temperatureText: '',
      );

      final hasError = cubit.state.maybeWhen(
        ready: (data) => data.errors['bloodPressure'] == 'systolicError',
        orElse: () => false,
      );

      expect(hasError, isTrue);

      await cubit.close();
    });

    test('emits success on valid submit', () async {
      final cubit = DataInputCubit(
        getConfig: GetDataInputConfig(_FakeRepository()),
        submitDataInput: SubmitDataInput(_FakeRepository()),
      );

      await cubit.load();
      await cubit.submit(
        systolicText: '120',
        diastolicText: '80',
        glucoseText: '120',
        weightText: '70',
        temperatureText: '36.6',
      );

      expect(
        cubit.state.maybeWhen(success: (_) => true, orElse: () => false),
        isTrue,
      );

      await cubit.close();
    });
  });
}
