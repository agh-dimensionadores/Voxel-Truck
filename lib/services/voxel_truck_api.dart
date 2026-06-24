import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:voxel_truck/config/app_config.dart';
import 'package:voxel_truck/models/truck.dart';

class VoxelTruckApiException implements Exception {
  VoxelTruckApiException(this.message, {this.statusCode, this.detail});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? detail;

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
        _baseUrl = (baseUrl ?? AppConfig.resolvedApiBaseUrl).trim().replaceAll(RegExp(r'/+$'), ''),
        _token = (token ?? AppConfig.apiToken).trim(),
        _clientId = (clientId ?? AppConfig.clientId).trim();

  final http.Client _client;
  final String _baseUrl;
  final String _token;
  final String _clientId;

  Map<String, String> get _jsonHeaders => {
        ..._authHeaders,
        'Content-Type': 'application/json',
      };

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
      };

  void _ensureConfigured() {
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
  }

  Future<List<Truck>> listCamiones({TruckStatus? estado}) async {
    _ensureConfigured();
    final query = <String, String>{'client_id': _clientId};
    if (estado != null) {
      query['estado'] = _statusToApi(estado);
    }

    final uri = Uri.parse('$_baseUrl/api/voxel-truck/camiones').replace(queryParameters: query);
    final response = await _get(uri);
    final data = _expectDataList(response);
    return data.map(Truck.fromApi).toList();
  }

  Future<Truck> getCamion(String id) async {
    _ensureConfigured();
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/camiones/$id').replace(
      queryParameters: {'client_id': _clientId},
    );
    final response = await _get(uri);
    return Truck.fromApi(_expectDataMap(response));
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 45));
    } on VoxelTruckApiException {
      rethrow;
    } on Exception catch (error) {
      if (kDebugMode) {
        debugPrint('VoxelTruckApi: $_baseUrl -> $error');
      }
      if (kIsWeb) {
        throw VoxelTruckApiException(
          'No se pudo conectar a $_baseUrl. '
          'Verificá que run-chrome.ps1 muestre "Proxy: listo" y recargá con R.',
        );
      }
      throw VoxelTruckApiException('Sin conexión al servidor. Verificá tu internet.');
    }
  }

  Future<Truck> createCamion({
    required String numeroViaje,
    required String origen,
    required String destino,
    String? observaciones,
    String? creadoPor,
    String? idDispositivo,
  }) async {
    _ensureConfigured();
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/camiones');
    final response = await _send(
      () => _client.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({
          'numero_viaje': numeroViaje,
          'origen': origen,
          'destino': destino,
          if (observaciones != null && observaciones.isNotEmpty) 'observaciones': observaciones,
          if (creadoPor != null && creadoPor.isNotEmpty) 'creado_por': creadoPor,
          if (idDispositivo != null && idDispositivo.isNotEmpty) 'id_dispositivo': idDispositivo,
          'client_id': _clientId,
        }),
      ),
    );

    return Truck.fromApi(_expectDataMap(response));
  }

  Future<HandlingUnit> agregarBulto(String camionId, String codigoHu) async {
    _ensureConfigured();
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/camiones/$camionId/bultos');
    final response = await _send(
      () => _client.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({
          'codigo_hu': codigoHu,
          'client_id': _clientId,
        }),
      ),
    );

    return HandlingUnit.fromApi(_expectDataMap(response));
  }

  Future<void> eliminarBulto(String camionId, String codigoHu) async {
    _ensureConfigured();
    final encodedHu = Uri.encodeComponent(codigoHu);
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/camiones/$camionId/bultos/$encodedHu').replace(
      queryParameters: {'client_id': _clientId},
    );
    await _delete(uri);
  }

  Future<Truck> cerrarCamion(
    String id, {
    required String estado,
    double? porcentajeOcupacion,
    String? tipoVehiculo,
    required bool alertaEmailEnviada,
  }) async {
    _ensureConfigured();
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/camiones/$id/cerrar');
    final response = await _send(
      () => _client.patch(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({
          'estado': estado,
          if (porcentajeOcupacion != null) 'porcentaje_ocupacion': porcentajeOcupacion,
          if (tipoVehiculo != null && tipoVehiculo.isNotEmpty) 'tipo_vehiculo': tipoVehiculo,
          'alerta_email_enviada': alertaEmailEnviada,
          'client_id': _clientId,
        }),
      ),
    );

    return Truck.fromApi(_expectDataMap(response));
  }

  Future<Truck> reabrirCamion(String id) async {
    _ensureConfigured();
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/camiones/$id/reabrir');
    final response = await _send(
      () => _client.patch(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({'client_id': _clientId}),
      ),
    );

    return Truck.fromApi(_expectDataMap(response));
  }

  Future<Truck> enviarCamion(String id) async {
    _ensureConfigured();
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/camiones/$id/enviar');
    final response = await _send(
      () => _client.patch(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({'client_id': _clientId}),
      ),
    );

    return Truck.fromApi(_expectDataMap(response));
  }

  Future<HandlingUnit?> fetchHu(String hu) async {
    _ensureConfigured();

    http.Response response;
    try {
      response = await _postConsultaHu(hu);
      if (response.statusCode == 404) {
        response = await _getHuWithClientId(hu);
      }
    } on VoxelTruckApiException {
      rethrow;
    } on Exception catch (error) {
      throw VoxelTruckApiException('Sin conexión al servidor. Verificá tu internet. ($error)');
    }

    return _parseHuResponse(response, hu);
  }

  Future<http.Response> _get(Uri uri) async {
    return _send(() => _client.get(uri, headers: _authHeaders));
  }

  Future<void> _delete(Uri uri) async {
    final response = await _send(() => _client.delete(uri, headers: _authHeaders));
    _parseBody(response);
  }

  Future<http.Response> _getHuWithClientId(String hu) {
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/hu/${Uri.encodeComponent(hu)}').replace(
      queryParameters: {'client_id': _clientId},
    );
    return _send(() => _client.get(uri, headers: _authHeaders));
  }

  Future<http.Response> _postConsultaHu(String hu) {
    final uri = Uri.parse('$_baseUrl/api/voxel-truck/consulta-hu');
    return _send(
      () => _client.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({
          'hu': hu,
          'client_id': _clientId,
        }),
      ),
    );
  }

  HandlingUnit? _parseHuResponse(http.Response response, String scannedHu) {
    final body = _parseBody(response);

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

    return null;
  }

  Map<String, dynamic> _parseBody(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw VoxelTruckApiException('Respuesta inválida del servidor (${response.statusCode}).');
    }

    if (response.statusCode == 401) {
      throw VoxelTruckApiException('Token inválido o no autorizado.', statusCode: 401);
    }

    if (response.statusCode == 403) {
      final detail = body['error'] ?? body['detail'];
      throw VoxelTruckApiException(
        detail?.toString() ?? 'Client ID no autorizado para este token.',
        statusCode: 403,
      );
    }

    if (response.statusCode == 409) {
      final message = body['error']?.toString() ?? 'Conflicto con un recurso existente.';
      final detail = body['detail'];
      throw VoxelTruckApiException(
        message,
        statusCode: 409,
        detail: detail is Map<String, dynamic> ? detail : null,
      );
    }

    if (response.statusCode == 404) {
      final detail = body['error'] ?? body['detail'];
      throw VoxelTruckApiException(
        detail?.toString() ?? 'Recurso no encontrado.',
        statusCode: 404,
      );
    }

    if (response.statusCode == 422) {
      final detail = body['error'] ?? body['detail'];
      throw VoxelTruckApiException(
        detail?.toString() ?? 'Operación no permitida.',
        statusCode: 422,
      );
    }

    if (response.statusCode >= 500) {
      final detail = body['detail'] ?? body['error'];
      throw VoxelTruckApiException(
        detail?.toString() ?? 'Error del servidor (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400 || body['success'] == false) {
      final detail = body['error'] ?? body['detail'];
      throw VoxelTruckApiException(
        detail?.toString() ?? 'Error del servidor (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  Map<String, dynamic> _expectDataMap(http.Response response) {
    final body = _parseBody(response);
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw VoxelTruckApiException('Formato de respuesta inesperado.');
    }
    return data;
  }

  List<Map<String, dynamic>> _expectDataList(http.Response response) {
    final body = _parseBody(response);
    final data = body['data'];
    if (data is! List) {
      throw VoxelTruckApiException('Formato de respuesta inesperado.');
    }
    return data.whereType<Map<String, dynamic>>().toList();
  }

  static String _statusToApi(TruckStatus status) => switch (status) {
        TruckStatus.abierto => 'abierto',
        TruckStatus.pendiente => 'pendiente',
        TruckStatus.cerrado => 'cerrado',
        TruckStatus.enviado => 'enviado',
      };

  void close() => _client.close();
}
