import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:drift/drift.dart';

class ScheduleDao {
  const ScheduleDao(
    this._database, [
    this._workspace = const UserWorkspace.local(),
  ]);

  final AppDatabase _database;
  final UserWorkspace _workspace;

  Stream<List<SchedulesTableData>> watchSchedules(ScheduleFilter filter) {
    final query = _database.select(_database.schedulesTable)
      ..where(
        (tbl) => tbl.deletedAt.isNull() & tbl.userId.equals(_workspace.userId),
      );

    switch (filter) {
      case ScheduleFilter.all:
        break;
      case ScheduleFilter.today:
        final range = _todayRangeUtc();
        query.where(
          (tbl) => tbl.status.isNotValue('cancelled') &
              tbl.startAt.isBiggerOrEqualValue(range.start) &
              tbl.startAt.isSmallerThanValue(range.end),
        );
      case ScheduleFilter.upcoming:
        query.where(
          (tbl) => tbl.status.equals('planned') &
              tbl.startAt.isBiggerOrEqualValue(DateTime.now().toUtc()),
        );
      case ScheduleFilter.completed:
        query.where((tbl) => tbl.status.equals('completed'));
    }

    return query.watch().map((rows) {
      final schedules = rows.toList()..sort(_compareSchedules);
      return schedules;
    });
  }

  Future<void> insertSchedule(SchedulesTableCompanion companion) {
    return _database.into(_database.schedulesTable).insert(companion);
  }

  Future<void> updateScheduleStatus({
    required String id,
    required String status,
    required DateTime updatedAt,
    required int localVersion,
    DateTime? completedAt,
  }) {
    return (_database.update(_database.schedulesTable)
          ..where(
            (tbl) => tbl.id.equals(id) & tbl.userId.equals(_workspace.userId),
          ))
        .write(
      SchedulesTableCompanion(
        status: Value(status),
        completedAt: Value(completedAt),
        updatedAt: Value(updatedAt),
        syncStatus: const Value('pending_update'),
        localVersion: Value(localVersion),
        deviceId: Value(_workspace.deviceId),
      ),
    );
  }

  Future<void> updateSchedule({
    required String id,
    required String title,
    required String? description,
    required DateTime startAt,
    required DateTime endAt,
    required bool isAllDay,
    required String? location,
    required String? category,
    required String? recurrenceRule,
    required int? reminderMinutesBefore,
    required DateTime updatedAt,
    required int localVersion,
    String priority = 'not_urgent_important',
  }) {
    return (_database.update(_database.schedulesTable)
          ..where(
            (tbl) => tbl.id.equals(id) & tbl.userId.equals(_workspace.userId),
          ))
        .write(
      SchedulesTableCompanion(
        title: Value(title),
        description: Value(description),
        startAt: Value(startAt),
        endAt: Value(endAt),
        isAllDay: Value(isAllDay),
        location: Value(location),
        category: Value(category),
        priority: Value(priority),
        recurrenceRule: Value(recurrenceRule),
        reminderMinutesBefore: Value(reminderMinutesBefore),
        updatedAt: Value(updatedAt),
        syncStatus: const Value('pending_update'),
        localVersion: Value(localVersion),
        deviceId: Value(_workspace.deviceId),
      ),
    );
  }

  int _compareSchedules(SchedulesTableData left, SchedulesTableData right) {
    final leftCompleted = left.status == 'completed';
    final rightCompleted = right.status == 'completed';

    if (leftCompleted != rightCompleted) {
      return leftCompleted ? 1 : -1;
    }

    if (!leftCompleted) {
      return left.startAt.compareTo(right.startAt);
    }

    final leftCompletedAt = left.completedAt ?? left.updatedAt;
    final rightCompletedAt = right.completedAt ?? right.updatedAt;
    return rightCompletedAt.compareTo(leftCompletedAt);
  }

  _UtcRange _todayRangeUtc() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = DateTime(now.year, now.month, now.day + 1).toUtc();
    return _UtcRange(start: start, end: end);
  }
}

class _UtcRange {
  const _UtcRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}
