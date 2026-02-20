import '../../domain/entities/activity_sample.dart';

class ActivitySampleModel extends ActivitySample {
  const ActivitySampleModel({
    required super.label,
    required super.steps,
  });

  factory ActivitySampleModel.fromJson(Map<String, dynamic> json) {
    return ActivitySampleModel(
      label: json['label']?.toString() ?? '',
      steps: json['steps'] is int ? json['steps'] as int : int.tryParse('${json['steps']}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'steps': steps,
    };
  }
}
