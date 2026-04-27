import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_ai/features/dashboard/data/services/harvard_activity_recommendation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Harvard preprocessor compatibility', () {
    test('parses v2 manifest with nested scaler block', () {
      final payload = <String, dynamic>{
        'version': 'harvard-preprocessor-v2',
        'scaler': {
          'mean': [1.0, 2.0, 3.0],
          'std': [0.1, 0.2, 0.3],
        },
        'feature_names': ['f1', 'f2', 'f3'],
        'target_mapping': {'Lying': 0, 'Sitting': 1},
        'inverse_target_mapping': {'0': 'Lying', '1': 'Sitting'},
      };

      final manifest = parseHarvardPreprocessorManifest(payload);

      expect(manifest.version, 'harvard-preprocessor-v2');
      expect(manifest.mean, [1.0, 2.0, 3.0]);
      expect(manifest.std, [0.1, 0.2, 0.3]);
      expect(manifest.featureNames, ['f1', 'f2', 'f3']);
      expect(manifest.targetMapping['Lying'], 0);
      expect(manifest.inverseTargetMapping[1], 'Sitting');
    });

    test('parses legacy v1 manifest with flat mean/std', () {
      final payload = <String, dynamic>{
        'mean': [10.0, 20.0],
        'std': [2.0, 4.0],
        'feature_names': ['x1', 'x2'],
        'target_mapping': {'Self Pace walk': 4},
        'inverse_target_mapping': {'4': 'Self Pace walk'},
      };

      final manifest = parseHarvardPreprocessorManifest(payload);

      expect(manifest.version, 'preprocessor_v1');
      expect(manifest.mean, [10.0, 20.0]);
      expect(manifest.std, [2.0, 4.0]);
      expect(manifest.featureNames, ['x1', 'x2']);
      expect(manifest.inverseTargetMapping[4], 'Self Pace walk');
    });

    test('loads v2 preprocessor when both assets are present', () async {
      final bundle = _MapAssetBundle(
        strings: {
          kHarvardPreprocessorV2AssetPath: jsonEncode({
            'version': 'harvard-preprocessor-v2',
            'scaler': {
              'mean': [1.0],
              'std': [1.0],
            },
            'feature_names': ['f1'],
          }),
          kHarvardPreprocessorV1AssetPath: jsonEncode({
            'mean': [2.0],
            'std': [2.0],
            'feature_names': ['legacy'],
          }),
        },
      );

      final loaded = await loadHarvardPreprocessorPayload(assetBundle: bundle);

      expect(loaded.sourcePath, kHarvardPreprocessorV2AssetPath);
      expect(loaded.payload['version'], 'harvard-preprocessor-v2');
    });

    test('falls back to v1 when v2 asset is absent', () async {
      final bundle = _MapAssetBundle(
        strings: {
          kHarvardPreprocessorV1AssetPath: jsonEncode({
            'mean': [5.0],
            'std': [0.5],
            'feature_names': ['legacy_feature'],
          }),
        },
      );

      final loaded = await loadHarvardPreprocessorPayload(assetBundle: bundle);

      expect(loaded.sourcePath, kHarvardPreprocessorV1AssetPath);
      expect(loaded.payload['feature_names'], ['legacy_feature']);
    });

    test('reads model version from metadata with safe default', () async {
      final bundle = _MapAssetBundle(
        strings: {
          kHarvardMetadataAssetPath: jsonEncode({
            'model_version': 'harvard-aw-xgb-v2',
          }),
        },
      );
      final missingBundle = _MapAssetBundle(strings: const {});

      final fromMetadata = await loadHarvardModelVersion(assetBundle: bundle);
      final fallback = await loadHarvardModelVersion(
        assetBundle: missingBundle,
      );

      expect(fromMetadata, 'harvard-aw-xgb-v2');
      expect(fallback, kHarvardDefaultModelVersion);
    });
  });
}

class _MapAssetBundle extends CachingAssetBundle {
  final Map<String, String> strings;

  _MapAssetBundle({required this.strings});

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = strings[key];
    if (value == null) {
      throw Exception('Unable to load asset: $key');
    }
    return value;
  }

  @override
  Future<ByteData> load(String key) async {
    throw Exception('Unable to load asset: $key');
  }
}
