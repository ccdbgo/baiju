import 'package:baiju_app/app/app.dart';
import 'package:baiju_app/app/bootstrap/bootstrap.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  await initializeDateFormatting('zh_CN');
  final environment = await AppBootstrap.initialize();
  runApp(
    ProviderScope(
      child: BaijuApp(environment: environment),
    ),
  );
}
