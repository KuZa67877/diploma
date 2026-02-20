import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/splash_data.dart';
import '../../domain/usecases/get_splash_data.dart';
import '../models/splash_ui_models.dart';

part 'splash_cubit.freezed.dart';
part 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  final GetSplashData getSplashData;
  Timer? _timer;

  SplashCubit({
    required this.getSplashData,
  }) : super(const SplashState.initial());

  Future<void> load() async {
    emit(const SplashState.loading());

    final result = await getSplashData(const NoParams());
    result.fold(
      (failure) => emit(SplashState.error(message: _mapFailureMessage(failure))),
      (data) {
        final viewData = _mapToViewData(data);
        emit(SplashState.ready(data: viewData));
        _scheduleComplete(viewData.durationMs);
      },
    );
  }

  void _scheduleComplete(int durationMs) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: durationMs), () {
      emit(const SplashState.completed());
    });
  }

  SplashViewData _mapToViewData(SplashData data) {
    return SplashViewData(
      appName: data.appName,
      tagline: data.tagline,
      durationMs: data.durationMs,
    );
  }

  String _mapFailureMessage(Failure failure) {
    return failure.message;
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
