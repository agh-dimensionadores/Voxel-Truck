import 'package:flutter/widgets.dart';import 'package:shared_preferences/shared_preferences.dart';
import 'package:voxel_truck/models/display_units.dart';

class DisplaySettingsScope extends InheritedNotifier<DisplaySettingsController> {
  const DisplaySettingsScope({
    super.key,
    required DisplaySettingsController super.notifier,
    required super.child,
  });

  static DisplaySettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DisplaySettingsScope>();
    assert(scope != null, 'DisplaySettingsScope not found');
    return scope!.notifier!;
  }
}

class DisplaySettingsController extends ChangeNotifier {
  DisplaySettingsController();

  static const _volumeKey = 'display_volume_unit';
  static const _dimensionKey = 'display_dimension_unit';

  DisplaySettings _settings = const DisplaySettings();
  bool _loaded = false;

  DisplaySettings get settings => _settings;
  VolumeDisplayUnit get volumeUnit => _settings.volumeUnit;
  DimensionDisplayUnit get dimensionUnit => _settings.dimensionUnit;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = DisplaySettings(
      volumeUnit: VolumeDisplayUnit.values[prefs.getInt(_volumeKey) ?? VolumeDisplayUnit.dm3.index],
      dimensionUnit: DimensionDisplayUnit.values[prefs.getInt(_dimensionKey) ?? DimensionDisplayUnit.cm.index],
    );
    _loaded = true;
    notifyListeners();
  }

  Future<void> setVolumeUnit(VolumeDisplayUnit unit) async {
    if (_settings.volumeUnit == unit) return;
    _settings = _settings.copyWith(volumeUnit: unit);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_volumeKey, unit.index);
  }

  Future<void> setDimensionUnit(DimensionDisplayUnit unit) async {
    if (_settings.dimensionUnit == unit) return;
    _settings = _settings.copyWith(dimensionUnit: unit);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dimensionKey, unit.index);
  }
}
