import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/ai_built_prompt.dart';
import '../../domain/entities/ai_chat_attachment.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_date_range_selection.dart';
import '../bloc/deepseek_chat_cubit.dart';
import '../widgets/ai_chat_bubble.dart';
import '../widgets/health_data_selector.dart';

class AiAssistantChatScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AiAssistantChatScreen({super.key, required this.onBack});

  @override
  State<AiAssistantChatScreen> createState() => _AiAssistantChatScreenState();
}

class _AiAssistantChatScreenState extends State<AiAssistantChatScreen> {
  late final TextEditingController _messageController;
  final ImagePicker _imagePicker = ImagePicker();
  String? _pendingDataText;
  String? _pendingDataTitle;
  List<String> _pendingDataLabels = const [];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DeepSeekChatCubit>()..load(),
      child: BlocBuilder<DeepSeekChatCubit, DeepSeekChatState>(
        builder: (context, state) {
          final cubit = context.read<DeepSeekChatCubit>();
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final titleColor = isDark
              ? AppColors.darkForeground
              : AppColors.lightForeground;
          final subtitleColor = isDark
              ? AppColors.darkMutedForeground
              : AppColors.mutedForeground;

          return Scaffold(
            body: GradientBackground(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    children: [
                      _ChatHeader(
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                        onBack: widget.onBack,
                        onAddData: () => _openAddDataSheet(context, cubit),
                      ),
                      if (state.errorMessage?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        _InlineBanner(
                          color: AppColors.danger,
                          backgroundColor: AppColors.danger.withValues(
                            alpha: 0.08,
                          ),
                          message: state.errorMessage!,
                        ),
                      ],
                      if (state.infoMessage?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        _InlineBanner(
                          color: AppColors.primary,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.08,
                          ),
                          message: state.infoMessage!,
                        ),
                      ],
                      Expanded(
                        child: state.messages.isEmpty
                            ? const _EmptyChatState()
                            : Column(
                                children: [
                                  const SizedBox(height: 12),
                                  const _AssistantIntroCard(),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: _ChatTimeline(
                                      messages: state.messages,
                                      isSending:
                                          state.status ==
                                          DeepSeekChatStatus.sending,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      _ComposerCard(
                        messageController: _messageController,
                        pendingAttachment: state.pendingAttachment,
                        pendingDataTitle: _pendingDataTitle,
                        pendingDataText: _pendingDataText,
                        pendingDataLabels: _pendingDataLabels,
                        isSending: state.status == DeepSeekChatStatus.sending,
                        messageHint: state.messages.isEmpty
                            ? 'Например: Почему я так устал?'
                            : 'Введите вопрос',
                        onPickAttachment: () => _pickAttachment(context, cubit),
                        onRemoveAttachment: cubit.clearPendingAttachment,
                        onRemoveData: _clearPendingDataDraft,
                        onSend: () async {
                          final sent = await cubit.sendFollowUp(
                            _buildOutgoingText(),
                          );
                          if (sent) {
                            _messageController.clear();
                            _clearPendingDataDraft();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAttachment(
    BuildContext context,
    DeepSeekChatCubit cubit,
  ) async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return;
      }

      final attachment = AiChatAttachment(
        fileName: file.name,
        mimeType: _inferMimeType(file.name),
        base64Data: base64Encode(bytes),
      );
      cubit.setPendingAttachment(attachment);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось выбрать фото. Попробуйте ещё раз.'),
        ),
      );
    }
  }

  String _inferMimeType(String fileName) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.png')) {
      return 'image/png';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    if (normalized.endsWith('.heic')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  String _buildOutgoingText() {
    final message = _messageController.text.trim();
    final dataText = _pendingDataText?.trim() ?? '';
    if (dataText.isEmpty) {
      return message;
    }
    if (message.isEmpty) {
      return 'Данные пользователя:\n$dataText';
    }
    return 'Данные пользователя:\n$dataText\n\nВопрос пользователя:\n$message';
  }

  void _clearPendingDataDraft() {
    if (!mounted) {
      return;
    }
    setState(() {
      _pendingDataText = null;
      _pendingDataTitle = null;
      _pendingDataLabels = const [];
    });
  }

  Future<void> _openAddDataSheet(
    BuildContext context,
    DeepSeekChatCubit cubit,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BlocProvider.value(
          value: cubit,
          child: _AddDataSheet(
            onApply: (builtPrompt, range) {
              if (!mounted) {
                return;
              }
              setState(() {
                _pendingDataText = builtPrompt.contextSummary.trim();
                _pendingDataTitle = 'Данные за ${_rangeLabel(range.preset)}';
                _pendingDataLabels = builtPrompt.includedDataLabels
                    .take(4)
                    .toList(growable: false);
              });
              cubit.clearBuiltPromptDraft();
              Navigator.of(sheetContext).pop();
            },
          ),
        );
      },
    );
    cubit.clearBuiltPromptDraft();
  }

  String _rangeLabel(AiDateRangePreset preset) {
    return switch (preset) {
      AiDateRangePreset.today => 'сегодня',
      AiDateRangePreset.last3Days => '3 дня',
      AiDateRangePreset.last7Days => '7 дней',
      AiDateRangePreset.last14Days => '14 дней',
      AiDateRangePreset.custom => 'выбранный период',
    };
  }
}

class _ChatHeader extends StatelessWidget {
  final Color titleColor;
  final Color subtitleColor;
  final VoidCallback onBack;
  final VoidCallback onAddData;

  const _ChatHeader({
    required this.titleColor,
    required this.subtitleColor,
    required this.onBack,
    required this.onAddData,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderCircleButton(icon: LucideIcons.chevronLeft, onTap: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI-чат',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              Text(
                'Помощник по вопросам о здоровье',
                style: TextStyle(fontSize: 12, color: subtitleColor),
              ),
            ],
          ),
        ),
        _HeaderActionButton(onTap: onAddData),
      ],
    );
  }
}

class _AssistantIntroCard extends StatelessWidget {
  const _AssistantIntroCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final muted = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Спросите про симптомы, сон или активность',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Можно ввести вопрос текстом или приложить фото графика, часов или еды. Ассистент ответит с учётом вашего контекста здоровья.',
            style: TextStyle(fontSize: 12, height: 1.4, color: muted),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final muted = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    LucideIcons.messageCircle,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Пока нет диалога',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 248),
                  child: Text(
                    'Задайте вопрос про сон, пульс, стресс или питание. Можно также прикрепить фото и получить краткое пояснение.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.45, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTimeline extends StatelessWidget {
  final List<AiChatMessage> messages;
  final bool isSending;

  const _ChatTimeline({required this.messages, required this.isSending});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final message in messages) AiChatBubble(message: message),
        if (isSending) const _TypingBubble(),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ассистент',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _TypingDot(color: Color(0xFFCBD5E1)),
                SizedBox(width: 6),
                _TypingDot(color: Color(0xFF94A3B8)),
                SizedBox(width: 6),
                _TypingDot(color: Color(0xFFCBD5E1)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Анализирую ответ...',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkMutedForeground
                    : AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  final Color color;

  const _TypingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  final TextEditingController messageController;
  final AiChatAttachment? pendingAttachment;
  final String? pendingDataTitle;
  final String? pendingDataText;
  final List<String> pendingDataLabels;
  final bool isSending;
  final String messageHint;
  final VoidCallback onPickAttachment;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onRemoveData;
  final VoidCallback onSend;

  const _ComposerCard({
    required this.messageController,
    required this.pendingAttachment,
    required this.pendingDataTitle,
    required this.pendingDataText,
    required this.pendingDataLabels,
    required this.isSending,
    required this.messageHint,
    required this.onPickAttachment,
    required this.onRemoveAttachment,
    required this.onRemoveData,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final muted = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendingDataText?.trim().isNotEmpty == true) ...[
            _DataDraftCard(
              title: pendingDataTitle ?? 'Данные пользователя',
              preview: pendingDataText!,
              labels: pendingDataLabels,
              onRemove: onRemoveData,
            ),
            const SizedBox(height: 8),
          ],
          if (pendingAttachment != null) ...[
            _AttachmentDraftCard(
              attachment: pendingAttachment!,
              subtitle: '1 фото прикреплено',
              onRemove: onRemoveAttachment,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PhotoButton(onTap: isSending ? null : onPickAttachment),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: messageController,
                  minLines: 1,
                  maxLines: 4,
                  enabled: !isSending,
                  style: TextStyle(fontSize: 14, color: foreground),
                  decoration: InputDecoration(
                    hintText: messageHint,
                    hintStyle: TextStyle(color: muted),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkMuted
                        : AppColors.lightBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                onTap: isSending ? null : onSend,
                isSending: isSending,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttachmentDraftCard extends StatelessWidget {
  final AiChatAttachment attachment;
  final String subtitle;
  final VoidCallback onRemove;

  const _AttachmentDraftCard({
    required this.attachment,
    required this.subtitle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final muted = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return GestureDetector(
      onLongPress: onRemove,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMuted : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              child: Image.memory(
                attachment.bytes,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 44,
                  height: 44,
                  color: AppColors.primaryLight,
                  alignment: Alignment.center,
                  child: const Text(
                    'IMG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataDraftCard extends StatelessWidget {
  final String title;
  final String preview;
  final List<String> labels;
  final VoidCallback onRemove;

  const _DataDraftCard({
    required this.title,
    required this.preview,
    required this.labels,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark
        ? AppColors.darkForeground
        : AppColors.lightForeground;
    final muted = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6ECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.activity,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    LucideIcons.x,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (labels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: labels
                  .map(
                    (label) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            preview,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.4, color: muted),
          ),
        ],
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  final Color color;
  final Color backgroundColor;
  final String message;

  const _InlineBanner({
    required this.color,
    required this.backgroundColor,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.darkForeground : AppColors.lightForeground,
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderActionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD6ECE8)),
        ),
        child: const Text(
          'Добавить данные',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _PhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkMuted : AppColors.muted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Text(
          '+ Фото',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkForeground
                : AppColors.lightForeground,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isSending;

  const _SendButton({required this.onTap, required this.isSending});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 48,
        height: 44,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.primary
              : AppColors.muted.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  LucideIcons.send,
                  size: 18,
                  color: isEnabled
                      ? Colors.white
                      : AppColors.lightForeground.withValues(alpha: 0.5),
                ),
        ),
      ),
    );
  }
}

class _AddDataSheet extends StatelessWidget {
  final void Function(AiBuiltPrompt builtPrompt, AiDateRangeSelection range)
  onApply;

  const _AddDataSheet({required this.onApply});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: BlocBuilder<DeepSeekChatCubit, DeepSeekChatState>(
            builder: (context, state) {
              final cubit = context.read<DeepSeekChatCubit>();
              final foreground = isDark
                  ? AppColors.darkForeground
                  : AppColors.lightForeground;
              final muted = isDark
                  ? AppColors.darkMutedForeground
                  : AppColors.mutedForeground;
              final isBusy =
                  state.status == DeepSeekChatStatus.buildingPrompt ||
                  state.status == DeepSeekChatStatus.loading;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Добавить данные',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Выберите период и данные. Они будут приложены к следующему сообщению как текстовый контекст.',
                      style: TextStyle(fontSize: 13, height: 1.4, color: muted),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Период',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _RangeChip(
                          label: 'Сегодня',
                          selected:
                              state.range.preset == AiDateRangePreset.today,
                          onTap: () =>
                              cubit.selectRangePreset(AiDateRangePreset.today),
                        ),
                        _RangeChip(
                          label: '7 дней',
                          selected:
                              state.range.preset == AiDateRangePreset.last7Days,
                          onTap: () => cubit.selectRangePreset(
                            AiDateRangePreset.last7Days,
                          ),
                        ),
                        _RangeChip(
                          label: '14 дней',
                          selected:
                              state.range.preset ==
                              AiDateRangePreset.last14Days,
                          onTap: () => cubit.selectRangePreset(
                            AiDateRangePreset.last14Days,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Типы данных',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 10),
                    HealthDataSelector(
                      selectedTypes: state.selectedDataTypes,
                      onToggle: cubit.toggleDataType,
                    ),
                    if (state.errorMessage?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 14),
                      _InlineBanner(
                        color: AppColors.danger,
                        backgroundColor: AppColors.danger.withValues(
                          alpha: 0.08,
                        ),
                        message: state.errorMessage!,
                      ),
                    ],
                    if (state.infoMessage?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 14),
                      _InlineBanner(
                        color: AppColors.primary,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.08,
                        ),
                        message: state.infoMessage!,
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isBusy
                            ? null
                            : () async {
                                await cubit.buildPrompt();
                                final builtPrompt = cubit.state.builtPrompt;
                                if (builtPrompt == null) {
                                  return;
                                }
                                onApply(builtPrompt, cubit.state.range);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Добавить в сообщение',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.35)
            : (isDark ? AppColors.darkBorder : AppColors.border),
      ),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? AppColors.primary
            : (isDark ? AppColors.darkForeground : AppColors.lightForeground),
      ),
    );
  }
}
