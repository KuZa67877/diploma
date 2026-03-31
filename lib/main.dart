import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'injection_container.dart';
import 'core/bloc/app_bloc_observer.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/language_cubit.dart';
import 'core/routing/app_router.dart';
import 'core/auth/auth_status_cubit.dart';
import 'core/supabase/supabase_initializer.dart';
import 'core/config/app_env.dart';
import 'core/logging/app_logger.dart';
import 'core/widgets/dev_logs_overlay_button.dart';

late final GoRouter _router;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = AppLogger.instance;
  Bloc.observer = AppBlocObserver();
  logger.info('app.lifecycle', 'Application bootstrap started');

  FlutterError.onError = (FlutterErrorDetails details) {
    logger.error(
      'flutter.error',
      details.exceptionAsString(),
      payload: {'stackTrace': details.stack.toString()},
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    logger.error(
      'dart.error',
      error.toString(),
      payload: {'stackTrace': stackTrace.toString()},
    );
    return false;
  };

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize dependencies
  await dotenv.load(fileName: '.env');
  logger.info('app.config', '.env loaded');
  await initSupabase();
  await initDependencies();
  logger.info('app.lifecycle', 'Dependencies initialized');

  final authStatusCubit = getIt<AuthStatusCubit>();
  if (AppEnv.enableAuthBypass) {
    logger.warning('auth.mode', 'Auth bypass mode is enabled');
    authStatusCubit.setAuthenticated();
  } else {
    final hasActiveSession =
        AppEnv.isSupabaseConfigured &&
        Supabase.instance.client.auth.currentSession != null;
    logger.info(
      'auth.session',
      hasActiveSession
          ? 'Found persisted Supabase session on startup'
          : 'No persisted session on startup',
    );
    if (hasActiveSession) {
      authStatusCubit.setAuthenticated();
    } else {
      authStatusCubit.setUnauthenticated();
    }
  }

  _router = AppRouter(authStatusCubit: authStatusCubit).router;
  logger.info('app.lifecycle', 'Router configured');

  runApp(MainApp(router: _router));
}

class MainApp extends StatelessWidget {
  final GoRouter router;

  const MainApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(create: (_) => getIt<ThemeCubit>()),
        BlocProvider<LanguageCubit>(create: (_) => getIt<LanguageCubit>()),
        BlocProvider<AuthStatusCubit>(create: (_) => getIt<AuthStatusCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          final themeMode = themeState.mode;
          return BlocBuilder<LanguageCubit, LanguageState>(
            builder: (context, languageState) {
              final language = languageState.language;
              return AnimatedTheme(
                data: themeMode == ThemeMode.dark
                    ? AppTheme.darkTheme
                    : AppTheme.lightTheme,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: MaterialApp.router(
                  title: 'MediAI',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeMode,
                  locale: Locale(language.code),
                  builder: (context, child) => DevLogsOverlayButton(
                    child: child ?? const SizedBox(),
                    onOpenLogs: () {
                      final currentRouteName =
                          router.routerDelegate.currentConfiguration.last.route
                              .name;
                      if (currentRouteName == AppRouter.debugLogsRoute) {
                        return;
                      }
                      router.pushNamed(AppRouter.debugLogsRoute);
                    },
                  ),
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                  routerConfig: router,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
