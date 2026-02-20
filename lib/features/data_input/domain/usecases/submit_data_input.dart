import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/data_input_entry.dart';
import '../errors/data_input_failures.dart';
import '../repositories/data_input_repository.dart';

class SubmitDataInput implements UseCase<Unit, SubmitDataInputParams> {
  final DataInputRepository repository;

  const SubmitDataInput(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SubmitDataInputParams params) async {
    final errors = _validate(params.entry);
    if (errors.isNotEmpty) {
      return Left(DataInputValidationFailure(errors));
    }

    return repository.submitEntry(params.entry);
  }

  Map<String, String> _validate(DataInputEntry entry) {
    final errors = <String, String>{};

    if (entry.systolic != null) {
      if (entry.systolic! < 70 || entry.systolic! > 200) {
        errors['bloodPressure'] = 'systolicError';
      }
    }

    if (entry.glucose != null) {
      if (entry.glucose! < 50 || entry.glucose! > 400) {
        errors['glucose'] = 'glucoseError';
      }
    }

    if (entry.temperature != null) {
      if (entry.temperature! < 35 || entry.temperature! > 42) {
        errors['temperature'] = 'temperatureError';
      }
    }

    return errors;
  }
}

class SubmitDataInputParams extends Equatable {
  final DataInputEntry entry;

  const SubmitDataInputParams({required this.entry});

  @override
  List<Object> get props => [entry];
}
