import 'package:equatable/equatable.dart';

enum PatientSex { female, male, unspecified }

class PatientContext extends Equatable {
  final int? age;
  final PatientSex sex;

  const PatientContext({required this.age, this.sex = PatientSex.unspecified});

  @override
  List<Object?> get props => [age, sex];
}
