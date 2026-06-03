import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final options = _parseArgs(args);
  final perfReport = _readJson(options['perf']);
  final startupReport = _readJson(options['startup']);
  final meminfoRaw = _readText(options['meminfo']);
  final apkPath = options['apk'];
  final outputPath =
      options['output'] ?? 'artifacts/perf/performance_summary.json';

  final apkSizeBytes = apkPath == null ? null : File(apkPath).lengthSync();
  final meminfo = meminfoRaw == null ? null : _parseMeminfo(meminfoRaw);

  final summary = <String, Object?>{
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'startup': startupReport,
    'integration': perfReport,
    'memory_android': meminfo,
    'apk_size_mb': apkSizeBytes == null
        ? null
        : double.parse((apkSizeBytes / (1024 * 1024)).toStringAsFixed(2)),
  };

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(summary),
  );
  stdout.writeln(outputFile.path);
}

Map<String, String?> _parseArgs(List<String> args) {
  final options = <String, String?>{};
  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (!arg.startsWith('--')) {
      continue;
    }
    final key = arg.substring(2);
    final next = index + 1 < args.length ? args[index + 1] : null;
    if (next != null && !next.startsWith('--')) {
      options[key] = next;
      index += 1;
      continue;
    }
    options[key] = null;
  }
  return options;
}

Map<String, Object?>? _readJson(String? path) {
  if (path == null) {
    return null;
  }
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

String? _readText(String? path) {
  if (path == null) {
    return null;
  }
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  return file.readAsStringSync();
}

Map<String, Object?> _parseMeminfo(String raw) {
  final lines = const LineSplitter().convert(raw);
  int? totalPssKb;
  int? totalPrivateDirtyKb;

  for (final line in lines) {
    final normalized = line.trim();
    if (!normalized.startsWith('TOTAL')) {
      continue;
    }
    final parts = normalized.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      totalPssKb = int.tryParse(parts[1]);
      totalPrivateDirtyKb = int.tryParse(parts[2]);
    }
    break;
  }

  return <String, Object?>{
    'total_pss_kb': totalPssKb,
    'total_pss_mb': totalPssKb == null
        ? null
        : double.parse((totalPssKb / 1024).toStringAsFixed(2)),
    'total_private_dirty_kb': totalPrivateDirtyKb,
    'total_private_dirty_mb': totalPrivateDirtyKb == null
        ? null
        : double.parse((totalPrivateDirtyKb / 1024).toStringAsFixed(2)),
    'raw_excerpt': lines.take(20).toList(growable: false),
  };
}
