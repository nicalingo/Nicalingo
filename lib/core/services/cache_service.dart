import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static CacheService? _instance;
  static SharedPreferences? _prefs;

  CacheService._();

  static Future<CacheService> get instance async {
    _instance ??= CacheService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Guarda cualquier dato en local
  Future<void> saveData(String key, dynamic data) async {
    final jsonString = jsonEncode(data);
    await _prefs?.setString(key, jsonString);
  }

  // Lee el dato en local si no hay internet
  dynamic getData(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  // Encola acciones pendientes para cuando vuelva el internet
  Future<void> enqueuePendingAction(Map<String, dynamic> action) async {
    final pending = getPendingActions();
    pending.add(action);
    await _prefs?.setString('pending_sync_queue', jsonEncode(pending));
  }

  List<Map<String, dynamic>> getPendingActions() {
    final raw = _prefs?.getString('pending_sync_queue');
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearPendingActions() async {
    await _prefs?.remove('pending_sync_queue');
  }
}