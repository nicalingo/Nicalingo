import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cache_service.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  void init() {
    // Escucha cambios de red en tiempo real
    Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline) {
        syncPendingData();
      }
    });
  }

  Future<void> syncPendingData() async {
    final cache = await CacheService.instance;
    final pendingList = cache.getPendingActions();

    if (pendingList.isEmpty) return;

    final client = Supabase.instance.client;

    for (final action in List.from(pendingList)) {
      try {
        final table = action['table'] as String;
        final data = action['data'] as Map<String, dynamic>;

        // Intenta subir a Supabase
        await client.from(table).upsert(data);

        // Si subió con éxito, lo saca de pendientes
        pendingList.remove(action);
      } catch (e) {
        // Si la conexión sigue inestable, para y lo reintenta después
        break;
      }
    }

    if (pendingList.isEmpty) {
      await cache.clearPendingActions();
    } else {
      await cache.saveData('pending_sync_queue', pendingList);
    }
  }
}