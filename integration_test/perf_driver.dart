import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      final path =
          Platform.environment['PERF_REPORT_PATH'] ??
          'artifacts/perf/perf_response_data.json';
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data ?? <String, dynamic>{}),
      );
    },
  );
}
