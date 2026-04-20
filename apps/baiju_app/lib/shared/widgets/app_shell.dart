import 'package:baiju_app/features/user/presentation/widgets/user_avatar_button.dart';
import 'package:baiju_app/shared/constants/app_breakpoints.dart';
import 'package:baiju_app/shared/constants/app_constants.dart';
import 'package:baiju_app/shared/widgets/quick_create_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<_ShellItem> _items = <_ShellItem>[
    _ShellItem(
      label: '今日',
      icon: Icons.today_outlined,
      selectedIcon: Icons.today,
      branchIndex: 0,
    ),
    _ShellItem(
      label: '日程',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      branchIndex: 1,
    ),
    _ShellItem(
      label: '待办',
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      branchIndex: 2,
    ),
    _ShellItem(
      label: '习惯',
      icon: Icons.bolt_outlined,
      selectedIcon: Icons.bolt,
      branchIndex: 3,
    ),
    _ShellItem(
      label: '纪念日',
      icon: Icons.celebration_outlined,
      selectedIcon: Icons.celebration,
      branchIndex: 4,
    ),
    _ShellItem(
      label: '目标',
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag,
      branchIndex: 5,
    ),
    _ShellItem(
      label: '笔记',
      icon: Icons.note_alt_outlined,
      selectedIcon: Icons.note_alt,
      branchIndex: 6,
    ),
    _ShellItem(
      label: '时间线',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
      branchIndex: 7,
    ),
    _ShellItem(
      label: '天气',
      icon: Icons.wb_sunny_outlined,
      selectedIcon: Icons.wb_sunny,
      branchIndex: 8,
    ),
    _ShellItem(
      label: '设置',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      branchIndex: 9,
    ),
  ];

  static const List<_ShellItem> _compactPrimaryItems = <_ShellItem>[
    _ShellItem(
      label: '今日',
      icon: Icons.today_outlined,
      selectedIcon: Icons.today,
      branchIndex: 0,
    ),
    _ShellItem(
      label: '日程',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      branchIndex: 1,
    ),
    _ShellItem(
      label: '待办',
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      branchIndex: 2,
    ),
    _ShellItem(
      label: '时间线',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights,
      branchIndex: 7,
    ),
    _ShellItem(
      label: '更多',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      branchIndex: null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_items[navigationShell.currentIndex].label),
          actions: <Widget>[
            IconButton(
              onPressed: () => _openFeatureNavigator(context),
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: '全部功能',
            ),
            IconButton(
              onPressed: () => _openQuickCreate(context),
              icon: const Icon(Icons.add),
              tooltip: '快速新增',
            ),
            const UserAvatarButton(),
          ],
        ),
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _compactSelectedIndex,
          destinations: _compactPrimaryItems
              .map(
                (item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
              )
              .toList(),
          onDestinationSelected: (index) => _onCompactTap(context, index),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: <Widget>[
            Container(
              width: 132,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppConstants.appName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  Expanded(
                    child: NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      labelType: NavigationRailLabelType.all,
                      destinations: _items
                          .map(
                            (item) => NavigationRailDestination(
                              icon: Icon(item.icon),
                              selectedIcon: Icon(item.selectedIcon),
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                      onDestinationSelected: _onTap,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _items[navigationShell.currentIndex].label,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _openQuickCreate(context),
                          icon: const Icon(Icons.add),
                          label: const Text('快速新增'),
                        ),
                        const SizedBox(width: 8),
                        const UserAvatarButton(),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  int get _compactSelectedIndex {
    switch (navigationShell.currentIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2;
      case 7:
        return 3;
      default:
        return 4;
    }
  }

  void _onCompactTap(BuildContext context, int index) {
    final item = _compactPrimaryItems[index];
    if (item.branchIndex == null) {
      _openFeatureNavigator(context);
      return;
    }
    _onTap(item.branchIndex!);
  }

  Future<void> _openQuickCreate(BuildContext context) async {
    final message = await showQuickCreateSheet(context);
    if (!context.mounted || message == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openFeatureNavigator(BuildContext context) async {
    final branchIndex = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('全部功能', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '移动端底部保留高频入口，其余模块从这里快速进入。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _items.map((item) {
                    final isActive =
                        item.branchIndex == navigationShell.currentIndex;
                    return SizedBox(
                      width: 148,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: item.branchIndex == null
                            ? null
                            : () => Navigator.of(context).pop(item.branchIndex),
                        child: Card(
                          color: isActive
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  isActive ? item.selectedIcon : item.icon,
                                  size: 24,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  item.label,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isActive ? '当前所在模块' : '点击进入',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (branchIndex == null) {
      return;
    }
    _onTap(branchIndex);
  }
}

class _ShellItem {
  const _ShellItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.branchIndex,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int? branchIndex;
}
