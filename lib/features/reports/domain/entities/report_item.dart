import 'package:equatable/equatable.dart';

class ReportItem extends Equatable {
  final int id;
  final String titleKey;
  final String date;
  final String type;
  final String status;

  const ReportItem({
    required this.id,
    required this.titleKey,
    required this.date,
    required this.type,
    required this.status,
  });

  @override
  List<Object> get props => [id, titleKey, date, type, status];
}
