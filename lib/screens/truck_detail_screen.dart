import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:voxel_truck/data/mock_data.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/state/truck_controller.dart';
import 'package:voxel_truck/theme/app_colors.dart';
import 'package:voxel_truck/widgets/common_widgets.dart';
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
          title: const Text('Cerrar camión'),
          content: Text(
            'La carga está optimizada (${occupancy.toStringAsFixed(0)}% de ocupación). '
            'Se guardará el porcentaje para trazabilidad.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                _controller.closeTruck(widget.truckId, occupancyPercent: occupancy);
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Camión cerrado · ${occupancy.toStringAsFixed(0)}% guardado',
                    ),
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
        title: const Text('Camión no optimizado'),
        content: Text(
          isExcess
              ? 'La carga excede la capacidad del vehículo (${occupancy.toStringAsFixed(0)}%). '
                  'Se enviará una alerta por email a los representantes.'
              : 'La ocupación es inferior al 80% de la capacidad (${occupancy.toStringAsFixed(0)}%). '
                  'Se enviará una alerta por email a los representantes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              _controller.closeTruck(widget.truckId, occupancyPercent: occupancy);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Alerta enviada por email · Camión en PENDIENTE'),
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
        title: const Text('Reanudar camión'),
        content: Text(
          '¿Desea reabrir el viaje ${truck.tripNumber} para escanear o eliminar bultos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
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
        title: const Text('Marcar como enviado'),
        content: Text(
          '¿Confirmar envío del viaje ${truck.tripNumber}? '
          'Ocupación registrada: ${truck.savedOccupancyPercent?.toStringAsFixed(0)}%.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
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
      appBar: AppBar(
        title: Text(truck.tripNumber),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          StatusBadge(status: truck.status),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.warehouse_outlined,
                    label: 'Centro',
                    value: truck.logisticsCenter,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.place_outlined,
                    label: 'Destino',
                    value: truck.destination,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Fecha',
                    value: dateFormat.format(truck.date),
                  ),
                  if (truck.observations != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.notes_outlined,
                      label: 'Obs.',
                      value: truck.observations!,
                    ),
                  ],
                ],
              ),
            ),
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
              const SizedBox(width: 8),
              StatChip(
                icon: Icons.scale_outlined,
                label: 'Peso',
                value: '${truck.totalWeight.toStringAsFixed(0)} kg',
                accent: AppColors.teal,
              ),
              const SizedBox(width: 8),
              StatChip(
                icon: Icons.view_in_ar_outlined,
                label: 'Volumen',
                value: '${truck.totalVolume.toStringAsFixed(1)} m³',
                accent: AppColors.tealDark,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bultos (${truck.huCount})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              if (isEditable)
                TextButton.icon(
                  onPressed: _scanHu,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Escanear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (truck.handlingUnits.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 48,
                      color: AppColors.purple.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sin bultos escaneados',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Escanee HU, pallets o bultos',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
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
        ],
      ),
      bottomNavigationBar: _buildBottomBar(truck, occupancy, validation),
      floatingActionButton: isEditable
          ? FloatingActionButton(
              onPressed: _scanHu,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget? _buildBottomBar(Truck truck, double occupancy, LoadValidation validation) {
    switch (truck.status) {
      case TruckStatus.abierto:
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _scanHu,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear HU'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _confirmCloseTruck(truck, occupancy, validation),
                  child: const Text('CERRAR CAMIÓN'),
                ),
              ],
            ),
          ),
        );
      case TruckStatus.pendiente:
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton(
              onPressed: () => _confirmReopen(truck),
              child: const Text('REANUDAR CAMIÓN'),
            ),
          ),
        );
      case TruckStatus.cerrado:
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
            ),
          ),
        );
      case TruckStatus.enviado:
        return null;
    }
  }
}

class _EmailAlertBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.mail_outline, color: AppColors.warning),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alerta enviada',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
                Text(
                  'Se notificó por email a los representantes. Reanude el camión para ajustar la carga.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.purpleLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppColors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trazabilidad',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.purpleDark,
                  ),
                ),
                Text(
                  'Ocupación registrada al cierre: ${percent.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
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
