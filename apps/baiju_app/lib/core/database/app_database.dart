import 'package:baiju_app/core/database/database_connection_native.dart'
    if (dart.library.js_interop) 'package:baiju_app/core/database/database_connection_web.dart'
    as db_connection;
import 'package:baiju_app/core/database/tables/app_settings_table.dart';
import 'package:baiju_app/core/database/tables/anniversaries_table.dart';
import 'package:baiju_app/core/database/tables/goals_table.dart';
import 'package:baiju_app/core/database/tables/habits_table.dart';
import 'package:baiju_app/core/database/tables/habit_records_table.dart';
import 'package:baiju_app/core/database/tables/notes_table.dart';
import 'package:baiju_app/core/database/tables/schedules_table.dart';
import 'package:baiju_app/core/database/tables/sync_queue_table.dart';
import 'package:baiju_app/core/database/tables/timeline_events_table.dart';
import 'package:baiju_app/core/database/tables/todo_subtasks_table.dart';
import 'package:baiju_app/core/database/tables/todos_table.dart';
import 'package:baiju_app/core/database/tables/users_table.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    AppSettingsTable,
    AnniversariesTable,
    GoalsTable,
    SchedulesTable,
    TodosTable,
    TodoSubtasksTable,
    HabitsTable,
    HabitRecordsTable,
    NotesTable,
    TimelineEventsTable,
    SyncQueueTable,
    UsersTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(habitRecordsTable);
      }
      if (from < 3) {
        await m.addColumn(
          schedulesTable,
          schedulesTable.reminderMinutesBefore as GeneratedColumn<Object>,
        );
      }
      if (from < 4) {
        await m.createTable(goalsTable);
      }
      if (from < 5) {
        await m.addColumn(
          goalsTable,
          goalsTable.progressMode as GeneratedColumn<Object>,
        );
      }
      if (from < 6) {
        await m.addColumn(
          goalsTable,
          goalsTable.todoWeight as GeneratedColumn<Object>,
        );
        await m.addColumn(
          goalsTable,
          goalsTable.habitWeight as GeneratedColumn<Object>,
        );
      }
      if (from < 7) {
        await m.addColumn(
          habitsTable,
          habitsTable.progressWeight as GeneratedColumn<Object>,
        );
        await m.addColumn(
          goalsTable,
          goalsTable.todoUnitWeight as GeneratedColumn<Object>,
        );
        await m.addColumn(
          goalsTable,
          goalsTable.habitUnitWeight as GeneratedColumn<Object>,
        );
      }
      if (from < 8) {
        await m.createTable(usersTable);
        await m.addColumn(
          syncQueueTable,
          syncQueueTable.userId as GeneratedColumn<Object>,
        );
        await into(usersTable).insert(
          UsersTableCompanion.insert(
            id: 'local_user',
            displayName: '默认用户',
            authProvider: const Value('local'),
            lastLoginAt: Value(DateTime.now().toUtc()),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      if (from < 9) {
        await m.createTable(anniversariesTable);
      }
      if (from < 10) {
        await m.createTable(notesTable);
      }
      if (from < 11) {
        await m.addColumn(
          usersTable,
          usersTable.role as GeneratedColumn<Object>,
        );
        await (update(usersTable)..where((tbl) => tbl.id.equals('local_user')))
            .write(const UsersTableCompanion(role: Value('admin')));
      }
      if (from < 12) {
        await m.createTable(todoSubtasksTable);
      }
      if (from < 13) {
        await m.addColumn(
          usersTable,
          usersTable.passwordHash as GeneratedColumn<Object>,
        );
      }
      if (from < 14) {
        await m.addColumn(
          goalsTable,
          goalsTable.priority as GeneratedColumn<Object>,
        );
        await m.addColumn(
          schedulesTable,
          schedulesTable.priority as GeneratedColumn<Object>,
        );
      }
    },
  );
}

QueryExecutor _openConnection() {
  return db_connection.openDatabaseConnection();
}
