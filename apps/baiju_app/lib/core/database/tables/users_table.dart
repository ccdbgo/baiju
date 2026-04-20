import 'package:drift/drift.dart';

class UsersTable extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get authProvider => text().withDefault(const Constant('local'))();
  TextColumn get role => text().withDefault(const Constant('member'))();
  TextColumn get passwordHash => text().nullable()();
  TextColumn get authProviderUserId => text().nullable()();
  TextColumn get wechatOpenId => text().nullable()();
  TextColumn get wechatUnionId => text().nullable()();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
