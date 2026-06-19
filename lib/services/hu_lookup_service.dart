import 'package:voxel_truck/config/app_config.dart';
import 'package:voxel_truck/data/mock_data.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/services/voxel_truck_api.dart';

class HuLookupResult {
  const HuLookupResult({
    this.unit,
    this.scannedCode = '',
    this.errorMessage,
  });

  final HandlingUnit? unit;
  final String scannedCode;
  final String? errorMessage;

  bool get found => unit != null;

  String get sourceLabel {
    if (unit == null) return '';
    return unit!.source == DimensionSource.voxelCam ? 'Voxel Cam' : 'Coresa';
  }
}

class HuLookupService {
  HuLookupService({VoxelTruckApi? api}) : _api = api ?? VoxelTruckApi();

  static final HuLookupService _instance = HuLookupService();

  final VoxelTruckApi _api;

  static String normalizeCode(String code) {
    var cleaned = code.trim().replaceAll(RegExp(r'[\x00-\x1F]'), '');
    // Prefijos AIM de pistolas lectoras (]C1, ]d2, etc.)
    cleaned = cleaned.replaceAll(RegExp(r'^\][A-Za-z]\d'), '');
    cleaned = cleaned.replaceAll(
      RegExp(r'^(REMITO_|ARTICULO_|LOTE_)', caseSensitive: false),
      '',
    );
    return cleaned.trim();
  }

  Future<HuLookupResult> lookup(
    String code, {
    void Function(String message)? onProgress,
  }) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty) return const HuLookupResult();

    if (AppConfig.isApiConfigured) {
      return _lookupFromApi(normalized, onProgress);
    }

    return _lookupFromMock(normalized, onProgress);
  }

  static Future<HuLookupResult> search(
    String code, {
    void Function(String message)? onProgress,
  }) =>
      _instance.lookup(code, onProgress: onProgress);

  static String notFoundMessage(String code) => 'No se encontró el escaneo: $code';

  Future<HuLookupResult> _lookupFromApi(
    String normalized,
    void Function(String message)? onProgress,
  ) async {
    onProgress?.call('Consultando Voxel Cam...');

    try {
      final unit = await _api.fetchHu(normalized);
      if (unit != null) {
        return HuLookupResult(unit: unit, scannedCode: normalized);
      }
      return HuLookupResult(
        scannedCode: normalized,
        errorMessage: notFoundMessage(normalized),
      );
    } on VoxelTruckApiException catch (error) {
      if (_isNotFoundError(error)) {
        return HuLookupResult(
          scannedCode: normalized,
          errorMessage: notFoundMessage(normalized),
        );
      }
      return HuLookupResult(
        scannedCode: normalized,
        errorMessage: error.message,
      );
    } catch (error) {
      return HuLookupResult(
        scannedCode: normalized,
        errorMessage: 'Error al consultar HU: $error',
      );
    }
  }

  Future<HuLookupResult> _lookupFromMock(
    String normalized,
    void Function(String message)? onProgress,
  ) async {
    onProgress?.call('Buscando en Voxel Cam (demo)...');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final lookupKey = normalized.toUpperCase();
    final unit = mockHuDatabase[lookupKey];
    if (unit != null) {
      return HuLookupResult(unit: unit, scannedCode: lookupKey);
    }

    return HuLookupResult(
      scannedCode: lookupKey,
      errorMessage: notFoundMessage(lookupKey),
    );
  }

  bool _isNotFoundError(VoxelTruckApiException error) {
    final message = error.message.toLowerCase();
    return message.contains('no se encontr') ||
        message.contains('not found') ||
        error.statusCode == 404;
  }
}
