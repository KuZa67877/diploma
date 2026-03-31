import 'package:equatable/equatable.dart';

class ProfileUser extends Equatable {
  final String name;
  final String email;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final int? healthScore;
  final int recordsCount;
  final int streakDays;
  final int wellbeingEntriesCount;
  final int healthSamplesCount;
  final List<String> connectedHealthSourceIds;

  const ProfileUser({
    required this.name,
    required this.email,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.healthScore,
    this.recordsCount = 0,
    this.streakDays = 0,
    this.wellbeingEntriesCount = 0,
    this.healthSamplesCount = 0,
    this.connectedHealthSourceIds = const <String>[],
  });

  @override
  List<Object?> get props => [
    name,
    email,
    age,
    sex,
    heightCm,
    weightKg,
    healthScore,
    recordsCount,
    streakDays,
    wellbeingEntriesCount,
    healthSamplesCount,
    connectedHealthSourceIds,
  ];
}
