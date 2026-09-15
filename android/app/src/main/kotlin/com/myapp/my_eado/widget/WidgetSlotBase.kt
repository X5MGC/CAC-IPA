package com.myapp.my_eado.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import com.myapp.my_eado.MainActivity
import com.myapp.my_eado.R
import kotlin.math.roundToInt

/**
 * 桌面小组件自适应网格：
 * - 格数 = 宽格数 × 高格数（上限 8）
 * - 每行个数 = 宽格数
 * - 信息/控制统一占格，按加入顺序填充
 * - 新建页 size 仅预览；桌面以拖拽后 options 为准
 */
abstract class WidgetSlotBase : AppWidgetProvider() {
    abstract val slotNumber: Int

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            renderWidget(context, manager, id, slotNumber, manager.getAppWidgetOptions(id))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        renderWidget(context, manager, appWidgetId, slotNumber, newOptions)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        try {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, this.javaClass))
            onUpdate(context, manager, ids)
        } catch (e: Exception) {
            Log.e(TAG, "onReceive error slot=$slotNumber", e)
        }
    }

    companion object {
        private const val TAG = "WidgetSlot"

        private fun iconForControl(btnId: String): Int = when (btnId) {
            "ctrl_lock" -> R.drawable.widget_ic_lock
            "ctrl_unlock" -> R.drawable.widget_ic_unlock
            "ctrl_ignition_on" -> R.drawable.widget_ic_ignition_on
            "ctrl_ignition_off" -> R.drawable.widget_ic_ignition_off
            "ctrl_window_open" -> R.drawable.widget_ic_window_open
            "ctrl_window_half" -> R.drawable.widget_ic_window_open
            "ctrl_window_close" -> R.drawable.widget_ic_window_close
            "ctrl_sunroof_open" -> R.drawable.widget_ic_sunroof_open
            "ctrl_sunroof_tilt" -> R.drawable.widget_ic_sunroof_tilt
            "ctrl_sunroof_close" -> R.drawable.widget_ic_sunroof_close
            "ctrl_ac_on" -> R.drawable.widget_ic_ac_on
            "ctrl_ac_off" -> R.drawable.widget_ic_ac_off
            "ctrl_horn" -> R.drawable.widget_ic_horn
            "ctrl_flash" -> R.drawable.widget_ic_flash
            "ctrl_horn_flash" -> R.drawable.widget_ic_horn_flash
            else -> R.drawable.widget_ic_ac_on
        }

        private val controlIds = setOf(
            "ctrl_lock", "ctrl_unlock", "ctrl_ignition_on", "ctrl_ignition_off",
            "ctrl_window_open", "ctrl_window_half", "ctrl_window_close",
            "ctrl_sunroof_open", "ctrl_sunroof_tilt", "ctrl_sunroof_close",
            "ctrl_ac_on", "ctrl_ac_off",
            "ctrl_horn", "ctrl_flash", "ctrl_horn_flash"
        )

        private fun isControl(id: String) = id in controlIds

        private val cellIds = (1..28).map {
            when (it) {
                1 -> R.id.widget_btn_1; 2 -> R.id.widget_btn_2; 3 -> R.id.widget_btn_3; 4 -> R.id.widget_btn_4
                5 -> R.id.widget_btn_5; 6 -> R.id.widget_btn_6; 7 -> R.id.widget_btn_7; 8 -> R.id.widget_btn_8
                9 -> R.id.widget_btn_9; 10 -> R.id.widget_btn_10; 11 -> R.id.widget_btn_11; 12 -> R.id.widget_btn_12
                13 -> R.id.widget_btn_13; 14 -> R.id.widget_btn_14; 15 -> R.id.widget_btn_15; 16 -> R.id.widget_btn_16
                17 -> R.id.widget_btn_17; 18 -> R.id.widget_btn_18; 19 -> R.id.widget_btn_19; 20 -> R.id.widget_btn_20
                21 -> R.id.widget_btn_21; 22 -> R.id.widget_btn_22; 23 -> R.id.widget_btn_23; 24 -> R.id.widget_btn_24
                25 -> R.id.widget_btn_25; 26 -> R.id.widget_btn_26; 27 -> R.id.widget_btn_27; 28 -> R.id.widget_btn_28
                else -> R.id.widget_btn_1
            }
        }
        private val iconIds = (1..28).map {
            when (it) {
                1 -> R.id.widget_btn_1_icon; 2 -> R.id.widget_btn_2_icon; 3 -> R.id.widget_btn_3_icon; 4 -> R.id.widget_btn_4_icon
                5 -> R.id.widget_btn_5_icon; 6 -> R.id.widget_btn_6_icon; 7 -> R.id.widget_btn_7_icon; 8 -> R.id.widget_btn_8_icon
                9 -> R.id.widget_btn_9_icon; 10 -> R.id.widget_btn_10_icon; 11 -> R.id.widget_btn_11_icon; 12 -> R.id.widget_btn_12_icon
                13 -> R.id.widget_btn_13_icon; 14 -> R.id.widget_btn_14_icon; 15 -> R.id.widget_btn_15_icon; 16 -> R.id.widget_btn_16_icon
                17 -> R.id.widget_btn_17_icon; 18 -> R.id.widget_btn_18_icon; 19 -> R.id.widget_btn_19_icon; 20 -> R.id.widget_btn_20_icon
                21 -> R.id.widget_btn_21_icon; 22 -> R.id.widget_btn_22_icon; 23 -> R.id.widget_btn_23_icon; 24 -> R.id.widget_btn_24_icon
                25 -> R.id.widget_btn_25_icon; 26 -> R.id.widget_btn_26_icon; 27 -> R.id.widget_btn_27_icon; 28 -> R.id.widget_btn_28_icon
                else -> R.id.widget_btn_1_icon
            }
        }
        private val textIds = (1..28).map {
            when (it) {
                1 -> R.id.widget_btn_1_text; 2 -> R.id.widget_btn_2_text; 3 -> R.id.widget_btn_3_text; 4 -> R.id.widget_btn_4_text
                5 -> R.id.widget_btn_5_text; 6 -> R.id.widget_btn_6_text; 7 -> R.id.widget_btn_7_text; 8 -> R.id.widget_btn_8_text
                9 -> R.id.widget_btn_9_text; 10 -> R.id.widget_btn_10_text; 11 -> R.id.widget_btn_11_text; 12 -> R.id.widget_btn_12_text
                13 -> R.id.widget_btn_13_text; 14 -> R.id.widget_btn_14_text; 15 -> R.id.widget_btn_15_text; 16 -> R.id.widget_btn_16_text
                17 -> R.id.widget_btn_17_text; 18 -> R.id.widget_btn_18_text; 19 -> R.id.widget_btn_19_text; 20 -> R.id.widget_btn_20_text
                21 -> R.id.widget_btn_21_text; 22 -> R.id.widget_btn_22_text; 23 -> R.id.widget_btn_23_text; 24 -> R.id.widget_btn_24_text
                25 -> R.id.widget_btn_25_text; 26 -> R.id.widget_btn_26_text; 27 -> R.id.widget_btn_27_text; 28 -> R.id.widget_btn_28_text
                else -> R.id.widget_btn_1_text
            }
        }
        private val titleIds = (1..28).map {
            when (it) {
                1 -> R.id.widget_btn_1_title; 2 -> R.id.widget_btn_2_title; 3 -> R.id.widget_btn_3_title; 4 -> R.id.widget_btn_4_title
                5 -> R.id.widget_btn_5_title; 6 -> R.id.widget_btn_6_title; 7 -> R.id.widget_btn_7_title; 8 -> R.id.widget_btn_8_title
                9 -> R.id.widget_btn_9_title; 10 -> R.id.widget_btn_10_title; 11 -> R.id.widget_btn_11_title; 12 -> R.id.widget_btn_12_title
                13 -> R.id.widget_btn_13_title; 14 -> R.id.widget_btn_14_title; 15 -> R.id.widget_btn_15_title; 16 -> R.id.widget_btn_16_title
                17 -> R.id.widget_btn_17_title; 18 -> R.id.widget_btn_18_title; 19 -> R.id.widget_btn_19_title; 20 -> R.id.widget_btn_20_title
                21 -> R.id.widget_btn_21_title; 22 -> R.id.widget_btn_22_title; 23 -> R.id.widget_btn_23_title; 24 -> R.id.widget_btn_24_title
                25 -> R.id.widget_btn_25_title; 26 -> R.id.widget_btn_26_title; 27 -> R.id.widget_btn_27_title; 28 -> R.id.widget_btn_28_title
                else -> R.id.widget_btn_1_title
            }
        }
        private val infoIds = (1..28).map {
            when (it) {
                1 -> R.id.widget_btn_1_info; 2 -> R.id.widget_btn_2_info; 3 -> R.id.widget_btn_3_info; 4 -> R.id.widget_btn_4_info
                5 -> R.id.widget_btn_5_info; 6 -> R.id.widget_btn_6_info; 7 -> R.id.widget_btn_7_info; 8 -> R.id.widget_btn_8_info
                9 -> R.id.widget_btn_9_info; 10 -> R.id.widget_btn_10_info; 11 -> R.id.widget_btn_11_info; 12 -> R.id.widget_btn_12_info
                13 -> R.id.widget_btn_13_info; 14 -> R.id.widget_btn_14_info; 15 -> R.id.widget_btn_15_info; 16 -> R.id.widget_btn_16_info
                17 -> R.id.widget_btn_17_info; 18 -> R.id.widget_btn_18_info; 19 -> R.id.widget_btn_19_info; 20 -> R.id.widget_btn_20_info
                21 -> R.id.widget_btn_21_info; 22 -> R.id.widget_btn_22_info; 23 -> R.id.widget_btn_23_info; 24 -> R.id.widget_btn_24_info
                25 -> R.id.widget_btn_25_info; 26 -> R.id.widget_btn_26_info; 27 -> R.id.widget_btn_27_info; 28 -> R.id.widget_btn_28_info
                else -> R.id.widget_btn_1_info
            }
        }
        private val ctrlIds = (1..28).map {
            when (it) {
                1 -> R.id.widget_btn_1_ctrl; 2 -> R.id.widget_btn_2_ctrl; 3 -> R.id.widget_btn_3_ctrl; 4 -> R.id.widget_btn_4_ctrl
                5 -> R.id.widget_btn_5_ctrl; 6 -> R.id.widget_btn_6_ctrl; 7 -> R.id.widget_btn_7_ctrl; 8 -> R.id.widget_btn_8_ctrl
                9 -> R.id.widget_btn_9_ctrl; 10 -> R.id.widget_btn_10_ctrl; 11 -> R.id.widget_btn_11_ctrl; 12 -> R.id.widget_btn_12_ctrl
                13 -> R.id.widget_btn_13_ctrl; 14 -> R.id.widget_btn_14_ctrl; 15 -> R.id.widget_btn_15_ctrl; 16 -> R.id.widget_btn_16_ctrl
                17 -> R.id.widget_btn_17_ctrl; 18 -> R.id.widget_btn_18_ctrl; 19 -> R.id.widget_btn_19_ctrl; 20 -> R.id.widget_btn_20_ctrl
                21 -> R.id.widget_btn_21_ctrl; 22 -> R.id.widget_btn_22_ctrl; 23 -> R.id.widget_btn_23_ctrl; 24 -> R.id.widget_btn_24_ctrl
                25 -> R.id.widget_btn_25_ctrl; 26 -> R.id.widget_btn_26_ctrl; 27 -> R.id.widget_btn_27_ctrl; 28 -> R.id.widget_btn_28_ctrl
                else -> R.id.widget_btn_1_ctrl
            }
        }
        private val ctrlLabelIds = (1..28).map {
            when (it) {
                1 -> R.id.widget_btn_1_ctrl_label; 2 -> R.id.widget_btn_2_ctrl_label; 3 -> R.id.widget_btn_3_ctrl_label; 4 -> R.id.widget_btn_4_ctrl_label
                5 -> R.id.widget_btn_5_ctrl_label; 6 -> R.id.widget_btn_6_ctrl_label; 7 -> R.id.widget_btn_7_ctrl_label; 8 -> R.id.widget_btn_8_ctrl_label
                9 -> R.id.widget_btn_9_ctrl_label; 10 -> R.id.widget_btn_10_ctrl_label; 11 -> R.id.widget_btn_11_ctrl_label; 12 -> R.id.widget_btn_12_ctrl_label
                13 -> R.id.widget_btn_13_ctrl_label; 14 -> R.id.widget_btn_14_ctrl_label; 15 -> R.id.widget_btn_15_ctrl_label; 16 -> R.id.widget_btn_16_ctrl_label
                17 -> R.id.widget_btn_17_ctrl_label; 18 -> R.id.widget_btn_18_ctrl_label; 19 -> R.id.widget_btn_19_ctrl_label; 20 -> R.id.widget_btn_20_ctrl_label
                21 -> R.id.widget_btn_21_ctrl_label; 22 -> R.id.widget_btn_22_ctrl_label; 23 -> R.id.widget_btn_23_ctrl_label; 24 -> R.id.widget_btn_24_ctrl_label
                25 -> R.id.widget_btn_25_ctrl_label; 26 -> R.id.widget_btn_26_ctrl_label; 27 -> R.id.widget_btn_27_ctrl_label; 28 -> R.id.widget_btn_28_ctrl_label
                else -> R.id.widget_btn_1_ctrl_label
            }
        }
        private val rowIds = listOf(
            R.id.widget_btn_row1, R.id.widget_btn_row2,
            R.id.widget_btn_row3, R.id.widget_btn_row4,
            R.id.widget_btn_row5, R.id.widget_btn_row6,
            R.id.widget_btn_row7
        )

        /** "宽x高" → (maxCols≤4, maxRows≤7) */
        private fun parseMaxSize(size: String?): Pair<Int, Int> {
            val s = size ?: "1x1"
            val p = s.lowercase().split("x")
            val w = p.getOrNull(0)?.toIntOrNull() ?: 1
            val h = p.getOrNull(1)?.toIntOrNull() ?: 1
            return w.coerceIn(1, 4) to h.coerceIn(1, 7)
        }

        /**
         * 桌面实际格子，但不超过该组件创建时选的 size 上限。
         * 初始 1x1，用户最多拖到设定尺寸。
         */
        private fun colsRowsFromOptions(
            context: Context,
            options: Bundle?,
            maxSize: String?
        ): Pair<Int, Int> {
            val (maxCols, maxRows) = parseMaxSize(maxSize)
            if (options == null) return 1 to 1

            fun toDp(v: Int): Int {
                if (v <= 0) return 0
                return if (v > 400) TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_PX, v.toFloat(), context.resources.displayMetrics
                ).toInt() else v
            }
            val minW = toDp(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0))
            val maxW = toDp(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0))
            val minH = toDp(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0))
            val maxH = toDp(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0))
            val w = if (maxW > minW) (minW + maxW) / 2 else minW
            val h = if (maxH > minH) (minH + maxH) / 2 else minH

            // 按实际拖拽估算，再截断到创建时设定的上限
            val cols = (w / 70).coerceIn(1, maxCols)
            val rows = (h / 70).coerceIn(1, maxRows)
            Log.i(TAG, "raw=${w}x$h max=${maxCols}x$maxRows -> ${cols}x$rows")
            return cols to rows
        }

        private fun infoTitle(id: String): String = when (id) {
            "info_vehicle_temp" -> "车内温度"
            "info_env_temp" -> "车外温度"
            "info_fuel_level" -> "剩余油量"
            "info_range" -> "可行驶里程"
            "info_mileage" -> "总里程"
            "info_nickname" -> "车辆昵称"
            "info_plate" -> "车牌号"
            "info_lock_status" -> "车锁状态"
            "info_door_status" -> "车门状态"
            "info_window_status" -> "车窗状态"
            "info_sunroof_status" -> "天窗状态"
            "info_trunk_status" -> "后备箱状态"
            "info_light_status" -> "车灯状态"
            "info_ac_status" -> "空调状态"
            "info_engine_status" -> "发动机状态"
            "info_battery_status" -> "动力电池"
            "info_aux_battery" -> "蓄电池状态"
            "info_avg_fuel" -> "平均油耗"
            "info_total_fuel" -> "累计油耗"
            "info_water_temp" -> "水温"
            "info_voltage" -> "电压"
            "info_altitude" -> "海拔"
            "info_tire_fl" -> "胎压-左前"
            "info_tire_fr" -> "胎压-右前"
            "info_tire_rl" -> "胎压-左后"
            "info_tire_rr" -> "胎压-右后"
            else -> if (id.startsWith("info_blank")) "" else ""
        }

        private fun ctrlLabel(id: String): String = when (id) {
            "ctrl_lock" -> "锁车"
            "ctrl_unlock" -> "解锁"
            "ctrl_ignition_on" -> "点火"
            "ctrl_ignition_off" -> "熄火"
            "ctrl_window_open" -> "开窗"
            "ctrl_window_half" -> "微开窗"
            "ctrl_window_close" -> "关窗"
            "ctrl_sunroof_open" -> "开天窗"
            "ctrl_sunroof_tilt" -> "翘天窗"
            "ctrl_sunroof_close" -> "关天窗"
            "ctrl_ac_on" -> "空调开"
            "ctrl_ac_off" -> "空调关"
            "ctrl_horn" -> "鸣笛"
            "ctrl_flash" -> "闪灯"
            "ctrl_horn_flash" -> "鸣笛闪灯"
            else -> ""
        }

        private fun infoLabel(
            id: String,
            acOn: Boolean,
            vehicleTemp: Int,
            envTemp: Int,
            carName: String,
            carPlate: String,
            range: Int,
            mileage: Int,
            fuel: Float,
            lockSt: String,
            doorSt: String,
            winSt: String,
            sunSt: String,
            trunkSt: String,
            engSt: String,
            battSt: String,
            lightSt: String,
            powerBattSt: String,
            avgFuelSt: String,
            totalFuelSt: String,
            waterTempSt: String,
            voltageSt: String,
            altitudeSt: String,
            tireFlSt: String,
            tireFrSt: String,
            tireRlSt: String,
            tireRrSt: String
        ): String = when (id) {
            "info_vehicle_temp" -> "${vehicleTemp}°"
            "info_env_temp" -> "${envTemp}°"
            "info_fuel_level" -> "${fuel.roundToInt()}%"
            "info_range" -> "${range}km"
            "info_mileage" -> "${mileage}km"
            "info_nickname" -> carName.ifEmpty { "--" }
            "info_plate" -> carPlate.ifEmpty { "--" }
            "info_lock_status" -> lockSt
            "info_door_status" -> doorSt
            "info_window_status" -> winSt
            "info_sunroof_status" -> sunSt
            "info_trunk_status" -> trunkSt
            "info_light_status" -> lightSt
            "info_ac_status" -> if (acOn) "开" else "关"
            "info_engine_status" -> engSt
            "info_battery_status" -> powerBattSt
            "info_aux_battery" -> battSt
            "info_avg_fuel" -> avgFuelSt
            "info_total_fuel" -> totalFuelSt
            "info_water_temp" -> waterTempSt
            "info_voltage" -> voltageSt
            "info_altitude" -> altitudeSt
            "info_tire_fl" -> tireFlSt
            "info_tire_fr" -> tireFrSt
            "info_tire_rl" -> tireRlSt
            "info_tire_rr" -> tireRrSt
            else -> if (id.startsWith("info_blank")) "" else id
        }

        fun renderWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            slot: Int,
            options: Bundle? = null
        ) {
            try {
                val prefs = context.getSharedPreferences("widget_slot_$slot", Context.MODE_PRIVATE)
                val buttonsRaw = prefs.getString("buttons", "") ?: ""
                val buttons = buttonsRaw.split(",").filter { it.isNotEmpty() }
                val maxSize = prefs.getString("size", "1x1")
                fun dbg(msg: String) {
                    try {
                        java.io.File(context.cacheDir, "widget_debug.txt").appendText(msg + "\n")
                    } catch (_: Throwable) {}
                }
                dbg("render id=$widgetId slot=$slot n=${buttons.size}")
                val (cols, rows) = colsRowsFromOptions(context, options, maxSize)
                val capacity = (cols * rows).coerceAtMost(28)
                val show = buttons.take(capacity)
                dbg("grid=${cols}x$rows show=${show.size}")
                val views = RemoteViews(context.packageName, R.layout.widget_cell_grid)
                dbg("views ok")
                val dataPrefs = try {
                    es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
                } catch (t: Throwable) {
                    dbg("getData fail $t")
                    null
                }
                dbg("prefs ok")
                val all = try { dataPrefs?.all ?: emptyMap<String, Any?>() } catch (_: Throwable) { emptyMap<String, Any?>() }
                fun s(key: String, def: String = ""): String =
                    (all[key] as? String) ?: def
                fun i(key: String, def: Int = 0): Int = when (val v = all[key]) {
                    is Int -> v
                    is Long -> v.toInt()
                    is Double -> v.toInt()
                    is Float -> v.toInt()
                    is String -> v.toIntOrNull() ?: def
                    else -> def
                }
                fun f(key: String, def: Float = 0f): Float = when (val v = all[key]) {
                    is Float -> v
                    is Double -> v.toFloat()
                    is Long -> if (v in -1000L..10000L) v.toFloat() else def
                    is Int -> v.toFloat()
                    is String -> v.toFloatOrNull() ?: def
                    else -> def
                }
                fun b(key: String, def: Boolean = false): Boolean = when (val v = all[key]) {
                    is Boolean -> v
                    else -> def
                }
                val acOn = b("widget_ac_on")
                val vehicleTemp = i("widget_vehicle_temp")
                val envTemp = i("widget_env_temp")
                val carPlate = s("widget_car_plate")
                val carName = s("widget_car_name")
                val range = i("widget_range")
                val mileage = i("widget_mileage")
                val fuel = f("widget_fuel").let {
                    if (it < 0f || it > 100f) 0f else it
                }
                val lockSt = s("widget_lock_status", "--")
                val doorSt = s("widget_door_status", "--")
                val winSt = s("widget_window_status", "--")
                val sunSt = s("widget_sunroof_status", "--")
                val trunkSt = s("widget_trunk_status", "--")
                val engSt = s("widget_engine_status", "--")
                val battSt = s("widget_battery_status", "--")
                val lightSt = s("widget_light_status", "--")
                val powerBattSt = s("widget_power_battery_status", "--")
                val avgFuelSt = s("widget_avg_fuel", "--")
                val totalFuelSt = s("widget_total_fuel", "--")
                val waterTempSt = s("widget_water_temp", "--")
                val voltageSt = s("widget_voltage", "--")
                val altitudeSt = s("widget_altitude", "--")
                val tireFlSt = s("widget_tire_fl", "--")
                val tireFrSt = s("widget_tire_fr", "--")
                val tireRlSt = s("widget_tire_rl", "--")
                val tireRrSt = s("widget_tire_rr", "--")
                dbg("data fuel=$fuel t=$vehicleTemp lock=$lockSt plate=$carPlate")

                // 隐藏全部
                for (i in 0 until 28) {
                    try {
                        views.setViewVisibility(cellIds[i], View.GONE)
                        views.setViewVisibility(ctrlIds[i], View.GONE)
                        views.setViewVisibility(iconIds[i], View.GONE)
                        views.setViewVisibility(ctrlLabelIds[i], View.GONE)
                        views.setViewVisibility(infoIds[i], View.GONE)
                        views.setViewVisibility(titleIds[i], View.GONE)
                        views.setViewVisibility(textIds[i], View.GONE)
                    } catch (_: Exception) {}
                }

                try {
                    for (r in 0 until 7) {
                        val start = r * cols
                        val count = (show.size - start).coerceIn(0, cols)
                        views.setViewVisibility(rowIds[r], if (count > 0) View.VISIBLE else View.GONE)
                    }
                } catch (_: Exception) {}

                show.forEachIndexed { i, id ->
                    try {
                        views.setViewVisibility(cellIds[i], View.VISIBLE)
                        if (isControl(id)) {
                            // 控制：显示图标+小标题
                            views.setViewVisibility(ctrlIds[i], View.VISIBLE)
                            views.setViewVisibility(iconIds[i], View.VISIBLE)
                            views.setViewVisibility(ctrlLabelIds[i], View.VISIBLE)
                            views.setViewVisibility(infoIds[i], View.GONE)
                            views.setImageViewResource(iconIds[i], iconForControl(id))
                            views.setTextViewText(ctrlLabelIds[i], ctrlLabel(id))
                            // 后台广播，不拉起任何窗口
                            val intent = Intent(context, WidgetActionReceiver::class.java).apply {
                                action = "com.myapp.my_eado.WIDGET_CMD"
                                data = Uri.parse("myeado://widget/$widgetId/$i/$id")
                                putExtra("command", id)
                            }
                            val pi = PendingIntent.getBroadcast(
                                context, widgetId * 100 + i, intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            views.setOnClickPendingIntent(cellIds[i], pi)
                        } else {
                            // 信息：双行显示（标题+数据）
                            views.setViewVisibility(iconIds[i], View.GONE)
                            views.setViewVisibility(infoIds[i], View.VISIBLE)
                            views.setViewVisibility(titleIds[i], View.VISIBLE)
                            views.setViewVisibility(textIds[i], View.VISIBLE)
                            views.setTextViewText(titleIds[i], infoTitle(id))
                            views.setTextViewText(
                                textIds[i],
                                infoLabel(
                                    id, acOn, vehicleTemp, envTemp, carName, carPlate,
                                    range, mileage, fuel, lockSt, doorSt, winSt,
                                    sunSt, trunkSt, engSt, battSt, lightSt, powerBattSt,
                                    avgFuelSt, totalFuelSt, waterTempSt, voltageSt, altitudeSt,
                                    tireFlSt, tireFrSt, tireRlSt, tireRrSt
                                )
                            )
                            val intent = Intent(context, MainActivity::class.java).apply {
                                action = Intent.ACTION_MAIN
                                addCategory(Intent.CATEGORY_LAUNCHER)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            }
                            val pi = PendingIntent.getActivity(
                                context, widgetId * 100 + i, intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            views.setOnClickPendingIntent(cellIds[i], pi)
                        }
                    } catch (e: Exception) {
                        try {
                            java.io.File(context.cacheDir, "widget_debug.txt")
                                .appendText("cell $i $id fail $e\n")
                        } catch (_: Exception) {}
                    }
                }

                try {
                    java.io.File(context.cacheDir, "widget_debug.txt")
                        .appendText("before-update id=$widgetId\n")
                    manager.updateAppWidget(intArrayOf(widgetId), views)
                    java.io.File(context.cacheDir, "widget_debug.txt")
                        .appendText("updated id=$widgetId cells=${show.size}\n")
                } catch (t: Throwable) {
                    java.io.File(context.cacheDir, "widget_debug.txt")
                        .appendText("update fail ${t.javaClass.name}: $t\n")
                }
            } catch (t: Throwable) {
                try {
                    java.io.File(context.cacheDir, "widget_debug.txt")
                        .appendText("RENDER_ERR slot=$slot id=$widgetId ${t.javaClass.name}: $t\n")
                } catch (_: Throwable) {}
                Log.e(TAG, "render error slot=$slot id=$widgetId", t)
            }
        }

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            try {
                java.io.File(context.cacheDir, "widget_debug.txt")
                    .writeText("updateAllWidgets ${System.currentTimeMillis()}\n")
            } catch (_: Exception) {}
            for (i in 1..20) {
                try {
                    val clazz = Class.forName(
                        "${context.packageName}.widget.WidgetSlot${i.toString().padStart(2, '0')}"
                    )
                    val ids = manager.getAppWidgetIds(ComponentName(context, clazz))
                    try {
                        java.io.File(context.cacheDir, "widget_debug.txt")
                            .appendText("slot $i ids=${ids?.toList()}\n")
                    } catch (_: Exception) {}
                    if (ids == null || ids.isEmpty()) continue
                    for (id in ids) {
                        renderWidget(context, manager, id, i, manager.getAppWidgetOptions(id))
                    }
                } catch (e: Exception) {
                    try {
                        java.io.File(context.cacheDir, "widget_debug.txt")
                            .appendText("slot $i err $e\n")
                    } catch (_: Exception) {}
                }
            }
        }
    }
}
