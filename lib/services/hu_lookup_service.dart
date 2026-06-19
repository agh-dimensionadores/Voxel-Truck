import 'package:voxel_truck/data/mock_data.dart';
import 'package:voxel_truck/models/truck.dart';

class HuLookupResult {
  const HuLookupResult({this.unit, this.scannedCode = ''});

  final HandlingUnit? unit;
  final String scannedCode;

  bool get found => unit != null;

  String get sourceLabel {
    if (unit == null) return '';
    return unit!.source == DimensionSource.voxelCam ? 'Voxel Cam' : 'Coresa';
  }
}

class HuLookupService {
  static String normalizeCode(String code) {
    final cleaned = code
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\x00-\x1F]'), '');

    final match = RegExp(r'(HU|PLT)-\d+').firstMatch(cleaned);
    if (match != null) return match.group(0)!;

    return cleaned;
  }

  static Future<HuLookupResult> lookup(
    String code, {
    void Function(String message)? onProgress,
  }) async {
    final normalized = normalizeCode(code);
    if (normalized.isEmpty) return const HuLookupResult();

    onProgress?.call('Buscando en Voxel Cam...');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    HandlingUnit? unit = mockHuDatabase[normalized];

    if (unit == null) {
      onProgress?.call('No encontrado. Consultando Coresa...');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      unit = mockHuDatabase[normalized];
    }

    return HuLookupResult(unit: unit, scannedCode: normalized);
  }
}
