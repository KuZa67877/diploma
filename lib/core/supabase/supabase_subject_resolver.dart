import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../error/failures.dart';
import '../logging/app_logger.dart';

abstract class SupabaseSubjectResolver {
  Future<String> resolveSubjectId();
}

class SupabaseSubjectResolverImpl implements SupabaseSubjectResolver {
  static const String _tableName = 'user_private_subjects';
  static const int _maxAttempts = 4;

  final SupabaseClient Function() _clientProvider;
  final _logger = AppLogger.instance;
  final Random _random = Random.secure();

  SupabaseSubjectResolverImpl({
    required SupabaseClient Function() clientProvider,
  }) : _clientProvider = clientProvider;

  @override
  Future<String> resolveSubjectId() async {
    final client = _clientProvider();
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure('No active session. Please sign in again.');
    }

    final existing = await _selectSubjectIdByUserId(user.id);
    if (existing != null) {
      return existing;
    }

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final generated = _generateSubjectId();
      try {
        await client.from(_tableName).insert({
          'subject_id': generated,
          'user_id': user.id,
        });
        _logger.info(
          'subject.resolver',
          'Created anonymous subject id',
          payload: {'userId': user.id},
        );
        return generated;
      } catch (_) {
        final concurrent = await _selectSubjectIdByUserId(user.id);
        if (concurrent != null) {
          return concurrent;
        }
      }
    }

    throw const ServerFailure(
      'Failed to resolve anonymous subject for current user.',
    );
  }

  Future<String?> _selectSubjectIdByUserId(String userId) async {
    final rows = await _clientProvider()
        .from(_tableName)
        .select('subject_id')
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) {
      return null;
    }
    final first = rows.first;
    final value = first['subject_id']?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String _generateSubjectId() {
    final millis = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final randomPart = List.generate(
      10,
      (_) => _random.nextInt(36).toRadixString(36),
    ).join();
    return 'sub_$millis$randomPart';
  }
}
