import 'package:equatable/equatable.dart';

class AiAssistantSettings extends Equatable {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String visionModel;
  final int maxTokens;
  final double temperature;
  final int dailyRequestLimit;
  final bool economyModeByDefault;

  const AiAssistantSettings({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.visionModel,
    required this.maxTokens,
    required this.temperature,
    required this.dailyRequestLimit,
    required this.economyModeByDefault,
  });

  const AiAssistantSettings.defaults({
    this.apiKey = '',
    this.baseUrl = 'https://api.groq.com/openai/v1',
    this.model = 'llama-3.1-8b-instant',
    this.visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct',
    this.maxTokens = 400,
    this.temperature = 0.2,
    this.dailyRequestLimit = 20,
    this.economyModeByDefault = true,
  });

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  String resolveModel({required bool hasImage}) {
    if (!hasImage) {
      return model.trim();
    }
    final preferredVisionModel = visionModel.trim();
    return preferredVisionModel.isEmpty ? model.trim() : preferredVisionModel;
  }

  AiAssistantSettings copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
    String? visionModel,
    int? maxTokens,
    double? temperature,
    int? dailyRequestLimit,
    bool? economyModeByDefault,
  }) {
    return AiAssistantSettings(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      visionModel: visionModel ?? this.visionModel,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      dailyRequestLimit: dailyRequestLimit ?? this.dailyRequestLimit,
      economyModeByDefault: economyModeByDefault ?? this.economyModeByDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'model': model,
      'visionModel': visionModel,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'dailyRequestLimit': dailyRequestLimit,
      'economyModeByDefault': economyModeByDefault,
    };
  }

  factory AiAssistantSettings.fromJson(Map<String, dynamic> json) {
    return AiAssistantSettings(
      apiKey: json['apiKey']?.toString() ?? '',
      baseUrl: json['baseUrl']?.toString() ?? 'https://api.groq.com/openai/v1',
      model: json['model']?.toString() ?? 'llama-3.1-8b-instant',
      visionModel:
          json['visionModel']?.toString() ??
          'meta-llama/llama-4-scout-17b-16e-instruct',
      maxTokens: _toInt(json['maxTokens']) ?? 400,
      temperature: _toDouble(json['temperature']) ?? 0.2,
      dailyRequestLimit: _toInt(json['dailyRequestLimit']) ?? 20,
      economyModeByDefault: json['economyModeByDefault'] == true,
    );
  }

  static int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  List<Object?> get props => [
    apiKey,
    baseUrl,
    model,
    visionModel,
    maxTokens,
    temperature,
    dailyRequestLimit,
    economyModeByDefault,
  ];
}
