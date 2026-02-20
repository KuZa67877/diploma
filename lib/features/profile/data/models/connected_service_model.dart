import '../../domain/entities/connected_service.dart';

class ConnectedServiceModel extends ConnectedService {
  const ConnectedServiceModel({
    required super.id,
    required super.nameKey,
    required super.iconKey,
    required super.colorKey,
    required super.connected,
  });

  factory ConnectedServiceModel.fromJson(Map<String, dynamic> json) {
    return ConnectedServiceModel(
      id: json['id']?.toString() ?? '',
      nameKey: json['nameKey']?.toString() ?? '',
      iconKey: json['iconKey']?.toString() ?? '',
      colorKey: json['colorKey']?.toString() ?? '',
      connected: json['connected'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nameKey': nameKey,
      'iconKey': iconKey,
      'colorKey': colorKey,
      'connected': connected,
    };
  }
}
