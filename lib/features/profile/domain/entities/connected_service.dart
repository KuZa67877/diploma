import 'package:equatable/equatable.dart';

class ConnectedService extends Equatable {
  final String id;
  final String nameKey;
  final String iconKey;
  final String colorKey;
  final bool connected;

  const ConnectedService({
    required this.id,
    required this.nameKey,
    required this.iconKey,
    required this.colorKey,
    required this.connected,
  });

  ConnectedService copyWith({bool? connected}) {
    return ConnectedService(
      id: id,
      nameKey: nameKey,
      iconKey: iconKey,
      colorKey: colorKey,
      connected: connected ?? this.connected,
    );
  }

  @override
  List<Object> get props => [id, nameKey, iconKey, colorKey, connected];
}
