import 'package:equatable/equatable.dart';

class ManualVitals extends Equatable {
  final int? systolic;
  final int? diastolic;
  final int? glucose;
  final double? temperature;
  final double? weight;

  const ManualVitals({
    this.systolic,
    this.diastolic,
    this.glucose,
    this.temperature,
    this.weight,
  });

  @override
  List<Object?> get props => [
    systolic,
    diastolic,
    glucose,
    temperature,
    weight,
  ];
}
