import 'package:drift/drift.dart';

class HabitsTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get frequencyType => text().withDefault(const Constant('daily'))();
  TextColumn get frequencyRule => text()();
  TextColumn get reminderTime => text().nullable()();
  TextColumn get goalId => text().nullable()();
  RealColumn get progressWeight => real().withDefault(const Constant(1.0))();
  DateTimeColumn get startDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('active'))();
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
