enum VolumeDisplayUnit {
  m3,
  dm3;

  String get label => switch (this) {
        VolumeDisplayUnit.m3 => 'm³',
        VolumeDisplayUnit.dm3 => 'dm³',
      };

  String get title => switch (this) {
        VolumeDisplayUnit.m3 => 'Metros cúbicos (m³)',
        VolumeDisplayUnit.dm3 => 'Decímetros cúbicos (dm³)',
      };
}

enum DimensionDisplayUnit {
  cm,
  mm;

  String get label => switch (this) {
        DimensionDisplayUnit.cm => 'cm',
        DimensionDisplayUnit.mm => 'mm',
      };

  String get title => switch (this) {
        DimensionDisplayUnit.cm => 'Centímetros (cm)',
        DimensionDisplayUnit.mm => 'Milímetros (mm)',
      };
}

class DisplaySettings {
  const DisplaySettings({
    this.volumeUnit = VolumeDisplayUnit.dm3,
    this.dimensionUnit = DimensionDisplayUnit.cm,
  });

  final VolumeDisplayUnit volumeUnit;
  final DimensionDisplayUnit dimensionUnit;

  DisplaySettings copyWith({
    VolumeDisplayUnit? volumeUnit,
    DimensionDisplayUnit? dimensionUnit,
  }) {
    return DisplaySettings(
      volumeUnit: volumeUnit ?? this.volumeUnit,
      dimensionUnit: dimensionUnit ?? this.dimensionUnit,
    );
  }
}
