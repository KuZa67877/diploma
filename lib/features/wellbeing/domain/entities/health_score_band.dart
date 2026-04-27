enum HealthScoreBand { green, yellow, orange, red, noAccess }

extension HealthScoreBandX on HealthScoreBand {
  String get code => switch (this) {
    HealthScoreBand.green => 'green',
    HealthScoreBand.yellow => 'yellow',
    HealthScoreBand.orange => 'orange',
    HealthScoreBand.red => 'red',
    HealthScoreBand.noAccess => 'no_access',
  };

  static HealthScoreBand fromCode(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'green' => HealthScoreBand.green,
      'yellow' => HealthScoreBand.yellow,
      'orange' => HealthScoreBand.orange,
      'red' => HealthScoreBand.red,
      'no_access' => HealthScoreBand.noAccess,
      _ => HealthScoreBand.noAccess,
    };
  }
}
