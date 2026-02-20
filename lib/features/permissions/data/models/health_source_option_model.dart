import '../../domain/entities/health_source_option.dart';

class HealthSourceOptionModel extends HealthSourceOption {
  const HealthSourceOptionModel({
    required super.id,
    required super.nameKey,
    required super.descKey,
    required super.iconKey,
    required super.gradientKeys,
  });

  factory HealthSourceOptionModel.fromJson(Map<String, dynamic> json) {
    final gradientKeys = (json['gradientKeys'] as List<dynamic>?)
            ?.map((value) => value.toString())
            .toList() ??
        const <String>[];

    return HealthSourceOptionModel(
      id: json['id']?.toString() ?? '',
      nameKey: json['nameKey']?.toString() ?? '',
      descKey: json['descKey']?.toString() ?? '',
      iconKey: json['iconKey']?.toString() ?? '',
      gradientKeys: gradientKeys,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameKey': nameKey,
      'descKey': descKey,
      'iconKey': iconKey,
      'gradientKeys': gradientKeys,
    };
  }
}
