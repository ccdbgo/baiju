import 'dart:math' as math;

import 'package:baiju_app/features/weather/domain/weather_models.dart';
import 'package:baiju_app/features/weather/presentation/providers/weather_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class WeatherPage extends ConsumerStatefulWidget {
  const WeatherPage({super.key});

  @override
  ConsumerState<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends ConsumerState<WeatherPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ref.watch(currentWeatherProvider);

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('天气预报', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      current.maybeWhen(
                        data: (info) => info != null
                            ? Text(
                                '${info.condition.emoji}  ${info.temperatureCelsius.round()}°C  ${info.condition.label}'
                                '${info.locationName != null ? "  · ${info.locationName}" : ""}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_outlined),
                  tooltip: '刷新',
                  onPressed: () {
                    ref.invalidate(currentWeatherProvider);
                    ref.invalidate(forecast15Provider);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            tabs: const <Tab>[
              Tab(text: '今日详情'),
              Tab(text: '15 天预报'),
            ],
            padding: const EdgeInsets.symmetric(horizontal: 20),
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                _TodayDetailTab(),
                _Forecast15Tab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 1: 今日详情
// ─────────────────────────────────────────────

class _TodayDetailTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(currentWeatherProvider);
    final hourly = ref.watch(hourlyForecastProvider);
    final theme = Theme.of(context);

    return weather.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('天气获取失败，请检查位置权限或网络'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(currentWeatherProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (info) {
        if (info == null) {
          return const Center(child: Text('无法获取位置，天气不可用'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            // 主卡片：横向布局
            Card(
              color: info.hasSevereAlert
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: <Widget>[
                    Text(info.condition.emoji,
                        style: const TextStyle(fontSize: 52)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${info.temperatureCelsius.round()}°C',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: info.hasSevereAlert
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            info.condition.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: info.hasSevereAlert
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          if (info.hasSevereAlert) ...<Widget>[
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                Icon(Icons.warning_amber_rounded,
                                    size: 14, color: theme.colorScheme.error),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    info.alertMessage,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 指标卡片：两列紧凑网格
            Card(
              child: Column(
                children: <Widget>[
                  _MetricRow(
                    left: _MetricItem(
                      icon: Icons.thermostat_outlined,
                      label: '体感温度',
                      value: '${info.feelsLikeCelsius.round()}°C',
                    ),
                    right: _MetricItem(
                      icon: Icons.water_drop_outlined,
                      label: '相对湿度',
                      value: '${info.humidity.round()}%',
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _MetricRow(
                    left: _MetricItem(
                      icon: Icons.air_outlined,
                      label: '风速',
                      value: '${info.windSpeedKmh.round()} km/h',
                    ),
                    right: _MetricItem(
                      icon: Icons.wb_sunny_outlined,
                      label: '天气状况',
                      value: info.condition.label,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _MetricRow(
                    left: _MetricItem(
                      icon: Icons.thermostat,
                      label: '是否高温',
                      value: info.isExtremeHeat ? '是 ⚠️' : '否',
                    ),
                    right: _MetricItem(
                      icon: Icons.access_time_outlined,
                      label: '更新时间',
                      value: DateFormat('HH:mm:ss').format(info.fetchedAt),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 每小时预报
            _HourlyForecastCard(hourly: hourly),
          ],
        );
      },
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.left, required this.right});

  final _MetricItem left;
  final _MetricItem right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: <Widget>[
          Expanded(child: left),
          VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 每小时预报卡片
// ─────────────────────────────────────────────

class _HourlyForecastCard extends StatelessWidget {
  const _HourlyForecastCard({required this.hourly});

  final AsyncValue<List<HourlyForecast>?> hourly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              '每小时预报',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 110,
            child: hourly.when(
              skipLoadingOnRefresh: true,
              loading: () =>
                  const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) =>
                  const Center(child: Text('小时预报加载失败')),
              data: (items) {
                if (items == null || items.isEmpty) {
                  return const Center(child: Text('暂无数据'));
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final h = items[i];
                    final isNow = i == 0;
                    final timeLabel = isNow
                        ? '现在'
                        : DateFormat('HH:mm').format(h.time);
                    return Container(
                      width: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: isNow
                          ? BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            )
                          : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Text(
                            timeLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: isNow
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isNow
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          Text(
                            h.condition.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          Text(
                            '${h.temperatureCelsius.round()}°',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (h.precipitationMm > 0)
                            Text(
                              '${h.precipitationMm.toStringAsFixed(1)}mm',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontSize: 9,
                              ),
                            )
                          else
                            const SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 2: 15天预报
// ─────────────────────────────────────────────

class _Forecast15Tab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(forecast15Provider);

    return forecast.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('天气获取失败，请检查位置权限或网络'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(forecast15Provider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (days) {
        if (days == null || days.isEmpty) {
          return const Center(child: Text('无法获取位置，天气不可用'));
        }
        return Column(
          children: <Widget>[
            // 温度趋势图（横向滚动）
            SizedBox(
              height: 160,
              child: _TrendChart(days: days),
            ),
            const Divider(height: 1),
            // 列表
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 28),
                itemCount: days.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, i) =>
                    _DayTile(forecast: days[i], isToday: i == 0),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// 温度趋势图
// ─────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.days});

  final List<DailyForecast> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const colWidth = 56.0;
    final totalWidth = colWidth * days.length;

    final allTemps = <double>[
      for (final d in days) ...<double>[d.tempMax, d.tempMin],
    ];
    final globalMin = allTemps.reduce(math.min) - 2;
    final globalMax = allTemps.reduce(math.max) + 2;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: totalWidth,
        height: 160,
        child: CustomPaint(
          painter: _TrendPainter(
            days: days,
            globalMin: globalMin,
            globalMax: globalMax,
            maxColor: theme.colorScheme.error,
            minColor: theme.colorScheme.primary,
            gridColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          child: Row(
            children: List.generate(days.length, (i) {
              final d = days[i];
              final isToday = i == 0;
              final dateLabel = isToday
                  ? '今天'
                  : DateFormat('M/d', 'zh_CN').format(d.date);
              final weekLabel = isToday
                  ? ''
                  : DateFormat('EEE', 'zh_CN').format(d.date);
              return SizedBox(
                width: colWidth,
                child: Column(
                  children: <Widget>[
                    // 日期（顶部）
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        children: <Widget>[
                          Text(
                            dateLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (weekLabel.isNotEmpty)
                            Text(
                              weekLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // 天气图标（底部）
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        children: <Widget>[
                          Text(d.condition.emoji,
                              style: const TextStyle(fontSize: 18)),
                          Text(
                            '${d.tempMax.round()}°',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${d.tempMin.round()}°',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.days,
    required this.globalMin,
    required this.globalMax,
    required this.maxColor,
    required this.minColor,
    required this.gridColor,
  });

  final List<DailyForecast> days;
  final double globalMin;
  final double globalMax;
  final Color maxColor;
  final Color minColor;
  final Color gridColor;

  static const double colWidth = 56.0;
  // 曲线绘制区域：顶部留给日期(40px)，底部留给图标(52px)
  static const double topPad = 40.0;
  static const double bottomPad = 52.0;

  double _yFor(double temp, double height) {
    final chartH = height - topPad - bottomPad;
    final frac = (temp - globalMin) / (globalMax - globalMin);
    return topPad + chartH * (1 - frac);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // 水平参考线（0°C 和中间温度）
    for (final t in <double>[0, (globalMin + globalMax) / 2]) {
      if (t > globalMin && t < globalMax) {
        final y = _yFor(t, size.height);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // 最高温曲线
    _drawCurve(canvas, size,
        temps: days.map((d) => d.tempMax).toList(), color: maxColor);
    // 最低温曲线
    _drawCurve(canvas, size,
        temps: days.map((d) => d.tempMin).toList(), color: minColor);
  }

  void _drawCurve(Canvas canvas, Size size,
      {required List<double> temps, required Color color}) {
    if (temps.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final points = List.generate(temps.length, (i) {
      final x = colWidth * i + colWidth / 2;
      final y = _yFor(temps[i], size.height);
      return Offset(x, y);
    });

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cpX = (prev.dx + curr.dx) / 2;
      path.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(path, paint);

    // 端点圆点
    final dotPaint = Paint()..color = color;
    for (final p in points) {
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.days != days;
}

// ─────────────────────────────────────────────
// 列表行
// ─────────────────────────────────────────────

class _DayTile extends StatelessWidget {
  const _DayTile({required this.forecast, required this.isToday});

  final DailyForecast forecast;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = isToday
        ? '今天'
        : DateFormat('M月d日 EEE', 'zh_CN').format(forecast.date);
    final isSevere = forecast.hasSevereAlert;

    return Container(
      color: isSevere
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.25)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 84,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    dateLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday ? theme.colorScheme.primary : null,
                    ),
                  ),
                  if (isSevere)
                    Text(
                      '⚠️ 预警',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            Text(forecast.condition.emoji,
                style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                forecast.condition.label,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (forecast.precipitationMm > 0) ...<Widget>[
              Icon(Icons.water_drop_outlined,
                  size: 13, color: theme.colorScheme.primary),
              const SizedBox(width: 2),
              Text(
                '${forecast.precipitationMm.toStringAsFixed(1)}mm',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              '${forecast.tempMin.round()}°',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 4),
            _TempBar(
              min: forecast.tempMin,
              max: forecast.tempMax,
              globalMin: -10,
              globalMax: 45,
            ),
            const SizedBox(width: 4),
            Text(
              '${forecast.tempMax.round()}°',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TempBar extends StatelessWidget {
  const _TempBar({
    required this.min,
    required this.max,
    required this.globalMin,
    required this.globalMax,
  });

  final double min;
  final double max;
  final double globalMin;
  final double globalMax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = globalMax - globalMin;
    final startFrac = ((min - globalMin) / range).clamp(0.0, 1.0);
    final endFrac = ((max - globalMin) / range).clamp(0.0, 1.0);

    return SizedBox(
      width: 56,
      height: 6,
      child: CustomPaint(
        painter: _BarPainter(
          startFrac: startFrac,
          endFrac: endFrac,
          trackColor: theme.colorScheme.surfaceContainerHighest,
          barColor: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.startFrac,
    required this.endFrac,
    required this.trackColor,
    required this.barColor,
  });

  final double startFrac;
  final double endFrac;
  final Color trackColor;
  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(r)),
      Paint()..color = trackColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startFrac * size.width, 0,
            (endFrac - startFrac) * size.width, size.height),
        Radius.circular(r),
      ),
      Paint()..color = barColor,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.startFrac != startFrac || old.endFrac != endFrac;
}
