import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/diagnostics/data/datasources/diagnostics_local_data_source.dart';
import 'package:medi_ai/features/diagnostics/domain/entities/manual_vitals.dart';
import 'package:medi_ai/features/diagnostics/domain/entities/patient_context.dart';
import 'package:medi_ai/features/diagnostics/domain/entities/risk_assessment_request.dart';
import 'package:medi_ai/features/diagnostics/domain/entities/risk_assessment_response.dart';
import 'package:medi_ai/features/diagnostics/domain/entities/wearable_aggregates.dart';

void main() {
  group('DiagnosticsLocalDataSourceImpl', () {
    final dataSource = DiagnosticsLocalDataSourceImpl();

    test('returns low risk for neutral baseline request', () async {
      final response = await dataSource.assessRisk(
        _request(
          patientContext: const PatientContext(age: 29),
          manualVitals: const ManualVitals(
            systolic: 118,
            diastolic: 76,
            temperature: 36.6,
          ),
          wearableAggregates: const WearableAggregates(
            heartRate: 72,
            steps: 8500,
            sleepHours: 7.5,
            bloodOxygen: 98,
          ),
        ),
      );

      expect(response.riskLevel, RiskLevel.low);
      expect(response.recommendedAction, RecommendedAction.selfMonitoring);
      expect(response.riskScore, lessThan(0.33));
    });

    test('returns medium risk for moderate symptom and hypertension', () async {
      final response = await dataSource.assessRisk(
        _request(
          symptoms: const <String>['dizziness'],
          patientContext: const PatientContext(age: 48),
          manualVitals: const ManualVitals(
            systolic: 145,
            diastolic: 88,
          ),
          wearableAggregates: const WearableAggregates(
            heartRate: 98,
            steps: 3200,
            sleepHours: 5.5,
            bloodOxygen: 96,
          ),
        ),
      );

      expect(response.riskLevel, RiskLevel.medium);
      expect(
        response.recommendedAction,
        RecommendedAction.scheduleConsultation,
      );
      expect(response.riskScore, inInclusiveRange(0.33, 0.65));
      expect(
        response.topFactors.map((factor) => factor.code),
        contains('bp_sys_140'),
      );
    });

    test('returns high risk for chest pain and critical vitals', () async {
      final response = await dataSource.assessRisk(
        _request(
          symptoms: const <String>['chestPain', 'shortnessOfBreath'],
          patientContext: const PatientContext(age: 67),
          manualVitals: const ManualVitals(
            systolic: 185,
            diastolic: 122,
            glucose: 220,
            temperature: 38.3,
          ),
          wearableAggregates: const WearableAggregates(
            heartRate: 118,
            steps: 600,
            sleepHours: 3.2,
            bloodOxygen: 90,
          ),
          missingFlags: const <String, bool>{
            'sleep': true,
            'spo2': true,
            'glucose': true,
          },
        ),
      );

      expect(response.riskLevel, RiskLevel.high);
      expect(
        response.recommendedAction,
        RecommendedAction.urgentMedicalAttention,
      );
      expect(response.riskScore, greaterThanOrEqualTo(0.66));
      expect(
        response.topFactors.map((factor) => factor.code),
        containsAll(<String>[
          'symptom_chest_pain',
          'spo2_critical',
          'bp_sys_180',
        ]),
      );
      expect(
        response.topFactors.first.contribution,
        greaterThanOrEqualTo(response.topFactors.last.contribution),
      );
    });
  });
}

RiskAssessmentRequest _request({
  List<String> symptoms = const <String>[],
  ManualVitals manualVitals = const ManualVitals(),
  WearableAggregates wearableAggregates = const WearableAggregates(),
  PatientContext patientContext = const PatientContext(age: null),
  Map<String, bool> missingFlags = const <String, bool>{},
}) {
  return RiskAssessmentRequest(
    timestamp: DateTime.utc(2026, 4, 30, 10),
    manualVitals: manualVitals,
    wearableAggregates: wearableAggregates,
    symptoms: symptoms,
    patientContext: patientContext,
    missingFlags: missingFlags,
  );
}
