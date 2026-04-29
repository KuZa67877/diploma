import 'package:flutter/services.dart';

class NativeShareService {
  static const MethodChannel _channel = MethodChannel('medi_ai/export_share');

  const NativeShareService();

  Future<void> shareText({required String text, String? subject}) {
    return _channel.invokeMethod<void>('shareText', {
      'text': text,
      'subject': subject,
    });
  }

  Future<void> shareFile({
    required String path,
    required String mimeType,
    String? subject,
    String? text,
  }) {
    return _channel.invokeMethod<void>('shareFile', {
      'path': path,
      'mimeType': mimeType,
      'subject': subject,
      'text': text,
    });
  }
}
