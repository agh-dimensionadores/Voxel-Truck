import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:voxel_truck/models/truck.dart';
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

  String _logisticsCenter = 'CD Santiago Norte';
  String _destination = '';
  DateTime _date = DateTime.now();

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.purple,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final truck = Truck(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tripNumber: _tripController.text.trim(),
      logisticsCenter: _logisticsCenter,
      destination: _destination.trim(),
      date: _date,
      observations: _observationsController.text.trim().isEmpty
          ? null
          : _observationsController.text.trim(),
    );

    context.pop(truck);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo camión'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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
              initialValue: _logisticsCenter,
              decoration: const InputDecoration(
                labelText: 'Centro logístico *',
                prefixIcon: Icon(Icons.warehouse_outlined),
              ),
              items: _centers
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _logisticsCenter = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
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
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha *',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(dateFormat.format(_date)),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _observationsController,
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                hintText: 'Opcional',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submit,
              child: const Text('Crear camión'),
            ),
          ],
        ),
      ),
    );
  }
}
