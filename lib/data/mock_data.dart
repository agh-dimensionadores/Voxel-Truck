import 'package:voxel_truck/models/truck.dart';

const vehicleTypes = [
  VehicleType(name: 'Chasis', volumeM3: 40),
  VehicleType(name: 'Balancín', volumeM3: 60),
  VehicleType(name: 'Semi', volumeM3: 90),
];

final sampleTrucks = [
  Truck(
    id: '1',
    tripNumber: 'VT-2026-0142',
    origen: 'CD Santiago Norte',
    destination: 'Concepción',
    observations: 'Mercadería seca',
    createdAt: DateTime(2026, 6, 16),
    handlingUnits: [
      const HandlingUnit(
        code: 'HU-884521',
        length: 120,
        width: 80,
        height: 100,
        weight: 45.5,
        source: DimensionSource.voxelCam,
        idRegistroOrigen: 'VL-DEMO-884521',
      ),
      const HandlingUnit(
        code: 'HU-884522',
        length: 100,
        width: 80,
        height: 90,
        weight: 38.2,
        source: DimensionSource.voxelCam,
        idRegistroOrigen: 'VL-DEMO-884522',
      ),
      const HandlingUnit(
        code: 'PLT-00931',
        length: 120,
        width: 100,
        height: 150,
        weight: 320,
        source: DimensionSource.coresa,
        idRegistroOrigen: '931',
      ),
    ],
  ),
  Truck(
    id: '2',
    tripNumber: 'VT-2026-0143',
    origen: 'CD Santiago Sur',
    destination: 'Valparaíso',
    createdAt: DateTime(2026, 6, 16),
    handlingUnits: [
      const HandlingUnit(
        code: 'HU-771001',
        length: 60,
        width: 40,
        height: 30,
        weight: 5.2,
        source: DimensionSource.voxelCam,
        idRegistroOrigen: 'VL-DEMO-771001',
      ),
    ],
  ),
  Truck(
    id: '3',
    tripNumber: 'VT-2026-0138',
    origen: 'CD Santiago Norte',
    destination: 'Antofagasta',
    createdAt: DateTime(2026, 6, 15),
    status: TruckStatus.enviado,
    savedOccupancyPercent: 85,
    closedAt: DateTime(2026, 6, 15, 14, 30),
    sentAt: DateTime(2026, 6, 15, 16, 0),
    handlingUnits: [
      const HandlingUnit(
        code: 'HU-660012',
        length: 110,
        width: 90,
        height: 120,
        weight: 52,
        source: DimensionSource.voxelCam,
        idRegistroOrigen: 'VL-DEMO-660012',
      ),
    ],
  ),
];

const mockHuDatabase = {
  'HU-884521': HandlingUnit(
    code: 'HU-884521',
    length: 120,
    width: 80,
    height: 100,
    weight: 45.5,
    source: DimensionSource.voxelCam,
    idRegistroOrigen: 'VL-DEMO-884521',
  ),
  'HU-884522': HandlingUnit(
    code: 'HU-884522',
    length: 100,
    width: 80,
    height: 90,
    weight: 38.2,
    source: DimensionSource.voxelCam,
    idRegistroOrigen: 'VL-DEMO-884522',
  ),
  'PLT-00931': HandlingUnit(
    code: 'PLT-00931',
    length: 120,
    width: 100,
    height: 150,
    weight: 320,
    source: DimensionSource.coresa,
    idRegistroOrigen: '931',
  ),
  'HU-771001': HandlingUnit(
    code: 'HU-771001',
    length: 60,
    width: 40,
    height: 30,
    weight: 5.2,
    source: DimensionSource.voxelCam,
    idRegistroOrigen: 'VL-DEMO-771001',
  ),
};
