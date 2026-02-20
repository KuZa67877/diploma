import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/splash_data_model.dart';

abstract class SplashLocalDataSource {
  Future<SplashDataModel> getSplashData();
}

class SplashLocalDataSourceImpl implements SplashLocalDataSource {
  static const String _assetPath = 'assets/data/splash.json';

  @override
  Future<SplashDataModel> getSplashData() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return SplashDataModel.fromJson(decoded);
  }
}
