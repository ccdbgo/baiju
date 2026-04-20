import 'package:drift/drift.dart';

class TodoSubtasksTable extends Table {
  TextColumn get id => text()();
  TextColumn get todoId => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
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
