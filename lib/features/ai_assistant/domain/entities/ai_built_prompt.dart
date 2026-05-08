import 'package:equatable/equatable.dart';

class AiBuiltPrompt extends Equatable {
  final String systemPrompt;
  final String userPrompt;
  final String contextSummary;
  final String previewText;
  final List<String> includedDataLabels;

  const AiBuiltPrompt({
    required this.systemPrompt,
    required this.userPrompt,
    required this.contextSummary,
    required this.previewText,
    required this.includedDataLabels,
  });

  String get combinedPrompt => '$systemPrompt\n\n$userPrompt';

  @override
  List<Object?> get props => [
    systemPrompt,
    userPrompt,
    contextSummary,
    previewText,
    includedDataLabels,
  ];
}
