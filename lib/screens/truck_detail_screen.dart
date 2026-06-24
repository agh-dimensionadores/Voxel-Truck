import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:voxel_truck/data/mock_data.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/services/hu_lookup_service.dart';
import 'package:voxel_truck/state/truck_controller.dart';
import 'package:voxel_truck/state/display_settings_controller.dart';
import 'package:voxel_truck/theme/app_colors.dart';
import 'package:voxel_truck/utils/barcode_scan_guard.dart';
import 'package:voxel_truck/utils/platform_utils.dart';
import 'package:voxel_truck/utils/unit_formatter.dart';
import 'package:voxel_truck/widgets/barcode_camera_scanner.dart';
import 'package:voxel_truck/widgets/common_widgets.dart';
import 'package:voxel_truck/widgets/modern_surface.dart';
import 'package:voxel_truck/widgets/truck_widgets.dart';

class TruckDetailScreen extends StatefulWidget {
  const TruckDetailScreen({super.key, required this.truckId});

  final String truckId;

  @override
  State<TruckDetailScreen> createState() => _TruckDetailScreenState();
}

class _TruckDetailScreenState extends State<TruckDetailScreen> {
  final _scanController = TextEditingController();
  final _scanFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _scanGuard = BarcodeScanGuard();
  Timer? _scanDebounce;
  bool _isLookingUp = false;
  bool _showCameraFab = true;

  static const _closeActionsVisibilityThreshold = 160.0;

  TruckController get _controller => TruckScope.of(context);

  Truck? get _truck => _controller.findById(widget.truckId);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateCameraFabVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.refreshCamion(widget.truckId);
      _requestScanFocus();
      _updateCameraFabVisibility();
    });
  }

  @override
  void dispose() {
    _scanDebounce?.cancel();
    _scrollController.removeListener(_updateCameraFabVisibility);
    _scrollController.dispose();
    _scanController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  void _updateCameraFabVisibility() {
    if (!mounted || !_scrollController.hasClients) return;

    final truck = _truck;
    if (truck == null || !truck.isEditable) return;

    final position = _scrollController.position;
    final distanceToBottom = position.maxScrollExtent - position.pixels;
    final nearCloseActions = distanceToBottom <= _closeActionsVisibilityThreshold;
    if (_showCameraFab == nearCloseActions) {
      setState(() => _showCameraFab = !nearCloseActions);
    }
  }

  void _requestScanFocus() {
    final truck = _truck;
    if (truck != null && truck.isEditable && mounted) {
      _scanFocusNode.requestFocus();
    }
  }

  void _showScanFeedback(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.warning : AppColors.tealDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<bool> _tryAddFromBarcode(String code) async {
    final normalized = _scanGuard.prepare(code);
    if (normalized == null || _isLookingUp) return false;

    final truck = _truck;
    if (truck == null || !truck.isEditable) return false;

    setState(() => _isLookingUp = true);

    try {
      final unit = await _controller.agregarBulto(widget.truckId, normalized);

      if (!mounted) return false;

      if (unit != null) {
        setState(() {});
        _showScanFeedback('${unit.code} agregado');
        _requestScanFocus();
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateCameraFabVisibility());
        return true;
      }

      _showScanFeedback(
        _controller.errorMessage ?? HuLookupService.notFoundMessage(normalized),
        isError: true,
      );
      return false;
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  Future<void> _finalizeScan() async {
    _scanDebounce?.cancel();
    final code = _scanController.text;
    _scanController.clear();
    await _tryAddFromBarcode(code);
    _requestScanFocus();
  }

  void _onScanFieldChanged(String value) {
    _scanDebounce?.cancel();
    if (value.contains('\n') || value.contains('\r')) {
      unawaited(_finalizeScan());
      return;
    }
    _scanDebounce = Timer(const Duration(milliseconds: 250), () {
      if (_scanController.text.trim().isNotEmpty) {
        unawaited(_finalizeScan());
      }
    });
  }

  Future<void> _onBarcodeSubmitted(String _) async {
    await _finalizeScan();
  }

  Future<void> _openCameraScan() async {
    if (!supportsBarcodeCamera) {
      await _scanHu();
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _CameraScanPage(
          onCodeScanned: (code) async {
            final added = await _tryAddFromBarcode(code);
            if (added && context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
    _requestScanFocus();
  }

  Future<void> _scanHu() async {
    final added = await context.push<bool>('/scan/${widget.truckId}');
    if (added == true && mounted) {
      setState(() {});
      _requestScanFocus();
    } else {
      _requestScanFocus();
    }
  }

  void _confirmCloseTruck(Truck truck, double occupancy, LoadValidation validation) {
    if (truck.handlingUnits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agregue al menos un HU antes de cerrar el camión'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (validation == LoadValidation.optimizada) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cerrar camión'),
          content: Text(
            'La carga está optimizada (${occupancy.toStringAsFixed(0)}% de ocupación). '
            'Se guardará el porcentaje para trazabilidad.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final ok = await _controller.closeTruck(
                  widget.truckId,
                  occupancyPercent: occupancy,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                setState(() {});
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Camión cerrado · ${occupancy.toStringAsFixed(0)}% guardado'),
                      backgroundColor: AppColors.purple,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (_controller.errorMessage != null) {
                  _showScanFeedback(_controller.errorMessage!, isError: true);
                }
              },
              child: const Text('Cerrar camión'),
            ),
          ],
        ),
      );
      return;
    }

    if (_controller.optimizationAlertWasSent(truck)) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cerrar camión'),
          content: Text(
            'La carga sigue sin optimizar (${occupancy.toStringAsFixed(0)}%), '
            'pero la alerta por email ya fue enviada. '
            'Podés cerrar el camión y marcarlo como enviado.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final ok = await _controller.closeTruck(
                  widget.truckId,
                  occupancyPercent: occupancy,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                setState(() {});
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Camión cerrado · ${occupancy.toStringAsFixed(0)}% guardado · listo para enviar',
                      ),
                      backgroundColor: AppColors.purple,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (_controller.errorMessage != null) {
                  _showScanFeedback(_controller.errorMessage!, isError: true);
                }
              },
              child: const Text('Cerrar camión'),
            ),
          ],
        ),
      );
      return;
    }

    final isExcess = validation == LoadValidation.excedida;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Camión no optimizado'),
        content: Text(
          isExcess
              ? 'La carga excede la capacidad (${occupancy.toStringAsFixed(0)}%). '
                  'Se enviará una alerta por email a los representantes.'
              : 'Ocupación inferior al 80% (${occupancy.toStringAsFixed(0)}%). '
                  'Se enviará una alerta por email a los representantes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final ok = await _controller.closeTruck(
                widget.truckId,
                occupancyPercent: occupancy,
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              if (!mounted) return;
              setState(() {});
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alerta enviada · Camión en PENDIENTE'),
                    backgroundColor: AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (_controller.errorMessage != null) {
                _showScanFeedback(_controller.errorMessage!, isError: true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Cerrar camión'),
          ),
        ],
      ),
    );
  }

  void _confirmReopen(Truck truck) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reanudar camión'),
        content: Text(
          '¿Reabrir el viaje ${truck.tripNumber} para escanear o eliminar bultos?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final ok = await _controller.reopenTruck(widget.truckId);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (!mounted) return;
              setState(() {});
              if (ok) {
                _requestScanFocus();
              } else if (_controller.errorMessage != null) {
                _showScanFeedback(_controller.errorMessage!, isError: true);
              }
            },
            child: const Text('Reanudar camión'),
          ),
        ],
      ),
    );
  }

  void _confirmSend(Truck truck) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Marcar como enviado'),
        content: Text(
          '¿Confirmar envío del viaje ${truck.tripNumber}? '
          'Ocupación: ${truck.savedOccupancyPercent?.toStringAsFixed(0)}%.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final ok = await _controller.markAsSent(widget.truckId);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (!mounted) return;
              setState(() {});
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Camión marcado como ENVIADO'),
                    backgroundColor: AppColors.purple,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (_controller.errorMessage != null) {
                _showScanFeedback(_controller.errorMessage!, isError: true);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final truck = _truck;
    if (truck == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camión')),
        body: const Center(child: Text('Camión no encontrado')),
      );
    }

    final isEditable = truck.isEditable;
    final vehicle = truck.recommendedVehicle(vehicleTypes);
    final validation = truck.validateLoad(vehicleTypes);
    final optimizationAlertAlreadySent = _controller.optimizationAlertWasSent(truck);
    final occupancy = truck.occupancyPercent(vehicle);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final createdLabel = truck.createdAt != null
        ? dateFormat.format(truck.createdAt!)
        : '—';
    final formatter = UnitFormatter(DisplaySettingsScope.of(context).settings);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusBadge(status: truck.status),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(20, 100, 20, isEditable && _showCameraFab ? 96 : 32),
        children: [
          _TripHeader(
            tripNumber: truck.tripNumber,
            destination: truck.destination,
            origen: truck.origen,
            createdLabel: createdLabel,
            observations: truck.observations,
          ),
          if (truck.status == TruckStatus.pendiente && truck.alertEmailSent) ...[
            const SizedBox(height: 16),
            _EmailAlertBanner(),
          ],
          if (isEditable && optimizationAlertAlreadySent) ...[
            const SizedBox(height: 16),
            _EmailAlertResumedBanner(),
          ],
          if (truck.savedOccupancyPercent != null) ...[
            const SizedBox(height: 16),
            _TraceabilityCard(percent: truck.savedOccupancyPercent!),
          ],
          if (isEditable) ...[
            const SizedBox(height: 16),
            LoadAlertBanner(
              validation: validation,
              optimizationAlertAlreadySent: optimizationAlertAlreadySent,
            ),
          ],
          const SizedBox(height: 16),
          if (vehicle != null) ...[
            VehicleRecommendationCard(vehicle: vehicle),
            const SizedBox(height: 12),
            OccupancyGauge(
              percent: isEditable ? occupancy : (truck.savedOccupancyPercent ?? occupancy),
              volumeUsed: truck.totalVolume,
              volumeCapacity: vehicle.volumeM3,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              StatChip(
                icon: Icons.inventory_2_outlined,
                label: 'HU',
                value: '${truck.huCount}',
                accent: AppColors.purple,
              ),
              const SizedBox(width: 10),
              StatChip(
                icon: Icons.scale_outlined,
                label: 'Peso',
                value: '${truck.totalWeight.toStringAsFixed(0)} kg',
                accent: AppColors.teal,
              ),
              const SizedBox(width: 10),
              StatChip(
                icon: Icons.view_in_ar_outlined,
                label: 'Volumen',
                value: formatter.formatVolume(truck.totalVolume),
                accent: AppColors.tealDark,
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionLabel(
            title: 'Bultos',
            count: truck.huCount,
            trailing: isEditable
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (supportsBarcodeCamera)
                        IconButton(
                          onPressed: _openCameraScan,
                          tooltip: 'Escanear con cámara',
                          icon: const Icon(Icons.photo_camera_outlined, size: 22),
                          color: AppColors.teal,
                          visualDensity: VisualDensity.compact,
                        ),
                      TextButton.icon(
                        onPressed: _scanHu,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: const Text('Escanear'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.teal,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          if (truck.handlingUnits.isEmpty)
            ModernSurface(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.purpleLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 28,
                      color: AppColors.purple.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Sin bultos escaneados', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'Escanee con cámara, pistola lectora o el botón Escanear',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...truck.handlingUnits.map(
              (unit) => HuListTile(
                unit: unit,
                canDelete: isEditable,
                onDelete: () async {
                  final ok = await _controller.removeHandlingUnit(widget.truckId, unit.code);
                  if (!mounted) return;
                  if (ok) {
                    setState(() {});
                    WidgetsBinding.instance.addPostFrameCallback((_) => _updateCameraFabVisibility());
                  } else if (_controller.errorMessage != null) {
                    _showScanFeedback(_controller.errorMessage!, isError: true);
                  }
                },
              ),
            ),
          const SizedBox(height: 32),
          _buildScrollActions(truck, occupancy, validation),
        ],
      ),
          if (isEditable)
            Opacity(
              opacity: 0,
              child: SizedBox(
                width: 1,
                height: 1,
                child: TextField(
                  controller: _scanController,
                  focusNode: _scanFocusNode,
                  enableSuggestions: false,
                  autocorrect: false,
                  enableInteractiveSelection: false,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: _onScanFieldChanged,
                  onSubmitted: _onBarcodeSubmitted,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isEditable && _showCameraFab
          ? FloatingActionButton.extended(
              onPressed: supportsBarcodeCamera ? _openCameraScan : _scanHu,
              elevation: 6,
              icon: Icon(supportsBarcodeCamera ? Icons.photo_camera_outlined : Icons.qr_code_scanner_rounded),
              label: Text(supportsBarcodeCamera ? 'Cámara' : 'Escanear'),
            )
          : null,
    );
  }

  Widget _buildScrollActions(Truck truck, double occupancy, LoadValidation validation) {
    switch (truck.status) {
      case TruckStatus.abierto:
        return Column(
          children: [
            const Divider(height: 1),
            const SizedBox(height: 24),
            Text(
              'Revisá todos los bultos antes de cerrar',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => _confirmCloseTruck(truck, occupancy, validation),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                backgroundColor: AppColors.purple,
              ),
              child: const Text('CERRAR CAMIÓN'),
            ),
            const SizedBox(height: 16),
          ],
        );
      case TruckStatus.pendiente:
        return OutlinedButton(
          onPressed: () => _confirmReopen(truck),
          child: const Text('REANUDAR CAMIÓN'),
        );
      case TruckStatus.cerrado:
        return Column(
          children: [
            FilledButton(
              onPressed: () => _confirmSend(truck),
              child: const Text('MARCAR COMO ENVIADO'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _confirmReopen(truck),
              child: const Text('REANUDAR CAMIÓN'),
            ),
          ],
        );
      case TruckStatus.enviado:
        return const SizedBox.shrink();
    }
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({
    required this.tripNumber,
    required this.destination,
    required this.origen,
    required this.createdLabel,
    this.observations,
  });

  final String tripNumber;
  final String destination;
  final String origen;
  final String createdLabel;
  final String? observations;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple,
            AppColors.purpleDark,
            AppColors.teal.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tripNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            destination,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(icon: Icons.warehouse_outlined, label: origen),
              _HeaderChip(icon: Icons.calendar_today_outlined, label: createdLabel),
              if (observations != null)
                _HeaderChip(icon: Icons.notes_outlined, label: observations!),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailAlertBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ModernSurface(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      child: const Row(
        children: [
          Icon(Icons.mail_outline_rounded, color: AppColors.warning, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Alerta enviada por email. Reanudá el camión para ajustar la carga.',
              style: TextStyle(fontSize: 13, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailAlertResumedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ModernSurface(
      padding: const EdgeInsets.all(14),
      color: AppColors.purpleLight.withValues(alpha: 0.5),
      border: Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.purple, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Alerta de optimización ya enviada. Podés cerrar y enviar aunque la carga no esté optimizada.',
              style: TextStyle(fontSize: 13, color: AppColors.purpleDark, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceabilityCard extends StatelessWidget {
  const _TraceabilityCard({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return ModernSurface(
      padding: const EdgeInsets.all(14),
      color: AppColors.purpleLight.withValues(alpha: 0.5),
      border: Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppColors.purple, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Trazabilidad · ${percent.toStringAsFixed(1)}% al cierre',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.purpleDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraScanPage extends StatelessWidget {
  const _CameraScanPage({required this.onCodeScanned});

  final Future<void> Function(String code) onCodeScanned;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D26),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Escanear con cámara'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: BarcodeCameraScanner(onCodeScanned: onCodeScanned),
              ),
              const SizedBox(height: 16),
              Text(
                'Apunte al código de barras del bulto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TruckScope extends InheritedNotifier<TruckController> {
  const TruckScope({
    super.key,
    required TruckController super.notifier,
    required super.child,
  });

  static TruckController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TruckScope>();
    assert(scope != null, 'TruckScope not found');
    return scope!.notifier!;
  }
}
