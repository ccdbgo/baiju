import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:drift/drift.dart';

class HabitDao {
  const HabitDao(
    this._database, [
    this._workspace = const UserWorkspace.local(),
  ]);

  final AppDatabase _database;
  final UserWorkspace _workspace;

  Stream<List<HabitTodayItem>> watchHabitsForToday() {
    return (_database.select(_database.habitsTable)
          ..where(
            (tbl) => tbl.deletedAt.isNull() & tbl.userId.equals(_workspace.userId),
          )
          ..orderBy(
            <OrderingTerm Function($HabitsTableTable)>[
              (tbl) => OrderingTerm.asc(tbl.updatedAt),
            ],
          ))
        .watch()
        .asyncMap((habits) async {
      final todayRange = _todayRangeUtc();
      final habitIds = habits.map((habit) => habit.id).toList();

      final records = habitIds.isEmpty
          ? <HabitRecordsTableData>[]
          : await (_database.select(_database.habitRecordsTable)
                ..where(
                  (tbl) => tbl.deletedAt.isNull() &
                      tbl.userId.equals(_workspace.userId) &
                      tbl.habitId.isIn(habitIds) &
                      tbl.recordDate.isBiggerOrEqualValue(todayRange.start) &
                      tbl.recordDate.isSmallerThanValue(todayRange.end),
                ))
              .get();

      final recordsByHabitId = <String, HabitRecordsTableData>{
        for (final record in records) record.habitId: record,
      };

      return habits
          .map(
            (habit) => HabitTodayItem(
              habit: habit,
              checkedToday: recordsByHabitId[habit.id]?.status == 'done',
              record: recordsByHabitId[habit.id],
            ),
          )
          .toList();
    });
  }

  Future<void> insertHabit(HabitsTableCompanion companion) {
    return _database.into(_database.habitsTable).insert(companion);
  }

  Future<void> updateHabitTimestamp({
    required String id,
    required DateTime updatedAt,
    required int localVersion,
  }) {
    return (_database.update(_database.habitsTable)
          ..where(
            (tbl) => tbl.id.equals(id) & tbl.userId.equals(_workspace.userId),
          ))
        .write(
      HabitsTableCompanion(
        updatedAt: Value(updatedAt),
        syncStatus: const Value('pending_update'),
        localVersion: Value(localVersion),
        deviceId: Value(_workspace.deviceId),
      ),
    );
  }

  Future<void> updateHabit({
    required String id,
    required String name,
    required String? reminderTime,
    required String? goalId,
    required double progressWeight,
    required DateTime updatedAt,
    required int localVersion,
  }) {
    return (_database.update(_database.habitsTable)
          ..where(
            (tbl) => tbl.id.equals(id) & tbl.userId.equals(_workspace.userId),
          ))
        .write(
      HabitsTableCompanion(
        name: Value(name),
        reminderTime: Value(reminderTime),
        goalId: Value(goalId),
        progressWeight: Value(progressWeight),
        updatedAt: Value(updatedAt),
        syncStatus: const Value('pending_update'),
        localVersion: Value(localVersion),
        deviceId: Value(_workspace.deviceId),
      ),
    );
  }

  Future<HabitRecordsTableData?> findTodayRecord(String habitId) {
    final range = _todayRangeUtc();
    return (_database.select(_database.habitRecordsTable)
          ..where(
            (tbl) => tbl.deletedAt.isNull() &
                tbl.userId.equals(_workspace.userId) &
                tbl.habitId.equals(habitId) &
                tbl.recordDate.isBiggerOrEqualValue(range.start) &
                tbl.recordDate.isSmallerThanValue(range.end),
          ))
        .getSingleOrNull();
  }

  Future<void> insertHabitRecord(HabitRecordsTableCompanion companion) {
    return _database.into(_database.habitRecordsTable).insert(companion);
  }

  Future<void> updateHabitRecord({
    required String id,
    required String status,
    required DateTime recordedAt,
    required DateTime updatedAt,
    required int localVersion,
  }) {
    return (_database.update(_database.habitRecordsTable)
          ..where(
            (tbl) => tbl.id.equals(id) & tbl.userId.equals(_workspace.userId),
          ))
        .write(
      HabitRecordsTableCompanion(
        status: Value(status),
        recordedAt: Value(recordedAt),
        updatedAt: Value(updatedAt),
        syncStatus: const Value('pending_update'),
        localVersion: Value(localVersion),
        deviceId: Value(_workspace.deviceId),
      ),
    );
  }

  _UtcRange _todayRangeUtc() {
    final now = DateTime.now();
    final start = DateTime.utc(now.year, now.month, now.day);
    final end = DateTime.utc(now.year, now.month, now.day + 1);
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
