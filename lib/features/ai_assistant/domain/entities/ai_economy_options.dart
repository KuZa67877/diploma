import 'package:equatable/equatable.dart';

class AiEconomyOptions extends Equatable {
  final bool economizeTokens;
  final bool sendAggregatesOnly;
  final bool trimChatHistory;
  final bool excludeDiaryNotes;

  const AiEconomyOptions({
    required this.economizeTokens,
    required this.sendAggregatesOnly,
    required this.trimChatHistory,
    required this.excludeDiaryNotes,
  });

  const AiEconomyOptions.defaults({bool economyMode = true})
    : economizeTokens = economyMode,
      sendAggregatesOnly = economyMode,
      trimChatHistory = economyMode,
      excludeDiaryNotes = false;

  AiEconomyOptions copyWith({
    bool? economizeTokens,
    bool? sendAggregatesOnly,
    bool? trimChatHistory,
    bool? excludeDiaryNotes,
  }) {
    return AiEconomyOptions(
      economizeTokens: economizeTokens ?? this.economizeTokens,
      sendAggregatesOnly: sendAggregatesOnly ?? this.sendAggregatesOnly,
      trimChatHistory: trimChatHistory ?? this.trimChatHistory,
      excludeDiaryNotes: excludeDiaryNotes ?? this.excludeDiaryNotes,
    );
  }

  @override
  List<Object?> get props => [
    economizeTokens,
    sendAggregatesOnly,
    trimChatHistory,
    excludeDiaryNotes,
  ];
}
