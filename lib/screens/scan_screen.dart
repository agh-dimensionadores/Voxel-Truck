import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voxel_truck/data/mock_data.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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
    if (trimmed.isEmpty) return;

    setState(() {
      _isSearching = true;
      _statusMessage = 'Buscando en Voxel Cam...';
      _found = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));

    HandlingUnit? unit = mockHuDatabase[trimmed];

    if (unit == null) {
      setState(() => _statusMessage = 'No encontrado. Consultando Coresa...');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      unit = mockHuDatabase[trimmed];
    }

    if (!mounted) return;

    if (unit != null) {
      setState(() {
        _isSearching = false;
        _found = true;
        _statusMessage = 'HU encontrado (${unit!.source == DimensionSource.voxelCam ? 'Voxel Cam' : 'Coresa'})';
      });
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) context.pop(unit);
    } else {
      setState(() {
        _isSearching = false;
        _found = false;
        _statusMessage = 'HU no encontrado en ninguna fuente';
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
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.teal.withValues(
                              alpha: 0.4 + _pulseController.value * 0.4,
                            ),
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
                            Positioned(
                              top: 16,
                              left: 16,
                              child: _CornerBracket(),
                            ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Transform.rotate(
                                angle: 1.5708,
                                child: _CornerBracket(),
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              left: 16,
                              child: Transform.rotate(
                                angle: -1.5708,
                                child: _CornerBracket(),
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: Transform.rotate(
                                angle: 3.14159,
                                child: _CornerBracket(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Text(
                'Apunte la cámara al código o use la pistola lectora',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
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
                onPressed: () => _lookupCode('HU-884521'),
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

class _CornerBracket extends StatelessWidget {
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
