import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ai_assistant_settings.dart';
import '../../domain/entities/ai_built_prompt.dart';
import '../../domain/entities/ai_cached_response.dart';
import '../../domain/entities/ai_chat_attachment.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_date_range_selection.dart';
import '../../domain/entities/ai_economy_options.dart';
import '../../domain/entities/ai_health_context.dart';
import '../../domain/entities/ai_health_data_type.dart';
import '../../domain/entities/ai_prompt_mode.dart';
import '../../domain/entities/ai_request_size.dart';
import '../../domain/entities/ai_usage_limits.dart';
import '../../domain/repositories/deepseek_chat_repository.dart';
import '../../domain/services/ai_usage_limiter_service.dart';
import '../../domain/services/health_data_prompt_builder.dart';
import '../../domain/services/token_estimator_service.dart';
import '../../domain/usecases/build_ai_health_context.dart';

enum DeepSeekChatStatus {
  initial,
  loading,
  buildingPrompt,
  promptReady,
  sending,
  success,
  error,
  limitExceeded,
  cached,
}

class DeepSeekChatState extends Equatable {
  final DeepSeekChatStatus status;
  final AiDateRangeSelection range;
  final Set<AiHealthDataType> selectedDataTypes;
  final AiPromptMode promptMode;
  final AiEconomyOptions economyOptions;
  final AiAssistantSettings settings;
  final AiUsageStats usageStats;
  final AiBuiltPrompt? builtPrompt;
  final AiHealthContext? healthContext;
  final List<AiChatMessage> messages;
  final int estimatedRequestTokens;
  final AiRequestSize requestSize;
  final String? infoMessage;
  final String? errorMessage;
  final AiChatAttachment? pendingAttachment;

  const DeepSeekChatState({
    required this.status,
    required this.range,
    required this.selectedDataTypes,
    required this.promptMode,
    required this.economyOptions,
    required this.settings,
    required this.usageStats,
    required this.builtPrompt,
    required this.healthContext,
    required this.messages,
    required this.estimatedRequestTokens,
    required this.requestSize,
    required this.infoMessage,
    required this.errorMessage,
    required this.pendingAttachment,
  });

  factory DeepSeekChatState.initial() {
    final settings = const AiAssistantSettings.defaults();
    return DeepSeekChatState(
      status: DeepSeekChatStatus.initial,
      range: AiDateRangeSelection.last7Days(),
      selectedDataTypes: const <AiHealthDataType>{
        AiHealthDataType.healthScore,
        AiHealthDataType.sleep,
        AiHealthDataType.pulse,
        AiHealthDataType.hrv,
        AiHealthDataType.steps,
        AiHealthDataType.stress,
        AiHealthDataType.anomalies,
        AiHealthDataType.baseline,
        AiHealthDataType.diary,
      },
      promptMode: AiPromptMode.shortAnalysis,
      economyOptions: AiEconomyOptions.defaults(
        economyMode: settings.economyModeByDefault,
      ),
      settings: settings,
      usageStats: AiUsageStats.empty(date: DateTime.now()),
      builtPrompt: null,
      healthContext: null,
      messages: const <AiChatMessage>[],
      estimatedRequestTokens: 0,
      requestSize: AiRequestSize.small,
      infoMessage: null,
      errorMessage: null,
      pendingAttachment: null,
    );
  }

  DeepSeekChatState copyWith({
    DeepSeekChatStatus? status,
    AiDateRangeSelection? range,
    Set<AiHealthDataType>? selectedDataTypes,
    AiPromptMode? promptMode,
    AiEconomyOptions? economyOptions,
    AiAssistantSettings? settings,
    AiUsageStats? usageStats,
    AiBuiltPrompt? builtPrompt,
    bool clearBuiltPrompt = false,
    AiHealthContext? healthContext,
    bool clearHealthContext = false,
    List<AiChatMessage>? messages,
    int? estimatedRequestTokens,
    AiRequestSize? requestSize,
    String? infoMessage,
    bool clearInfoMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    AiChatAttachment? pendingAttachment,
    bool clearPendingAttachment = false,
  }) {
    return DeepSeekChatState(
      status: status ?? this.status,
      range: range ?? this.range,
      selectedDataTypes: selectedDataTypes ?? this.selectedDataTypes,
      promptMode: promptMode ?? this.promptMode,
      economyOptions: economyOptions ?? this.economyOptions,
      settings: settings ?? this.settings,
      usageStats: usageStats ?? this.usageStats,
      builtPrompt: clearBuiltPrompt ? null : builtPrompt ?? this.builtPrompt,
      healthContext: clearHealthContext
          ? null
          : healthContext ?? this.healthContext,
      messages: messages ?? this.messages,
      estimatedRequestTokens:
          estimatedRequestTokens ?? this.estimatedRequestTokens,
      requestSize: requestSize ?? this.requestSize,
      infoMessage: clearInfoMessage ? null : infoMessage ?? this.infoMessage,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      pendingAttachment: clearPendingAttachment
          ? null
          : pendingAttachment ?? this.pendingAttachment,
    );
  }

  @override
  List<Object?> get props => [
    status,
    range,
    selectedDataTypes,
    promptMode,
    economyOptions,
    settings,
    usageStats,
    builtPrompt,
    healthContext,
    messages,
    estimatedRequestTokens,
    requestSize,
    infoMessage,
    errorMessage,
    pendingAttachment,
  ];
}

class DeepSeekChatCubit extends Cubit<DeepSeekChatState> {
  final BuildAiHealthContextUseCase _buildAiHealthContext;
  final HealthDataPromptBuilder _promptBuilder;
  final TokenEstimatorService _tokenEstimator;
  final AiUsageLimiterService _usageLimiter;
  final DeepSeekChatRepository _repository;

  DeepSeekChatCubit({
    required BuildAiHealthContextUseCase buildAiHealthContext,
    required HealthDataPromptBuilder promptBuilder,
    required TokenEstimatorService tokenEstimator,
    required AiUsageLimiterService usageLimiter,
    required DeepSeekChatRepository repository,
  }) : _buildAiHealthContext = buildAiHealthContext,
       _promptBuilder = promptBuilder,
       _tokenEstimator = tokenEstimator,
       _usageLimiter = usageLimiter,
       _repository = repository,
       super(DeepSeekChatState.initial());

  Future<void> load() async {
    emit(
      state.copyWith(
        status: DeepSeekChatStatus.loading,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );
    final settings = await _repository.getSettings();
    final usageStats = await _usageLimiter.getStats();
    emit(
      state.copyWith(
        status: DeepSeekChatStatus.initial,
        settings: settings,
        usageStats: usageStats,
        economyOptions: state.economyOptions.copyWith(
          economizeTokens: settings.economyModeByDefault,
          sendAggregatesOnly: settings.economyModeByDefault,
          trimChatHistory: settings.economyModeByDefault,
        ),
      ),
    );
  }

  void selectRangePreset(AiDateRangePreset preset) {
    final now = DateTime.now();
    final range = switch (preset) {
      AiDateRangePreset.today => AiDateRangeSelection.today(now: now),
      AiDateRangePreset.last3Days => AiDateRangeSelection.last3Days(now: now),
      AiDateRangePreset.last7Days => AiDateRangeSelection.last7Days(now: now),
      AiDateRangePreset.last14Days => AiDateRangeSelection.last14Days(now: now),
      AiDateRangePreset.custom => state.range,
    };
    emit(
      state.copyWith(
        range: range,
        clearInfoMessage: true,
        clearErrorMessage: true,
      ),
    );
  }

  void setCustomRange(DateTime start, DateTime end) {
    emit(
      state.copyWith(
        range: AiDateRangeSelection.custom(start: start, end: end),
        clearInfoMessage: true,
        clearErrorMessage: true,
      ),
    );
  }

  void toggleDataType(AiHealthDataType type) {
    final next = {...state.selectedDataTypes};
    if (next.contains(type) && next.length == 1) {
      return;
    }
    if (!next.add(type)) {
      next.remove(type);
    }
    emit(
      state.copyWith(
        selectedDataTypes: next,
        clearInfoMessage: true,
        clearErrorMessage: true,
      ),
    );
  }

  void selectPromptMode(AiPromptMode mode) {
    emit(
      state.copyWith(
        promptMode: mode,
        clearInfoMessage: true,
        clearErrorMessage: true,
      ),
    );
  }

  void setEconomizeTokens(bool value) {
    emit(
      state.copyWith(
        economyOptions: state.economyOptions.copyWith(
          economizeTokens: value,
          sendAggregatesOnly: value
              ? true
              : state.economyOptions.sendAggregatesOnly,
          trimChatHistory: value ? true : state.economyOptions.trimChatHistory,
        ),
      ),
    );
  }

  void setSendAggregatesOnly(bool value) {
    emit(
      state.copyWith(
        economyOptions: state.economyOptions.copyWith(
          sendAggregatesOnly: value,
        ),
      ),
    );
  }

  void setTrimChatHistory(bool value) {
    emit(
      state.copyWith(
        economyOptions: state.economyOptions.copyWith(trimChatHistory: value),
      ),
    );
  }

  void setExcludeDiaryNotes(bool value) {
    emit(
      state.copyWith(
        economyOptions: state.economyOptions.copyWith(excludeDiaryNotes: value),
      ),
    );
  }

  Future<void> updateApiKey(String value) async {
    await _saveSettings(state.settings.copyWith(apiKey: value.trim()));
  }

  Future<void> updateModel(String value) async {
    await _saveSettings(state.settings.copyWith(model: value.trim()));
  }

  Future<void> updateVisionModel(String value) async {
    await _saveSettings(state.settings.copyWith(visionModel: value.trim()));
  }

  Future<void> updateMaxTokens(String value) async {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return;
    }
    await _saveSettings(state.settings.copyWith(maxTokens: parsed));
  }

  Future<void> updateTemperature(String value) async {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) {
      return;
    }
    await _saveSettings(
      state.settings.copyWith(temperature: parsed.clamp(0.0, 1.5)),
    );
  }

  Future<void> updateDailyRequestLimit(String value) async {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return;
    }
    await _saveSettings(state.settings.copyWith(dailyRequestLimit: parsed));
  }

  Future<void> updateEconomyModeDefault(bool value) async {
    await _saveSettings(state.settings.copyWith(economyModeByDefault: value));
    emit(
      state.copyWith(
        economyOptions: state.economyOptions.copyWith(
          economizeTokens: value,
          sendAggregatesOnly: value,
          trimChatHistory: value,
        ),
      ),
    );
  }

  void clearBuiltPromptDraft() {
    emit(
      state.copyWith(
        status: DeepSeekChatStatus.initial,
        clearBuiltPrompt: true,
        clearHealthContext: true,
        estimatedRequestTokens: 0,
        requestSize: AiRequestSize.small,
        clearInfoMessage: true,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> buildPrompt() async {
    emit(
      state.copyWith(
        status: DeepSeekChatStatus.buildingPrompt,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    final result = await _buildAiHealthContext(
      BuildAiHealthContextParams(
        range: state.range,
        selectedDataTypes: state.selectedDataTypes,
        economyOptions: state.economyOptions,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DeepSeekChatStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (context) {
        final builtPrompt = _promptBuilder.build(
          context: context,
          mode: state.promptMode,
          selectedDataTypes: state.selectedDataTypes,
          economyOptions: state.economyOptions,
        );
        final estimatedTokens = _tokenEstimator.estimateTextTokens(
          builtPrompt.combinedPrompt,
        );
        final requestSize = _tokenEstimator.classifyRequestSize(
          estimatedTokens,
        );
        final infoMessage = <String>[
          if (context.missingData.isNotEmpty)
            'Недостаточно данных для уверенного анализа. Можно отправить запрос, но ответ будет менее точным.',
          if (requestSize == AiRequestSize.large)
            'Запрос получился большим. Он может быстрее расходовать лимит API. Включите режим экономии или отправьте агрегированные данные.',
        ].join('\n');

        emit(
          state.copyWith(
            status: DeepSeekChatStatus.promptReady,
            builtPrompt: builtPrompt,
            healthContext: context,
            estimatedRequestTokens: estimatedTokens,
            requestSize: requestSize,
            infoMessage: infoMessage.trim().isEmpty ? null : infoMessage.trim(),
          ),
        );
      },
    );
  }

  Future<void> sendBuiltPrompt() async {
    final builtPrompt = state.builtPrompt;
    if (builtPrompt == null) {
      emit(
        state.copyWith(
          status: DeepSeekChatStatus.error,
          errorMessage: 'Сначала сформируйте промт из данных.',
        ),
      );
      return;
    }
    if (!state.settings.hasApiKey) {
      emit(
        state.copyWith(
          status: DeepSeekChatStatus.error,
          errorMessage:
              'Добавьте API-ключ Groq в .env (GROQ_API_KEY), чтобы использовать AI-чат.',
        ),
      );
      return;
    }

    final userMessage = _createMessage(
      role: AiChatRole.user,
      content: builtPrompt.userPrompt,
    );
    final cached = await _repository.getCachedResponse(
      prompt: builtPrompt.userPrompt,
      model: state.settings.model,
      mode: state.promptMode,
    );
    if (cached != null) {
      final assistantMessage = _createMessage(
        role: AiChatRole.assistant,
        content: cached.response,
      );
      emit(
        state.copyWith(
          status: DeepSeekChatStatus.cached,
          messages: [...state.messages, userMessage, assistantMessage],
          infoMessage: 'Показан сохраненный ответ для такого же набора данных.',
          clearErrorMessage: true,
        ),
      );
      return;
    }

    final outboundMessages = [
      _createMessage(
        role: AiChatRole.system,
        content: builtPrompt.systemPrompt,
      ),
      userMessage,
    ];

    await _sendMessages(
      outboundMessages: outboundMessages,
      appendUserMessage: userMessage,
      cacheOnSuccess: true,
      promptToCache: builtPrompt.userPrompt,
      clearPendingAttachmentOnSuccess: false,
    );
  }

  Future<bool> sendFollowUp(String text) async {
    final trimmed = text.trim();
    final attachment = state.pendingAttachment;
    if (trimmed.isEmpty && attachment == null) {
      return false;
    }
    final builtPrompt = state.builtPrompt;
    if (!state.settings.hasApiKey) {
      emit(
        state.copyWith(
          status: DeepSeekChatStatus.error,
          errorMessage:
              'Добавьте API-ключ Groq в .env (GROQ_API_KEY), чтобы использовать AI-чат.',
        ),
      );
      return false;
    }

    final systemMessage = _createMessage(
      role: AiChatRole.system,
      content: _buildConversationSystemPrompt(hasImage: attachment != null),
    );
    final followUpMessage = _createMessage(
      role: AiChatRole.user,
      content: trimmed,
      attachment: attachment,
    );
    final outboundMessages = [
      systemMessage,
      if (builtPrompt != null)
        _createMessage(
          role: AiChatRole.user,
          content: builtPrompt.contextSummary,
        ),
      ..._trimmedHistory(),
      followUpMessage,
    ];

    return _sendMessages(
      outboundMessages: outboundMessages,
      appendUserMessage: followUpMessage,
      cacheOnSuccess: false,
      promptToCache: null,
      clearPendingAttachmentOnSuccess: attachment != null,
    );
  }

  void setPendingAttachment(AiChatAttachment attachment) {
    emit(
      state.copyWith(
        pendingAttachment: attachment,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );
  }

  void clearPendingAttachment() {
    emit(state.copyWith(clearPendingAttachment: true, clearErrorMessage: true));
  }

  void clearHistory() {
    emit(
      state.copyWith(
        messages: const <AiChatMessage>[],
        status: state.builtPrompt == null
            ? DeepSeekChatStatus.initial
            : DeepSeekChatStatus.promptReady,
        clearInfoMessage: true,
        clearErrorMessage: true,
        clearPendingAttachment: true,
      ),
    );
  }

  Future<void> resetDebugLimits() async {
    await _usageLimiter.resetDebugStats();
    final usageStats = await _usageLimiter.getStats();
    emit(
      state.copyWith(
        usageStats: usageStats,
        infoMessage: 'Локальные AI-лимиты сброшены.',
      ),
    );
  }

  Future<bool> _sendMessages({
    required List<AiChatMessage> outboundMessages,
    required AiChatMessage appendUserMessage,
    required bool cacheOnSuccess,
    required String? promptToCache,
    required bool clearPendingAttachmentOnSuccess,
  }) async {
    emit(
      state.copyWith(
        status: DeepSeekChatStatus.sending,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );

    final estimatedTokens = _tokenEstimator.estimateMessagesTokens(
      outboundMessages
          .map(
            (item) => item.copyWith(
              estimatedTokens: _tokenEstimator.estimateTextTokens(item.content),
            ),
          )
          .toList(growable: false),
    );
    final requestSize = _tokenEstimator.classifyRequestSize(estimatedTokens);
    final limits = const AiUsageLimits.defaults().copyWith(
      maxRequestsPerDay: state.settings.dailyRequestLimit,
    );

    final limitCheck = await _usageLimiter.canSendRequest(
      estimatedInputTokens: estimatedTokens,
      requestSize: requestSize,
      limits: limits,
    );
    if (!limitCheck.allowed) {
      emit(
        state.copyWith(
          status: DeepSeekChatStatus.limitExceeded,
          errorMessage: limitCheck.message,
          usageStats: limitCheck.stats,
          estimatedRequestTokens: estimatedTokens,
          requestSize: requestSize,
        ),
      );
      return false;
    }

    final reservedStats = await _usageLimiter.registerRequest(
      estimatedInputTokens: estimatedTokens,
      requestSize: requestSize,
    );
    final result = await _repository.sendMessages(
      settings: state.settings,
      messages: outboundMessages,
    );

    var wasSuccessful = false;
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: DeepSeekChatStatus.error,
            errorMessage: failure.message,
            usageStats: reservedStats,
            estimatedRequestTokens: estimatedTokens,
            requestSize: requestSize,
          ),
        );
        return;
      },
      (completion) async {
        final assistantMessage = _createMessage(
          role: AiChatRole.assistant,
          content: completion.content,
        );
        final outputTokens =
            completion.completionTokens ??
            _tokenEstimator.estimateTextTokens(completion.content);
        final usageStats = await _usageLimiter.registerResponse(
          estimatedOutputTokens: outputTokens,
        );
        if (cacheOnSuccess && promptToCache != null) {
          await _repository.cacheResponse(
            AiCachedResponse(
              promptHash: _repository.buildPromptHash(
                prompt: promptToCache,
                model: state.settings.model,
                mode: state.promptMode,
              ),
              response: completion.content,
              createdAt: DateTime.now(),
              model: completion.model,
              selectedFrom: state.range.start,
              selectedTo: state.range.end,
              selectedMode: state.promptMode,
            ),
          );
        }

        emit(
          state.copyWith(
            status: DeepSeekChatStatus.success,
            messages: [...state.messages, appendUserMessage, assistantMessage],
            usageStats: usageStats,
            estimatedRequestTokens: estimatedTokens,
            requestSize: requestSize,
            infoMessage: requestSize == AiRequestSize.large
                ? 'Большой запрос отправлен. Для следующих запросов лучше использовать summary или режим экономии токенов.'
                : null,
            clearPendingAttachment: clearPendingAttachmentOnSuccess,
          ),
        );
        wasSuccessful = true;
      },
    );
    return wasSuccessful;
  }

  Future<void> _saveSettings(AiAssistantSettings settings) async {
    await _repository.saveSettings(settings);
    emit(state.copyWith(settings: settings));
  }

  List<AiChatMessage> _trimmedHistory() {
    final builtPrompt = state.builtPrompt;
    final history = state.messages
        .where((item) {
          if (item.role == AiChatRole.system) {
            return false;
          }
          if (builtPrompt != null && item.content == builtPrompt.userPrompt) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    final hardLimit = const AiUsageLimits.defaults().maxMessagesInContext;
    final target = state.economyOptions.trimChatHistory ? 4 : 6;
    final effectiveLimit = target > hardLimit ? hardLimit : target;
    if (history.length <= effectiveLimit) {
      return history;
    }
    return history.sublist(history.length - effectiveLimit);
  }

  AiChatMessage _createMessage({
    required AiChatRole role,
    required String content,
    AiChatAttachment? attachment,
  }) {
    final now = DateTime.now();
    return AiChatMessage(
      id: '${role.name}_${now.microsecondsSinceEpoch}',
      role: role,
      content: content,
      createdAt: now,
      estimatedTokens: _tokenEstimator.estimateTextTokens(content),
      attachment: attachment,
    );
  }

  String _buildConversationSystemPrompt({required bool hasImage}) {
    final basePrompt = state.builtPrompt?.systemPrompt ?? _fallbackChatPrompt;
    final multimodalPrompt = hasImage
        ? '''
Если пользователь приложил изображение:
- опиши только визуально заметные признаки;
- не ставь медицинский диагноз и не утверждай наличие инфаркта, инсульта или иного заболевания;
- сопоставь видимые признаки с текстом пользователя и, если доступен, с контекстом health-данных;
- оцени уровень тревожности состояния как low, medium или high;
- укажи confidence_percent как эвристическую уверенность в наличии тревожных признаков, а не вероятность диагноза;
- если есть опасные сочетания признаков, порекомендуй срочно обратиться к врачу или вызвать скорую;
- завершай ответ фразой: "Результат не является медицинским диагнозом.".

Предпочтительный формат ответа при наличии фото:
1. Краткий вывод
2. Видимые признаки
3. Оценка в контексте симптомов и данных приложения
4. Уровень тревожности: low / medium / high
5. Confidence percent: 0-100
6. Рекомендация
7. Дисклеймер
'''
        : '''
Отвечай строго на русском языке.
Сохраняй медицинскую осторожность: не ставь диагноз и не назначай лечение.
Если данных недостаточно, прямо говори об этом.
В каждом ответе напоминай, что результат не является медицинским диагнозом.
''';

    return '$basePrompt\n\n$multimodalPrompt'.trim();
  }

  static const String _fallbackChatPrompt = '''
Ты — AI-помощник мобильного приложения MediAI для мониторинга самочувствия.
Отвечай строго на русском языке.
Ты не ставишь диагнозы и не заменяешь врача.
Твоя задача — объяснять наблюдаемые признаки и показатели простым языком, осторожно оценивать тревожность состояния и предлагать безопасные следующие шаги.
Если есть возможные тревожные признаки, рекомендуй обратиться к врачу или в экстренную службу.
Не назначай лекарства и не делай категоричных медицинских выводов.
''';
}
