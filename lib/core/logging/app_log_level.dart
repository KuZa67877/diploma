enum AppLogLevel { debug, info, warning, error }

extension AppLogLevelX on AppLogLevel {
  String get label {
    switch (this) {
      case AppLogLevel.debug:
        return 'DEBUG';
      case AppLogLevel.info:
        return 'INFO';
      case AppLogLevel.warning:
        return 'WARN';
      case AppLogLevel.error:
        return 'ERROR';
    }
  }
}
