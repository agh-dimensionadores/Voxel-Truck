import 'package:shared_preferences/shared_preferences.dart';

class DeviceId {
  static const _storageKey = 'voxel_truck_device_id';

  static Future<String> get() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_storageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = 'vt-${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(_storageKey, generated);
    return generated;
  }
}
