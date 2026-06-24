import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/screens/truck_detail_screen.dart';
import 'package:voxel_truck/theme/app_colors.dart';

class CreateTruckScreen extends StatefulWidget {
  const CreateTruckScreen({super.key});

  @override
  State<CreateTruckScreen> createState() => _CreateTruckScreenState();
}

class _CreateTruckScreenState extends State<CreateTruckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tripController = TextEditingController();
  final _observationsController = TextEditingController();

  String _origen = 'CD Santiago Norte';
  String _destination = '';
  bool _isSubmitting = false;

  static const _centers = [
    'CD Santiago Norte',
    'CD Santiago Sur',
    'CD Valparaíso',
    'CD Concepción',
  ];

  @override
  void dispose() {
    _tripController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final controller = TruckScope.of(context);
    final truck = await controller.createCamion(
      numeroViaje: _tripController.text.trim(),
      origen: _origen,
      destino: _destination.trim(),
      observaciones: _observationsController.text.trim().isEmpty
          ? null
          : _observationsController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (truck != null) {
      context.pop(truck);
      return;
    }

    final message = controller.errorMessage ?? 'No se pudo crear el camión';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo camión'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isSubmitting ? null : () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.purpleLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.purple),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El camión se creará con estado ABIERTO para comenzar a escanear HU.',
                      style: TextStyle(fontSize: 13, color: AppColors.purpleDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _tripController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Número de viaje *',
                hintText: 'Ej: VT-2026-0144',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingrese el número de viaje' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _origen,
              decoration: const InputDecoration(
                labelText: 'Origen *',
                prefixIcon: Icon(Icons.warehouse_outlined),
              ),
              items: _centers
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: _isSubmitting ? null : (v) => setState(() => _origen = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Destino *',
                hintText: 'Ej: Concepción',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              onChanged: (v) => _destination = v,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingrese el destino' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _observationsController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                hintText: 'Opcional',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Crear camión'),
            ),
          ],
        ),
      ),
    );
  }
}
