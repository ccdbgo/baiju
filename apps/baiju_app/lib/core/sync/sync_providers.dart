import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/sync/sync_engine.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return SyncEngine(database, workspace.userId);
});

final syncControllerProvider = Provider<SyncController>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return SyncController(engine);
});

/// Watches the count of pending (not yet synced) items in the sync queue.
final pendingSyncQueueCountProvider = StreamProvider.autoDispose<int>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return (database.select(database.syncQueueTable)
        ..where(
          (tbl) =>
              tbl.userId.equals(workspace.userId) &
              tbl.status.isNotValue('done'),
        ))
      .watch()
      .map((items) => items.length);
});

/// Watches failed sync items for the current user.
final failedSyncQueueItemsProvider =
    StreamProvider.autoDispose<List<SyncQueueTableData>>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return (database.select(database.syncQueueTable)
        ..where(
          (tbl) =>
              tbl.userId.equals(workspace.userId) &
              tbl.status.equals('failed'),
        )
        ..orderBy(<OrderingTerm Function($SyncQueueTableTable)>[
          (tbl) => OrderingTerm.desc(tbl.updatedAt),
        ]))
      .watch();
});

class SyncController {
  const SyncController(this._engine);

  final SyncEngine _engine;

  bool get isConfigured => _engine.isConfigured;

  Future<SyncResult> sync() => _engine.sync();

  Future<SyncResult> pushOnly() => _engine.pushPendingChanges();

  Future<SyncResult> pullOnly() => _engine.pullRemoteChanges();
}
