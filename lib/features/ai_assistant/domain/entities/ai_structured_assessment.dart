import 'dart:convert';

enum AiAssessmentRiskLevel { low, medium, high }

enum AiStructuredAssessmentSource { jsonPayload, plainText }

class AiStructuredAssessment {
  final AiAssessmentRiskLevel? riskLevel;
  final int? confidencePercent;
  final String? title;
  final String? explanation;
  final String? recommendation;
  final String? disclaimer;
  final List<String> visibleSigns;
  final AiStructuredAssessmentSource source;

  const AiStructuredAssessment({
    required this.riskLevel,
    required this.confidencePercent,
    required this.title,
    required this.explanation,
    required this.recommendation,
    required this.disclaimer,
    required this.visibleSigns,
    required this.source,
  });

  bool get shouldHideRawContent =>
      source == AiStructuredAssessmentSource.jsonPayload;

  String get riskLabel => switch (riskLevel) {
    AiAssessmentRiskLevel.low => 'Низкий риск',
    AiAssessmentRiskLevel.medium => 'Средний риск',
    AiAssessmentRiskLevel.high => 'Высокий риск',
    null => 'Оценка состояния',
  };

  String? get summaryText {
    if (explanation != null && explanation!.trim().isNotEmpty) {
      return explanation!.trim();
    }
    return null;
  }

  static AiStructuredAssessment? tryParse(String content) {
    final normalized = content.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final jsonMap = _extractJsonMap(normalized);
    if (jsonMap != null) {
      final parsed = _fromMap(
        jsonMap,
        source: AiStructuredAssessmentSource.jsonPayload,
      );
      if (parsed != null) {
        return parsed;
      }
    }

    return _fromText(normalized);
  }

  static AiStructuredAssessment? _fromMap(
    Map<String, dynamic> json, {
    required AiStructuredAssessmentSource source,
  }) {
    final riskLevel = AiAssessmentRiskLevelX.tryParse(
      json['risk_level'] ?? json['risk'] ?? json['riskLevel'],
    );
    final confidencePercent = _parsePercent(
      json['confidence_percent'] ??
          json['confidence'] ??
          json['confidencePercent'],
    );
    final title = _cleanString(json['title']);
    final explanation = _cleanString(
      json['explanation'] ?? json['description'],
    );
    final recommendation = _cleanString(json['recommendation']);
    final disclaimer = _cleanString(json['disclaimer']);
    final visibleSigns = _stringList(
      json['visible_signs'] ?? json['visibleSigns'],
    );

    if (riskLevel == null &&
        confidencePercent == null &&
        recommendation == null &&
        title == null &&
        explanation == null &&
        visibleSigns.isEmpty) {
      return null;
    }

    return AiStructuredAssessment(
      riskLevel: riskLevel,
      confidencePercent: confidencePercent,
      title: title,
      explanation: explanation,
      recommendation: recommendation,
      disclaimer: disclaimer,
      visibleSigns: visibleSigns,
      source: source,
    );
  }

  static AiStructuredAssessment? _fromText(String text) {
    final riskLevel = AiAssessmentRiskLevelX.tryParse(
      _extractGroup(
        text,
        RegExp(
          r'(?:risk_level|risk|уровень\s+тревожности)\s*[:=\-]\s*"?([a-zа-я]+)"?',
          caseSensitive: false,
        ),
      ),
    );
    final confidencePercent = _parsePercent(
      _extractGroup(
        text,
        RegExp(
          r'(?:confidence_percent|confidence|уверенность)\s*[:=\-]\s*"?(\d{1,3})',
          caseSensitive: false,
        ),
      ),
    );
    final recommendation = _extractGroup(
      text,
      RegExp(
        r'(?:recommendation|рекомендация)\s*[:=\-]\s*(.+)',
        caseSensitive: false,
        multiLine: true,
      ),
    );
    final explanation = _extractGroup(
      text,
      RegExp(
        r'(?:explanation|описание|объяснение)\s*[:=\-]\s*(.+)',
        caseSensitive: false,
        multiLine: true,
      ),
    );
    final disclaimer = _extractGroup(
      text,
      RegExp(
        r'(?:disclaimer|дисклеймер)\s*[:=\-]\s*(.+)',
        caseSensitive: false,
        multiLine: true,
      ),
    );

    if (riskLevel == null &&
        confidencePercent == null &&
        recommendation == null &&
        explanation == null &&
        disclaimer == null) {
      return null;
    }

    return AiStructuredAssessment(
      riskLevel: riskLevel,
      confidencePercent: confidencePercent,
      title: null,
      explanation: explanation,
      recommendation: recommendation,
      disclaimer: disclaimer,
      visibleSigns: const <String>[],
      source: AiStructuredAssessmentSource.plainText,
    );
  }

  static Map<String, dynamic>? _extractJsonMap(String text) {
    final candidates =
        <String?>[text, _stripCodeFence(text), _extractBracedJson(text)]
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty);

    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static String? _stripCodeFence(String text) {
    final match = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1);
  }

  static String? _extractBracedJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return null;
    }
    return text.substring(start, end + 1);
  }

  static String? _cleanString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static int? _parsePercent(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return _clampPercent(value);
    }
    if (value is num) {
      return _clampPercent(value.round());
    }
    final match = RegExp(r'\d{1,3}').firstMatch(value.toString());
    if (match == null) {
      return null;
    }
    final parsed = int.tryParse(match.group(0)!);
    if (parsed == null) {
      return null;
    }
    return _clampPercent(parsed);
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    final single = _cleanString(value);
    if (single == null) {
      return const <String>[];
    }
    return [single];
  }

  static String? _extractGroup(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static int _clampPercent(int value) => value < 0
      ? 0
      : value > 100
      ? 100
      : value;
}

extension AiAssessmentRiskLevelX on AiAssessmentRiskLevel {
  static AiAssessmentRiskLevel? tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'low' || 'низкий' || 'низкая' => AiAssessmentRiskLevel.low,
      'medium' ||
      'med' ||
      'средний' ||
      'средняя' => AiAssessmentRiskLevel.medium,
      'high' || 'высокий' || 'высокая' => AiAssessmentRiskLevel.high,
      _ => null,
    };
  }
}
