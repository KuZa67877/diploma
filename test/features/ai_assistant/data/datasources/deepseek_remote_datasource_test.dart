import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/core/error/failures.dart';
import 'package:medi_ai/features/ai_assistant/data/datasources/deepseek_remote_datasource.dart';
import 'package:medi_ai/features/ai_assistant/domain/entities/ai_assistant_settings.dart';
import 'package:medi_ai/features/ai_assistant/domain/entities/ai_chat_message.dart';

void main() {
  group('DeepSeekRemoteDataSource', () {
    final settings = const AiAssistantSettings.defaults(apiKey: 'test-key');
    final messages = <AiChatMessage>[
      AiChatMessage(
        id: '1',
        role: AiChatRole.user,
        content: 'Analyze my health data',
        createdAt: DateTime(2026, 5, 1),
      ),
    ];

    test('parses successful chat completion response', () async {
      final dataSource = DeepSeekRemoteDataSourceImpl(
        postInvoker: ({
          required uri,
          required headers,
          required body,
          required timeout,
        }) async {
          return const DeepSeekHttpResponse(
            statusCode: 200,
            body:
                '{"model":"deepseek-chat","choices":[{"message":{"content":"Summary response"}}],"usage":{"prompt_tokens":120,"completion_tokens":64}}',
          );
        },
      );

      final response = await dataSource.createChatCompletion(
        settings: settings,
        messages: messages,
      );

      expect(response.content, 'Summary response');
      expect(response.promptTokens, 120);
      expect(response.completionTokens, 64);
    });

    test('throws auth failure for 401', () async {
      final dataSource = DeepSeekRemoteDataSourceImpl(
        postInvoker: ({
          required uri,
          required headers,
          required body,
          required timeout,
        }) async {
          return const DeepSeekHttpResponse(statusCode: 401, body: '{}');
        },
      );

      expect(
        () => dataSource.createChatCompletion(
          settings: settings,
          messages: messages,
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Неверный API-ключ'),
          ),
        ),
      );
    });

    test('throws readable message for 429', () async {
      final dataSource = DeepSeekRemoteDataSourceImpl(
        postInvoker: ({
          required uri,
          required headers,
          required body,
          required timeout,
        }) async {
          return const DeepSeekHttpResponse(statusCode: 429, body: '{}');
        },
      );

      expect(
        () => dataSource.createChatCompletion(
          settings: settings,
          messages: messages,
        ),
        throwsA(
          isA<ServerFailure>().having(
            (failure) => failure.message,
            'message',
            contains('Превышен текущий лимит API'),
          ),
        ),
      );
    });

    test('throws timeout as network failure', () async {
      final dataSource = DeepSeekRemoteDataSourceImpl(
        postInvoker: ({
          required uri,
          required headers,
          required body,
          required timeout,
        }) async {
          throw TimeoutException('timeout');
        },
      );

      expect(
        () => dataSource.createChatCompletion(
          settings: settings,
          messages: messages,
        ),
        throwsA(
          isA<NetworkFailure>().having(
            (failure) => failure.message,
            'message',
            contains('timeout'),
          ),
        ),
      );
    });

    test('throws network failure without internet', () async {
      final dataSource = DeepSeekRemoteDataSourceImpl(
        postInvoker: ({
          required uri,
          required headers,
          required body,
          required timeout,
        }) async {
          throw const SocketException('offline');
        },
      );

      expect(
        () => dataSource.createChatCompletion(
          settings: settings,
          messages: messages,
        ),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
