import 'package:equatable/equatable.dart';
import 'manual_vitals.dart';
import 'patient_context.dart';
import 'wearable_aggregates.dart';

class RiskAssessmentRequest extends Equatable {
  final DateTime timestamp;
  final ManualVitals manualVitals;
  final WearableAggregates wearableAggregates;
  final List<String> symptoms;
  final PatientContext patientContext;
  final Map<String, bool> missingFlags;

  const RiskAssessmentRequest({
    required this.timestamp,
    required this.manualVitals,
    required this.wearableAggregates,
    required this.symptoms,
    required this.patientContext,
    required this.missingFlags,
  });

  @override
  List<Object> get props => [
    timestamp,
    manualVitals,
    wearableAggregates,
    symptoms,
    patientContext,
    missingFlags,
  ];
}
