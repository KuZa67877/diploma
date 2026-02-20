import 'package:equatable/equatable.dart';
import 'symptom_option.dart';

class DataInputConfig extends Equatable {
  final List<SymptomOption> symptoms;

  const DataInputConfig({
    required this.symptoms,
  });

  @override
  List<Object> get props => [symptoms];
}
