import '../../domain/entities/splash_data.dart';

class SplashDataModel extends SplashData {
  const SplashDataModel({
    required super.appName,
    required super.tagline,
    required super.durationMs,
  });

  factory SplashDataModel.fromJson(Map<String, dynamic> json) {
    return SplashDataModel(
      appName: json['appName']?.toString() ?? '',
      tagline: json['tagline']?.toString() ?? '',
      durationMs: json['durationMs'] is int
          ? json['durationMs'] as int
          : int.tryParse('${json['durationMs']}') ?? 2500,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'tagline': tagline,
      'durationMs': durationMs,
    };
  }
}
