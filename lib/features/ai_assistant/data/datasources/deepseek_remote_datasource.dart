import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/ai_assistant_settings.dart';
import '../../domain/entities/ai_chat_completion.dart';
import '../../domain/entities/ai_chat_message.dart';

class DeepSeekHttpResponse {
  final int statusCode;
  final String body;

  const DeepSeekHttpResponse({required this.statusCode, required this.body});
}

typedef DeepSeekPostInvoker =
    Future<DeepSeekHttpResponse> Function({
      required Uri uri,
      required Map<String, String> headers,
      required String body,
      required Duration timeout,
    });

abstract class DeepSeekRemoteDataSource {
  Future<AiChatCompletion> createChatCompletion({
    required AiAssistantSettings settings,
    required List<AiChatMessage> messages,
  });
}

class DeepSeekRemoteDataSourceImpl implements DeepSeekRemoteDataSource {
  static const Duration _defaultTimeout = Duration(seconds: 30);

  final DeepSeekPostInvoker _postInvoker;
  final AppLogger _logger = AppLogger.instance;

  DeepSeekRemoteDataSourceImpl({DeepSeekPostInvoker? postInvoker})
    : _postInvoker = postInvoker ?? _defaultPostInvoker;

  @override
  Future<AiChatCompletion> createChatCompletion({
    required AiAssistantSettings settings,
    required List<AiChatMessage> messages,
  }) async {
    final hasImage = messages.any((item) => item.hasImageAttachment);
    if (!settings.hasApiKey) {
      throw const AuthFailure(
        'Добавьте API-ключ Groq в .env (GROQ_API_KEY), чтобы использовать AI-чат.',
      );
    }

    final uri = Uri.parse(
      '${settings.baseUrl.replaceFirst(RegExp(r'/$'), '')}/chat/completions',
    );
    final selectedModel = settings.resolveModel(hasImage: hasImage);
    if (selectedModel.isEmpty) {
      throw const ValidationFailure(
        'Укажите модель Groq в .env перед отправкой запроса.',
      );
    }
    final requestBody = jsonEncode({
      'model': selectedModel,
      'messages': messages.map(_toApiMessage).toList(growable: false),
      'temperature': settings.temperature,
      'max_completion_tokens': settings.maxTokens,
    });

    try {
      final response = await _postInvoker(
        uri: uri,
        headers: {
          'Authorization': 'Bearer ${settings.apiKey}',
          'Content-Type': 'application/json',
        },
        body: requestBody,
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 401) {
        throw const AuthFailure(
          'Неверный API-ключ Groq. Проверьте значение GROQ_API_KEY в .env.',
        );
      }
      if (response.statusCode == 429) {
        throw const ServerFailure(
          'Превышен текущий лимит API. Попробуйте позже или уменьшите объем запроса.',
        );
      }
      if (response.statusCode >= 500) {
        throw ServerFailure(
          'Groq временно недоступен (${response.statusCode}). Попробуйте позже.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final apiError = _extractApiErrorMessage(response.body);
        throw ServerFailure(
          apiError ?? 'Groq вернул ошибку ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ServerFailure('Groq вернул неожиданный формат ответа.');
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const ServerFailure('Groq вернул пустой ответ без choices.');
      }

      final firstChoice = choices.first;
      if (firstChoice is! Map<String, dynamic>) {
        throw const ServerFailure('Groq вернул неожиданный формат choices.');
      }

      final message = firstChoice['message'];
      if (message is! Map<String, dynamic>) {
        throw const ServerFailure('Groq не вернул message в ответе.');
      }

      final content = message['content']?.toString().trim() ?? '';
      if (content.isEmpty) {
        throw const ServerFailure('Groq вернул пустое содержимое ответа.');
      }

      final usage = decoded['usage'];
      final promptTokens = usage is Map<String, dynamic>
          ? _toInt(usage['prompt_tokens'])
          : null;
      final completionTokens = usage is Map<String, dynamic>
          ? _toInt(usage['completion_tokens'])
          : null;

      return AiChatCompletion(
        content: content,
        model: decoded['model']?.toString() ?? settings.model,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
      );
    } on SocketException {
      throw const NetworkFailure(
        'Нет подключения к интернету. Проверьте сеть и попробуйте снова.',
      );
    } on Failure {
      rethrow;
    } on HandshakeException catch (error) {
      _logger.error(
        'ai.chat',
        'TLS handshake error while requesting Groq',
        payload: error.toString(),
      );
      throw const NetworkFailure(
        'Не удалось установить защищенное соединение с Groq. Проверьте сеть, дату устройства или VPN/proxy.',
      );
    } on HttpException catch (error) {
      _logger.error(
        'ai.chat',
        'HTTP exception while requesting Groq',
        payload: error.toString(),
      );
      throw ServerFailure('HTTP ошибка при обращении к Groq: ${error.message}');
    } on FormatException catch (error) {
      _logger.error(
        'ai.chat',
        'Failed to parse Groq response',
        payload: error.toString(),
      );
      throw const ServerFailure(
        'Groq вернул ответ в неожиданном формате. Проверьте модель или содержимое ответа.',
      );
    } on TimeoutException {
      throw const NetworkFailure(
        'Запрос к Groq превысил timeout. Попробуйте позже.',
      );
    } catch (error) {
      _logger.error(
        'ai.chat',
        'Unexpected error while requesting Groq',
        payload: {
          'type': error.runtimeType.toString(),
          'message': error.toString(),
          'model': selectedModel,
          'hasImage': hasImage,
        },
      );
      throw ServerFailure(
        'Неожиданная ошибка при обработке ответа Groq: ${error.runtimeType}.',
      );
    }
  }

  static Map<String, dynamic> _toApiMessage(AiChatMessage message) {
    final content = message.attachment == null
        ? message.content
        : [
            if (message.content.trim().isNotEmpty)
              {'type': 'text', 'text': message.content},
            {
              'type': 'image_url',
              'image_url': {'url': message.attachment!.dataUri},
            },
          ];

    return {'role': message.role.apiValue, 'content': content};
  }

  static Future<DeepSeekHttpResponse> _defaultPostInvoker({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
    required Duration timeout,
  }) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(uri).timeout(timeout);
      headers.forEach(request.headers.set);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.add(utf8.encode(body));
      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();
      return DeepSeekHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      httpClient.close(force: true);
    }
  }

  static int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _extractApiErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
