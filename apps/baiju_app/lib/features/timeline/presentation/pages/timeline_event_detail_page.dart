import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_export_formatter.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TimelineEventDetailPage extends ConsumerWidget {
  const TimelineEventDetailPage({required this.eventId, super.key});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(timelineEventDetailProvider(eventId));
    final adjacent = ref.watch(timelineAdjacentEventsProvider(eventId));
    final relatedEvents = ref.watch(relatedTimelineEventsProvider(eventId));
    final sameDayEvents = ref.watch(sameDayTimelineEventsProvider(eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('事件详情')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: event.when(
          data: (value) {
            if (value == null) {
              return const Center(child: Text('事件不存在或已删除'));
            }

            final occurredAt = value.occurredAt.toLocal();
            final sourceRoute = _sourceObjectRoute(value);
            return ListView(
              children: <Widget>[
                Text(
                  value.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Chip(label: Text(_eventTypeLabel(value.eventType))),
                    Chip(label: Text(_eventActionLabel(value.eventAction))),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _copyText(
                        context,
                        buildTimelineEventSummary(value),
                        '事件摘要已复制',
                      ),
                      icon: const Icon(Icons.content_copy_outlined, size: 18),
                      label: const Text('复制事件摘要'),
                    ),
                    if (value.payloadJson != null && value.payloadJson!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _copyText(
                          context,
                          buildTimelineEventPayload(value),
                          '事件载荷已复制',
                        ),
                        icon: const Icon(Icons.data_object, size: 18),
                        label: const Text('复制事件载荷'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                adjacent.when(
                  data: (value) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '前后事件导航',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '按当前时间线顺序切换',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: value.previous == null
                                    ? null
                                    : () => context.pushReplacement(
                                        '/timeline/${value.previous!.id}',
                                      ),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('上一条'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: value.next == null
                                    ? null
                                    : () => context.pushReplacement(
                                        '/timeline/${value.next!.id}',
                                      ),
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('下一条'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => Text('前后事件加载失败：$error'),
                ),
                _DetailRow(
                  label: '发生时间',
                  value: DateFormat('yyyy年M月d日 HH:mm').format(occurredAt),
                ),
                _DetailRow(
                  label: '来源类型',
                  value: _eventTypeLabel(value.eventType),
                ),
                _DetailRow(label: '来源 ID', value: value.sourceEntityId),
                if (value.summary != null && value.summary!.isNotEmpty)
                  _DetailRow(label: '摘要', value: value.summary!),
                const SizedBox(height: 16),
                Text('来源对象', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _LinkedSourceTile(
                  label: _sourceObjectLabel(value),
                  title: value.title,
                  icon: _sourceObjectIcon(value),
                  onTap: sourceRoute == null
                      ? null
                      : () => context.push(sourceRoute),
                ),
                if (value.payloadJson != null &&
                    value.payloadJson!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 24),
                  Text('事件载荷', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _PayloadCard(payload: buildTimelineEventPayload(value)),
                ],
                const SizedBox(height: 24),
                Text('关联事件', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                relatedEvents.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const _EmptySection(text: '没有同源关联事件');
                    }
                    return Column(
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ContextEventTile(event: item),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => Text('关联事件加载失败：$error'),
                ),
                const SizedBox(height: 24),
                Text('同日上下文', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                sameDayEvents.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const _EmptySection(text: '当天没有其他事件');
                    }
                    return Column(
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ContextEventTile(event: item),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => Text('同日事件加载失败：$error'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('加载失败：$error')),
        ),
      ),
    );
  }

  String _eventTypeLabel(String eventType) {
    switch (eventType) {
      case 'schedule':
        return '日程';
      case 'todo':
        return '待办';
      case 'habit':
        return '习惯';
      case 'anniversary':
        return '纪念日';
      case 'goal':
        return '目标';
      case 'note':
        return '笔记';
      default:
        return eventType;
    }
  }

  String _eventActionLabel(String action) {
    switch (action) {
      case 'created':
        return '创建';
      case 'updated':
        return '更新';
      case 'completed':
        return '完成';
      case 'checked_in':
        return '打卡';
      case 'scheduled':
        return '转日程';
      case 'archived':
        return '归档';
      case 'paused':
        return '暂停';
      case 'resumed':
        return '恢复';
      case 'deleted':
        return '删除';
      case 'cancelled':
        return '取消';
      default:
        return action;
    }
  }

  String? _sourceObjectRoute(TimelineEventsTableData event) {
    return switch (event.sourceEntityType) {
      'goal' => '/goal/${event.sourceEntityId}',
      'todo' => '/todo/${event.sourceEntityId}',
      'schedule' => '/schedule/${event.sourceEntityId}',
      'habit' => '/habit/${event.sourceEntityId}',
      'anniversary' => '/anniversary/${event.sourceEntityId}',
      'note' => '/note/${event.sourceEntityId}',
      _ => null,
    };
  }

  String _sourceObjectLabel(TimelineEventsTableData event) {
    switch (event.sourceEntityType) {
      case 'goal':
        return '原始目标';
      case 'todo':
        return '原始待办';
      case 'schedule':
        return '原始日程';
      case 'habit':
        return '原始习惯';
      case 'anniversary':
        return '原始纪念日';
      default:
        return event.sourceEntityType == 'note' ? '原始笔记' : '原始对象';
    }
  }

  IconData _sourceObjectIcon(TimelineEventsTableData event) {
    switch (event.sourceEntityType) {
      case 'goal':
        return Icons.flag_outlined;
      case 'todo':
        return Icons.checklist_outlined;
      case 'schedule':
        return Icons.event_outlined;
      case 'habit':
        return Icons.bolt_outlined;
      case 'anniversary':
        return Icons.celebration_outlined;
      case 'note':
        return Icons.note_alt_outlined;
      default:
        return Icons.open_in_new;
    }
  }

  Future<void> _copyText(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ContextEventTile extends StatelessWidget {
  const _ContextEventTile({required this.event});

  final TimelineEventsTableData event;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/timeline/${event.id}'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text('${event.eventType} / ${event.eventAction}'),
                  ],
                ),
              ),
              Text(DateFormat('HH:mm').format(event.occurredAt.toLocal())),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _LinkedSourceTile extends StatelessWidget {
  const _LinkedSourceTile({
    required this.label,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        enabled: onTap != null,
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(label),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _PayloadCard extends StatelessWidget {
  const _PayloadCard({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          payload,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: 'Consolas'),
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text(text)),
      ),
    );
  }
}
