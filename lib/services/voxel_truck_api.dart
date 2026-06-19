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
    String? clientId,
  })  : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).trim().replaceAll(RegExp(r'/+$'), ''),
        _token = (token ?? AppConfig.apiToken).trim(),
        _clientId = (clientId ?? AppConfig.clientId).trim();

  final http.Client _client;
  final String _baseUrl;
  final String _token;
  final String _clientId;

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
      };

  Future<HandlingUnit?> fetchHu(String hu) async {
    if (_baseUrl.isEmpty || _token.isEmpty) {
      throw VoxelTruckApiException(
        'API no configurada. Definí VOXEL_TRUCK_API_URL y VOXEL_TRUCK_API_TOKEN al compilar.',
      );
    }

    if (_clientId.isEmpty) {
      throw VoxelTruckApiException(
        'Client ID no configurado. Definí VOXEL_TRUCK_CLIENT_ID al compilar.',
      );
    }

    http.Response response;
    try {
      response = await _postConsultaHu(hu);
      if (response.statusCode == 404) {
        response = await _getHuWithClientId(hu);
      }
    } on Exception {
      throw VoxelTruckApiException('Sin conexión al servidor. Verificá tu internet.');
    }

    return _parseHuResponse(response, hu);
  }

  Future<http.Response> _getHuWithClientId(String hu) {
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/hu/${Uri.encodeComponent(hu)}').replace(
      queryParameters: {'client_id': _clientId},
    );
    return _client.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 20));
  }

  Future<http.Response> _postConsultaHu(String hu) {
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/consulta-hu');
    return _client
        .post(
          uri,
          headers: {
            ..._authHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'hu': hu,
            'client_id': _clientId,
          }),
        )
        .timeout(const Duration(seconds: 20));
  }

  HandlingUnit? _parseHuResponse(http.Response response, String scannedHu) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw VoxelTruckApiException('Respuesta inválida del servidor (${response.statusCode}).');
    }

    if (response.statusCode == 401) {
      throw VoxelTruckApiException('Token inválido o no autorizado.');
    }

    if (response.statusCode == 403) {
      final detail = body['error'] ?? body['detail'];
      throw VoxelTruckApiException(
        detail?.toString() ?? 'Client ID no autorizado para este token.',
        statusCode: 403,
      );
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
        return HandlingUnit.fromVoxelCamApi(data, scannedHu);
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
