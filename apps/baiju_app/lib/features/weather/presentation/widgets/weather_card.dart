import 'package:baiju_app/features/weather/domain/weather_models.dart';
import 'package:baiju_app/features/weather/presentation/providers/weather_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeatherCard extends ConsumerWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(currentWeatherProvider);
    final theme = Theme.of(context);

    return weather.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('正在获取天气...'),
            ],
          ),
        ),
      ),
      error: (_, __) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(Icons.cloud_off_outlined, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '天气获取失败（请检查位置权限）',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () => ref.invalidate(currentWeatherProvider),
                tooltip: '重试',
              ),
            ],
          ),
        ),
      ),
      data: (info) {
        if (info == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.location_off_outlined,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '无法获取位置，天气不可用',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return _WeatherContent(info: info, onRefresh: () => ref.invalidate(currentWeatherProvider));
      },
    );
  }
}

class _WeatherContent extends StatelessWidget {
  const _WeatherContent({required this.info, required this.onRefresh});

  final WeatherInfo info;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSevere = info.hasSevereAlert;
    final cardColor = isSevere
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerLow;
    final textColor = isSevere
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(info.condition.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${info.temperatureCelsius.round()}°C  ${info.condition.label}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '体感 ${info.feelsLikeCelsius.round()}°C · 湿度 ${info.humidity.round()}% · 风速 ${info.windSpeedKmh.round()} km/h',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 18, color: textColor.withValues(alpha: 0.6)),
                  onPressed: onRefresh,
                  tooltip: '刷新天气',
                ),
              ],
            ),
            if (isSevere) ...<Widget>[
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Icon(Icons.warning_amber_rounded, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '恶劣天气提醒：${info.alertMessage}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
