import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/onboarding_slide.dart';
import '../../domain/usecases/get_onboarding_slides.dart';
import '../models/onboarding_slide_ui_model.dart';

part 'onboarding_cubit.freezed.dart';
part 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final GetOnboardingSlides getOnboardingSlides;

  OnboardingCubit({
    required this.getOnboardingSlides,
  }) : super(const OnboardingState.initial());

  Future<void> loadSlides() async {
    emit(const OnboardingState.loading());
    final result = await getOnboardingSlides(const NoParams());

    result.fold(
      (failure) => emit(
        OnboardingState.error(message: _mapFailureMessage(failure)),
      ),
      (slides) => emit(
        OnboardingState.loaded(slides: _mapSlides(slides)),
      ),
    );
  }

  List<OnboardingSlideUiModel> _mapSlides(List<OnboardingSlide> slides) {
    return slides
        .map(
          (slide) => OnboardingSlideUiModel(
            icon: _iconForKey(slide.iconKey),
            titleKey: slide.titleKey,
            descriptionKey: slide.descriptionKey,
            gradientColors:
                slide.gradientKeys.map(_colorForKey).toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'brain':
        return LucideIcons.brain;
      case 'activity':
        return LucideIcons.activity;
      case 'shield':
        return LucideIcons.shield;
      default:
        return LucideIcons.sparkles;
    }
  }

  Color _colorForKey(String key) {
    switch (key) {
      case 'primary':
        return AppColors.primary;
      case 'primaryGlow':
        return AppColors.primaryGlow;
      case 'secondary':
        return AppColors.secondary;
      case 'success':
        return AppColors.success;
      case 'aiPurple':
        return AppColors.aiPurple;
      case 'accent':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }
}
