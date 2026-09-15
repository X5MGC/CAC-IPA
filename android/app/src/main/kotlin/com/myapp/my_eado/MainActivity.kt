package com.myapp.my_eado

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.myapp.my_eado.widget.WidgetSlotBase

class MainActivity: FlutterActivity() {
    private var pendingAction: String? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 引擎就绪后立刻刷新桌面小组件
        android.os.Handler(mainLooper).postDelayed({
            try {
                WidgetSlotBase.updateAllWidgets(this)
                java.io.File(cacheDir, "widget_debug.txt")
                    .writeText("engine_ready ${System.currentTimeMillis()}\n")
            } catch (e: Exception) {
                java.io.File(cacheDir, "widget_debug.txt")
                    .writeText("engine_err $e\n")
            }
        }, 300)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.myapp.my_eado/widget")
        methodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    "createWidget" -> {
                        val title = call.argument<String>("title") ?: "MyEADO"
                        val size = call.argument<String>("size") ?: "1x1"
                        val buttons = call.argument<String>("buttons") ?: ""
                        val positions = call.argument<String>("positions") ?: ""
                        val slot = findFreeSlot()
                        if (slot == 0) {
                            result.success(0)
                            return@setMethodCallHandler
                        }
                        getSharedPreferences("widget_slot_$slot", Context.MODE_PRIVATE).edit()
                            .putString("title", title)
                            .putString("size", size)
                            .putString("buttons", buttons)
                            .putString("positions", positions)
                            .apply()
                        // 启用组件
                        setSlotEnabled(slot, true)
                        // 请求pin
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val manager = AppWidgetManager.getInstance(this)
                            val cls = ComponentName(this,
                                "${packageName}.widget.WidgetSlot${slot.toString().padStart(2, '0')}")
                            if (manager.isRequestPinAppWidgetSupported) {
                                manager.requestPinAppWidget(cls, null, null)
                            }
                        }
                        // 延迟刷新，保证 pin 后立刻有内容
                        android.os.Handler(mainLooper).postDelayed({
                            WidgetSlotBase.updateAllWidgets(this)
                        }, 800)
                        result.success(slot)
                    }
                    "saveWidgetSlot" -> {
                        val slot = call.argument<Int>("slot") ?: 0
                        val title = call.argument<String>("title") ?: "MyEADO"
                        val size = call.argument<String>("size") ?: "1x1"
                        val buttons = call.argument<String>("buttons") ?: ""
                        val positions = call.argument<String>("positions") ?: ""
                        if (slot in 1..20) {
                            getSharedPreferences("widget_slot_$slot", Context.MODE_PRIVATE).edit()
                                .putString("title", title)
                                .putString("size", size)
                                .putString("buttons", buttons)
                                .putString("positions", positions)
                                .apply()
                            WidgetSlotBase.updateAllWidgets(this)
                        }
                        result.success(true)
                    }
                    "deleteWidgetSlot" -> {
                        val slot = call.argument<Int>("slot") ?: 0
                        if (slot in 1..20) {
                            getSharedPreferences("widget_slot_$slot", Context.MODE_PRIVATE).edit().clear().apply()
                            setSlotEnabled(slot, false)
                            WidgetSlotBase.updateAllWidgets(this)
                        }
                        result.success(true)
                    }
                    "refreshAllWidgets" -> {
                        WidgetSlotBase.updateAllWidgets(this)
                        result.success(true)
                    }
                    "getActiveWidgets" -> {
                        val widgets = mutableListOf<Map<String, Any>>()
                        for (i in 1..20) {
                            val prefs = getSharedPreferences("widget_slot_$i", Context.MODE_PRIVATE)
                            val buttons = prefs.getString("buttons", "") ?: ""
                            if (buttons.isNotEmpty()) {
                                widgets.add(mapOf(
                                    "slot" to i,
                                    "title" to (prefs.getString("title", "MyEADO") ?: "MyEADO"),
                                    "size" to (prefs.getString("size", "1x1") ?: "1x1"),
                                    "buttons" to buttons,
                                    "positions" to (prefs.getString("positions", "") ?: ""),
                                ))
                            }
                        }
                        result.success(widgets)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun findFreeSlot(): Int {
        for (i in 1..20) {
            val prefs = getSharedPreferences("widget_slot_$i", Context.MODE_PRIVATE)
            val buttons = prefs.getString("buttons", "") ?: ""
            if (buttons.isEmpty()) return i
        }
        return 0
    }

    private fun setSlotEnabled(slot: Int, enabled: Boolean) {
        val cls = ComponentName(this,
            "${packageName}.widget.WidgetSlot${slot.toString().padStart(2, '0')}")
        val state = if (enabled)
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        else
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        packageManager.setComponentEnabledSetting(cls, state, PackageManager.DONT_KILL_APP)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent?.action, intent)
        window.decorView.systemUiVisibility = (
            android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )
        window.navigationBarColor = android.graphics.Color.TRANSPARENT
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        // 启动后刷新桌面小组件，避免一直空白
        android.os.Handler(mainLooper).postDelayed({
            try { WidgetSlotBase.updateAllWidgets(this) } catch (_: Exception) {}
        }, 500)
    }

    override fun onResume() {
        super.onResume()
        try { WidgetSlotBase.updateAllWidgets(this) } catch (_: Exception) {}
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        val actionStr = handleIntent(intent.action, intent)
        // 热启动（引擎已就绪）：立即推送给Flutter
        if (actionStr != null) {
            methodChannel?.invokeMethod("onWidgetAction", actionStr)
        }
    }

    /** 解析intent并保存pendingAction，返回归一化的action字符串 */
    private fun handleIntent(action: String?, intent: android.content.Intent? = null): String? {
        val actionStr = when (action) {
            "com.myapp.my_eado.WIDGET_CONFIG" -> "widget_config"
            "com.myapp.my_eado.WIDGET_CONTROL" -> {
                val command = intent?.getStringExtra("command") ?: ""
                "widget_control:$command"
            }
            else -> null
        }
        if (actionStr != null) {
            pendingAction = actionStr
        }
        return actionStr
    }
}
