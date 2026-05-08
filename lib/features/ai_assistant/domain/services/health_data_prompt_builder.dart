import 'package:intl/intl.dart';

import '../entities/ai_built_prompt.dart';
import '../entities/ai_economy_options.dart';
import '../entities/ai_health_context.dart';
import '../entities/ai_health_data_type.dart';
import '../entities/ai_prompt_mode.dart';

class HealthDataPromptBuilder {
  const HealthDataPromptBuilder();

  AiBuiltPrompt build({
    required AiHealthContext context,
    required AiPromptMode mode,
    required Set<AiHealthDataType> selectedDataTypes,
    required AiEconomyOptions economyOptions,
  }) {
    final includedTypes = AiHealthDataType.values
        .where((item) => selectedDataTypes.contains(item))
        .toList(growable: false);
    final includedLabels = includedTypes
        .map((item) => item.displayText)
        .toList(growable: false);
    final systemPrompt = _buildSystemPrompt(economyOptions: economyOptions);
    final dataSections = _buildDataSections(
      context,
      includedTypes,
      economyOptions,
    );
    final dateLabel =
        '${_date(context.from)} — ${_date(context.to)}';
    final missingDataText = context.missingData.isEmpty
        ? 'Нет.'
        : context.missingData.join(', ');
    final warningsText = context.warnings.isEmpty
        ? 'Нет дополнительных предупреждений.'
        : context.warnings.map((item) => '- $item').join('\n');
    final economyNotes = <String>[
      if (economyOptions.economizeTokens)
        'Экономия токенов включена: отвечай кратко, по существу, без повторов.',
      if (economyOptions.sendAggregatesOnly)
        'В запрос переданы агрегированные summary вместо сырых измерений.',
      if (economyOptions.trimChatHistory)
        'История диалога обрезается для экономии контекста.',
      if (economyOptions.excludeDiaryNotes)
        'Свободные заметки пользователя не передавались.',
    ];

    final userPrompt = StringBuffer()
      ..writeln('Проанализируй данные пользователя за период: $dateLabel.')
      ..writeln()
      ..writeln('Цель анализа: ${mode.goalText}.')
      ..writeln()
      ..writeln('Данные:')
      ..writeln(dataSections.isEmpty ? 'Данных недостаточно.' : dataSections)
      ..writeln()
      ..writeln('Недостающие данные: $missingDataText')
      ..writeln()
      ..writeln('Предупреждения и контекст:')
      ..writeln(warningsText)
      ..writeln()
      ..writeln('Сформируй ответ в формате:')
      ..writeln('- краткий вывод;')
      ..writeln('- что повлияло на состояние;')
      ..writeln('- какие данные выглядят нормальными;')
      ..writeln('- какие данные требуют внимания;')
      ..writeln('- рекомендации на ближайший день;')
      ..writeln('- уровень уверенности анализа: высокий / средний / низкий;')
      ..writeln('- какие данные стоит добавить для более точного анализа.')
      ..writeln()
      ..writeln('Ограничения:')
      ..writeln('- не ставь диагноз;')
      ..writeln('- не назначай лечение;')
      ..writeln('- не используй категоричные формулировки;')
      ..writeln('- если данных мало, прямо скажи, что уверенность низкая;');

    if (economyNotes.isNotEmpty) {
      userPrompt
        ..writeln()
        ..writeln('Режим экономии и приватности:')
        ..writeln(economyNotes.map((item) => '- $item').join('\n'));
    }

    final contextSummary = StringBuffer()
      ..writeln('Контекст самочувствия за период $dateLabel:')
      ..writeln(dataSections.isEmpty ? 'Данных недостаточно.' : dataSections);
    if (context.missingData.isNotEmpty) {
      contextSummary.writeln('Недостает: $missingDataText');
    }

    final preview = StringBuffer()
      ..writeln('Будут отправлены данные: ${includedLabels.join(', ')}')
      ..writeln('Период: $dateLabel')
      ..writeln()
      ..writeln(_collapseForPreview(userPrompt.toString()));

    return AiBuiltPrompt(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt.toString().trimRight(),
      contextSummary: contextSummary.toString().trimRight(),
      previewText: preview.toString().trimRight(),
      includedDataLabels: includedLabels,
    );
  }

  String _buildSystemPrompt({
    required AiEconomyOptions economyOptions,
  }) {
    final economyLine = economyOptions.economizeTokens
        ? 'Если можно ответить короче без потери смысла, выбирай более короткий вариант.'
        : 'Можно отвечать подробнее, но без воды и повторов.';
    return '''
Ты — AI-помощник для анализа данных самочувствия в мобильном приложении.
Ты не ставишь диагнозы и не заменяешь врача.
Твоя задача — объяснить показатели пользователя простым языком, указать возможные причины изменений и дать осторожные рекомендации общего характера.
Если есть тревожные признаки, посоветуй обратиться к специалисту.
Не делай категоричных медицинских выводов.
Не назначай лекарства.
Не интерпретируй данные как экстренное состояние без осторожной формулировки.
При потенциально опасных симптомах рекомендуй обратиться к врачу или в экстренную службу.
$economyLine
'''.trim();
  }

  String _buildDataSections(
    AiHealthContext context,
    List<AiHealthDataType> includedTypes,
    AiEconomyOptions economyOptions,
  ) {
    final sections = <String>[];
    var index = 1;
    for (final type in includedTypes) {
      final value = context.summaries[type.name];
      if (value == null) {
        continue;
      }
      if (economyOptions.excludeDiaryNotes && type == AiHealthDataType.comments) {
        continue;
      }
      final sanitized = _sanitizeSummary(
        value.toString(),
        type: type,
        economyOptions: economyOptions,
      );
      if (sanitized.trim().isEmpty) {
        continue;
      }
      sections.add('${index++}. ${type.displayText}:\n$sanitized');
    }
    if (sections.isEmpty && context.healthScore != null) {
      sections.add('1. HealthScore:\nТекущее значение: ${context.healthScore}');
    }
    return sections.join('\n\n');
  }

  String _sanitizeSummary(
    String summary, {
    required AiHealthDataType type,
    required AiEconomyOptions economyOptions,
  }) {
    if (!economyOptions.sendAggregatesOnly && !economyOptions.economizeTokens) {
      return summary.trim();
    }
    if (type == AiHealthDataType.comments) {
      return economyOptions.excludeDiaryNotes ? '' : summary.trim();
    }
    final sentences = summary
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((item) => item.trim().isNotEmpty)
        .where((item) {
          final trimmed = item.trimLeft();
          return !trimmed.startsWith('По дням:') &&
              !trimmed.startsWith('Последние измерения:') &&
              !trimmed.startsWith('Последние тренировки:') &&
              !trimmed.startsWith('Последние комментарии пользователя:');
        })
        .toList(growable: false);
    return sentences.join(' ').trim();
  }

  String _collapseForPreview(String text) {
    final normalized = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (normalized.length <= 900) {
      return normalized;
    }
    return '${normalized.substring(0, 900)}...';
  }

  String _date(DateTime value) => DateFormat('dd.MM.yyyy').format(value.toLocal());
}
