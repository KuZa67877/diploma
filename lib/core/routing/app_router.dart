import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_status_cubit.dart';
import '../config/app_env.dart';
import '../logging/app_logger.dart';
import '../../injection_container.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/data_input/presentation/pages/data_input_page.dart';
import '../../features/health_data/presentation/pages/health_import_preview_page.dart';
import '../../features/health_data/presentation/pages/health_sources_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/debug_logs_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/wellbeing/presentation/bloc/wellbeing_cubit.dart';
import '../../features/wellbeing/presentation/pages/wellbeing_checkin_page.dart';
import '../../features/wellbeing/presentation/pages/wellbeing_page.dart';
import 'go_router_refresh_stream.dart';
import 'main_shell_scaffold.dart';

class AppRouter {
  final AuthStatusCubit authStatusCubit;
  final _logger = AppLogger.instance;

  AppRouter({required this.authStatusCubit});

  static const String splashPath = '/splash';
  static const String authPath = '/auth';
  static const String dataInputPath = '/data-input';
  static const String healthSourcesPath = '/health-sources';
  static const String healthImportPreviewPath = '/health-import-preview';

  static const String homePath = '/home';
  static const String wellbeingPath = '/wellbeing';
  static const String analyticsPath = '/analytics';
  static const String settingsPath = '/settings';
  static const String profilePath = '/profile';
  static const String debugLogsPath = '/debug-logs';
  static const String wellbeingCheckInPath = '/wellbeing-check-in';

  static const String splashRoute = 'splash';
  static const String authRoute = 'auth';
  static const String dataInputRoute = 'data-input';
  static const String healthSourcesRoute = 'health-sources';
  static const String healthImportPreviewRoute = 'health-import-preview';

  static const String homeRoute = 'home';
  static const String wellbeingRoute = 'wellbeing';
  static const String analyticsRoute = 'analytics';
  static const String settingsRoute = 'settings';
  static const String profileRoute = 'profile';
  static const String debugLogsRoute = 'debug-logs';
  static const String wellbeingCheckInRoute = 'wellbeing-check-in';

  late final GoRouter router = GoRouter(
    initialLocation: splashPath,
    refreshListenable: GoRouterRefreshStream(authStatusCubit.stream),
    redirect: _redirect,
    routes: [
      GoRoute(path: '/', redirect: (_, __) => splashPath),
      GoRoute(
        path: splashPath,
        name: splashRoute,
        builder: (context, state) =>
            SplashPage(onComplete: () => context.goNamed(authRoute)),
      ),
      GoRoute(
        path: authPath,
        name: authRoute,
        builder: (context, state) => AuthPage(
          onAuthSuccess: (isLogin) {
            if (isLogin) {
              authStatusCubit.setAuthenticated();
              context.goNamed(homeRoute);
              return;
            }
            // Registration flow is explicit: data input -> health sources.
            context.goNamed(dataInputRoute);
          },
        ),
      ),
      GoRoute(
        path: dataInputPath,
        name: dataInputRoute,
        builder: (context, state) => DataInputPage(
          onComplete: () => context.goNamed(healthSourcesRoute),
        ),
      ),
      GoRoute(
        path: healthSourcesPath,
        name: healthSourcesRoute,
        builder: (context, state) {
          final openedFromSettings =
              state.uri.queryParameters['from'] == 'settings';

          return HealthSourcesPage(
            onBack: () {
              if (openedFromSettings) {
                context.pop();
                return;
              }
              context.goNamed(dataInputRoute);
            },
            onComplete: () {
              if (openedFromSettings) {
                context.pop();
                return;
              }
              authStatusCubit.setAuthenticated();
              context.goNamed(homeRoute);
            },
            showSkipAction: !openedFromSettings,
            showContinueAction: !openedFromSettings,
            onSkip: () {
              if (openedFromSettings) {
                context.pop();
                return;
              }
              authStatusCubit.setAuthenticated();
              context.goNamed(homeRoute);
            },
          );
        },
      ),
      GoRoute(
        path: healthImportPreviewPath,
        name: healthImportPreviewRoute,
        builder: (context, state) =>
            HealthImportPreviewPage(onBack: () => context.pop()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: homePath,
                name: homeRoute,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: DashboardPage(
                    onOpenProfile: () => context.pushNamed(profileRoute),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: wellbeingPath,
                name: wellbeingRoute,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: BlocProvider<WellbeingCubit>.value(
                    value: getIt<WellbeingCubit>()..ensureLoaded(),
                    child: WellbeingPage(
                      onOpenCheckIn: (date) => context.pushNamed(
                        wellbeingCheckInRoute,
                        queryParameters: {'date': _toDateQuery(date)},
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: analyticsPath,
                name: analyticsRoute,
                pageBuilder: (context, state) =>
                    NoTransitionPage(child: const AnalyticsPage()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: settingsPath,
        name: settingsRoute,
        builder: (context, state) => SettingsPage(
          onBack: () => context.pop(),
          onOpenHealthSources: () => context.pushNamed(
            healthSourcesRoute,
            queryParameters: const {'from': 'settings'},
          ),
        ),
      ),
      GoRoute(
        path: wellbeingCheckInPath,
        name: wellbeingCheckInRoute,
        builder: (context, state) {
          final dateParam = state.uri.queryParameters['date'];
          final selectedDate = _fromDateQuery(dateParam);
          return BlocProvider<WellbeingCubit>.value(
            value: getIt<WellbeingCubit>()..ensureLoaded(),
            child: WellbeingCheckInPage(initialDate: selectedDate),
          );
        },
      ),
      GoRoute(
        path: profilePath,
        name: profileRoute,
        builder: (context, state) => ProfilePage(
          onBack: () => context.pop(),
          onOpenSettings: () => context.pushNamed(settingsRoute),
          onLogout: () async {
            if (AppEnv.isSupabaseConfigured) {
              try {
                await Supabase.instance.client.auth.signOut();
                _logger.info('auth.session', 'Supabase session signed out');
              } catch (error, stackTrace) {
                _logger.error(
                  'auth.session',
                  'Supabase signOut failed',
                  payload: {
                    'error': error.toString(),
                    'stackTrace': stackTrace.toString(),
                  },
                );
              }
            }
            if (!context.mounted) {
              return;
            }
            authStatusCubit.setUnauthenticated();
            context.goNamed(authRoute);
          },
        ),
      ),
      if (AppLogger.instance.isEnabled)
        GoRoute(
          path: debugLogsPath,
          name: debugLogsRoute,
          builder: (context, state) =>
              DebugLogsPage(onBack: () => context.pop()),
        ),
    ],
  );

  String? _redirect(_, GoRouterState state) {
    final status = authStatusCubit.state.status;
    final location = state.matchedLocation;
    final isSetupFlow = _setupFlowLocations.contains(location);
    final isProtected = _protectedLocations.contains(location);

    if (status == AuthStatus.unauthenticated && isProtected) {
      return authPath;
    }

    if (status == AuthStatus.authenticated && isSetupFlow) {
      return homePath;
    }

    return null;
  }

  static const List<String> _setupFlowLocations = [
    splashPath,
    authPath,
    dataInputPath,
  ];

  static final List<String> _protectedLocations = [
    homePath,
    wellbeingPath,
    analyticsPath,
    settingsPath,
    wellbeingCheckInPath,
    profilePath,
    if (AppLogger.instance.isEnabled) debugLogsPath,
  ];
}

String _toDateQuery(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final year = normalized.year.toString().padLeft(4, '0');
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime _fromDateQuery(String? value) {
  final now = DateTime.now();
  final fallback = DateTime(now.year, now.month, now.day);
  if (value == null || value.isEmpty) {
    return fallback;
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return fallback;
  }

  final normalized = DateTime(parsed.year, parsed.month, parsed.day);
  final today = DateTime(now.year, now.month, now.day);
  if (normalized.isAfter(today)) {
    return today;
  }
  return normalized;
}
