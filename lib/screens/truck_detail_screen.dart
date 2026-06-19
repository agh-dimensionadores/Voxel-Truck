import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:voxel_truck/data/mock_data.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/state/truck_controller.dart';
import 'package:voxel_truck/theme/app_colors.dart';
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
  TruckController get _controller => TruckScope.of(context);

  Truck? get _truck => _controller.findById(widget.truckId);

  Future<void> _scanHu() async {
    final unit = await context.push<HandlingUnit>('/scan/${widget.truckId}');
    if (unit != null && mounted) {
      _controller.addHandlingUnit(widget.truckId, unit);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${unit.code} agregado'),
          backgroundColor: AppColors.tealDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
              onPressed: () {
                _controller.closeTruck(widget.truckId, occupancyPercent: occupancy);
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Camión cerrado · ${occupancy.toStringAsFixed(0)}% guardado'),
                    backgroundColor: AppColors.purple,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
            onPressed: () {
              _controller.closeTruck(widget.truckId, occupancyPercent: occupancy);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Alerta enviada · Camión en PENDIENTE'),
                  backgroundColor: AppColors.warning,
                  behavior: SnackBarBehavior.floating,
                ),
              );
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
            onPressed: () {
              _controller.reopenTruck(widget.truckId);
              Navigator.pop(context);
              setState(() {});
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
            onPressed: () {
              _controller.markAsSent(widget.truckId);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Camión marcado como ENVIADO'),
                  backgroundColor: AppColors.purple,
                  behavior: SnackBarBehavior.floating,
                ),
              );
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
    final occupancy = truck.occupancyPercent(vehicle);
    final dateFormat = DateFormat('dd/MM/yyyy');

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 100, 20, 32),
        children: [
          _TripHeader(
            tripNumber: truck.tripNumber,
            destination: truck.destination,
            logisticsCenter: truck.logisticsCenter,
            date: dateFormat.format(truck.date),
            observations: truck.observations,
          ),
          if (truck.status == TruckStatus.pendiente && truck.alertEmailSent) ...[
            const SizedBox(height: 16),
            _EmailAlertBanner(),
          ],
          if (truck.savedOccupancyPercent != null) ...[
            const SizedBox(height: 16),
            _TraceabilityCard(percent: truck.savedOccupancyPercent!),
          ],
          if (isEditable) ...[
            const SizedBox(height: 16),
            LoadAlertBanner(validation: validation),
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
                value: '${truck.totalVolume.toStringAsFixed(1)} m³',
                accent: AppColors.tealDark,
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionLabel(
            title: 'Bultos',
            count: truck.huCount,
            trailing: isEditable
                ? TextButton.icon(
                    onPressed: _scanHu,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Escanear'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      visualDensity: VisualDensity.compact,
                    ),
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
                    'Use el botón de escaneo para agregar HU',
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
                onDelete: () {
                  _controller.removeHandlingUnit(widget.truckId, unit.code);
                  setState(() {});
                },
              ),
            ),
          const SizedBox(height: 32),
          _buildScrollActions(truck, occupancy, validation),
        ],
      ),
      floatingActionButton: isEditable
          ? FloatingActionButton.extended(
              onPressed: _scanHu,
              elevation: 6,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Escanear'),
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
    required this.logisticsCenter,
    required this.date,
    this.observations,
  });

  final String tripNumber;
  final String destination;
  final String logisticsCenter;
  final String date;
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
              _HeaderChip(icon: Icons.warehouse_outlined, label: logisticsCenter),
              _HeaderChip(icon: Icons.calendar_today_outlined, label: date),
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
