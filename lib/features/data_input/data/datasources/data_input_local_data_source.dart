import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/data_input_config_model.dart';

abstract class DataInputLocalDataSource {
  Future<DataInputConfigModel> getConfig();
  Future<void> saveEntry(Map<String, dynamic> payload);
}

class DataInputLocalDataSourceImpl implements DataInputLocalDataSource {
  static const String _assetPath = 'assets/data/data_input.json';
  final List<Map<String, dynamic>> _entries = [];

  @override
  Future<DataInputConfigModel> getConfig() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return DataInputConfigModel.fromJson(decoded);
  }

  @override
  Future<void> saveEntry(Map<String, dynamic> payload) async {
    _entries.add(payload);
  }
}
