import 'package:baiju_app/features/settings/domain/app_display_settings.dart';
import 'package:baiju_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsGeneralPage extends ConsumerWidget {
  const SettingsGeneralPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displaySettings = ref.watch(appDisplaySettingsProvider);
    final preferences = ref.watch(userPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('通用设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: displaySettings.when(
                data: (value) => _DisplaySettingsPanel(
                  settings: value,
                  onChanged: (next) => _saveDisplaySettings(context, ref, next),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text('显示设置加载失败：$error'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: preferences.when(
                data: (value) => _GeneralPreferencePanel(
                  preferences: value,
                  onAutoRolloverChanged: (enabled) => _savePreferences(
                    context,
                    ref,
                    value.copyWith(autoRolloverTodosToToday: enabled),
                    '已更新待办顺延规则',
                  ),
                  onAutoSyncChanged: (enabled) => _savePreferences(
                    context,
                    ref,
                    value.copyWith(autoSyncOnLaunch: enabled),
                    '已更新同步策略',
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text('通用偏好加载失败：$error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDisplaySettings(
    BuildContext context,
    WidgetRef ref,
    AppDisplaySettings settings,
  ) async {
    await ref.read(appSettingsActionsProvider).save(settings);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('首页显示设置已更新')));
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

class _DisplaySettingsPanel extends StatelessWidget {
  const _DisplaySettingsPanel({
    required this.settings,
    required this.onChanged,
  });

  final AppDisplaySettings settings;
  final ValueChanged<AppDisplaySettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('首页显示', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SwitchListTile(
          value: settings.showTodayHero,
          contentPadding: EdgeInsets.zero,
          title: const Text('显示今日首页头图'),
          onChanged: (value) =>
              onChanged(settings.copyWith(showTodayHero: value)),
        ),
        SwitchListTile(
          value: settings.showActiveTodoPreview,
          contentPadding: EdgeInsets.zero,
          title: const Text('显示进行中待办预览'),
          onChanged: (value) =>
              onChanged(settings.copyWith(showActiveTodoPreview: value)),
        ),
        SwitchListTile(
          value: settings.showUpcomingAnniversaries,
          contentPadding: EdgeInsets.zero,
          title: const Text('显示临近纪念日'),
          onChanged: (value) =>
              onChanged(settings.copyWith(showUpcomingAnniversaries: value)),
        ),
        SwitchListTile(
          value: settings.showRecentNotes,
          contentPadding: EdgeInsets.zero,
          title: const Text('显示最近笔记'),
          onChanged: (value) =>
              onChanged(settings.copyWith(showRecentNotes: value)),
        ),
      ],
    );
  }
}

class _GeneralPreferencePanel extends StatelessWidget {
  const _GeneralPreferencePanel({
    required this.preferences,
    required this.onAutoRolloverChanged,
    required this.onAutoSyncChanged,
  });

  final UserPreferences preferences;
  final ValueChanged<bool> onAutoRolloverChanged;
  final ValueChanged<bool> onAutoSyncChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('通用策略', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SwitchListTile(
          value: preferences.autoRolloverTodosToToday,
          contentPadding: EdgeInsets.zero,
          title: const Text('未完成待办自动顺延到今天'),
          onChanged: onAutoRolloverChanged,
        ),
        SwitchListTile(
          value: preferences.autoSyncOnLaunch,
          contentPadding: EdgeInsets.zero,
          title: const Text('启动时自动准备同步'),
          onChanged: onAutoSyncChanged,
        ),
      ],
    );
  }
}
