import '../entities/health_score_input.dart';
import '../entities/health_score_result.dart';
import '../services/healthscore_calculator_service.dart';

class CalculateHealthScore {
  final HealthScoreCalculatorService _calculatorService;

  const CalculateHealthScore(this._calculatorService);

  HealthScoreResult call(HealthScoreInput input) {
    return _calculatorService.calculate(input);
  }
}
