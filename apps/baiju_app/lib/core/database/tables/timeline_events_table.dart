import 'package:drift/drift.dart';

class TimelineEventsTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get eventType => text()();
  TextColumn get eventAction => text()();
  TextColumn get sourceEntityId => text()();
  TextColumn get sourceEntityType => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get title => text()();
  TextColumn get summary => text().nullable()();
  TextColumn get payloadJson => text().nullable()();
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
