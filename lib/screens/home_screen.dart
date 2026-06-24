import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voxel_truck/config/app_config.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/screens/truck_detail_screen.dart';
import 'package:voxel_truck/theme/app_colors.dart';
import 'package:voxel_truck/widgets/common_widgets.dart';
import 'package:voxel_truck/widgets/modern_surface.dart';
import 'package:voxel_truck/widgets/truck_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TruckScope.of(context).loadCamiones();
    });
  }

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
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: controller.loadCamiones,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: VoxelLogo(height: 48),
                              ),
                              IconButton(
                                onPressed: () => context.push('/settings'),
                                tooltip: 'Configuración',
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                                  ),
                                  child: const Icon(Icons.settings_outlined, size: 22, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Camiones',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.usesApi
                                ? '${controller.trucks.length} viajes · sincronizado con servidor'
                                : '${controller.trucks.length} viajes · modo demo',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                          if (!AppConfig.isApiConfigured) ...[
                            const SizedBox(height: 12),
                            const _DemoBanner(),
                          ],
                          if (controller.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _ErrorBanner(
                              message: controller.errorMessage!,
                              onDismiss: controller.clearError,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (controller.isLoading && controller.trucks.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    ..._buildSection(context, title: 'Abiertos', trucks: openTrucks),
                    ..._buildSection(context, title: 'Pendientes', trucks: pendingTrucks),
                    ..._buildSection(context, title: 'Listos para envío', trucks: closedTrucks),
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
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final truck = await context.push<Truck>('/create');
              if (truck != null && context.mounted) {
                context.push('/truck/${truck.id}');
              }
            },
            elevation: 6,
            icon: const Icon(Icons.add_rounded),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: SectionLabel(title: title, count: trucks.length),
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

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return ModernSurface(
      padding: const EdgeInsets.all(12),
      color: AppColors.purpleLight.withValues(alpha: 0.5),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.purple, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo demo: datos locales. Configurá la API para sincronizar con el servidor.',
              style: TextStyle(fontSize: 12, color: AppColors.purpleDark, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ModernSurface(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFFEE2E2).withValues(alpha: 0.7),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18, color: AppColors.error),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
