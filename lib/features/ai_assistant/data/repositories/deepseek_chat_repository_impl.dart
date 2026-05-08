import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/ai_assistant_settings.dart';
import '../../domain/entities/ai_cached_response.dart';
import '../../domain/entities/ai_chat_completion.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_prompt_mode.dart';
import '../../domain/repositories/deepseek_chat_repository.dart';
import '../datasources/ai_assistant_local_data_source.dart';
import '../datasources/deepseek_remote_datasource.dart';

class DeepSeekChatRepositoryImpl implements DeepSeekChatRepository {
  final DeepSeekRemoteDataSource _remoteDataSource;
  final AiAssistantLocalDataSource _localDataSource;
  final AppLogger _logger = AppLogger.instance;

  DeepSeekChatRepositoryImpl({
    required DeepSeekRemoteDataSource remoteDataSource,
    required AiAssistantLocalDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  @override
  Future<Either<Failure, AiChatCompletion>> sendMessages({
    required AiAssistantSettings settings,
    required List<AiChatMessage> messages,
  }) async {
    try {
      final response = await _remoteDataSource.createChatCompletion(
        settings: settings,
        messages: messages,
      );
      return Right(response);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      _logger.error(
        'ai.chat',
        'Repository swallowed unexpected Groq error',
        payload: {
          'type': error.runtimeType.toString(),
          'message': error.toString(),
        },
      );
      return Left(
        ServerFailure(
          'Не удалось получить ответ от Groq: ${error.runtimeType}.',
        ),
      );
    }
  }

  @override
  Future<AiAssistantSettings> getSettings() {
    return _localDataSource.getSettings();
  }

  @override
  Future<void> saveSettings(AiAssistantSettings settings) {
    return _localDataSource.saveSettings(settings);
  }

  @override
  Future<AiCachedResponse?> getCachedResponse({
    required String prompt,
    required String model,
    required AiPromptMode mode,
  }) {
    return _localDataSource.getCachedResponse(
      buildPromptHash(prompt: prompt, model: model, mode: mode),
    );
  }

  @override
  Future<void> cacheResponse(AiCachedResponse response) {
    return _localDataSource.saveCachedResponse(response);
  }

  @override
  String buildPromptHash({
    required String prompt,
    required String model,
    required AiPromptMode mode,
  }) {
    final input = '$prompt|$model|${mode.name}';
    const int fnvOffset = 0xcbf29ce484222325;
    const int fnvPrime = 0x100000001b3;
    const int mask64 = 0xffffffffffffffff;
    var hash = fnvOffset;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & mask64;
    }
    return hash.toRadixString(16);
  }
}
