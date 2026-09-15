import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _taskName = 'widgetDataRefresh';

/// WorkManager 回调入口（必须是顶层函数）
@pragma('vm:entry-point')
void widgetCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _taskName) return true;
    try {
      await _fetchAndSave();
    } catch (e) {
      // ignore
    }
    return true;
  });
}

Future<void> _fetchAndSave() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  final carId = prefs.getString('carId');
  if (token == null || token.isEmpty || carId == null || carId.isEmpty) return;

  final url =
      'https://m.iov.changan.com.cn/app2/api/car/data?carId=$carId&ErrorAutoProjectile=false&toast=false&keys=*&token=$token&isNev=0';

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.postUrl(Uri.parse(url));
    req.headers.set('Accept', 'application/json, text/plain, */*');
    req.headers.set('vcs-app-id', 'inCall');
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    if (json['code'] != 0 || json['data'] == null) return;
    final d = json['data'] as Map<String, dynamic>;
    await _saveToWidget(d);
  } finally {
    client.close();
  }
}

Future<void> _saveToWidget(Map<String, dynamic> d) async {
  final prefs = await SharedPreferences.getInstance();

  // 状态解析
  final locks = [
    d['driverDoorLock'],
    d['passengerDoorLock'],
    d['leftRearDoorLock'],
    d['rightRearDoorLock'],
  ];
  final lock = locks.any((e) => e == 0 || e == '0') ? '已解锁' : '已上锁';

  final doors = [
    d['leftFrontDoorStatus'],
    d['rightFrontDoorStatus'],
    d['leftRearDoorStatus'],
    d['rightRearDoorStatus'],
  ];
  final door = doors.any((e) => e == 1 || e == '1') ? '有开启' : '已关闭';

  final wins = [
    d['diverWindow'],
    d['passengerWindow'],
    d['leftRearWindow'],
    d['rightRearWindow'],
  ];
  final win = wins.any((e) => e == 1 || e == '1') ? '有开启' : '已关闭';

  final sun = (d['skyWindow'] == 1 || d['skyWindow'] == '1') ? '有开启' : '已关闭';
  final trunk = (d['trunk'] == 1 || d['trunk'] == '1') ? '已开启' : '已关闭';
  final engine = (d['fireStatus'] == 2 || d['fireStatus'] == '2') ? '运行中' : '熄火';

  final bv = d['batteryVoltage'];
  final batt = bv == null ? '--' : '${bv}V';

  // 车灯
  final lights = [
    d['lowBeam'],
    d['highBeam'],
    d['frontFogLight'],
    d['rearFogLight'],
    d['positionLight'],
  ];
  final lightSt = lights.any((v) => v == 1) ? '已开' : '已关';

  // 动力电池
  final powerBattSt = (d['powerBatteryStatus'] == 0) ? '正常' : '异常';

  // 油耗
  final avgFuel = d['fuelConsumption100km'];
  final avgFuelSt = avgFuel != null ? '$avgFuel L/100km' : '--';
  final totalFuel = d['igniteCumulativeOil'];
  final totalFuelSt = totalFuel != null ? '$totalFuel L' : '--';

  // 水温、海拔
  final wt = d['engineWaterTemp'];
  final waterTempSt = wt != null ? '${wt}°C' : '--';
  final alt = d['alti'];
  final altitudeSt = alt != null ? '$alt m' : '--';

  // 胎压
  final fl = d['lfTyrePressure'] ?? d['leftFrontTirePressure'] ?? d['tirePressureFL'] ?? '--';
  final fr = d['rfTyrePressure'] ?? d['rightFrontTirePressure'] ?? d['tirePressureFR'] ?? '--';
  final rl = d['lrTyrePressure'] ?? d['leftRearTirePressure'] ?? d['tirePressureRL'] ?? '--';
  final rr = d['rrTyrePressure'] ?? d['rightRearTirePressure'] ?? d['tirePressureRR'] ?? '--';

  final acOn = d['airStatus'] == 1;
  final vehicleTemp = (d['vehicleTemperature'] ?? 0).round();
  final envTemp = (d['environmentalTemp'] ?? 0).round();
  final range = (d['remainedOilMile'] ?? 0).round();
  final mileage = (d['totalOdometer'] ?? 0).round();
  final fuel = (d['remainingFuel'] ?? 0).toDouble();

  final carName = prefs.getString('carName') ?? '';
  final carPlate = prefs.getString('plateNumber') ?? '';

  await Future.wait([
    HomeWidget.saveWidgetData<bool>('widget_ac_on', acOn),
    HomeWidget.saveWidgetData<int>('widget_ac_temp', vehicleTemp),
    HomeWidget.saveWidgetData<int>('widget_vehicle_temp', vehicleTemp),
    HomeWidget.saveWidgetData<int>('widget_env_temp', envTemp),
    HomeWidget.saveWidgetData<String>(
        'widget_car_plate', carPlate.isNotEmpty ? carPlate : 'MyEADO'),
    HomeWidget.saveWidgetData<String>(
        'widget_car_name', carName.isNotEmpty ? carName : '未知车辆'),
    HomeWidget.saveWidgetData<int>('widget_range', range),
    HomeWidget.saveWidgetData<int>('widget_mileage', mileage),
    HomeWidget.saveWidgetData<int>('widget_fuel', fuel.round().clamp(0, 100)),
    HomeWidget.saveWidgetData<String>('widget_lock_status', lock),
    HomeWidget.saveWidgetData<String>('widget_door_status', door),
    HomeWidget.saveWidgetData<String>('widget_window_status', win),
    HomeWidget.saveWidgetData<String>('widget_sunroof_status', sun),
    HomeWidget.saveWidgetData<String>('widget_trunk_status', trunk),
    HomeWidget.saveWidgetData<String>('widget_engine_status', engine),
    HomeWidget.saveWidgetData<String>('widget_battery_status', batt),
    HomeWidget.saveWidgetData<String>('widget_light_status', lightSt),
    HomeWidget.saveWidgetData<String>(
        'widget_power_battery_status', powerBattSt),
    HomeWidget.saveWidgetData<String>('widget_avg_fuel', avgFuelSt),
    HomeWidget.saveWidgetData<String>('widget_total_fuel', totalFuelSt),
    HomeWidget.saveWidgetData<String>('widget_water_temp', waterTempSt),
    HomeWidget.saveWidgetData<String>('widget_voltage', batt),
    HomeWidget.saveWidgetData<String>('widget_altitude', altitudeSt),
    HomeWidget.saveWidgetData<String>('widget_tire_fl', fl.toString()),
    HomeWidget.saveWidgetData<String>('widget_tire_fr', fr.toString()),
    HomeWidget.saveWidgetData<String>('widget_tire_rl', rl.toString()),
    HomeWidget.saveWidgetData<String>('widget_tire_rr', rr.toString()),
    HomeWidget.saveWidgetData<int>(
        'widget_update_ts', DateTime.now().millisecondsSinceEpoch),
  ]);

  // 通知小组件刷新
  const channel = MethodChannel('com.myapp.my_eado/widget');
  try {
    await channel.invokeMethod('refreshAllWidgets');
  } catch (_) {}
}

/// 注册定时任务
Future<void> registerWidgetPeriodicTask() async {
  await Workmanager().initialize(
    widgetCallbackDispatcher,
    isInDebugMode: false,
  );
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );
}

/// 取消定时任务
Future<void> cancelWidgetPeriodicTask() async {
  await Workmanager().cancelByUniqueName(_taskName);
}
