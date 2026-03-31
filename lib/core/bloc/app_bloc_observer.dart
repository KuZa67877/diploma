import 'package:flutter_bloc/flutter_bloc.dart';
import '../logging/app_logger.dart';

class AppBlocObserver extends BlocObserver {
  final _logger = AppLogger.instance;

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    _logger.debug('bloc.change', '${bloc.runtimeType} $change');
    super.onChange(bloc, change);
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    _logger.debug('bloc.transition', '${bloc.runtimeType} $transition');
    super.onTransition(bloc, transition);
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _logger.error(
      'bloc.error',
      '${bloc.runtimeType} $error',
      payload: {'stackTrace': stackTrace.toString()},
    );
    super.onError(bloc, error, stackTrace);
  }
}
