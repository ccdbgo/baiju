import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsNotificationsPage extends ConsumerStatefulWidget {
  const SettingsNotificationsPage({super.key});

  @override
  ConsumerState<SettingsNotificationsPage> createState() =>
      _SettingsNotificationsPageState();
}

class _SettingsNotificationsPageState
    extends ConsumerState<SettingsNotificationsPage> {
  bool _isManagingReminders = false;

  @override
  Widget build(BuildContext context) {
    final pendingReminderCount = ref.watch(pendingReminderCountProvider);
    final preferences = ref.watch(userPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('通知与提醒')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('提醒状态', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  pendingReminderCount.when(
                    data: (count) => Text('当前待触发提醒：$count'),
                    loading: () => const Text('正在读取提醒状态...'),
                    error: (error, stackTrace) => Text('提醒状态读取失败：$error'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _isManagingReminders
                            ? null
                            : () => _syncAllReminders(context, ref),
                        icon: _isManagingReminders
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: const Text('重新同步提醒'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isManagingReminders
                            ? null
                            : () => _clearAllReminders(context, ref),
                        icon: const Icon(Icons.notifications_off_outlined),
                        label: const Text('清空提醒'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: preferences.when(
                data: (value) => _NotificationPreferencePanel(
                  preferences: value,
                  onReminderChanged: (minutes) => _savePreferences(
                    context,
                    ref,
                    minutes == null
                        ? value.copyWith(clearDefaultScheduleReminder: true)
                        : value.copyWith(
                            defaultScheduleReminderMinutes: minutes,
                          ),
                    '已更新默认提醒',
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text('偏好加载失败：$error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncAllReminders(BuildContext context, WidgetRef ref) async {
    setState(() => _isManagingReminders = true);
    try {
      await ref.read(reminderSyncControllerProvider).syncAll();
      ref.invalidate(pendingReminderCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已重新同步本地提醒')));
      }
    } finally {
      if (mounted) {
        setState(() => _isManagingReminders = false);
      }
    }
  }

  Future<void> _clearAllReminders(BuildContext context, WidgetRef ref) async {
    setState(() => _isManagingReminders = true);
    try {
      await ref.read(reminderSyncControllerProvider).clearAll();
      ref.invalidate(pendingReminderCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清空本地提醒')));
      }
    } finally {
      if (mounted) {
        setState(() => _isManagingReminders = false);
      }
    }
  }

  Future<void> _savePreferences(
    BuildContext context,
    WidgetRef ref,
    UserPreferences preferences,
    String message,
  ) async {
    await ref.read(userPreferenceActionsProvider).save(preferences);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _NotificationPreferencePanel extends StatelessWidget {
  const _NotificationPreferencePanel({
    required this.preferences,
    required this.onReminderChanged,
  });

  final UserPreferences preferences;
  final ValueChanged<int?> onReminderChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('默认日程提醒', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _PreferenceChip(
              label: '不提醒',
              selected: preferences.defaultScheduleReminderMinutes == null,
              onSelected: () => onReminderChanged(null),
            ),
            _PreferenceChip(
              label: '5 分钟',
              selected: preferences.defaultScheduleReminderMinutes == 5,
              onSelected: () => onReminderChanged(5),
            ),
            _PreferenceChip(
              label: '15 分钟',
              selected: preferences.defaultScheduleReminderMinutes == 15,
              onSelected: () => onReminderChanged(15),
            ),
            _PreferenceChip(
              label: '30 分钟',
              selected: preferences.defaultScheduleReminderMinutes == 30,
              onSelected: () => onReminderChanged(30),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreferenceChip extends StatelessWidget {
  const _PreferenceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
