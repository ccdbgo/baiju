import 'package:baiju_app/features/settings/domain/app_support_draft.dart';
import 'package:baiju_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsSupportPage extends ConsumerStatefulWidget {
  const SettingsSupportPage({super.key});

  @override
  ConsumerState<SettingsSupportPage> createState() =>
      _SettingsSupportPageState();
}

class _SettingsSupportPageState extends ConsumerState<SettingsSupportPage> {
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(appSupportDraftProvider);

    draft.whenData((value) {
      if (_hydrated) {
        return;
      }
      _contactController.text = value.contact;
      _messageController.text = value.message;
      _hydrated = true;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('赞助与支持')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          const _SectionCard(
            title: '支持说明',
            child: Text(
              '如果你有建议或遇到问题，可以在这里整理反馈内容，或通过下方入口联系我们。',
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '常用去向',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/settings/notifications'),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('提醒中心'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/settings/account'),
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('账号与同步'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/settings/about'),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('关于应用'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionCard(
            title: '版本路线图',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ChangelogItem(
                  version: 'V1.0（当前）',
                  items: <String>[
                    '今日视图：日程、待办、习惯一体化',
                    '多用户隔离与密码保护',
                    '习惯打卡与连续天数统计',
                    '目标进度追踪',
                    '纪念日倒计时',
                    '笔记与时间线',
                    '日程转待办、同步打卡、顺延',
                  ],
                ),
                SizedBox(height: 12),
                _ChangelogItem(
                  version: 'V1.1（计划中）',
                  items: <String>[
                    '今日复盘模块',
                    '数据统计与图表',
                    '云端同步',
                    '小组件支持',
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '反馈草稿',
            child: draft.when(
              data: (value) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _DraftSnapshotCard(
                    draft: value,
                    contact: _contactController.text,
                    message: _messageController.text,
                  ),
                  const SizedBox(height: 12),
                  _SupportDraftPanel(
                    draft: value,
                    contactController: _contactController,
                    messageController: _messageController,
                    onCategoryChanged: (category) =>
                        _saveDraft(value.copyWith(category: category)),
                    onSave: () => _saveDraft(
                      value.copyWith(
                        contact: _contactController.text,
                        message: _messageController.text,
                      ),
                    ),
                    onCopy: () => _copyDraft(context, value),
                    onClear: _clearDraft,
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('反馈草稿加载失败：$error'),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionCard(
            title: '当前阶段',
            child: Text(
              '白驹当前仍处于快速迭代阶段，现阶段优先把核心模块闭环、交互体验和测试覆盖做完整，再决定正式的支持与商业化页面样式。',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraft(AppSupportDraft draft) async {
    await ref.read(appSettingsActionsProvider).saveSupportDraft(draft);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('反馈草稿已保存')));
    }
  }

  Future<void> _clearDraft() async {
    _contactController.clear();
    _messageController.clear();
    await ref.read(appSettingsActionsProvider).clearSupportDraft();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('反馈草稿已清空')));
    }
  }

  Future<void> _copyDraft(BuildContext context, AppSupportDraft draft) async {
    final text =
        '''
反馈类型：${draft.category.label}
联系方式：${_contactController.text.trim()}
反馈内容：
${_messageController.text.trim()}
''';
    await Clipboard.setData(ClipboardData(text: text.trim()));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('反馈摘要已复制')));
    }
  }
}

class _ChangelogItem extends StatelessWidget {
  const _ChangelogItem({required this.version, required this.items});

  final String version;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(version, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('• '),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DraftSnapshotCard extends StatelessWidget {
  const _DraftSnapshotCard({
    required this.draft,
    required this.contact,
    required this.message,
  });

  final AppSupportDraft draft;
  final String contact;
  final String message;

  @override
  Widget build(BuildContext context) {
    final normalizedContact = contact.trim();
    final normalizedMessage = message.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          Chip(label: Text('分类：${draft.category.label}')),
          Chip(
            label: Text('联系方式：${normalizedContact.isEmpty ? '未填写' : '已填写'}'),
          ),
          Chip(label: Text('内容长度：${normalizedMessage.length}')),
        ],
      ),
    );
  }
}

class _SupportDraftPanel extends StatelessWidget {
  const _SupportDraftPanel({
    required this.draft,
    required this.contactController,
    required this.messageController,
    required this.onCategoryChanged,
    required this.onSave,
    required this.onCopy,
    required this.onClear,
  });

  final AppSupportDraft draft;
  final TextEditingController contactController;
  final TextEditingController messageController;
  final ValueChanged<SupportCategory> onCategoryChanged;
  final VoidCallback onSave;
  final VoidCallback onCopy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SupportCategory.values.map((item) {
            return ChoiceChip(
              label: Text(item.label),
              selected: item == draft.category,
              onSelected: (_) => onCategoryChanged(item),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: contactController,
          decoration: const InputDecoration(
            labelText: '联系方式',
            hintText: '邮箱、微信或其他联系信息',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: messageController,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '反馈内容',
            hintText: '尽量描述复现步骤、期望结果或建议方向',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton(onPressed: onSave, child: const Text('保存草稿')),
            OutlinedButton(onPressed: onCopy, child: const Text('复制摘要')),
            TextButton(onPressed: onClear, child: const Text('清空')),
          ],
        ),
      ],
    );
  }
}
