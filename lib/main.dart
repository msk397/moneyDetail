import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app/app.dart';
import 'src/widget/widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  final launchTarget = await WidgetBridge.consumeLaunchTarget();
  final initialTab = launchTarget == 'entry' ? 1 : 0;
  runApp(ProviderScope(child: MoneyDetailApp(initialTab: initialTab)));
}
