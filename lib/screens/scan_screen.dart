import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/services/hu_lookup_service.dart';
import 'package:voxel_truck/theme/app_colors.dart';
import 'package:voxel_truck/utils/platform_utils.dart';
import 'package:voxel_truck/widgets/barcode_camera_scanner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.truckId});

  final String truckId;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _pulseController;

  String? _statusMessage;
  bool _isSearching = false;
  bool _found = false;

  bool get _useCamera => supportsBarcodeCamera;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (!_useCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _lookupCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty || _isSearching) return;

    setState(() {
      _isSearching = true;
      _statusMessage = 'Buscando en Voxel Cam...';
      _found = false;
    });

    final result = await HuLookupService.lookup(
      trimmed,
      onProgress: (message) {
        if (mounted) setState(() => _statusMessage = message);
      },
    );

    if (!mounted) return;

    if (result.found) {
      final unit = result.unit!;
      setState(() {
        _isSearching = false;
        _found = true;
        _statusMessage = 'HU encontrado (${result.sourceLabel})';
      });
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) context.pop<HandlingUnit>(unit);
    } else {
      setState(() {
        _isSearching = false;
        _found = false;
        _statusMessage = 'HU no encontrado: ${result.scannedCode}';
      });
    }
  }

  void _onSubmit(String value) => _lookupCode(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D26),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Escanear HU'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: _useCamera
                    ? BarcodeCameraScanner(
                        enabled: !_isSearching,
                        onCodeScanned: _lookupCode,
                      )
                    : Center(child: _ScannerPlaceholder(animation: _pulseController)),
              ),
              const SizedBox(height: 16),
              Text(
                _useCamera
                    ? 'Apunte la cámara al código o use la pistola lectora'
                    : 'Use la pistola lectora o ingrese el código manualmente',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Códigos demo: HU-884521, HU-884522, PLT-00931, HU-771001',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _codeController,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Código HU',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.teal,
                            ),
                          ),
                        )
                      : IconButton(
                          onPressed: () => _lookupCode(_codeController.text),
                          icon: const Icon(Icons.search, color: AppColors.teal),
                        ),
                ),
                onSubmitted: _onSubmit,
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _found
                          ? Icons.check_circle
                          : _isSearching
                              ? Icons.sync
                              : Icons.error_outline,
                      size: 16,
                      color: _found
                          ? AppColors.teal
                          : _isSearching
                              ? AppColors.teal
                              : AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isSearching ? null : () => _lookupCode('HU-884521'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  side: const BorderSide(color: AppColors.teal),
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Simular escaneo demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerPlaceholder extends StatelessWidget {
  const _ScannerPlaceholder({required this.animation});

  final AnimationController animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.teal.withValues(alpha: 0.4 + animation.value * 0.4),
              width: 3,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                size: 120,
                color: AppColors.teal.withValues(alpha: 0.6),
              ),
              const Positioned(top: 16, left: 16, child: _CornerBracket()),
              const Positioned(
                top: 16,
                right: 16,
                child: _RotatedCornerBracket(angle: 1.5708),
              ),
              const Positioned(
                bottom: 16,
                left: 16,
                child: _RotatedCornerBracket(angle: -1.5708),
              ),
              const Positioned(
                bottom: 16,
                right: 16,
                child: _RotatedCornerBracket(angle: 3.14159),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.teal, width: 3),
          left: BorderSide(color: AppColors.teal, width: 3),
        ),
      ),
    );
  }
}

class _RotatedCornerBracket extends StatelessWidget {
  const _RotatedCornerBracket({required this.angle});

  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: const _CornerBracket(),
    );
  }
}
