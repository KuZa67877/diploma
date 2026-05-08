import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/ai_assistant/domain/entities/ai_chat_message.dart';
import 'package:medi_ai/features/ai_assistant/domain/entities/ai_request_size.dart';
import 'package:medi_ai/features/ai_assistant/domain/services/token_estimator_service.dart';

void main() {
  group('TokenEstimatorService', () {
    const service = TokenEstimatorService();

    test('estimates text tokens with a simple length/4 heuristic', () {
      final text = 'a' * 400;

      final estimated = service.estimateTextTokens(text);

      expect(estimated, 100);
    });

    test('estimates tokens across messages', () {
      final messages = [
        AiChatMessage(
          id: '1',
          role: AiChatRole.user,
          content: 'a' * 120,
          createdAt: DateTime(2026, 5, 1),
        ),
        AiChatMessage(
          id: '2',
          role: AiChatRole.assistant,
          content: 'b' * 80,
          createdAt: DateTime(2026, 5, 1, 0, 1),
        ),
      ];

      final estimated = service.estimateMessagesTokens(messages);

      expect(estimated, 50);
    });

    test('classifies small medium and large requests', () {
      expect(service.classifyRequestSize(1200), AiRequestSize.small);
      expect(service.classifyRequestSize(1500), AiRequestSize.medium);
      expect(service.classifyRequestSize(5200), AiRequestSize.large);
    });
  });
}
