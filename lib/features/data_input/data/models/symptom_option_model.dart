import '../../domain/entities/symptom_option.dart';

class SymptomOptionModel extends SymptomOption {
  const SymptomOptionModel({
    required super.id,
    required super.labelKey,
  });

  factory SymptomOptionModel.fromJson(Map<String, dynamic> json) {
    return SymptomOptionModel(
      id: json['id']?.toString() ?? '',
      labelKey: json['labelKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'labelKey': labelKey,
    };
  }
}
