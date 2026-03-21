package com.mcdetail.moneydetail

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.widget.EditText

class WidgetQuickEntryActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val input = EditText(this).apply {
            hint = "例如：早餐豆浆油条 12 元"
            setSingleLine(true)
            inputType = InputType.TYPE_CLASS_TEXT
        }

        AlertDialog.Builder(this)
            .setTitle("快速记一笔")
            .setView(input)
            .setNegativeButton("取消") { _, _ -> finish() }
            .setPositiveButton("继续") { _, _ ->
                val text = input.text?.toString()?.trim().orEmpty()
                if (text.isNotEmpty()) {
                    val prefs = getSharedPreferences("widget_launch", MODE_PRIVATE)
                    prefs.edit()
                        .putString("launch_target", "entry")
                        .putString("quick_input_text", text)
                        .apply()
                }

                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra("open_tab", "entry")
                }
                startActivity(intent)
                finish()
            }
            .setOnCancelListener { finish() }
            .show()
    }
}
