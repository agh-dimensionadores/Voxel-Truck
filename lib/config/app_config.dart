class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'VOXEL_TRUCK_API_URL',
    defaultValue: '',
  );

  static const apiToken = String.fromEnvironment(
    'VOXEL_TRUCK_API_TOKEN',
    defaultValue: '',
  );

  static const clientId = String.fromEnvironment(
    'VOXEL_TRUCK_CLIENT_ID',
    defaultValue: '',
  );

  static String get resolvedApiBaseUrl => apiBaseUrl.trim();

  static bool get isApiConfigured =>
      resolvedApiBaseUrl.isNotEmpty &&
      apiToken.trim().isNotEmpty &&
      clientId.trim().isNotEmpty;
}
