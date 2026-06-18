import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voxel_truck/screens/create_truck_screen.dart';
import 'package:voxel_truck/screens/home_screen.dart';
import 'package:voxel_truck/screens/scan_screen.dart';
import 'package:voxel_truck/screens/truck_detail_screen.dart';
import 'package:voxel_truck/state/truck_controller.dart';
import 'package:voxel_truck/theme/app_theme.dart';
import 'package:voxel_truck/widgets/common_widgets.dart';

class VoxelTruckApp extends StatefulWidget {
  const VoxelTruckApp({super.key});

  @override
  State<VoxelTruckApp> createState() => _VoxelTruckAppState();
}

class _VoxelTruckAppState extends State<VoxelTruckApp> {
  late final TruckController _controller;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _controller = TruckController();
    _router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/create',
          builder: (context, state) => const CreateTruckScreen(),
        ),
        GoRoute(
          path: '/truck/:id',
          builder: (context, state) =>
              TruckDetailScreen(truckId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/scan/:truckId',
          builder: (context, state) =>
              ScanScreen(truckId: state.pathParameters['truckId']!),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TruckScope(
      notifier: _controller,
      child: MaterialApp.router(
        title: 'Voxel Truck',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
        builder: (context, child) {
          return MobileShell(child: child ?? const SizedBox.shrink());
        },
      ),
    );
  }
}
