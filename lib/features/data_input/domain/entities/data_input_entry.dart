import 'package:equatable/equatable.dart';

class DataInputEntry extends Equatable {
  final DateTime recordedAt;
  final String? firstName;
  final String? lastName;
  final double? height;
  final int? age;
  final String? sex;
  final int? systolic;
  final int? diastolic;
  final int? glucose;
  final double? weight;
  final double? temperature;
  final List<String> symptoms;

  const DataInputEntry({
    required this.recordedAt,
    this.firstName,
    this.lastName,
    this.height,
    this.age,
    this.sex,
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
    firstName,
    lastName,
    height,
    age,
    sex,
    systolic,
    diastolic,
    glucose,
    weight,
    temperature,
    symptoms,
  ];
}
