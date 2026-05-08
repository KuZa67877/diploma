import '../entities/ai_chat_message.dart';
import '../entities/ai_request_size.dart';

class TokenEstimatorService {
  static const int _estimatedImageTokens = 850;

  const TokenEstimatorService();

  int estimateTextTokens(String text) {
    if (text.trim().isEmpty) {
      return 0;
    }
    return (text.length / 4).ceil();
  }

  int estimateMessagesTokens(List<AiChatMessage> messages) {
    return messages.fold<int>(
      0,
      (sum, item) =>
          sum +
          (item.estimatedTokens ?? estimateTextTokens(item.content)) +
          (item.hasImageAttachment ? _estimatedImageTokens : 0),
    );
  }

  AiRequestSize classifyRequestSize(int estimatedTokens) {
    if (estimatedTokens > 5000) {
      return AiRequestSize.large;
    }
    if (estimatedTokens >= 1500) {
      return AiRequestSize.medium;
    }
    return AiRequestSize.small;
  }
}
