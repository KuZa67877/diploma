import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/ai_assistant/domain/entities/ai_economy_options.dart';
import 'package:medi_ai/features/ai_assistant/domain/entities/ai_health_context.dart';
import 'package:medi_ai/features/ai_assistant/domain/entities/ai_health_data_type.dart';
import 'package:medi_ai/features/ai_assistant/domain/entities/ai_prompt_mode.dart';
import 'package:medi_ai/features/ai_assistant/domain/services/health_data_prompt_builder.dart';

void main() {
  group('HealthDataPromptBuilder', () {
    const builder = HealthDataPromptBuilder();
    final context = AiHealthContext(
      from: DateTime(2026, 4, 25),
      to: DateTime(2026, 5, 1),
      healthScore: 74,
      summaries: <String, dynamic>{
        'healthScore':
            'Текущий HealthScore: 74/100. Основные драйверы: sleep: 14.2, stress: -10.4.',
        'sleep':
            'Средняя длительность сна: 6.8 ч. Дней с недосыпом (<7 ч): 4 из 7. По дням: 25.04: 6.1 ч; 26.04: 7.0 ч.',
        'diary':
            'Дневниковых записей: 4. Высокий стресс: 2 дн. Частые теги: insomnia, headache.',
        'comments':
            'Последние комментарии пользователя: 30.04.2026: "Была сильная усталость после работы".',
      },
      warnings: <String>['Есть повышенный индекс физиологических аномалий.'],
      missingData: <String>['SpO2'],
    );

    test('builds a structured prompt without null errors', () {
      final prompt = builder.build(
        context: context,
        mode: AiPromptMode.detailedAnalysis,
        selectedDataTypes: const <AiHealthDataType>{
          AiHealthDataType.healthScore,
          AiHealthDataType.sleep,
          AiHealthDataType.diary,
        },
        economyOptions: const AiEconomyOptions(
          economizeTokens: false,
          sendAggregatesOnly: false,
          trimChatHistory: false,
          excludeDiaryNotes: false,
        ),
      );

      expect(prompt.systemPrompt, contains('не ставишь диагнозы'));
      expect(prompt.userPrompt, contains('Цель анализа: Подробный анализ'));
      expect(prompt.userPrompt, contains('HealthScore'));
      expect(prompt.userPrompt, contains('Недостающие данные: SpO2'));
    });

    test('does not include raw daily fragments in economy mode', () {
      final prompt = builder.build(
        context: context,
        mode: AiPromptMode.shortAnalysis,
        selectedDataTypes: const <AiHealthDataType>{
          AiHealthDataType.sleep,
        },
        economyOptions: const AiEconomyOptions(
          economizeTokens: true,
          sendAggregatesOnly: true,
          trimChatHistory: true,
          excludeDiaryNotes: false,
        ),
      );

      expect(prompt.userPrompt, isNot(contains('По дням:')));
      expect(prompt.userPrompt, contains('Средняя длительность сна'));
    });

    test('includes diary summary when diary is selected', () {
      final prompt = builder.build(
        context: context,
        mode: AiPromptMode.warningSignals,
        selectedDataTypes: const <AiHealthDataType>{
          AiHealthDataType.diary,
        },
        economyOptions: const AiEconomyOptions(
          economizeTokens: false,
          sendAggregatesOnly: false,
          trimChatHistory: false,
          excludeDiaryNotes: false,
        ),
      );

      expect(prompt.userPrompt, contains('Дневниковые отметки'));
      expect(prompt.userPrompt, contains('Частые теги'));
    });

    test('does not include comments when diary notes are disabled', () {
      final prompt = builder.build(
        context: context,
        mode: AiPromptMode.shortAnalysis,
        selectedDataTypes: const <AiHealthDataType>{
          AiHealthDataType.comments,
        },
        economyOptions: const AiEconomyOptions(
          economizeTokens: true,
          sendAggregatesOnly: true,
          trimChatHistory: true,
          excludeDiaryNotes: true,
        ),
      );

      expect(prompt.userPrompt, isNot(contains('Последние комментарии пользователя')));
      expect(prompt.userPrompt, contains('Режим экономии и приватности'));
    });

    test('adds missing data to the resulting prompt', () {
      final prompt = builder.build(
        context: context,
        mode: AiPromptMode.doctorSummary,
        selectedDataTypes: const <AiHealthDataType>{
          AiHealthDataType.healthScore,
        },
        economyOptions: const AiEconomyOptions(
          economizeTokens: false,
          sendAggregatesOnly: false,
          trimChatHistory: false,
          excludeDiaryNotes: false,
        ),
      );

      expect(prompt.userPrompt, contains('Недостающие данные: SpO2'));
    });
  });
}
