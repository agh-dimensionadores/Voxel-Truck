import 'package:voxel_truck/services/hu_lookup_service.dart';

/// Evita procesar fragmentos de escaneo o el mismo código repetido seguido.
class BarcodeScanGuard {
  BarcodeScanGuard({
    this.minLength = 4,
    this.duplicateWindow = const Duration(seconds: 2),
  });

  final int minLength;
  final Duration duplicateWindow;

  String? _lastCode;
  DateTime? _lastProcessedAt;

  String? prepare(String rawCode) {
    final normalized = HuLookupService.normalizeCode(rawCode);
    if (normalized.length < minLength) return null;

    final now = DateTime.now();
    if (_lastCode == normalized &&
        _lastProcessedAt != null &&
        now.difference(_lastProcessedAt!) < duplicateWindow) {
      return null;
    }

    _lastCode = normalized;
    _lastProcessedAt = now;
    return normalized;
  }

  void reset() {
    _lastCode = null;
    _lastProcessedAt = null;
  }
}
