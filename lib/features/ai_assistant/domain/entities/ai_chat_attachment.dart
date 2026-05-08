import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class AiChatAttachment extends Equatable {
  final String fileName;
  final String mimeType;
  final String base64Data;

  const AiChatAttachment({
    required this.fileName,
    required this.mimeType,
    required this.base64Data,
  });

  String get dataUri => 'data:$mimeType;base64,$base64Data';

  Uint8List get bytes => base64Decode(base64Data);

  @override
  List<Object?> get props => [fileName, mimeType, base64Data];
}
