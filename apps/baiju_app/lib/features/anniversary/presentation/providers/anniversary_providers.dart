import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/features/anniversary/domain/anniversary_models.dart';
import 'package:baiju_app/features/anniversary/infrastructure/anniversary_repository.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final anniversaryRepositoryProvider = Provider<AnniversaryRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return AnniversaryRepository(database, workspace: workspace);
});

final anniversaryListProvider =
    StreamProvider.autoDispose<List<AnniversariesTableData>>((ref) {
      final repository = ref.watch(anniversaryRepositoryProvider);
      return repository.watchAnniversaries();
    });

final anniversaryDetailProvider = StreamProvider.family
    .autoDispose<AnniversariesTableData?, String>((ref, anniversaryId) {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);
      return (database.select(database.anniversariesTable)..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(workspace.userId) &
                tbl.id.equals(anniversaryId),
          ))
          .watchSingleOrNull();
    });

final anniversarySummaryProvider =
    StreamProvider.autoDispose<AnniversarySummary>((ref) {
      final repository = ref.watch(anniversaryRepositoryProvider);
      return repository.watchAnniversaries().map((items) {
        final upcoming30Days = items.where((item) {
          final days = daysUntilNextAnniversary(item.baseDate);
          return days >= 0 && days <= 30;
        }).length;
        final withReminder = items
            .where((item) => item.remindDaysBefore != null)
            .length;
        return AnniversarySummary(
          total: items.length,
          upcoming30Days: upcoming30Days,
          withReminder: withReminder,
        );
      });
    });

final upcomingAnniversaryListProvider =
    StreamProvider.autoDispose<List<AnniversariesTableData>>((ref) {
      final repository = ref.watch(anniversaryRepositoryProvider);
      return repository.watchAnniversaries().map((items) {
        final sorted = items.toList()
          ..sort(
            (a, b) => daysUntilNextAnniversary(
              a.baseDate,
            ).compareTo(daysUntilNextAnniversary(b.baseDate)),
          );
        return sorted.take(3).toList();
      });
    });

final anniversaryActionsProvider = Provider<AnniversaryActions>((ref) {
  final repository = ref.watch(anniversaryRepositoryProvider);
  return AnniversaryActions(repository);
});

class AnniversaryActions {
  const AnniversaryActions(this._repository);

  final AnniversaryRepository _repository;

  Future<void> createAnniversary({
    required String title,
    required DateTime baseDate,
    required AnniversaryReminderOption reminder,
    String? category,
    String? note,
  }) {
    return _repository.createAnniversary(
      title: title,
      baseDate: baseDate,
      reminder: reminder,
      category: category,
      note: note,
    );
  }

  Future<void> updateAnniversary({
    required AnniversariesTableData anniversary,
    required String title,
    required DateTime baseDate,
    required AnniversaryReminderOption reminder,
    String? category,
    String? note,
  }) {
    return _repository.updateAnniversary(
      anniversary: anniversary,
      title: title,
      baseDate: baseDate,
      reminder: reminder,
      category: category,
      note: note,
    );
  }

  Future<void> deleteAnniversary(AnniversariesTableData anniversary) {
    return _repository.deleteAnniversary(anniversary);
  }
}

int daysUntilNextAnniversary(DateTime baseDate) {
  final localBase = baseDate.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var next = DateTime(today.year, localBase.month, localBase.day);
  if (next.isBefore(today)) {
    next = DateTime(today.year + 1, localBase.month, localBase.day);
  }
  return next.difference(today).inDays;
}
