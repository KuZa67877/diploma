import '../../domain/entities/profile_user.dart';

class ProfileUserModel extends ProfileUser {
  const ProfileUserModel({
    required super.name,
    required super.email,
    super.age,
    super.sex,
    super.heightCm,
    super.weightKg,
    super.healthScore,
    super.recordsCount,
    super.streakDays,
    super.wellbeingEntriesCount,
    super.healthSamplesCount,
    super.connectedHealthSourceIds,
  });

  factory ProfileUserModel.fromJson(Map<String, dynamic> json) {
    return ProfileUserModel(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      age: _intOrNull(json['age']),
      sex: json['sex']?.toString(),
      heightCm: _doubleOrNull(json['heightCm']),
      weightKg: _doubleOrNull(json['weightKg']),
      healthScore: _intOrNull(json['healthScore']),
      recordsCount: _intOrNull(json['recordsCount']) ?? 0,
      streakDays: _intOrNull(json['streakDays']) ?? 0,
      wellbeingEntriesCount: _intOrNull(json['wellbeingEntriesCount']) ?? 0,
      healthSamplesCount: _intOrNull(json['healthSamplesCount']) ?? 0,
      connectedHealthSourceIds:
          (json['connectedHealthSourceIds'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList(growable: false) ??
          const <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'age': age,
      'sex': sex,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'healthScore': healthScore,
      'recordsCount': recordsCount,
      'streakDays': streakDays,
      'wellbeingEntriesCount': wellbeingEntriesCount,
      'healthSamplesCount': healthSamplesCount,
      'connectedHealthSourceIds': connectedHealthSourceIds,
    };
  }

  static int? _intOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static double? _doubleOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }
}
