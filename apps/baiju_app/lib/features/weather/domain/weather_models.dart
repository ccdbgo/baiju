/// WMO Weather interpretation codes mapped to a simplified condition.
enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  heavyRain,
  snow,
  heavySnow,
  thunderstorm,
  hail,
  unknown;

  bool get isSevere {
    switch (this) {
      case WeatherCondition.heavyRain:
      case WeatherCondition.snow:
      case WeatherCondition.heavySnow:
      case WeatherCondition.thunderstorm:
      case WeatherCondition.hail:
        return true;
      default:
        return false;
    }
  }

  String get label {
    switch (this) {
      case WeatherCondition.clear:
        return '晴';
      case WeatherCondition.partlyCloudy:
        return '多云';
      case WeatherCondition.cloudy:
        return '阴';
      case WeatherCondition.fog:
        return '雾';
      case WeatherCondition.drizzle:
        return '小雨';
      case WeatherCondition.rain:
        return '中雨';
      case WeatherCondition.heavyRain:
        return '大雨/暴雨';
      case WeatherCondition.snow:
        return '小雪';
      case WeatherCondition.heavySnow:
        return '大雪/暴雪';
      case WeatherCondition.thunderstorm:
        return '雷暴';
      case WeatherCondition.hail:
        return '冰雹';
      case WeatherCondition.unknown:
        return '未知';
    }
  }

  String get emoji {
    switch (this) {
      case WeatherCondition.clear:
        return '☀️';
      case WeatherCondition.partlyCloudy:
        return '⛅';
      case WeatherCondition.cloudy:
        return '☁️';
      case WeatherCondition.fog:
        return '🌫️';
      case WeatherCondition.drizzle:
        return '🌦️';
      case WeatherCondition.rain:
        return '🌧️';
      case WeatherCondition.heavyRain:
        return '⛈️';
      case WeatherCondition.snow:
        return '🌨️';
      case WeatherCondition.heavySnow:
        return '❄️';
      case WeatherCondition.thunderstorm:
        return '⛈️';
      case WeatherCondition.hail:
        return '🌩️';
      case WeatherCondition.unknown:
        return '🌡️';
    }
  }

  static WeatherCondition fromWmoCode(int code) {
    if (code == 0) return WeatherCondition.clear;
    if (code <= 2) return WeatherCondition.partlyCloudy;
    if (code == 3) return WeatherCondition.cloudy;
    if (code >= 45 && code <= 48) return WeatherCondition.fog;
    if (code >= 51 && code <= 57) return WeatherCondition.drizzle;
    if (code >= 61 && code <= 65) {
      return code >= 63 ? WeatherCondition.heavyRain : WeatherCondition.rain;
    }
    if (code >= 66 && code <= 67) return WeatherCondition.rain;
    if (code >= 71 && code <= 75) {
      return code >= 73 ? WeatherCondition.heavySnow : WeatherCondition.snow;
    }
    if (code == 77) return WeatherCondition.snow;
    if (code >= 80 && code <= 82) {
      return code == 82 ? WeatherCondition.heavyRain : WeatherCondition.rain;
    }
    if (code >= 85 && code <= 86) return WeatherCondition.heavySnow;
    if (code >= 95 && code <= 99) {
      return code >= 96 ? WeatherCondition.hail : WeatherCondition.thunderstorm;
    }
    return WeatherCondition.unknown;
  }
}

class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.condition,
    required this.temperatureCelsius,
    required this.precipitationMm,
    required this.humidity,
    required this.windSpeedKmh,
  });

  final DateTime time;
  final WeatherCondition condition;
  final double temperatureCelsius;
  final double precipitationMm;
  final double humidity;
  final double windSpeedKmh;
}

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.condition,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationMm,
    required this.windSpeedMax,
    required this.uvIndex,
  });

  final DateTime date;
  final WeatherCondition condition;
  final double tempMax;
  final double tempMin;
  final double precipitationMm;
  final double windSpeedMax;
  final double uvIndex;

  bool get hasSevereAlert =>
      condition.isSevere || tempMax > 38 || tempMin < -10 || windSpeedMax > 60;
}

class WeatherInfo {
  const WeatherInfo({
    required this.condition,
    required this.temperatureCelsius,
    required this.feelsLikeCelsius,
    required this.humidity,
    required this.windSpeedKmh,
    required this.fetchedAt,
    this.locationName,
  });

  final WeatherCondition condition;
  final double temperatureCelsius;
  final double feelsLikeCelsius;
  final double humidity;
  final double windSpeedKmh;
  final DateTime fetchedAt;
  final String? locationName;

  bool get isExtremeCold => temperatureCelsius < -10;
  bool get isExtremeHeat => temperatureCelsius > 38;
  bool get isStrongWind => windSpeedKmh > 60;

  bool get hasSevereAlert =>
      condition.isSevere || isExtremeCold || isExtremeHeat || isStrongWind;

  String get alertMessage {
    final alerts = <String>[];
    if (condition.isSevere) alerts.add('${condition.label}天气');
    if (isExtremeHeat) alerts.add('高温预警（${temperatureCelsius.round()}°C）');
    if (isExtremeCold) alerts.add('低温预警（${temperatureCelsius.round()}°C）');
    if (isStrongWind) alerts.add('大风预警（${windSpeedKmh.round()} km/h）');
    return alerts.join('、');
  }
}
