import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/anniversary/domain/anniversary_models.dart';
import 'package:baiju_app/features/anniversary/infrastructure/anniversary_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AnniversaryRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = AnniversaryRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'createAnniversary writes anniversary, sync queue and timeline event',
    () async {
      await repository.createAnniversary(
        title: '入职纪念日',
        baseDate: DateTime(2020, 4, 1),
        reminder: AnniversaryReminderOption.three,
        category: '工作',
        note: '第一份正式工作',
      );

      final anniversaries = await database
          .select(database.anniversariesTable)
          .get();
      final syncQueue = await database.select(database.syncQueueTable).get();
      final timelineEvents = await database
          .select(database.timelineEventsTable)
          .get();

      expect(anniversaries, hasLength(1));
      expect(anniversaries.single.title, '入职纪念日');
      expect(anniversaries.single.remindDaysBefore, 3);
      expect(anniversaries.single.category, '工作');
      expect(syncQueue, hasLength(1));
      expect(syncQueue.single.entityType, 'anniversary');
      expect(syncQueue.single.operation, 'create');
      expect(timelineEvents, hasLength(1));
      expect(timelineEvents.single.eventType, 'anniversary');
      expect(timelineEvents.single.eventAction, 'created');
    },
  );

  test(
    'updateAnniversary updates fields and appends tracking records',
    () async {
      await repository.createAnniversary(
        title: '恋爱纪念日',
        baseDate: DateTime(2021, 5, 20),
        reminder: AnniversaryReminderOption.one,
      );

      final created =
          (await database.select(database.anniversariesTable).get()).single;

      await repository.updateAnniversary(
        anniversary: created,
        title: '结婚纪念日',
        baseDate: DateTime(2022, 10, 1),
        reminder: AnniversaryReminderOption.seven,
        category: '家庭',
        note: '重要日期',
      );

      final updated =
          (await database.select(database.anniversariesTable).get()).single;
      final syncQueue = await database.select(database.syncQueueTable).get();
      final timelineEvents = await database
          .select(database.timelineEventsTable)
          .get();

      expect(updated.title, '结婚纪念日');
      expect(updated.remindDaysBefore, 7);
      expect(updated.category, '家庭');
      expect(updated.localVersion, 2);
      expect(syncQueue, hasLength(2));
      expect(syncQueue.last.operation, 'update');
      expect(timelineEvents.last.eventAction, 'updated');
    },
  );

  test(
    'deleteAnniversary marks row deleted and writes delete tracking',
    () async {
      await repository.createAnniversary(
        title: '生日',
        baseDate: DateTime(1990, 6, 1),
        reminder: AnniversaryReminderOption.none,
      );

      final anniversary =
          (await database.select(database.anniversariesTable).get()).single;

      await repository.deleteAnniversary(anniversary);

      final deleted =
          (await database.select(database.anniversariesTable).get()).single;
      final syncQueue = await database.select(database.syncQueueTable).get();
      final timelineEvents = await database
          .select(database.timelineEventsTable)
          .get();

      expect(deleted.deletedAt, isNotNull);
      expect(syncQueue.last.operation, 'delete');
      expect(timelineEvents.last.eventAction, 'deleted');
    },
  );
}
