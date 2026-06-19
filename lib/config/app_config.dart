class AppConfig {
  /// URL base del backend, sin barra final.
  /// Ej: https://mi-backend.onrender.com
  static const apiBaseUrl = String.fromEnvironment(
    'VOXEL_TRUCK_API_URL',
    defaultValue: '',
  );

  /// Token de cliente (mismo que usan las máquinas scanner).
  static const apiToken = String.fromEnvironment(
    'VOXEL_TRUCK_API_TOKEN',
    defaultValue: '',
  );

  static bool get isApiConfigured =>
      apiBaseUrl.trim().isNotEmpty && apiToken.trim().isNotEmpty;
}
