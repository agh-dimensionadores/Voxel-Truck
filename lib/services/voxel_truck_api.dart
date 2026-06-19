import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:voxel_truck/config/app_config.dart';
import 'package:voxel_truck/models/truck.dart';

class VoxelTruckApiException implements Exception {
  VoxelTruckApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class VoxelTruckApi {
  VoxelTruckApi({
    http.Client? client,
    String? baseUrl,
    String? token,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).trim().replaceAll(RegExp(r'/+$'), ''),
        _token = (token ?? AppConfig.apiToken).trim();

  final http.Client _client;
  final String _baseUrl;
  final String _token;

  Future<HandlingUnit?> fetchHu(String hu) async {
    if (_baseUrl.isEmpty || _token.isEmpty) {
      throw VoxelTruckApiException(
        'API no configurada. Definí VOXEL_TRUCK_API_URL y VOXEL_TRUCK_API_TOKEN al compilar.',
      );
    }

    final uri = Uri.parse('$_baseUrl/api/voxel-truck/hu/${Uri.encodeComponent(hu)}');

    http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $_token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw VoxelTruckApiException('Sin conexión al servidor. Verificá tu internet.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw VoxelTruckApiException('Respuesta inválida del servidor (${response.statusCode}).');
    }

    if (response.statusCode == 401) {
      throw VoxelTruckApiException('Token inválido o no autorizado.');
    }

    if (response.statusCode >= 500) {
      final detail = body['detail'] ?? body['error'];
      throw VoxelTruckApiException(
        detail?.toString() ?? 'Error del servidor (${response.statusCode}).',
      );
    }

    if (body['success'] == true) {
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw VoxelTruckApiException('Formato de respuesta inesperado.');
      }
      try {
        return HandlingUnit.fromVoxelCamApi(data, hu);
      } catch (error) {
        throw VoxelTruckApiException('Error al procesar datos del HU: $error');
      }
    }

    final serverError = body['error'] ?? body['detail'];
    if (serverError != null) {
      throw VoxelTruckApiException(serverError.toString());
    }

    return null;
  }

  void close() => _client.close();
}
