import '../../../../core/error/failures.dart';

class DataInputValidationFailure extends Failure {
  final Map<String, String> fieldErrors;

  const DataInputValidationFailure(this.fieldErrors)
      : super('Validation failed');

  @override
  List<Object> get props => [message, fieldErrors];
}
