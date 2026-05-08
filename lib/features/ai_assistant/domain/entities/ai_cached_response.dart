import 'package:equatable/equatable.dart';

import 'ai_prompt_mode.dart';

class AiCachedResponse extends Equatable {
  final String promptHash;
  final String response;
  final DateTime createdAt;
  final String model;
  final DateTime selectedFrom;
  final DateTime selectedTo;
  final AiPromptMode selectedMode;

  const AiCachedResponse({
    required this.promptHash,
    required this.response,
    required this.createdAt,
    required this.model,
    required this.selectedFrom,
    required this.selectedTo,
    required this.selectedMode,
  });

  bool isExpired({DateTime? now, Duration ttl = const Duration(hours: 24)}) {
    final current = now ?? DateTime.now();
    return current.difference(createdAt) > ttl;
  }

  Map<String, dynamic> toJson() {
    return {
      'promptHash': promptHash,
      'response': response,
      'createdAt': createdAt.toIso8601String(),
      'model': model,
      'selectedFrom': selectedFrom.toIso8601String(),
      'selectedTo': selectedTo.toIso8601String(),
      'selectedMode': selectedMode.name,
    };
  }

  factory AiCachedResponse.fromJson(Map<String, dynamic> json) {
    return AiCachedResponse(
      promptHash: json['promptHash']?.toString() ?? '',
      response: json['response']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      model: json['model']?.toString() ?? '',
      selectedFrom:
          DateTime.tryParse(json['selectedFrom']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      selectedTo:
          DateTime.tryParse(json['selectedTo']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      selectedMode: AiPromptMode.values.firstWhere(
        (item) => item.name == json['selectedMode']?.toString(),
        orElse: () => AiPromptMode.shortAnalysis,
      ),
    );
  }

  @override
  List<Object?> get props => [
    promptHash,
    response,
    createdAt,
    model,
    selectedFrom,
    selectedTo,
    selectedMode,
  ];
}
