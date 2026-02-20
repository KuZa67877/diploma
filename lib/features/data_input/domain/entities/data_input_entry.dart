import 'package:equatable/equatable.dart';

class DataInputEntry extends Equatable {
  final DateTime recordedAt;
  final int? systolic;
  final int? diastolic;
  final int? glucose;
  final double? weight;
  final double? temperature;
  final List<String> symptoms;

  const DataInputEntry({
    required this.recordedAt,
    required this.systolic,
    required this.diastolic,
    required this.glucose,
    required this.weight,
    required this.temperature,
    required this.symptoms,
  });

  @override
  List<Object?> get props => [
        recordedAt,
        systolic,
        diastolic,
        glucose,
        weight,
        temperature,
        symptoms,
      ];
}
