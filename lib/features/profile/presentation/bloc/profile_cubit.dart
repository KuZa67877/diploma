import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/connected_service.dart';
import '../../domain/entities/profile_data.dart';
import '../../domain/usecases/get_profile_data.dart';
import '../models/profile_ui_models.dart';

part 'profile_cubit.freezed.dart';
part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final GetProfileData getProfileData;

  ProfileCubit({
    required this.getProfileData,
  }) : super(const ProfileState.initial());

  Future<void> load() async {
    emit(const ProfileState.loading());

    final result = await getProfileData(const NoParams());
    result.fold(
      (failure) => emit(ProfileState.error(message: _mapFailureMessage(failure))),
      (data) => emit(ProfileState.loaded(data: _mapToViewData(data))),
    );
  }

  ProfileViewData _mapToViewData(ProfileData data) {
    return ProfileViewData(
      userName: data.user.name,
      email: data.user.email,
      services: _mapServices(data.services),
    );
  }

  List<ProfileServiceUiModel> _mapServices(List<ConnectedService> services) {
    return services
        .map(
          (service) => ProfileServiceUiModel(
            id: service.id,
            nameKey: service.nameKey,
            icon: _iconForKey(service.iconKey),
            color: _colorForKey(service.colorKey),
            connected: service.connected,
          ),
        )
        .toList(growable: false);
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'heart':
        return LucideIcons.heart;
      case 'activity':
        return LucideIcons.activity;
      default:
        return LucideIcons.link;
    }
  }

  Color _colorForKey(String key) {
    switch (key) {
      case 'danger':
        return AppColors.danger;
      case 'secondary':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }
}
