import 'package:intl/intl.dart';
import '../../domain/entities/export_payload.dart';

class MedicalExportBuilder {
  const MedicalExportBuilder();

  String build(ExportPayload payload) {
    final buffer = StringBuffer();
    buffer.writeln('ОТЧЁТ О ПОКАЗАТЕЛЯХ СОСТОЯНИЯ');
    buffer.writeln();
    buffer.writeln(
      'Период наблюдения: ${_date(payload.range.start)} — ${_date(payload.range.end)}',
    );
    buffer.writeln();
    buffer.writeln('Источник данных:');
    buffer.writeln('- Данные носимого устройства / Health API');
    if (payload.personalData.isNotEmpty) {
      buffer.writeln('- Профиль пользователя включён вручную');
    }
    if (payload.observations.any((item) => item.isDerived)) {
      buffer.writeln('- Результаты ML-анализа приложения');
    }
    buffer.writeln();

    if (!payload.hasAnyData) {
      buffer.writeln('Недостаточно данных для экспорта.');
      buffer.writeln();
    } else {
      for (final section in payload.sections) {
        if (!section.hasData) {
          continue;
        }
        buffer.writeln(section.title.toUpperCase());
        for (final field in section.fields) {
          if (!field.hasValue) {
            continue;
          }
          buffer.writeln(
            '- ${field.label.toLowerCase()}: ${_fieldValue(field)}',
          );
        }
        if (section.note != null) {
          buffer.writeln('- комментарий: ${section.note}');
        }
        buffer.writeln();
      }
    }

    buffer.writeln('Дисклеймер:');
    buffer.writeln(
      'Отчёт сформирован автоматически и не является медицинским заключением.',
    );
    return buffer.toString().trimRight();
  }

  String _fieldValue(ExportField field) {
    final base = field.displayValue ?? 'нет данных';
    final unit = (field.unit ?? '').trim();
    final withUnit = unit.isEmpty ? base : '$base $unit';
    final extras = <String>[];
    if (field.status != null && field.status!.trim().isNotEmpty) {
      extras.add('статус ${field.status}');
    }
    if (field.deviation != null && field.deviation!.trim().isNotEmpty) {
      extras.add('откл. ${field.deviation}');
    }
    if (field.source != null && field.source!.trim().isNotEmpty) {
      extras.add(field.source!);
    }
    return extras.isEmpty ? withUnit : '$withUnit (${extras.join(', ')})';
  }

  String _date(DateTime value) =>
      DateFormat('dd.MM.yyyy').format(value.toLocal());
}
