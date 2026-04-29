import 'package:drift/drift.dart';

class GoalsTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get goalType => text().withDefault(const Constant('stage'))();
  TextColumn get progressMode => text().withDefault(const Constant('mixed'))();
  RealColumn get todoWeight => real().withDefault(const Constant(0.7))();
  RealColumn get habitWeight => real().withDefault(const Constant(0.3))();
  RealColumn get todoUnitWeight => real().withDefault(const Constant(1.0))();
  RealColumn get habitUnitWeight => real().withDefault(const Constant(0.5))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get priority =>
      text().withDefault(const Constant('not_urgent_important'))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  RealColumn get progressValue => real().nullable()();
  RealColumn get progressTarget => real().nullable()();
  TextColumn get unit => text().nullable()();
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
