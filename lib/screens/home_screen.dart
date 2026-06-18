import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/screens/truck_detail_screen.dart';
import 'package:voxel_truck/theme/app_colors.dart';
import 'package:voxel_truck/widgets/common_widgets.dart';
import 'package:voxel_truck/widgets/truck_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TruckScope.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final openTrucks =
            controller.trucks.where((t) => t.status == TruckStatus.abierto).toList();
        final pendingTrucks =
            controller.trucks.where((t) => t.status == TruckStatus.pendiente).toList();
        final closedTrucks =
            controller.trucks.where((t) => t.status == TruckStatus.cerrado).toList();
        final sentTrucks =
            controller.trucks.where((t) => t.status == TruckStatus.enviado).toList();

        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const VoxelLogo(height: 48),
                        const SizedBox(height: 20),
                        Text(
                          'Camiones',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Consolidación y despacho',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                ..._buildSection(
                  context,
                  title: 'Abiertos',
                  trucks: openTrucks,
                ),
                ..._buildSection(
                  context,
                  title: 'Pendientes',
                  trucks: pendingTrucks,
                ),
                ..._buildSection(
                  context,
                  title: 'Listos para envío',
                  trucks: closedTrucks,
                ),
                ..._buildSection(
                  context,
                  title: 'Enviados',
                  trucks: sentTrucks,
                  bottomPadding: 100,
                ),
                if (controller.trucks.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.border),
                          SizedBox(height: 16),
                          Text('No hay camiones creados'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final truck = await context.push<Truck>('/create');
              if (truck != null && context.mounted) {
                controller.addTruck(truck);
                context.push('/truck/${truck.id}');
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Nuevo camión'),
          ),
        );
      },
    );
  }

  List<Widget> _buildSection(
    BuildContext context, {
    required String title,
    required List<Truck> trucks,
    double bottomPadding = 0,
  }) {
    if (trucks.isEmpty) return [];

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => TruckListTile(
              truck: trucks[index],
              onTap: () => context.push('/truck/${trucks[index].id}'),
            ),
            childCount: trucks.length,
          ),
        ),
      ),
    ];
  }
}
