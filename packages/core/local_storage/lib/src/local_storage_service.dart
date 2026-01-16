import 'package:shared_preferences/shared_preferences.dart';

/// A wrapper around [SharedPreferences] to provide a simplified and testable
/// interface for local storage.
class LocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  /// Initializes the service by obtaining the [SharedPreferences] instance.
  static Future<LocalStorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  /// Retrieves a boolean value.
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  /// Saves a boolean value.
  Future<bool> setBool(String key, bool value) {
    return _prefs.setBool(key, value);
  }

  /// Retrieves a string value.
  String? getString(String key) {
    return _prefs.getString(key);
  }

  /// Saves a string value.
  Future<bool> setString(String key, String value) {
    return _prefs.setString(key, value);
  }

  /// Retrieves an int value.
  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  /// Saves an int value.
  Future<bool> setInt(String key, int value) {
    return _prefs.setInt(key, value);
  }

  /// Retrieves a double value.
  double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  /// Saves a double value.
  Future<bool> setDouble(String key, double value) {
    return _prefs.setDouble(key, value);
  }

  /// Retrieves a list of strings.
  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  /// Saves a list of strings.
  Future<bool> setStringList(String key, List<String> value) {
    return _prefs.setStringList(key, value);
  }

  /// Removes a key.
  Future<bool> remove(String key) {
    return _prefs.remove(key);
  }

  /// Clears all keys.
  Future<bool> clear() {
    return _prefs.clear();
  }
}
