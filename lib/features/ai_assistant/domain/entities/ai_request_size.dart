enum AiRequestSize { small, medium, large }

extension AiRequestSizeX on AiRequestSize {
  String get labelKey => switch (this) {
    AiRequestSize.small => 'aiRequestSizeSmall',
    AiRequestSize.medium => 'aiRequestSizeMedium',
    AiRequestSize.large => 'aiRequestSizeLarge',
  };
}
