import 'package:intl/intl.dart';
import '../../domain/entities/ai_prompt_template.dart';
import '../../domain/entities/export_payload.dart';

class AiPromptExportBuilder {
  const AiPromptExportBuilder();

  String build({
    required ExportPayload payload,
    required AiPromptTemplate template,
    required String customPrompt,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(_instruction(template, customPrompt));
    buffer.writeln();
    buffer.writeln('ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:');
    buffer.writeln(
      'Период: ${_date(payload.range.start)} — ${_date(payload.range.end)}',
    );
    buffer.writeln();

    if (payload.personalData.isNotEmpty) {
      buffer.writeln('Личные данные:');
      payload.personalData.forEach((key, value) {
        buffer.writeln('- ${_personalKey(key)}: $value');
      });
      buffer.writeln();
    }

    if (payload.sections.every((section) => !section.hasData)) {
      buffer.writeln('Недостаточно данных для экспорта.');
    } else {
      for (final section in payload.sections) {
        if (!section.hasData) {
          continue;
        }
        buffer.writeln('${section.title}:');
        for (final field in section.fields) {
          if (!field.hasValue) {
            continue;
          }
          buffer.writeln('- ${field.label}: ${_fieldValue(field)}');
        }
        if (section.note != null) {
          buffer.writeln('- Комментарий: ${section.note}');
        }
        buffer.writeln();
      }
    }

    buffer.writeln('Важно:');
    for (final warning in payload.warnings) {
      buffer.writeln('- $warning');
    }
    return buffer.toString().trimRight();
  }

  String _instruction(AiPromptTemplate template, String customPrompt) {
    return switch (template) {
      AiPromptTemplate.assessState =>
        'Ты — помощник для предварительного анализа самочувствия. Проанализируй данные, не ставь диагноз и объясни выводы простыми словами.',
      AiPromptTemplate.findAnomalies =>
        'Ты — помощник по разбору health-данных. Найди возможные отклонения, опиши вероятные причины и перечисли, что стоит проверить.',
      AiPromptTemplate.dayRecommendations =>
        'Ты — помощник по персональным рекомендациям. На основе данных составь рекомендации на ближайший день по сну, активности, восстановлению и стрессу.',
      AiPromptTemplate.doctorQuestions =>
        'Ты — помощник по подготовке к консультации. На основе данных составь список вопросов, которые стоит задать врачу.',
      AiPromptTemplate.explainSimply =>
        'Ты — помощник, который объясняет health-данные простыми словами. Объясни, что значат показатели, что может настораживать и что наблюдать дальше.',
      AiPromptTemplate.custom =>
        customPrompt.trim().isEmpty
            ? 'Проанализируй мои данные и дай нейтральное объяснение.'
            : customPrompt.trim(),
    };
  }

  String _fieldValue(ExportField field) {
    final base = field.displayValue ?? 'нет данных';
    final unit = (field.unit ?? '').trim();
    final withUnit = unit.isEmpty ? base : '$base $unit';
    final extras = <String>[];
    if (field.status != null && field.status!.trim().isNotEmpty) {
      extras.add('статус: ${field.status}');
    }
    if (field.deviation != null && field.deviation!.trim().isNotEmpty) {
      extras.add('отклонение: ${field.deviation}');
    }
    if (field.source != null && field.source!.trim().isNotEmpty) {
      extras.add('источник: ${field.source}');
    }
    return extras.isEmpty ? withUnit : '$withUnit (${extras.join(', ')})';
  }

  String _date(DateTime value) =>
      DateFormat('dd.MM.yyyy').format(value.toLocal());

  String _personalKey(String key) {
    return switch (key) {
      'name' => 'Имя',
      'email' => 'Email',
      'age' => 'Возраст',
      'sex' => 'Пол',
      'heightCm' => 'Рост, см',
      'weightKg' => 'Вес, кг',
      _ => key,
    };
  }
}
