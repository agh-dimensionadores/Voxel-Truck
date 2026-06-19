import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:voxel_truck/theme/app_colors.dart';

class BarcodeCameraScanner extends StatefulWidget {
  const BarcodeCameraScanner({
    super.key,
    required this.onCodeScanned,
    this.enabled = true,
    this.showTorchToggle = true,
  });

  final Future<void> Function(String code) onCodeScanned;
  final bool enabled;
  final bool showTorchToggle;

  @override
  State<BarcodeCameraScanner> createState() => _BarcodeCameraScannerState();
}

class _BarcodeCameraScannerState extends State<BarcodeCameraScanner> {
  late final MobileScannerController _controller;

  bool _isProcessing = false;
  String? _lastCode;
  MobileScannerException? _startError;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      cameraResolution: const Size(1280, 720),
    );
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanner());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final error = _controller.value.error;
    if (error != null && mounted) {
      setState(() => _startError = error);
    }
  }

  Future<void> _startScanner() async {
    if (!mounted) return;

    setState(() => _startError = null);

    try {
      await _controller.start();
    } on MobileScannerException catch (error) {
      if (mounted) setState(() => _startError = error);
    } catch (error) {
      if (mounted) {
        setState(() {
          _startError = MobileScannerException(
            errorCode: MobileScannerErrorCode.genericError,
            errorDetails: MobileScannerErrorDetails(message: error.toString()),
          );
        });
      }
    }
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (!widget.enabled || _isProcessing) return;

    final code = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    if (code.isEmpty) return;
    if (_lastCode == code) return;

    _lastCode = code;
    _isProcessing = true;

    try {
      await widget.onCodeScanned(code);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastCode = null;
        });
      }
    }
  }

  String _errorMessage(MobileScannerException error) {
    final details = error.errorDetails?.message;
    if (details != null && details.isNotEmpty) {
      return '${error.errorCode.message}\n$details';
    }
    return error.errorCode.message;
  }

  @override
  Widget build(BuildContext context) {
    if (_startError != null) {
      return _ScannerErrorView(
        message: _errorMessage(_startError!),
        onRetry: _startScanner,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
            errorBuilder: (context, error) {
              return _ScannerErrorView(
                message: _errorMessage(error),
                onRetry: _startScanner,
              );
            },
            placeholderBuilder: (context) {
              return const ColoredBox(
                color: Color(0xFF1A1D26),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                ),
              );
            },
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.85), width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
              margin: const EdgeInsets.all(24),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              ),
            ),
          if (widget.showTorchToggle)
            Positioned(
              top: 12,
              right: 12,
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller,
                builder: (context, state, child) {
                  if (!state.isRunning) return const SizedBox.shrink();

                  final torch = state.torchState;
                  return IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _controller.toggleTorch(),
                    icon: Icon(
                      torch == TorchState.on ? Icons.flash_on : Icons.flash_off,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1A1D26),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
