import 'package:flutter/foundation.dart';
import 'package:voxel_truck/data/mock_data.dart';
import 'package:voxel_truck/models/truck.dart';

class TruckController extends ChangeNotifier {
  TruckController() : _trucks = List.from(sampleTrucks);

  final List<Truck> _trucks;

  List<Truck> get trucks => List.unmodifiable(_trucks);

  Truck? findById(String id) {
    try {
      return _trucks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  void addTruck(Truck truck) {
    _trucks.insert(0, truck);
    notifyListeners();
  }

  void addHandlingUnit(String truckId, HandlingUnit unit) {
    final truck = findById(truckId);
    if (truck == null || !truck.isEditable) return;
    if (truck.handlingUnits.any((h) => h.code == unit.code)) return;
    truck.handlingUnits.add(unit);
    notifyListeners();
  }

  void removeHandlingUnit(String truckId, String code) {
    final truck = findById(truckId);
    if (truck == null || !truck.isEditable) return;
    truck.handlingUnits.removeWhere((h) => h.code == code);
    notifyListeners();
  }

  void closeTruck(String truckId, {required double occupancyPercent}) {
    final truck = findById(truckId);
    if (truck == null || truck.status != TruckStatus.abierto) return;

    if (truck.isOptimized(vehicleTypes)) {
      truck.status = TruckStatus.cerrado;
      truck.savedOccupancyPercent = occupancyPercent;
      truck.closedAt = DateTime.now();
      truck.alertEmailSent = false;
    } else {
      truck.status = TruckStatus.pendiente;
      truck.savedOccupancyPercent = null;
      truck.closedAt = DateTime.now();
      truck.alertEmailSent = true;
    }
    notifyListeners();
  }

  void reopenTruck(String truckId) {
    final truck = findById(truckId);
    if (truck == null) return;
    if (truck.status != TruckStatus.pendiente && truck.status != TruckStatus.cerrado) {
      return;
    }

    truck.status = TruckStatus.abierto;
    truck.savedOccupancyPercent = null;
    truck.closedAt = null;
    truck.alertEmailSent = false;
    notifyListeners();
  }

  void markAsSent(String truckId) {
    final truck = findById(truckId);
    if (truck == null || truck.status != TruckStatus.cerrado) return;
    truck.status = TruckStatus.enviado;
    notifyListeners();
  }
}
