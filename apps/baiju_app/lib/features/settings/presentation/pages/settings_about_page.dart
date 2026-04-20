import 'package:flutter/material.dart';

class SettingsAboutPage extends StatelessWidget {
  const SettingsAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于白驹')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: const <Widget>[
          _SectionCard(
            title: '白驹',
            child: Text(
              '白驹是一款本地优先的个人时间管理应用，整合日程、待办、习惯、纪念日、目标、笔记和时间线，帮助你建立统一、连续、可回顾的个人时间线。\n\n数据优先存储在本地，支持多端同步，离线也能正常使用。',
            ),
          ),
          SizedBox(height: 16),
          _SectionCard(
            title: '核心功能',
            child: _FeatureList(
              items: <String>[
                '今日 — 聚合今天的日程、待办和习惯，快速处理',
                '日程 — 日/周/月/年视图，支持重复和提醒',
                '待办 — 优先级、子任务、截止时间、关联目标',
                '习惯 — 每日打卡，连续天数统计，提醒',
                '纪念日 — 倒数天数，提前提醒重要日期',
                '目标 — 中长期目标，拆解为待办和习惯追踪进度',
                '笔记 — 日记、备忘录、想法记录，支持关联',
                '时间线 — 汇总所有模块事件，回顾生活轨迹',
              ],
            ),
          ),
          SizedBox(height: 16),
          _SectionCard(
            title: '版本信息',
            child: _InfoRow(items: <_InfoItem>[
              _InfoItem(label: '版本', value: 'V1.0'),
              _InfoItem(label: '平台', value: 'Android · iOS · Windows · macOS'),
              _InfoItem(label: '数据存储', value: '本地优先，支持云同步'),
            ]),
          ),
          SizedBox(height: 16),
          _SectionCard(
            title: '赞助与支持',
            child: Text(
              '如果白驹对你有帮助，欢迎通过赞助页支持我们继续开发。你的支持是我们持续改进的动力。',
            ),
          ),
        ],
      ),
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

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('• '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 80,
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Expanded(child: Text(item.value)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InfoItem {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;
}
