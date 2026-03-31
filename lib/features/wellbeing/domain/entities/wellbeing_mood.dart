enum WellbeingMood {
  veryLow,
  low,
  neutral,
  good,
  great;

  String get storageValue {
    switch (this) {
      case WellbeingMood.veryLow:
        return 'very_low';
      case WellbeingMood.low:
        return 'low';
      case WellbeingMood.neutral:
        return 'neutral';
      case WellbeingMood.good:
        return 'good';
      case WellbeingMood.great:
        return 'great';
    }
  }

  String get localizationKey {
    switch (this) {
      case WellbeingMood.veryLow:
        return 'veryLow';
      case WellbeingMood.low:
        return 'low';
      case WellbeingMood.neutral:
        return 'neutral';
      case WellbeingMood.good:
        return 'good';
      case WellbeingMood.great:
        return 'great';
    }
  }

  static WellbeingMood? fromStorageValue(String value) {
    switch (value) {
      case 'very_low':
        return WellbeingMood.veryLow;
      case 'low':
        return WellbeingMood.low;
      case 'neutral':
        return WellbeingMood.neutral;
      case 'good':
        return WellbeingMood.good;
      case 'great':
        return WellbeingMood.great;
      default:
        return null;
    }
  }
}
