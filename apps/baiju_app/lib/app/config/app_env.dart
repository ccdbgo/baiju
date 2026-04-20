import 'package:baiju_app/app/config/app_environment.dart';
import 'package:baiju_app/app/config/env_dev.dart';
import 'package:baiju_app/app/config/env_prod.dart';
import 'package:baiju_app/app/config/env_staging.dart';

AppEnvironment resolveAppEnvironment([String? name]) {
  final environmentName =
      name ?? const String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  switch (environmentName) {
    case 'prod':
      return prodEnvironment;
    case 'staging':
      return stagingEnvironment;
    case 'dev':
    default:
      return devEnvironment;
  }
}
