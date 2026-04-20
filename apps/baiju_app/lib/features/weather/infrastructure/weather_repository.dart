import 'dart:convert';

import 'package:baiju_app/features/weather/domain/weather_models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherRepository {
  WeatherRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Fetch current weather. Returns null if location permission denied or
  /// network unavailable.
  Future<WeatherInfo?> fetchCurrentWeather() async {
    final position = await _getPosition();
    final lat = position?.latitude ?? _fallbackLat;
    final lon = position?.longitude ?? _fallbackLon;
    final city = position == null ? _fallbackCity : null;

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,apparent_temperature,relative_humidity_2m,'
      'wind_speed_10m,weather_code'
      '&wind_speed_unit=kmh'
      '&timezone=auto',
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;

    final wmoCode = (current['weather_code'] as num).toInt();
    return WeatherInfo(
      condition: WeatherCondition.fromWmoCode(wmoCode),
      temperatureCelsius: (current['temperature_2m'] as num).toDouble(),
      feelsLikeCelsius: (current['apparent_temperature'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toDouble(),
      windSpeedKmh: (current['wind_speed_10m'] as num).toDouble(),
      fetchedAt: DateTime.now(),
      locationName: city,
    );
  }

  /// Fetch hourly forecast for today (next 24 hours).
  Future<List<HourlyForecast>?> fetchHourlyForecast() async {
    final position = await _getPosition();
    final lat = position?.latitude ?? _fallbackLat;
    final lon = position?.longitude ?? _fallbackLon;

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&hourly=temperature_2m,weather_code,precipitation,relative_humidity_2m,wind_speed_10m'
      '&wind_speed_unit=kmh'
      '&forecast_days=2'
      '&timezone=auto',
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;

    final times = hourly['time'] as List<dynamic>;
    final codes = hourly['weather_code'] as List<dynamic>;
    final temps = hourly['temperature_2m'] as List<dynamic>;
    final precip = hourly['precipitation'] as List<dynamic>;
    final humidity = hourly['relative_humidity_2m'] as List<dynamic>;
    final wind = hourly['wind_speed_10m'] as List<dynamic>;

    final now = DateTime.now();
    final result = <HourlyForecast>[];
    for (int i = 0; i < times.length; i++) {
      final t = DateTime.parse(times[i] as String);
      // 只取从当前小时起的 24 小时
      if (t.isBefore(DateTime(now.year, now.month, now.day, now.hour))) continue;
      if (result.length >= 24) break;
      result.add(HourlyForecast(
        time: t,
        condition: WeatherCondition.fromWmoCode((codes[i] as num).toInt()),
        temperatureCelsius: (temps[i] as num).toDouble(),
        precipitationMm: (precip[i] as num?)?.toDouble() ?? 0,
        humidity: (humidity[i] as num).toDouble(),
        windSpeedKmh: (wind[i] as num).toDouble(),
      ));
    }
    return result;
  }

  /// Fetch daily forecast for [days] days (max 16 via Open-Meteo).
  Future<List<DailyForecast>?> fetchForecast({int days = 7}) async {
    final position = await _getPosition();
    final lat = position?.latitude ?? _fallbackLat;
    final lon = position?.longitude ?? _fallbackLon;

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,'
      'precipitation_sum,wind_speed_10m_max,uv_index_max'
      '&wind_speed_unit=kmh'
      '&forecast_days=$days'
      '&timezone=auto',
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    final dates = daily['time'] as List<dynamic>;
    final codes = daily['weather_code'] as List<dynamic>;
    final maxTemps = daily['temperature_2m_max'] as List<dynamic>;
    final minTemps = daily['temperature_2m_min'] as List<dynamic>;
    final precip = daily['precipitation_sum'] as List<dynamic>;
    final wind = daily['wind_speed_10m_max'] as List<dynamic>;
    final uv = daily['uv_index_max'] as List<dynamic>;

    return List.generate(dates.length, (i) {
      return DailyForecast(
        date: DateTime.parse(dates[i] as String),
        condition: WeatherCondition.fromWmoCode((codes[i] as num).toInt()),
        tempMax: (maxTemps[i] as num).toDouble(),
        tempMin: (minTemps[i] as num).toDouble(),
        precipitationMm: (precip[i] as num?)?.toDouble() ?? 0,
        windSpeedMax: (wind[i] as num).toDouble(),
        uvIndex: (uv[i] as num?)?.toDouble() ?? 0,
      );
    });
  }

  Future<Position?> _getPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Fallback position (Beijing) used when geolocation is unavailable.
  static const _fallbackLat = 39.9042;
  static const _fallbackLon = 116.4074;
  static const _fallbackCity = '北京（默认位置）';
}
