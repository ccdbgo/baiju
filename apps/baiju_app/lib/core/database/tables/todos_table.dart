import 'package:drift/drift.dart';

class TodosTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  DateTimeColumn get plannedAt => dateTime().nullable()();
  TextColumn get listName => text().nullable()();
  TextColumn get goalId => text().nullable()();
  TextColumn get linkedNoteId => text().nullable()();
  TextColumn get convertedScheduleId => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending_create'))();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get remoteVersion => integer().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get deviceId => text().withDefault(const Constant('local'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
