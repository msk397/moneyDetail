package com.mcdetail.moneydetail

import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "com.mcdetail.moneydetail/widget"
	private val launchTargetKey = "launch_target"
	private val quickInputKey = "quick_input_text"

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		ExpenseWidgetProvider.requestUpdate(this)
		cacheLaunchTarget(intent?.getStringExtra("open_tab"))
	}

	override fun onNewIntent(intent: android.content.Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		ExpenseWidgetProvider.requestUpdate(this)
		cacheLaunchTarget(intent.getStringExtra("open_tab"))
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"requestWidgetUpdate" -> {
						ExpenseWidgetProvider.requestUpdate(this)
						result.success(null)
					}

					"consumeLaunchTarget" -> {
						val prefs = getSharedPreferences("widget_launch", MODE_PRIVATE)
						val value = prefs.getString(launchTargetKey, "") ?: ""
						prefs.edit().remove(launchTargetKey).apply()
						result.success(value)
					}

					"consumePendingQuickInput" -> {
						val prefs = getSharedPreferences("widget_launch", MODE_PRIVATE)
						val value = prefs.getString(quickInputKey, "") ?: ""
						prefs.edit().remove(quickInputKey).apply()
						result.success(value)
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun cacheLaunchTarget(target: String?) {
		if (target.isNullOrBlank()) return
		val prefs = getSharedPreferences("widget_launch", MODE_PRIVATE)
		prefs.edit().putString(launchTargetKey, target).apply()
	}
}
