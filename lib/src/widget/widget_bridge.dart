import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetBridge {
  static const _channel = MethodChannel('com.mcdetail.moneydetail/widget');
  static const _todayKey = 'widget_today_total';
  static const _monthKey = 'widget_month_total';

  static Future<void> updateTotals({
    required double today,
    required double month,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_todayKey, today);
    await prefs.setDouble(_monthKey, month);
    await _channel.invokeMethod<void>('requestWidgetUpdate');
  }

  static Future<String> consumeLaunchTarget() async {
    final value = await _channel.invokeMethod<String>('consumeLaunchTarget');
    return value ?? '';
  }

  static Future<String> consumePendingQuickInput() async {
    final value = await _channel.invokeMethod<String>('consumePendingQuickInput');
    return value ?? '';
  }
}
