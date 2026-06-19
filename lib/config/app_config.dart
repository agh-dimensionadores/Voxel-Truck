class AppConfig {
  /// URL base del backend, sin barra final.
  /// Ej: https://mi-backend.onrender.com
  static const apiBaseUrl = String.fromEnvironment(
    'VOXEL_TRUCK_API_URL',
    defaultValue: '',
  );

  /// Token de cliente (mismo que client_token en license_config.json).
  static const apiToken = String.fromEnvironment(
    'VOXEL_TRUCK_API_TOKEN',
    defaultValue: '',
  );

  /// ID del cliente asociado al token (mismo que client_id en license_config.json).
  static const clientId = String.fromEnvironment(
    'VOXEL_TRUCK_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isApiConfigured =>
      apiBaseUrl.trim().isNotEmpty &&
      apiToken.trim().isNotEmpty &&
      clientId.trim().isNotEmpty;
}
