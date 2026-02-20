import 'package:go_router/go_router.dart';
import '../auth/auth_status_cubit.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/data_input/presentation/pages/data_input_page.dart';
import '../../features/health_data/presentation/pages/health_sources_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/permissions/presentation/pages/permissions_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import 'go_router_refresh_stream.dart';
import 'main_shell_scaffold.dart';

class AppRouter {
  final AuthStatusCubit authStatusCubit;

  AppRouter({
    required this.authStatusCubit,
  });

  static const String splashPath = '/splash';
  static const String onboardingPath = '/onboarding';
  static const String authPath = '/auth';
  static const String permissionsPath = '/permissions';
  static const String healthSourcesPath = '/health-sources';

  static const String homePath = '/home';
  static const String dataPath = '/data';
  static const String analyticsPath = '/analytics';
  static const String reportsPath = '/reports';
  static const String profilePath = '/profile';

  static const String splashRoute = 'splash';
  static const String onboardingRoute = 'onboarding';
  static const String authRoute = 'auth';
  static const String permissionsRoute = 'permissions';
  static const String healthSourcesRoute = 'health-sources';

  static const String homeRoute = 'home';
  static const String dataRoute = 'data';
  static const String analyticsRoute = 'analytics';
  static const String reportsRoute = 'reports';
  static const String profileRoute = 'profile';

  late final GoRouter router = GoRouter(
    initialLocation: splashPath,
    refreshListenable: GoRouterRefreshStream(authStatusCubit.stream),
    redirect: _redirect,
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => splashPath,
      ),
      GoRoute(
        path: splashPath,
        name: splashRoute,
        builder: (context, state) => SplashPage(
          onComplete: () => context.goNamed(onboardingRoute),
        ),
      ),
      GoRoute(
        path: onboardingPath,
        name: onboardingRoute,
        builder: (context, state) => OnboardingPage(
          onComplete: () => context.goNamed(homeRoute),
          onSignIn: () => context.goNamed(authRoute),
        ),
      ),
      GoRoute(
        path: authPath,
        name: authRoute,
        builder: (context, state) => AuthPage(
          onBack: () => context.goNamed(onboardingRoute),
          onAuthSuccess: () => context.goNamed(permissionsRoute),
        ),
      ),
      GoRoute(
        path: permissionsPath,
        name: permissionsRoute,
        builder: (context, state) => PermissionsPage(
          onBack: () => context.goNamed(authRoute),
          onComplete: () {
            authStatusCubit.setAuthenticated();
            context.goNamed(homeRoute);
          },
        ),
      ),
      GoRoute(
        path: healthSourcesPath,
        name: healthSourcesRoute,
        builder: (context, state) => HealthSourcesPage(
          onBack: () => context.pop(),
        ),
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
                  child: const DashboardPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: dataPath,
                name: dataRoute,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const DataInputPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: analyticsPath,
                name: analyticsRoute,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const AnalyticsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: reportsPath,
                name: reportsRoute,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const ReportsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: profilePath,
                name: profileRoute,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: ProfilePage(
                    onLogout: () {
                      authStatusCubit.setUnauthenticated();
                      context.goNamed(onboardingRoute);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  String? _redirect(_, GoRouterState state) {
    final status = authStatusCubit.state.status;
    final location = state.matchedLocation;
    final isAuthFlow = _authFlowLocations.contains(location);
    final isTab = _tabLocations.contains(location);

    if (status == AuthStatus.unauthenticated && isTab) {
      return onboardingPath;
    }

    if (status == AuthStatus.authenticated &&
        isAuthFlow &&
        location != permissionsPath) {
      return homePath;
    }

    return null;
  }

  static const List<String> _authFlowLocations = [
    splashPath,
    onboardingPath,
    authPath,
    permissionsPath,
  ];

  static const List<String> _tabLocations = [
    homePath,
    dataPath,
    analyticsPath,
    reportsPath,
    profilePath,
    healthSourcesPath,
  ];
}
