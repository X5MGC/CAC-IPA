import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// 小组件数据管理 — 20个slot，预设1x1~4x4 + 自定义最大7x4
class WidgetData {
  static const _channel = MethodChannel('com.myapp.my_eado/widget');

  static const int maxCustomCols = 4;
  static const int maxCustomRows = 7;

  static const List<String> sizes = [
    '1x1', '1x2', '1x3', '1x4',
    '2x1', '2x2', '2x3', '2x4',
    '3x1', '3x2', '3x3', '3x4',
    '4x1', '4x2', '4x3', '4x4',
    'custom',
  ];

  /// 解析 "宽x高"，custom 由页面拼成 WxH
  static List<int> parseSize(String size) {
    final p = size.toLowerCase().split('x');
    final w = int.tryParse(p.isNotEmpty ? p[0] : '') ?? 2;
    final h = int.tryParse(p.length > 1 ? p[1] : '') ?? 2;
    return [
      w.clamp(1, maxCustomCols),
      h.clamp(1, maxCustomRows),
    ];
  }

  static String formatSize(int cols, int rows) =>
      '${cols.clamp(1, maxCustomCols)}x${rows.clamp(1, maxCustomRows)}';

  /// 控制类按钮（图标路径与APP一致）
  static const List<WidgetButtonDef> controlButtons = [
    WidgetButtonDef(id: 'ctrl_lock', label: '锁车', icon: 'assets/images/icons/suoding-web.png'),
    WidgetButtonDef(id: 'ctrl_unlock', label: '解锁', icon: 'assets/images/icons/kaisuo-web.png'),
    WidgetButtonDef(id: 'ctrl_ignition_on', label: '点火', icon: 'assets/images/icons/dianhuo-web.png'),
    WidgetButtonDef(id: 'ctrl_ignition_off', label: '熄火', icon: 'assets/images/icons/xihuo-web.png'),
    WidgetButtonDef(id: 'ctrl_window_open', label: '开窗', icon: 'assets/images/icons/quankai-web.png'),
    WidgetButtonDef(id: 'ctrl_window_half', label: '微开窗', icon: 'assets/images/icons/quankai-web.png'),
    WidgetButtonDef(id: 'ctrl_window_close', label: '关窗', icon: 'assets/images/icons/chechuangguanbi-web.png'),
    WidgetButtonDef(id: 'ctrl_sunroof_open', label: '开天窗', icon: 'assets/images/icons/tianchuangkaiqi-web.png'),
    WidgetButtonDef(id: 'ctrl_sunroof_tilt', label: '翘天窗', icon: 'assets/images/icons/tianchuangqiaoqi-web.png'),
    WidgetButtonDef(id: 'ctrl_sunroof_close', label: '关天窗', icon: 'assets/images/icons/tianchuangguanbi-web.png'),
    WidgetButtonDef(id: 'ctrl_ac_on', label: '空调开', icon: 'assets/images/icons/changan/air-open.png'),
    WidgetButtonDef(id: 'ctrl_ac_off', label: '空调关', icon: 'assets/images/icons/changan/air-close.png'),
    WidgetButtonDef(id: 'ctrl_horn', label: '鸣笛', icon: 'assets/images/icons/changan/air-open.png'),
    WidgetButtonDef(id: 'ctrl_flash', label: '闪灯', icon: 'assets/images/icons/changan/air-open.png'),
    WidgetButtonDef(id: 'ctrl_horn_flash', label: '鸣笛闪灯', icon: 'assets/images/icons/changan/air-open.png'),
  ];

  /// 信息类按钮
  static const List<WidgetButtonDef> infoButtons = [
    WidgetButtonDef(id: 'info_vehicle_temp', label: '车内温度'),
    WidgetButtonDef(id: 'info_env_temp', label: '车外温度'),
    WidgetButtonDef(id: 'info_fuel_level', label: '剩余油量'),
    WidgetButtonDef(id: 'info_range', label: '可行驶里程'),
    WidgetButtonDef(id: 'info_mileage', label: '总里程'),
    WidgetButtonDef(id: 'info_nickname', label: '车辆昵称'),
    WidgetButtonDef(id: 'info_plate', label: '车牌号'),
    WidgetButtonDef(id: 'info_lock_status', label: '车锁状态'),
    WidgetButtonDef(id: 'info_door_status', label: '车门状态'),
    WidgetButtonDef(id: 'info_window_status', label: '车窗状态'),
    WidgetButtonDef(id: 'info_sunroof_status', label: '天窗状态'),
    WidgetButtonDef(id: 'info_trunk_status', label: '后备箱状态'),
    WidgetButtonDef(id: 'info_light_status', label: '车灯状态'),
    WidgetButtonDef(id: 'info_ac_status', label: '空调状态'),
    WidgetButtonDef(id: 'info_engine_status', label: '发动机状态'),
    WidgetButtonDef(id: 'info_battery_status', label: '动力电池状态'),
    WidgetButtonDef(id: 'info_aux_battery', label: '蓄电池状态'),
    WidgetButtonDef(id: 'info_avg_fuel', label: '平均油耗'),
    WidgetButtonDef(id: 'info_total_fuel', label: '累计油耗'),
    WidgetButtonDef(id: 'info_water_temp', label: '水温'),
    WidgetButtonDef(id: 'info_voltage', label: '电压'),
    WidgetButtonDef(id: 'info_altitude', label: '海拔'),
    WidgetButtonDef(id: 'info_tire_fl', label: '胎压-左前'),
    WidgetButtonDef(id: 'info_tire_fr', label: '胎压-右前'),
    WidgetButtonDef(id: 'info_tire_rl', label: '胎压-左后'),
    WidgetButtonDef(id: 'info_tire_rr', label: '胎压-右后'),
    WidgetButtonDef(id: 'info_blank', label: '空白占位'),
  ];

  /// 所有按钮（合并）
  static List<WidgetButtonDef> get availableButtons => [...controlButtons, ...infoButtons];

  /// 根据id查找按钮
  static WidgetButtonDef? findButton(String id) {
    for (final b in availableButtons) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// 编码positions为字符串
  static String encodePositions(Map<String, Offset> positions) {
    return jsonEncode(positions.map((k, v) =>
      MapEntry(k, {'x': v.dx, 'y': v.dy})
    ));
  }

  /// 解码positions
  static Map<String, Offset> decodePositions(String? str) {
    if (str == null || str.isEmpty) return {};
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return map.map((k, v) =>
        MapEntry(k, Offset((v['x'] as num).toDouble(), (v['y'] as num).toDouble()))
      );
    } catch (_) {
      return {};
    }
  }

  /// 主APP轮询时写入车辆数据到小组件SharedPreferences
  static Future<void> updateVehicleData({
    required bool acOn,
    required int acTemp,
    required int vehicleTemp,
    required int envTemp,
    required String carPlate,
    required String carName,
    int range = 0,
    int mileage = 0,
    double fuel = 0,
    String lockStatus = '--',
    String doorStatus = '--',
    String windowStatus = '--',
    String sunroofStatus = '--',
    String trunkStatus = '--',
    String engineStatus = '--',
    String batteryStatus = '--',
    String lightStatus = '--',
    String powerBatteryStatus = '--',
    String avgFuel = '--',
    String totalFuel = '--',
    String waterTemp = '--',
    String voltage = '--',
    String altitude = '--',
    String tirePressureFL = '--',
    String tirePressureFR = '--',
    String tirePressureRL = '--',
    String tirePressureRR = '--',
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData<bool>('widget_ac_on', acOn),
      HomeWidget.saveWidgetData<int>('widget_ac_temp', acTemp),
      HomeWidget.saveWidgetData<int>('widget_vehicle_temp', vehicleTemp),
      HomeWidget.saveWidgetData<int>('widget_env_temp', envTemp),
      HomeWidget.saveWidgetData<String>('widget_car_plate', carPlate),
      HomeWidget.saveWidgetData<String>('widget_car_name', carName),
      HomeWidget.saveWidgetData<int>('widget_range', range),
      HomeWidget.saveWidgetData<int>('widget_mileage', mileage),
      HomeWidget.saveWidgetData<int>('widget_fuel', fuel.round().clamp(0, 100)),
      HomeWidget.saveWidgetData<String>('widget_lock_status', lockStatus),
      HomeWidget.saveWidgetData<String>('widget_door_status', doorStatus),
      HomeWidget.saveWidgetData<String>('widget_window_status', windowStatus),
      HomeWidget.saveWidgetData<String>('widget_sunroof_status', sunroofStatus),
      HomeWidget.saveWidgetData<String>('widget_trunk_status', trunkStatus),
      HomeWidget.saveWidgetData<String>('widget_engine_status', engineStatus),
      HomeWidget.saveWidgetData<String>('widget_battery_status', batteryStatus),
      HomeWidget.saveWidgetData<String>('widget_light_status', lightStatus),
      HomeWidget.saveWidgetData<String>('widget_power_battery_status', powerBatteryStatus),
      HomeWidget.saveWidgetData<String>('widget_avg_fuel', avgFuel),
      HomeWidget.saveWidgetData<String>('widget_total_fuel', totalFuel),
      HomeWidget.saveWidgetData<String>('widget_water_temp', waterTemp),
      HomeWidget.saveWidgetData<String>('widget_voltage', voltage),
      HomeWidget.saveWidgetData<String>('widget_altitude', altitude),
      HomeWidget.saveWidgetData<String>('widget_tire_fl', tirePressureFL),
      HomeWidget.saveWidgetData<String>('widget_tire_fr', tirePressureFR),
      HomeWidget.saveWidgetData<String>('widget_tire_rl', tirePressureRL),
      HomeWidget.saveWidgetData<String>('widget_tire_rr', tirePressureRR),
      HomeWidget.saveWidgetData<int>('widget_update_ts', DateTime.now().millisecondsSinceEpoch),
    ]);
    await _channel.invokeMethod('refreshAllWidgets');
  }

  /// 创建新小组件
  static Future<int> createWidget({
    required String title,
    required String size,
    required List<String> buttons,
    Map<String, Offset> positions = const {},
  }) async {
    final slot = await _channel.invokeMethod<int>('createWidget', {
      'title': title,
      'size': size,
      'buttons': buttons.join(','),
      'positions': encodePositions(positions),
    });
    return slot ?? 0;
  }

  /// 编辑已有slot配置
  static Future<void> saveSlot({
    required int slot,
    required String title,
    required String size,
    required List<String> buttons,
    Map<String, Offset> positions = const {},
  }) async {
    await _channel.invokeMethod('saveWidgetSlot', {
      'slot': slot,
      'title': title,
      'size': size,
      'buttons': buttons.join(','),
      'positions': encodePositions(positions),
    });
  }

  /// 删除slot
  static Future<void> deleteSlot(int slot) async {
    await _channel.invokeMethod('deleteWidgetSlot', {'slot': slot});
  }

  /// 获取所有活跃的小组件slot
  static Future<List<SlotConfig>> getActiveWidgets() async {
    final result = await _channel.invokeMethod('getActiveWidgets');
    if (result == null) return [];
    return (result as List).map((m) => SlotConfig(
      slot: m['slot'] as int,
      title: m['title'] as String,
      size: m['size'] as String? ?? '1x1',
      buttons: (m['buttons'] as String).split(',').where((s) => s.isNotEmpty).toList(),
      positions: decodePositions(m['positions'] as String?),
    )).toList();
  }
}

class WidgetButtonDef {
  final String id;
  final String label;
  final String? icon;
  const WidgetButtonDef({required this.id, required this.label, this.icon});
}

class SlotConfig {
  final int slot;
  final String title;
  final String size;
  final List<String> buttons;
  final Map<String, Offset> positions;
  const SlotConfig({required this.slot, required this.title, required this.size, required this.buttons, this.positions = const {}});
}
