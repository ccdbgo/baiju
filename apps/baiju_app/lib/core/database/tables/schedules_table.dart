import 'package:drift/drift.dart';

class SchedulesTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  TextColumn get timezone => text().withDefault(const Constant('UTC'))();
  TextColumn get location => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  TextColumn get priority =>
      text().withDefault(const Constant('not_urgent_important'))();
  TextColumn get recurrenceRule => text().nullable()();
  IntColumn get reminderMinutesBefore => integer().nullable()();
  TextColumn get sourceTodoId => text().nullable()();
  TextColumn get linkedNoteId => text().nullable()();
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
