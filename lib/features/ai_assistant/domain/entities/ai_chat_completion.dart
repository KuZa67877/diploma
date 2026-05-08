import 'package:equatable/equatable.dart';

class AiChatCompletion extends Equatable {
  final String content;
  final String model;
  final int? promptTokens;
  final int? completionTokens;

  const AiChatCompletion({
    required this.content,
    required this.model,
    this.promptTokens,
    this.completionTokens,
  });

  @override
  List<Object?> get props => [content, model, promptTokens, completionTokens];
}
