import '../../domain/entities/data_input_config.dart';
import 'symptom_option_model.dart';

class DataInputConfigModel extends DataInputConfig {
  const DataInputConfigModel({
    required super.symptoms,
  });

  factory DataInputConfigModel.fromJson(Map<String, dynamic> json) {
    final symptoms = (json['symptoms'] as List<dynamic>?)
            ?.map((item) => SymptomOptionModel.fromJson(
                  item as Map<String, dynamic>,
                ))
            .toList() ??
        const <SymptomOptionModel>[];

    return DataInputConfigModel(symptoms: symptoms);
  }

  Map<String, dynamic> toJson() {
    return {
      'symptoms': symptoms
          .map((item) => (item as SymptomOptionModel).toJson())
          .toList(),
    };
  }
}
