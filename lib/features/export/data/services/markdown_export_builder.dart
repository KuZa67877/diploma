import 'package:intl/intl.dart';
import '../../domain/entities/export_payload.dart';

class MarkdownExportBuilder {
  const MarkdownExportBuilder();

  String build(ExportPayload payload) {
    final buffer = StringBuffer();
    buffer.writeln('# Экспорт данных MediAI');
    buffer.writeln();
    buffer.writeln(
      '**Период:** ${_date(payload.range.start)} — ${_date(payload.range.end)}',
    );
    buffer.writeln('**Записей:** ${payload.recordCount}');
    buffer.writeln('**Источников:** ${payload.sourceCount}');
    buffer.writeln();

    if (payload.personalData.isNotEmpty) {
      buffer.writeln('## Личные данные');
      payload.personalData.forEach((key, value) {
        buffer.writeln('- ${_personalKey(key)}: $value');
      });
      buffer.writeln();
    }

    for (final section in payload.sections) {
      if (!section.hasData) {
        continue;
      }
      buffer.writeln('## ${section.title}');
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

    buffer.writeln('## Дисклеймер');
    for (final warning in payload.warnings) {
      buffer.writeln('- $warning');
    }
    return buffer.toString().trimRight();
  }

  String _fieldValue(ExportField field) {
    final base = field.displayValue ?? 'нет данных';
    final unit = (field.unit ?? '').trim();
    final withUnit = unit.isEmpty ? base : '$base $unit';
    final extras = <String>[];
    if (field.deviation != null && field.deviation!.trim().isNotEmpty) {
      extras.add('отклонение ${field.deviation}');
    }
    if (field.source != null && field.source!.trim().isNotEmpty) {
      extras.add('источник ${field.source}');
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
