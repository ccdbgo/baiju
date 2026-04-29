import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:drift/drift.dart';

class GoalDao {
  const GoalDao(
    this._database, [
    this._workspace = const UserWorkspace.local(),
  ]);

  final AppDatabase _database;
  final UserWorkspace _workspace;

  Stream<List<GoalsTableData>> watchGoals() {
    return (_database.select(_database.goalsTable)
          ..where(
            (tbl) => tbl.deletedAt.isNull() & tbl.userId.equals(_workspace.userId),
          )
          ..orderBy(
            <OrderingTerm Function($GoalsTableTable)>[
              (tbl) => OrderingTerm.desc(tbl.updatedAt),
            ],
          ))
        .watch();
  }

  Stream<List<TodosTableData>> watchTodosForGoalStats() {
    return (_database.select(_database.todosTable)
          ..where(
            (tbl) => tbl.deletedAt.isNull() & tbl.userId.equals(_workspace.userId),
          ))
        .watch();
  }

  Stream<List<HabitsTableData>> watchHabitsForGoalStats() {
    return (_database.select(_database.habitsTable)
          ..where(
            (tbl) => tbl.deletedAt.isNull() & tbl.userId.equals(_workspace.userId),
          ))
        .watch();
  }

  Stream<List<HabitRecordsTableData>> watchHabitRecordsForGoalStats() {
    return (_database.select(_database.habitRecordsTable)
          ..where(
            (tbl) => tbl.deletedAt.isNull() & tbl.userId.equals(_workspace.userId),
          ))
        .watch();
  }

  Future<void> insertGoal(GoalsTableCompanion companion) {
    return _database.into(_database.goalsTable).insert(companion);
  }

  Future<void> updateGoal({
    required String id,
    required String title,
    required String? description,
    required String goalType,
    required String progressMode,
    required double todoWeight,
    required double habitWeight,
    required double todoUnitWeight,
    required double habitUnitWeight,
    required String status,
    required String priority,
    required DateTime? startDate,
    required DateTime? endDate,
    required double? progressValue,
    required double? progressTarget,
    required String? unit,
    required DateTime updatedAt,
    required int localVersion,
  }) {
    return (_database.update(_database.goalsTable)
          ..where(
            (tbl) => tbl.id.equals(id) & tbl.userId.equals(_workspace.userId),
          ))
        .write(
      GoalsTableCompanion(
        title: Value(title),
        description: Value(description),
        goalType: Value(goalType),
        progressMode: Value(progressMode),
        todoWeight: Value(todoWeight),
        habitWeight: Value(habitWeight),
        todoUnitWeight: Value(todoUnitWeight),
        habitUnitWeight: Value(habitUnitWeight),
        status: Value(status),
        priority: Value(priority),
        startDate: Value(startDate),
        endDate: Value(endDate),
        progressValue: Value(progressValue),
        progressTarget: Value(progressTarget),
        unit: Value(unit),
        updatedAt: Value(updatedAt),
        syncStatus: const Value('pending_update'),
        localVersion: Value(localVersion),
        deviceId: Value(_workspace.deviceId),
      ),
    );
  }
}
