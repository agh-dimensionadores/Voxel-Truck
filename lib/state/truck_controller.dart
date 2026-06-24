import 'package:flutter/foundation.dart';
import 'package:voxel_truck/config/app_config.dart';
import 'package:voxel_truck/data/mock_data.dart';
import 'package:voxel_truck/models/truck.dart';
import 'package:voxel_truck/services/voxel_truck_api.dart';
import 'package:voxel_truck/utils/device_id.dart';

class TruckController extends ChangeNotifier {
  TruckController({VoxelTruckApi? api}) : _api = api ?? VoxelTruckApi() {
    if (!AppConfig.isApiConfigured) {
      _trucks.addAll(sampleTrucks);
    }
  }

  final VoxelTruckApi _api;
  final List<Truck> _trucks = [];
  final Set<String> _optimizationAlertAcknowledgedIds = {};

  bool isLoading = false;
  String? errorMessage;

  List<Truck> get trucks => List.unmodifiable(_trucks);

  bool get usesApi => AppConfig.isApiConfigured;

  Truck? findById(String id) {
    try {
      return _trucks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  /// True si ya se envió la alerta por falta de optimización (persiste tras reabrir).
  bool optimizationAlertWasSent(Truck truck) =>
      truck.alertEmailSent || _optimizationAlertAcknowledgedIds.contains(truck.id);

  Future<void> loadCamiones() async {
    if (!usesApi) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final camiones = await _api.listCamiones();
      _trucks
        ..clear()
        ..addAll(camiones);
      for (final camion in camiones) {
        _trackOptimizationAlertFromApi(camion);
      }
    } on VoxelTruckApiException catch (error) {
      errorMessage = error.message;
    } catch (error) {
      errorMessage = 'Error al cargar camiones: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Truck?> refreshCamion(String id) async {
    if (!usesApi) return findById(id);

    try {
      final camion = await _api.getCamion(id);
      _replaceTruck(camion);
      _trackOptimizationAlertFromApi(camion);
      notifyListeners();
      return camion;
    } on VoxelTruckApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return findById(id);
    } catch (error) {
      errorMessage = 'Error al actualizar camión: $error';
      notifyListeners();
      return findById(id);
    }
  }

  Future<Truck?> createCamion({
    required String numeroViaje,
    required String origen,
    required String destino,
    String? observaciones,
    String? creadoPor,
  }) async {
    if (!usesApi) {
      final truck = Truck(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tripNumber: numeroViaje,
        origen: origen,
        destination: destino,
        observations: observaciones,
        createdAt: DateTime.now(),
      );
      _trucks.insert(0, truck);
      notifyListeners();
      return truck;
    }

    errorMessage = null;
    notifyListeners();

    try {
      final idDispositivo = await DeviceId.get();
      final truck = await _api.createCamion(
        numeroViaje: numeroViaje,
        origen: origen,
        destino: destino,
        observaciones: observaciones,
        creadoPor: creadoPor,
        idDispositivo: idDispositivo,
      );
      _trucks.insert(0, truck);
      notifyListeners();
      return truck;
    } on VoxelTruckApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return null;
    } catch (error) {
      errorMessage = 'Error al crear camión: $error';
      notifyListeners();
      return null;
    }
  }

  Future<HandlingUnit?> agregarBulto(String truckId, String code) async {
    final truck = findById(truckId);
    if (truck == null || !truck.isEditable) return null;

    final normalized = code.trim();
    if (normalized.isEmpty) return null;

    if (!usesApi) {
      return _agregarBultoLocal(truckId, normalized);
    }

    errorMessage = null;

    try {
      final unit = await _api.agregarBulto(truckId, normalized);
      await refreshCamion(truckId);
      return unit;
    } on VoxelTruckApiException catch (error) {
      errorMessage = _mensajeAgregarBulto(error, normalized);
      notifyListeners();
      return null;
    } catch (error) {
      errorMessage = 'Error al agregar HU: $error';
      notifyListeners();
      return null;
    }
  }

  Future<bool> removeHandlingUnit(String truckId, String code) async {
    final truck = findById(truckId);
    if (truck == null || !truck.isEditable) return false;

    if (!usesApi) {
      truck.handlingUnits.removeWhere((h) => h.code == code);
      notifyListeners();
      return true;
    }

    try {
      await _api.eliminarBulto(truckId, code);
      await refreshCamion(truckId);
      return true;
    } on VoxelTruckApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (error) {
      errorMessage = 'Error al eliminar HU: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> closeTruck(String truckId, {required double occupancyPercent}) async {
    final truck = findById(truckId);
    if (truck == null || truck.status != TruckStatus.abierto) return false;

    final vehicle = truck.recommendedVehicle(vehicleTypes);
    final closePlan = _resolveClosePlan(truck, occupancyPercent);

    if (!usesApi) {
      _cerrarCamionLocal(truck, closePlan);
      if (closePlan.sendOptimizationAlert) {
        _optimizationAlertAcknowledgedIds.add(truck.id);
      }
      notifyListeners();
      return true;
    }

    try {
      final updated = await _api.cerrarCamion(
        truckId,
        estado: closePlan.apiEstado,
        porcentajeOcupacion: closePlan.occupancyPercent,
        tipoVehiculo: vehicle?.name,
        alertaEmailEnviada: closePlan.alertaEmailEnviada,
      );
      _replaceTruck(updated);
      if (closePlan.sendOptimizationAlert) {
        _optimizationAlertAcknowledgedIds.add(truckId);
      }
      notifyListeners();
      return true;
    } on VoxelTruckApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (error) {
      errorMessage = 'Error al cerrar camión: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> reopenTruck(String truckId) async {
    final truck = findById(truckId);
    if (truck == null) return false;
    if (truck.status != TruckStatus.pendiente && truck.status != TruckStatus.cerrado) {
      return false;
    }

    if (!usesApi) {
      truck.status = TruckStatus.abierto;
      truck.savedOccupancyPercent = null;
      truck.closedAt = null;
      notifyListeners();
      return true;
    }

    try {
      final updated = await _api.reabrirCamion(truckId);
      _replaceTruck(updated);
      if (optimizationAlertWasSent(truck)) {
        _optimizationAlertAcknowledgedIds.add(truckId);
      }
      notifyListeners();
      return true;
    } on VoxelTruckApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (error) {
      errorMessage = 'Error al reabrir camión: $error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsSent(String truckId) async {
    final truck = findById(truckId);
    if (truck == null || truck.status != TruckStatus.cerrado) return false;

    if (!usesApi) {
      truck.status = TruckStatus.enviado;
      notifyListeners();
      return true;
    }

    try {
      final updated = await _api.enviarCamion(truckId);
      _replaceTruck(updated);
      notifyListeners();
      return true;
    } on VoxelTruckApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (error) {
      errorMessage = 'Error al marcar enviado: $error';
      notifyListeners();
      return false;
    }
  }

  HandlingUnit? _agregarBultoLocal(String truckId, String normalized) {
    final truck = findById(truckId);
    if (truck == null) return null;

    final lookupKey = normalized.toUpperCase();
    final unit = mockHuDatabase[lookupKey];
    if (unit == null) {
      errorMessage = 'No se encontró el escaneo: $lookupKey';
      notifyListeners();
      return null;
    }

    if (truck.handlingUnits.any((h) => h.code.toUpperCase() == lookupKey)) {
      errorMessage = '$lookupKey ya está en el camión';
      notifyListeners();
      return null;
    }

    truck.handlingUnits.add(unit);
    notifyListeners();
    return unit;
  }

  void _cerrarCamionLocal(Truck truck, _ClosePlan plan) {
    truck.status = plan.status;
    truck.savedOccupancyPercent = plan.occupancyPercent;
    truck.closedAt = DateTime.now();
    if (plan.sendOptimizationAlert) {
      truck.alertEmailSent = true;
    } else if (plan.status == TruckStatus.cerrado && !plan.alertaEmailEnviada) {
      truck.alertEmailSent = false;
    }
  }

  void _trackOptimizationAlertFromApi(Truck truck) {
    if (truck.alertEmailSent) {
      _optimizationAlertAcknowledgedIds.add(truck.id);
    }
  }

  _ClosePlan _resolveClosePlan(Truck truck, double occupancyPercent) {
    final isOptimized = truck.isOptimized(vehicleTypes);
    if (isOptimized) {
      return _ClosePlan(
        status: TruckStatus.cerrado,
        apiEstado: 'cerrado',
        occupancyPercent: occupancyPercent,
        alertaEmailEnviada: false,
        sendOptimizationAlert: false,
      );
    }

    if (optimizationAlertWasSent(truck)) {
      return _ClosePlan(
        status: TruckStatus.cerrado,
        apiEstado: 'cerrado',
        occupancyPercent: occupancyPercent,
        alertaEmailEnviada: true,
        sendOptimizationAlert: false,
      );
    }

    return _ClosePlan(
      status: TruckStatus.pendiente,
      apiEstado: 'pendiente',
      occupancyPercent: null,
      alertaEmailEnviada: true,
      sendOptimizationAlert: true,
    );
  }

  void _replaceTruck(Truck updated) {
    final index = _trucks.indexWhere((t) => t.id == updated.id);
    if (index >= 0) {
      _trucks[index] = updated;
    } else {
      _trucks.insert(0, updated);
    }
  }

  String _mensajeAgregarBulto(VoxelTruckApiException error, String code) {
    if (error.statusCode == 409) {
      final detail = error.detail;
      final viaje = detail?['numero_viaje']?.toString();
      if (viaje != null && viaje.isNotEmpty) {
        return '$code ya está en el camión $viaje';
      }
      return error.message;
    }
    if (error.statusCode == 404) {
      return 'No se encontró el escaneo: $code';
    }
    return error.message;
  }
}

class _ClosePlan {
  const _ClosePlan({
    required this.status,
    required this.apiEstado,
    required this.occupancyPercent,
    required this.alertaEmailEnviada,
    required this.sendOptimizationAlert,
  });

  final TruckStatus status;
  final String apiEstado;
  final double? occupancyPercent;
  final bool alertaEmailEnviada;
  final bool sendOptimizationAlert;
}
