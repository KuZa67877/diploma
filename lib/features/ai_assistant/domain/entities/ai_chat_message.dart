import 'package:equatable/equatable.dart';

import 'ai_chat_attachment.dart';

enum AiChatRole { system, user, assistant }

extension AiChatRoleX on AiChatRole {
  String get apiValue => switch (this) {
    AiChatRole.system => 'system',
    AiChatRole.user => 'user',
    AiChatRole.assistant => 'assistant',
  };
}

class AiChatMessage extends Equatable {
  final String id;
  final AiChatRole role;
  final String content;
  final DateTime createdAt;
  final int? estimatedTokens;
  final AiChatAttachment? attachment;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.estimatedTokens,
    this.attachment,
  });

  bool get hasImageAttachment => attachment != null;

  AiChatMessage copyWith({
    String? id,
    AiChatRole? role,
    String? content,
    DateTime? createdAt,
    int? estimatedTokens,
    bool clearEstimatedTokens = false,
    AiChatAttachment? attachment,
    bool clearAttachment = false,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      estimatedTokens: clearEstimatedTokens
          ? null
          : estimatedTokens ?? this.estimatedTokens,
      attachment: clearAttachment ? null : attachment ?? this.attachment,
    );
  }

  @override
  List<Object?> get props => [
    id,
    role,
    content,
    createdAt,
    estimatedTokens,
    attachment,
  ];
}
