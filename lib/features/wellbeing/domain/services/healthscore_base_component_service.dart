class HealthScoreBaseComponentService {
  static const double _defaultBase = 78.0;

  const HealthScoreBaseComponentService();

  double? estimateScore({
    required int? systolic,
    required int? diastolic,
    required int? glucose,
    required double? temperatureC,
    required double? heightCm,
    required double? weightKg,
  }) {
    final bmi = _calculateBmi(heightCm, weightKg);
    final hasAnyCoreValue =
        systolic != null ||
        diastolic != null ||
        glucose != null ||
        temperatureC != null ||
        bmi != null;
    if (!hasAnyCoreValue) {
      return null;
    }

    var score = _defaultBase;

    if (systolic != null) {
      if (systolic >= 140 || systolic < 90) {
        score -= 12;
      } else if (systolic >= 130) {
        score -= 6;
      }
    }

    if (diastolic != null) {
      if (diastolic >= 90 || diastolic < 60) {
        score -= 10;
      } else if (diastolic >= 85) {
        score -= 5;
      }
    }

    if (glucose != null) {
      if (glucose > 180 || glucose < 70) {
        score -= 16;
      } else if (glucose > 140) {
        score -= 8;
      }
    }

    if (temperatureC != null) {
      if (temperatureC >= 38 || temperatureC < 35.5) {
        score -= 18;
      } else if (temperatureC >= 37.2) {
        score -= 8;
      }
    }

    if (bmi != null) {
      if (bmi >= 30 || bmi < 18.5) {
        score -= 10;
      } else if (bmi >= 27.5) {
        score -= 5;
      }
    }

    return score.clamp(0.0, 100.0);
  }

  double estimateConfidence({
    required int? systolic,
    required int? diastolic,
    required int? glucose,
    required double? temperatureC,
    required double? heightCm,
    required double? weightKg,
  }) {
    var available = 0;
    if (systolic != null) {
      available += 1;
    }
    if (diastolic != null) {
      available += 1;
    }
    if (glucose != null) {
      available += 1;
    }
    if (temperatureC != null) {
      available += 1;
    }
    if (_calculateBmi(heightCm, weightKg) != null) {
      available += 1;
    }

    if (available == 0) {
      return 0.0;
    }
    return (available / 5).clamp(0.0, 1.0);
  }

  double? _calculateBmi(double? heightCm, double? weightKg) {
    if (heightCm == null || weightKg == null || heightCm <= 0) {
      return null;
    }
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }
}
