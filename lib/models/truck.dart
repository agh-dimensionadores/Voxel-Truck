enum TruckStatus { abierto, pendiente, cerrado, enviado }

enum LoadValidation { optimizada, subutilizada, excedida }

enum DimensionSource { voxelCam, coresa, manual }

const double kOptimizedOccupancyMin = 80;

class HandlingUnit {
  const HandlingUnit({
    required this.code,
    required this.length,
    required this.width,
    required this.height,
    required this.weight,
    required this.source,
  });

  final String code;
  final double length;
  final double width;
  final double height;
  final double weight;
  final DimensionSource source;

  double get volume => (length * width * height) / 1_000_000;
}

class VehicleType {
  const VehicleType({required this.name, required this.volumeM3});

  final String name;
  final double volumeM3;
}

class Truck {
  Truck({
    required this.id,
    required this.tripNumber,
    required this.logisticsCenter,
    required this.destination,
    required this.date,
    this.observations,
    this.status = TruckStatus.abierto,
    this.savedOccupancyPercent,
    this.closedAt,
    this.alertEmailSent = false,
    List<HandlingUnit>? handlingUnits,
  }) : handlingUnits = handlingUnits ?? [];

  final String id;
  final String tripNumber;
  final String logisticsCenter;
  final String destination;
  final DateTime date;
  final String? observations;
  TruckStatus status;
  double? savedOccupancyPercent;
  DateTime? closedAt;
  bool alertEmailSent;
  final List<HandlingUnit> handlingUnits;

  double get totalWeight => handlingUnits.fold(0, (sum, hu) => sum + hu.weight);

  double get totalVolume =>
      handlingUnits.fold(0, (sum, hu) => sum + hu.volume);

  int get huCount => handlingUnits.length;

  bool get isEditable => status == TruckStatus.abierto;

  VehicleType? recommendedVehicle(List<VehicleType> vehicles) {
    if (handlingUnits.isEmpty) return null;
    for (final vehicle in vehicles) {
      if (totalVolume <= vehicle.volumeM3) return vehicle;
    }
    return vehicles.last;
  }

  double occupancyPercent(VehicleType? vehicle) {
    if (vehicle == null || vehicle.volumeM3 == 0) return 0;
    return (totalVolume / vehicle.volumeM3 * 100).clamp(0, 150);
  }

  LoadValidation validateLoad(List<VehicleType> vehicles) {
    if (handlingUnits.isEmpty) return LoadValidation.subutilizada;

    final vehicle = recommendedVehicle(vehicles);
    if (vehicle == null) return LoadValidation.subutilizada;

    final percent = occupancyPercent(vehicle);
    if (percent > 100) return LoadValidation.excedida;
    if (percent < kOptimizedOccupancyMin) return LoadValidation.subutilizada;
    return LoadValidation.optimizada;
  }

  bool isOptimized(List<VehicleType> vehicles) =>
      validateLoad(vehicles) == LoadValidation.optimizada;
}
