import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/ai_assistant_settings.dart';
import '../entities/ai_cached_response.dart';
import '../entities/ai_chat_completion.dart';
import '../entities/ai_chat_message.dart';
import '../entities/ai_prompt_mode.dart';

abstract class DeepSeekChatRepository {
  Future<Either<Failure, AiChatCompletion>> sendMessages({
    required AiAssistantSettings settings,
    required List<AiChatMessage> messages,
  });

  Future<AiAssistantSettings> getSettings();

  Future<void> saveSettings(AiAssistantSettings settings);

  Future<AiCachedResponse?> getCachedResponse({
    required String prompt,
    required String model,
    required AiPromptMode mode,
  });

  Future<void> cacheResponse(AiCachedResponse response);

  String buildPromptHash({
    required String prompt,
    required String model,
    required AiPromptMode mode,
  });
}
