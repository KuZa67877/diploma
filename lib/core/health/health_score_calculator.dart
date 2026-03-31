import '../supabase/onboarding_profile_snapshot.dart';

class HealthScoreCalculator {
  static int calculate(OnboardingProfileSnapshot profile, {int fallback = 78}) {
    if (!profile.hasAnyCoreHealthValue) {
      return fallback.clamp(0, 100);
    }

    var score = fallback;

    final systolic = profile.systolic;
    if (systolic != null) {
      if (systolic >= 140 || systolic < 90) {
        score -= 12;
      } else if (systolic >= 130) {
        score -= 6;
      }
    }

    final diastolic = profile.diastolic;
    if (diastolic != null) {
      if (diastolic >= 90 || diastolic < 60) {
        score -= 10;
      } else if (diastolic >= 85) {
        score -= 5;
      }
    }

    final glucose = profile.glucose;
    if (glucose != null) {
      if (glucose > 180 || glucose < 70) {
        score -= 16;
      } else if (glucose > 140) {
        score -= 8;
      }
    }

    final temperature = profile.temperatureC;
    if (temperature != null) {
      if (temperature >= 38 || temperature < 35.5) {
        score -= 18;
      } else if (temperature >= 37.2) {
        score -= 8;
      }
    }

    final bmi = _calculateBmi(profile.heightCm, profile.weightKg);
    if (bmi != null) {
      if (bmi >= 30 || bmi < 18.5) {
        score -= 10;
      } else if (bmi >= 27.5) {
        score -= 5;
      }
    }

    if (score < 0) {
      return 0;
    }
    if (score > 100) {
      return 100;
    }
    return score;
  }

  static String statusForScore(int score) {
    if (score < 50) {
      return 'risk';
    }
    if (score < 75) {
      return 'attention';
    }
    return 'stable';
  }

  static double? _calculateBmi(double? heightCm, double? weightKg) {
    if (heightCm == null || weightKg == null || heightCm <= 0) {
      return null;
    }
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }
}
