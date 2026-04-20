import 'dart:async';

import 'package:baiju_app/features/weather/domain/weather_models.dart';
import 'package:baiju_app/features/weather/infrastructure/weather_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>(
  (_) => WeatherRepository(),
);

// ── AsyncNotifier 基类：持有旧数据静默刷新 ──────────────────────────

abstract class _PollingNotifier<T> extends AsyncNotifier<T> {
  Duration get interval => const Duration(seconds: 5);
  Timer? _timer;

  Future<T> fetch();

  @override
  Future<T> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _refresh());
    return fetch();
  }

  Future<void> _refresh() async {
    // update() 保留旧数据，不会触发 loading 状态
    await update((_) => fetch());
  }
}

// ── 三个具体 provider ────────────────────────────────────────────────

final currentWeatherProvider =
    AsyncNotifierProvider<_CurrentWeatherNotifier, WeatherInfo?>(
  _CurrentWeatherNotifier.new,
);

class _CurrentWeatherNotifier extends _PollingNotifier<WeatherInfo?> {
  @override
  Future<WeatherInfo?> fetch() =>
      ref.read(weatherRepositoryProvider).fetchCurrentWeather();
}

final hourlyForecastProvider =
    AsyncNotifierProvider<_HourlyForecastNotifier, List<HourlyForecast>?>(
  _HourlyForecastNotifier.new,
);

class _HourlyForecastNotifier
    extends _PollingNotifier<List<HourlyForecast>?> {
  @override
  Future<List<HourlyForecast>?> fetch() =>
      ref.read(weatherRepositoryProvider).fetchHourlyForecast();
}

final forecast15Provider =
    AsyncNotifierProvider<_Forecast15Notifier, List<DailyForecast>?>(
  _Forecast15Notifier.new,
);

class _Forecast15Notifier extends _PollingNotifier<List<DailyForecast>?> {
  @override
  Future<List<DailyForecast>?> fetch() =>
      ref.read(weatherRepositoryProvider).fetchForecast(days: 15);
}
