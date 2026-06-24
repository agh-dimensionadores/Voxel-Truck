import 'package:voxel_truck/utils/unit_formatter.dart';

enum TruckStatus { abierto, pendiente, cerrado, enviado }

enum LoadValidation { optimizada, subutilizada, excedida }

enum DimensionSource { voxelCam, coresa }

const double kOptimizedOccupancyMin = 80;

class HandlingUnit {
  const HandlingUnit({
    this.id,
    required this.code,
    required this.length,
    required this.width,
    required this.height,
    required this.weight,
    required this.source,
    this.explicitVolumeM3,
    this.cantidadBultos = 1,
    this.idRegistroOrigen = '',
  });

  final String? id;
  final String code;
  final double length;
  final double width;
  final double height;
  final double weight;
  final DimensionSource source;
  final double? explicitVolumeM3;
  final int cantidadBultos;
  final String idRegistroOrigen;

  bool get isLot => cantidadBultos > 1;

  int? get bundleCount => isLot ? cantidadBultos : null;

  double get volume {
    if (explicitVolumeM3 != null) return explicitVolumeM3!;
    if (length > 0 && width > 0 && height > 0) {
      return (length * width * height) / 1_000_000;
    }
    return 0;
  }

  factory HandlingUnit.fromApi(Map<String, dynamic> json) {
    final cantidad = _toInt(json['cantidad_bultos']);
    final fuente = json['fuente_dimensiones']?.toString();
    final source = fuente == 'coresa' ? DimensionSource.coresa : DimensionSource.voxelCam;
    final largo = _toDouble(json['largo_cm']) ?? 0;
    final ancho = _toDouble(json['ancho_cm']) ?? 0;
    final alto = _toDouble(json['alto_cm']) ?? 0;
    final volumenM3 = _toDouble(json['volumen_m3']) ?? 0;
    final useExplicitVolume = volumenM3 > 0 && (cantidad > 1 || largo == 0 || ancho == 0 || alto == 0);

    return HandlingUnit(
      id: json['id']?.toString(),
      code: json['codigo_hu']?.toString() ?? '',
      length: largo,
      width: ancho,
      height: alto,
      weight: _toDouble(json['peso_kg']) ?? 0,
      source: source,
      explicitVolumeM3: useExplicitVolume ? volumenM3 : null,
      cantidadBultos: cantidad > 0 ? cantidad : 1,
      idRegistroOrigen: _parseIdRegistroOrigen(json),
    );
  }

  factory HandlingUnit.fromVoxelCamApi(Map<String, dynamic> data, String scannedCode) {
    final largo = _dimensionCm(data, 'largo');
    final ancho = _dimensionCm(data, 'ancho');
    final alto = _dimensionCm(data, 'alto');
    final peso = _toDouble(data['peso']);
    final pesoTotal = _toDouble(data['peso_total']);
    final volumen = _toDouble(data['volumen']);
    final volumenTotal = _toDouble(data['volumen_total']);
    final cantidadBultos = _toInt(data['cantidad_bultos']);

    final weight = peso ?? pesoTotal ?? 0;
    final rawVolumeDm3 = volumenTotal ?? volumen;
    final explicitVolume =
        rawVolumeDm3 != null ? volumeDm3ToM3(rawVolumeDm3) : null;

    return HandlingUnit(
      code: scannedCode,
      length: largo,
      width: ancho,
      height: alto,
      weight: weight,
      source: DimensionSource.voxelCam,
      explicitVolumeM3: explicitVolume,
      cantidadBultos: cantidadBultos > 0 ? cantidadBultos : 1,
      idRegistroOrigen: _parseIdRegistroOrigen(data, fallbackCode: scannedCode),
    );
  }

  static String _parseIdRegistroOrigen(
    Map<String, dynamic> data, {
    String? fallbackCode,
  }) {
    for (final key in ['id_registro_origen', 'id_lote', 'id']) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallbackCode?.trim() ?? '';
  }

  static double _dimensionCm(Map<String, dynamic> data, String base) {
    final direct = _toDouble(data['${base}_cm']) ??
        _toDouble(data[base]) ??
        _toDouble(data[_englishDimensionKey(base)]);
    return direct ?? 0;
  }

  static String _englishDimensionKey(String base) => switch (base) {
        'largo' => 'length',
        'ancho' => 'width',
        'alto' => 'height',
        _ => base,
      };

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int _toInt(Object? value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
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
    required this.origen,
    required this.destination,
    this.observations,
    this.status = TruckStatus.abierto,
    this.savedOccupancyPercent,
    this.tipoVehiculo,
    this.closedAt,
    this.sentAt,
    this.createdAt,
    this.alertEmailSent = false,
    this.cachedCantidadHu,
    this.cachedPesoTotalKg,
    this.cachedVolumenTotalM3,
    List<HandlingUnit>? handlingUnits,
  }) : handlingUnits = handlingUnits ?? [];

  final String id;
  final String tripNumber;
  final String origen;
  final String destination;
  final String? observations;
  TruckStatus status;
  double? savedOccupancyPercent;
  String? tipoVehiculo;
  DateTime? closedAt;
  DateTime? sentAt;
  DateTime? createdAt;
  bool alertEmailSent;
  final int? cachedCantidadHu;
  final double? cachedPesoTotalKg;
  final double? cachedVolumenTotalM3;
  final List<HandlingUnit> handlingUnits;

  double get totalWeight => handlingUnits.isNotEmpty
      ? handlingUnits.fold(0.0, (sum, hu) => sum + hu.weight)
      : (cachedPesoTotalKg ?? 0);

  double get totalVolume => handlingUnits.isNotEmpty
      ? handlingUnits.fold(0.0, (sum, hu) => sum + hu.volume)
      : (cachedVolumenTotalM3 ?? 0);

  int get huCount =>
      handlingUnits.isNotEmpty ? handlingUnits.length : (cachedCantidadHu ?? 0);

  bool get isEditable => status == TruckStatus.abierto;

  factory Truck.fromApi(Map<String, dynamic> json) {
    final bultosJson = json['bultos'];
    final units = <HandlingUnit>[];
    if (bultosJson is List) {
      for (final item in bultosJson) {
        if (item is Map<String, dynamic>) {
          units.add(HandlingUnit.fromApi(item));
        }
      }
    }

    return Truck(
      id: json['id']?.toString() ?? '',
      tripNumber: json['numero_viaje']?.toString() ?? '',
      origen: json['origen']?.toString() ?? '',
      destination: json['destino']?.toString() ?? '',
      observations: json['observaciones']?.toString(),
      status: _parseStatus(json['estado']?.toString()),
      savedOccupancyPercent: _toDouble(json['porcentaje_ocupacion']),
      tipoVehiculo: json['tipo_vehiculo']?.toString(),
      closedAt: _parseDateTime(json['cerrado_en']),
      sentAt: _parseDateTime(json['enviado_en']),
      createdAt: _parseDateTime(json['creado_en']),
      alertEmailSent: json['alerta_email_enviada'] == true,
      cachedCantidadHu: _toInt(json['cantidad_hu']),
      cachedPesoTotalKg: _toDouble(json['peso_total_kg']),
      cachedVolumenTotalM3: _toDouble(json['volumen_total_m3']),
      handlingUnits: units,
    );
  }

  static TruckStatus _parseStatus(String? value) => switch (value) {
        'pendiente' => TruckStatus.pendiente,
        'cerrado' => TruckStatus.cerrado,
        'enviado' => TruckStatus.enviado,
        _ => TruckStatus.abierto,
      };

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  VehicleType? recommendedVehicle(List<VehicleType> vehicles) {
    if (huCount == 0 && totalVolume == 0) return null;
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
    if (huCount == 0) return LoadValidation.subutilizada;

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
