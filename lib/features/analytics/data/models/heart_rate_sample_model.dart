import '../../domain/entities/heart_rate_sample.dart';

class HeartRateSampleModel extends HeartRateSample {
  const HeartRateSampleModel({
    required super.hour,
    required super.bpm,
  });

  factory HeartRateSampleModel.fromJson(Map<String, dynamic> json) {
    return HeartRateSampleModel(
      hour: json['hour'] is int ? json['hour'] as int : int.tryParse('${json['hour']}') ?? 0,
      bpm: json['bpm'] is int ? json['bpm'] as int : int.tryParse('${json['bpm']}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'bpm': bpm,
    };
  }
}
