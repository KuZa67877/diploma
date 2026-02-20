import '../../domain/entities/report_item.dart';

class ReportItemModel extends ReportItem {
  const ReportItemModel({
    required super.id,
    required super.titleKey,
    required super.date,
    required super.type,
    required super.status,
  });

  factory ReportItemModel.fromJson(Map<String, dynamic> json) {
    return ReportItemModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      titleKey: json['titleKey']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titleKey': titleKey,
      'date': date,
      'type': type,
      'status': status,
    };
  }
}
