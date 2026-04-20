import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TimelineFilter {
  all('全部'),
  schedule('日程'),
  todo('待办'),
  habit('习惯'),
  anniversary('纪念日'),
  note('笔记'),
  goal('目标');

  const TimelineFilter(this.label);

  final String label;
}

enum TimelineRangePreset {
  all('全部'),
  last7Days('近 7 天'),
  last30Days('近 30 天'),
  custom('自定义');

  const TimelineRangePreset(this.label);

  final String label;
}

class TimelineDateRangeFilter {
  const TimelineDateRangeFilter({required this.preset, this.range});

  final TimelineRangePreset preset;
  final DateTimeRange? range;

  DateTime? get start {
    final now = DateTime.now();
    switch (preset) {
      case TimelineRangePreset.all:
        return null;
      case TimelineRangePreset.last7Days:
        return DateTime(now.year, now.month, now.day - 6);
      case TimelineRangePreset.last30Days:
        return DateTime(now.year, now.month, now.day - 29);
      case TimelineRangePreset.custom:
        return range?.start;
    }
  }

  DateTime? get end {
    final now = DateTime.now();
    switch (preset) {
      case TimelineRangePreset.all:
        return null;
      case TimelineRangePreset.last7Days:
      case TimelineRangePreset.last30Days:
        return DateTime(now.year, now.month, now.day + 1);
      case TimelineRangePreset.custom:
        return range == null
            ? null
            : DateTime(range!.end.year, range!.end.month, range!.end.day + 1);
    }
  }
}

final selectedTimelineFilterProvider =
    NotifierProvider<SelectedTimelineFilterNotifier, TimelineFilter>(
      SelectedTimelineFilterNotifier.new,
    );

final selectedTimelineRangeProvider =
    NotifierProvider<SelectedTimelineRangeNotifier, TimelineDateRangeFilter>(
      SelectedTimelineRangeNotifier.new,
    );

final timelineEventsProvider =
    StreamProvider.autoDispose<List<TimelineEventsTableData>>((ref) {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);
      final filter = ref.watch(selectedTimelineFilterProvider);
      final rangeFilter = ref.watch(selectedTimelineRangeProvider);
      return _buildTimelineQuery(
        database,
        workspace.userId,
        filter,
        rangeFilter,
      ).watch();
    });

final timelineSummaryProvider = StreamProvider.autoDispose<TimelineSummary>((
  ref,
) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  final filter = ref.watch(selectedTimelineFilterProvider);
  final rangeFilter = ref.watch(selectedTimelineRangeProvider);

  return _buildTimelineQuery(
    database,
    workspace.userId,
    filter,
    rangeFilter,
  ).watch().map((events) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final today = events.where((event) {
      final local = event.occurredAt.toLocal();
      return !local.isBefore(start) && local.isBefore(end);
    }).length;
    final distinctSources = events
        .map((event) => '${event.sourceEntityType}:${event.sourceEntityId}')
        .toSet()
        .length;
    final distinctTypes = events.map((event) => event.eventType).toSet().length;

    return TimelineSummary(
      total: events.length,
      today: today,
      distinctSources: distinctSources,
      distinctTypes: distinctTypes,
    );
  });
});

final timelineEventDetailProvider = FutureProvider.family
    .autoDispose<TimelineEventsTableData?, String>((ref, eventId) {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);
      return (database.select(database.timelineEventsTable)..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(workspace.userId) &
                tbl.id.equals(eventId),
          ))
          .getSingleOrNull();
    });

final relatedTimelineEventsProvider = FutureProvider.family
    .autoDispose<List<TimelineEventsTableData>, String>((ref, eventId) async {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);
      final current =
          await (database.select(database.timelineEventsTable)..where(
                (tbl) =>
                    tbl.deletedAt.isNull() &
                    tbl.userId.equals(workspace.userId) &
                    tbl.id.equals(eventId),
              ))
              .getSingleOrNull();
      if (current == null) {
        return const <TimelineEventsTableData>[];
      }

      return (database.select(database.timelineEventsTable)
            ..where(
              (tbl) =>
                  tbl.deletedAt.isNull() &
                  tbl.userId.equals(workspace.userId) &
                  tbl.id.isNotValue(eventId) &
                  tbl.sourceEntityType.equals(current.sourceEntityType) &
                  tbl.sourceEntityId.equals(current.sourceEntityId),
            )
            ..orderBy(<OrderingTerm Function($TimelineEventsTableTable)>[
              (tbl) => OrderingTerm.desc(tbl.occurredAt),
            ]))
          .get();
    });

final sameDayTimelineEventsProvider = FutureProvider.family
    .autoDispose<List<TimelineEventsTableData>, String>((ref, eventId) async {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);
      final current =
          await (database.select(database.timelineEventsTable)..where(
                (tbl) =>
                    tbl.deletedAt.isNull() &
                    tbl.userId.equals(workspace.userId) &
                    tbl.id.equals(eventId),
              ))
              .getSingleOrNull();
      if (current == null) {
        return const <TimelineEventsTableData>[];
      }

      final local = current.occurredAt.toLocal();
      final start = DateTime(local.year, local.month, local.day).toUtc();
      final end = start.add(const Duration(days: 1));

      return (database.select(database.timelineEventsTable)
            ..where(
              (tbl) =>
                  tbl.deletedAt.isNull() &
                  tbl.userId.equals(workspace.userId) &
                  tbl.id.isNotValue(eventId) &
                  tbl.occurredAt.isBiggerOrEqualValue(start) &
                  tbl.occurredAt.isSmallerThanValue(end),
            )
            ..orderBy(<OrderingTerm Function($TimelineEventsTableTable)>[
              (tbl) => OrderingTerm.desc(tbl.occurredAt),
            ]))
          .get();
    });

final timelineAdjacentEventsProvider = FutureProvider.family
    .autoDispose<TimelineAdjacentEvents, String>((ref, eventId) async {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);
      final filter = ref.watch(selectedTimelineFilterProvider);
      final rangeFilter = ref.watch(selectedTimelineRangeProvider);
      final events = await _buildTimelineQuery(
        database,
        workspace.userId,
        filter,
        rangeFilter,
      ).get();
      final index = events.indexWhere((event) => event.id == eventId);

      if (index == -1) {
        return const TimelineAdjacentEvents();
      }

      return TimelineAdjacentEvents(
        previous: index > 0 ? events[index - 1] : null,
        next: index + 1 < events.length ? events[index + 1] : null,
      );
    });

SimpleSelectStatement<$TimelineEventsTableTable, TimelineEventsTableData>
_buildTimelineQuery(
  AppDatabase database,
  String userId,
  TimelineFilter filter,
  TimelineDateRangeFilter rangeFilter,
) {
  final query = database.select(database.timelineEventsTable)
    ..where((tbl) => tbl.deletedAt.isNull() & tbl.userId.equals(userId))
    ..orderBy(<OrderingTerm Function($TimelineEventsTableTable)>[
      (tbl) => OrderingTerm.desc(tbl.occurredAt),
      (tbl) => OrderingTerm.desc(tbl.createdAt),
    ]);

  if (filter != TimelineFilter.all) {
    query.where((tbl) => tbl.eventType.equals(filter.name));
  }
  if (rangeFilter.start != null) {
    query.where(
      (tbl) => tbl.occurredAt.isBiggerOrEqualValue(rangeFilter.start!),
    );
  }
  if (rangeFilter.end != null) {
    query.where((tbl) => tbl.occurredAt.isSmallerThanValue(rangeFilter.end!));
  }

  return query;
}

class TimelineAdjacentEvents {
  const TimelineAdjacentEvents({this.previous, this.next});

  final TimelineEventsTableData? previous;
  final TimelineEventsTableData? next;
}

class TimelineSummary {
  const TimelineSummary({
    required this.total,
    required this.today,
    required this.distinctSources,
    required this.distinctTypes,
  });

  final int total;
  final int today;
  final int distinctSources;
  final int distinctTypes;
}

class SelectedTimelineFilterNotifier extends Notifier<TimelineFilter> {
  @override
  TimelineFilter build() {
    return TimelineFilter.all;
  }

  void select(TimelineFilter filter) {
    state = filter;
  }
}

class SelectedTimelineRangeNotifier extends Notifier<TimelineDateRangeFilter> {
  @override
  TimelineDateRangeFilter build() {
    return const TimelineDateRangeFilter(preset: TimelineRangePreset.last7Days);
  }

  void selectPreset(TimelineRangePreset preset) {
    state = TimelineDateRangeFilter(preset: preset);
  }

  void selectCustomRange(DateTimeRange range) {
    state = TimelineDateRangeFilter(
      preset: TimelineRangePreset.custom,
      range: range,
    );
  }
}
