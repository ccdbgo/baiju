import 'package:baiju_app/app/app.dart';
import 'package:baiju_app/app/bootstrap/bootstrap.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  final environment = await AppBootstrap.initialize();
  runApp(
    ProviderScope(
      child: BaijuApp(environment: environment),
    ),
  );
}
