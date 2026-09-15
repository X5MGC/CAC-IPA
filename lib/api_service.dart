import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiService {
  static const String _apiBase = 'https://m.iov.changan.com.cn';
  static const String _cacApiBase = 'https://incallapi.changan.com.cn';
  static const String _clientId = '2c918082632162010163388048d60158';

  // 开放平台配置
  static const String _openBase = 'https://open.iov.changan.com.cn';
  static const String _openClientId = 'b235afd313004785bfde580c188c47bb';
  static const String _openClientSecret = 'YjIzNWFmZDMxMzAwNDc4NQ==';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  String? _accessToken;
  String? _refreshToken;
  String? _openid;
  int _expiresAt = 0;
  String? _phone;
  String? _carId;
  String? _deviceId;

  // 开放平台 token
  String? _openAccessToken;
  String? _openRefreshToken;
  int _openExpiresAt = 0;
  String? _openUid;
  String? _openSecretKey;
  String? _lastOpenError;

  void init() {
    _dio = Dio(BaseOptions(
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'vcs-app-id': 'inCall',
      },
    ));
  }

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _openid = prefs.getString('openid');
    _expiresAt = prefs.getInt('expires_at') ?? 0;
    _carId = prefs.getString('carId');
    _phone = prefs.getString('phone');
    // 设备ID：从缓存读取或获取真实 Android ID
    _deviceId = prefs.getString('device_id');
    if (_deviceId == null || _deviceId!.isEmpty) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = (androidInfo.data['androidId'] as String?) ??
            '${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}${Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}';
      } catch (_) {
        _deviceId =
            '${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}${Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0')}';
      }
      await prefs.setString('device_id', _deviceId!);
    }
    // 加载开放平台 token
    _openAccessToken = prefs.getString('open_access_token');
    _openRefreshToken = prefs.getString('open_refresh_token');
    _openExpiresAt = prefs.getInt('open_expires_at') ?? 0;
    _openUid = prefs.getString('open_uid');
    _openSecretKey = prefs.getString('open_secret_key');
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = data['access_token'];
    _refreshToken = data['refresh_token'];
    _openid = data['openid'];
    _expiresAt = DateTime.now().millisecondsSinceEpoch +
        (data['expires_in'] as int) * 1000;

    await prefs.setString('access_token', _accessToken ?? '');
    await prefs.setString('refresh_token', _refreshToken ?? '');
    await prefs.setString('openid', _openid ?? '');
    await prefs.setInt('expires_at', _expiresAt);
    await prefs.setInt('login_time', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = null;
    _refreshToken = null;
    _openid = null;
    _expiresAt = 0;
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('openid');
    await prefs.remove('expires_at');
    await prefs.remove('login_time');
    await prefs.remove('carId');
  }

  bool get isLoggedIn {
    return _accessToken != null &&
        _accessToken!.isNotEmpty &&
        DateTime.now().millisecondsSinceEpoch < _expiresAt - 60000;
  }

  String? get token => _accessToken;
  String? get carId => _carId;
  String? get phone => _phone;

  void setCarId(String carId) {
    _carId = carId;
  }

  // 刷新Token
  Future<bool> refreshToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;

    try {
      final url = '$_cacApiBase/cac/api/v1/oauth2/refresh_token'
          '?client_id=$_clientId&refresh_token=$_refreshToken';
      final resp = await _dio.get(url);
      final data = resp.data;
      if (data['status_code'] == '0' && data['access_token'] != null) {
        await _saveTokens(data);
        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  // 确保Token有效
  Future<bool> ensureToken() async {
    if (isLoggedIn) return true;
    return await refreshToken();
  }

  // ==================== 开放平台 Token 管理 ====================

  bool get _isOpenTokenValid {
    return _openAccessToken != null &&
        _openAccessToken!.isNotEmpty &&
        DateTime.now().millisecondsSinceEpoch < _openExpiresAt - 60000;
  }

  /// 打开 app 时调用：换取或刷新开放平台 token
  /// 流程：generate → authorize → oauth/token
  Future<void> ensureOpenToken() async {
    _lastOpenError = null;
    if (_isOpenTokenValid) return;
    if (_openRefreshToken != null && _openRefreshToken!.isNotEmpty) {
      if (await _refreshOpenToken()) return;
    }
    await _exchangeForOpenToken();
  }

  /// generate → authorize → oauth/token
  Future<bool> _exchangeForOpenToken() async {
    if (_accessToken == null || _accessToken!.isEmpty) {
      _lastOpenError = '未登录引力域';
      return false;
    }
    try {
      final cleanDio = Dio();

      // 步骤1: generate 拿 qrcode_id
      final qrId = await _openGenerate(cleanDio);
      if (qrId == null) return false;

      // 步骤2: authorize 拿 code
      final code = await _openAuthorize(cleanDio, qrId);
      if (code == null) return false;

      // 步骤3: oauth/token 换 access_token + refresh_token
      return await _openExchangeCode(cleanDio, code);
    } catch (e) {
      _lastOpenError = '换取异常: $e';
    }
    return false;
  }

  /// 步骤1: POST /oauth/api/qrcode/generate → 响应头 qrcode_id
  Future<String?> _openGenerate(Dio cleanDio) async {
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final deviceId = 'f${_accessToken!.substring(0, 15)}'; // 16 hex

    final params = {
      'client_id': _openClientId,
      'device_id': deviceId,
      'nonce': 'WYYL',
      'size': 'L',
      'state': 'OPPOWATCH',
      'timestamp': ts,
      'appCode': 'usercenter',
    };
    params['sign'] = _calcOpenSign(params);

    final resp = await cleanDio.post(
      '$_openBase/oauth/api/qrcode/generate',
      data: Uri(queryParameters: params).query,
      options: Options(
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        responseType: ResponseType.bytes,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final qrId = resp.headers.value('qrcode_id') ??
        resp.headers.value('qrcodeId') ??
        resp.headers.value('X-Qrcode-Id');
    if (qrId != null) return qrId;

    _lastOpenError = 'generate 未返回 qrcode_id';
    return null;
  }

  /// 步骤2: POST incallapi/oauth/api/qrcode/authorize → 授权码
  Future<String?> _openAuthorize(Dio cleanDio, String qrId) async {
    final resp = await cleanDio.post(
      '$_cacApiBase/oauth/api/qrcode/authorize',
      data: 'token=$_accessToken&qrcodeId=$qrId',
      options: Options(
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ),
    );
    final data = resp.data;
    if (data['success'] == true && data['data'] != null) {
      return data['data'] as String;
    }
    _lastOpenError = 'authorize失败: ${data['msg'] ?? data.toString()}';
    return null;
  }

  /// 步骤3: POST /oauth/token (authorization_code) → access_token + refresh_token
  Future<bool> _openExchangeCode(Dio cleanDio, String code) async {
    final resp = await cleanDio.post(
      '$_openBase/oauth/token',
      data: 'redict_uri=&code=$code&grant_type=authorization_code'
          '&client_secret=$_openClientSecret&client_id=$_openClientId',
      options: Options(
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ),
    );
    return _saveOpenTokenData(resp.data);
  }

  /// 刷新: POST /oauth/token (refresh_token)
  Future<bool> _refreshOpenToken() async {
    if (_openRefreshToken == null || _openRefreshToken!.isEmpty) return false;
    try {
      final cleanDio = Dio();
      final resp = await cleanDio.post(
        '$_openBase/oauth/token',
        data: 'redict_uri=&refresh_token=$_openRefreshToken'
            '&grant_type=refresh_token'
            '&client_secret=$_openClientSecret&client_id=$_openClientId',
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );
      return _saveOpenTokenData(resp.data);
    } catch (e) {
      _lastOpenError = '刷新异常: $e';
    }
    return false;
  }

  /// 保存开放平台 token 数据
  bool _saveOpenTokenData(dynamic data) {
    if (data['access_token'] != null) {
      _openAccessToken = data['access_token'];
      _openRefreshToken = data['refresh_token'] ?? _openRefreshToken;
      _openUid = data['uid'] ?? _openUid;
      _openSecretKey = data['secret_key'] ?? _openSecretKey;
      _openExpiresAt = DateTime.now().millisecondsSinceEpoch +
          ((data['expires_in'] as int?) ?? 86400) * 1000;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('open_access_token', _openAccessToken ?? '');
        prefs.setString('open_refresh_token', _openRefreshToken ?? '');
        prefs.setInt('open_expires_at', _openExpiresAt);
        if (_openUid != null) prefs.setString('open_uid', _openUid!);
        if (_openSecretKey != null) {
          prefs.setString('open_secret_key', _openSecretKey!);
        }
      });
      return true;
    }
    _lastOpenError =
        'token换取失败: ${data['error_description'] ?? data.toString()}';
    return false;
  }

  /// SignUtil: 去掉 appCode/sign，加 appKey，key排序拼接，SHA256 大写
  String _calcOpenSign(Map<String, String> params) {
    final p = Map<String, String>.from(params);
    p.remove('appCode');
    p.remove('sign');
    p['appKey'] = _openClientSecret;
    final keys = p.keys.toList()..sort();
    final buf = StringBuffer();
    for (final k in keys) {
      final v = p[k];
      if (v != null && v.isNotEmpty) {
        buf.write('$k=$v&');
      }
    }
    final bytes = utf8.encode(buf.toString());
    final digest = SHA256Digest().process(Uint8List.fromList(bytes));
    return digest
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  /// 通过开放平台 (openc-apigw) 执行空调指令
  Future<ApiResponse> executeACCommand(String cmd) async {
    await ensureOpenToken();
    if (!_isOpenTokenValid) {
      return ApiResponse(
          code: -1, msg: '空调token获取失败: ${_lastOpenError ?? "未知原因"}');
    }
    if (_carId == null || _carId!.isEmpty) {
      return ApiResponse(code: -1, msg: '未选择车辆');
    }
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final body = jsonEncode({
        'mapArgsJson': '{}',
        'senderType': 'APP',
        'cmd': cmd,
        'carId': _carId,
      });
      final resp = await Dio().post(
        '$_openBase/openc-apigw/vrtm-agent/api/v2/open/car-control/$cmd',
        data: body,
        options: Options(
          headers: {
            'x-vcs-nonce': 'WYYL',
            'x-vcs-user-access-token': _openAccessToken,
            'x-vcs-timestamp': timestamp,
            'Content-Type': 'application/json; charset=utf-8',
            'User-Agent': 'okhttp/3.10.0',
          },
        ),
      );
      final data = resp.data;
      if (data['success'] == true) {
        // 开放平台返回taskId时，复用V5轮询接口等待执行结果
        final taskId = data['data'] != null ? data['data']['taskId'] : null;
        if (taskId != null) {
          return await pollControlStatus(taskId);
        }
        return ApiResponse(code: 0, msg: data['msg'] ?? '指令已发送');
      }
      return ApiResponse(code: -1, msg: data['msg'] ?? '指令发送失败');
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 发送验证码
  Future<ApiResponse> sendSmsCode(String phone) async {
    try {
      final resp = await _dio.post(
        '$_apiBase/api/sms/sendAuthcode',
        data: 'phone=$phone',
        options: Options(
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'Content-Type': 'application/x-www-form-urlencoded',
            'vcs-app-id': 'inCall',
          },
        ),
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 登录（第一阶段）
  Future<ApiResponse> login(String phone, String code) async {
    try {
      final resp = await _dio.post(
        '$_apiBase/app2/api/oauth2login/token/stageOne',
        data: 'mobile=$phone&vercode=$code',
        options: Options(
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'Content-Type': 'application/x-www-form-urlencoded',
            'vcs-app-id': 'inCall',
            'X-Requested-With': 'cn.com.changan.cvim',
          },
        ),
      );
      final apiResp = ApiResponse.fromJson(resp.data);
      if (apiResp.code == 0 && apiResp.data != null) {
        await _saveTokens(apiResp.data);
        _phone = phone;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phone', phone);
      }
      return apiResp;
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 获取用户车辆列表
  Future<ApiResponse> getUserCars() async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.get(
        '$_apiBase/app2/api/user/cars?type=0&token=$_accessToken',
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 获取车辆实时数据
  Future<ApiResponse> getCarData() async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.post(
        '$_apiBase/app2/api/car/data?carId=$_carId&ErrorAutoProjectile=false&toast=false&keys=*&token=$_accessToken&isNev=0',
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 获取实名认证记录（用于计算陪伴天数）
  Future<ApiResponse> getRealNameRecord() async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.get(
        '$_apiBase/app2/api/v3/real-name-auth/getRealNameRecord?currentPage=1&pageSize=1000&loading=true&token=$_accessToken',
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 获取PIN验证码
  Future<ApiResponse> createPinVerifyCode() async {
    try {
      final resp = await _dio.post(
        '$_apiBase/app2/api/control/createPinVerifyCode',
        data: 'token=$_accessToken',
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 获取安全公钥
  Future<ApiResponse> getSecurityKey() async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.get(
        '$_apiBase/app2/api/v2/security/key?carId=$_carId&moblie=&token=$_accessToken',
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 获取pinToken (v5新增步骤)
  Future<ApiResponse> getPinToken(String s) async {
    try {
      final resp = await _dio.post(
        '$_apiBase/app2/api/v5/control/get-pin-token?token=$_accessToken&s=${Uri.encodeComponent(s)}',
        data: jsonEncode({'carId': _carId, 'deviceId': _deviceId}),
        options: Options(
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        ),
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // RSA-OAEP-SHA256 加密
  String rsaOAEPEncrypt(String plaintext, String publicKeyB64) {
    final pem =
        '-----BEGIN PUBLIC KEY-----\n$publicKeyB64\n-----END PUBLIC KEY-----';
    final publicKey = CryptoUtils.rsaPublicKeyFromPem(pem);
    final cipher = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final encrypted =
        cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    return base64Encode(encrypted);
  }

  // 获取控车码开关状态
  Future<ApiResponse> getPinStatus() async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.get(
        '$_apiBase/app2/api/v2/pin/get-pin-set?carId=$_carId&token=$_accessToken',
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 更新控车码开关状态
  Future<ApiResponse> updatePinStatus(bool pinSwitch,
      {String authCode = ''}) async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.get(
        '$_apiBase/app2/api/v2/pin/update-pin-set?carId=$_carId&token=$_accessToken&pinSwitch=$pinSwitch&authCode=$authCode',
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 发送控车码短信验证码
  Future<ApiResponse> sendControlCodeSms() async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.post(
        '$_apiBase/app2/api/code/cac/sms',
        data: 'token=$_accessToken&usage=carPinSet&mobile=$_phone',
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 执行控制指令
  Future<ApiResponse> executeCommand(String cmd,
      {Map<String, dynamic>? extraParams, String pin = ''}) async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      await refreshToken();
      final pinRes = await createPinVerifyCode();
      final keyRes = await getSecurityKey();
      if (pinRes.code != 0) return ApiResponse(code: -1, msg: 'PIN获取失败');
      if (keyRes.code != 0) return ApiResponse(code: -1, msg: '公钥获取失败');

      final plaintext = jsonEncode({
        'pinVerifyCode': pinRes.data,
        'cmd': cmd,
        'type': cmd,
        'pin': pin,
        'wifiPassword': '',
      });
      final s = rsaOAEPEncrypt(plaintext, keyRes.data);

      // v5: 获取pinToken
      final ptRes = await getPinToken(s);
      if (ptRes.code != 0) return ApiResponse(code: -1, msg: 'pinToken获取失败');

      // v5: 生成control-trace-id
      final traceId =
          'tlv_cmd_req_${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';

      String body =
          's=${Uri.encodeComponent(s)}&isNev=0&token=$_accessToken&carId=$_carId&pinToken=${ptRes.data}&deviceId=$_deviceId';
      if (extraParams != null) {
        for (final entry in extraParams.entries) {
          body +=
              '&${entry.key}=${Uri.encodeComponent(entry.value.toString())}';
        }
      }

      final resp = await _dio.post(
        '$_apiBase/app2/api/v5/control/execute',
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'control-trace-id': traceId,
          },
        ),
      );
      final data = ApiResponse.fromJson(resp.data);
      // code:3 表示需要输入控车码，直接返回让UI层处理
      if (data.code == 3) {
        return ApiResponse(code: 3, msg: data.msg ?? '输入控车码');
      }
      if (data.code != 0) {
        return ApiResponse(code: -1, msg: data.msg ?? '指令发送失败');
      }

      // 轮询指令执行状态
      if (data.data != null && data.data['taskId'] != null) {
        final result = await pollControlStatus(data.data['taskId']);
        return result;
      }
      return data;
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 轮询控制指令执行状态
  Future<ApiResponse> pollControlStatus(String taskId,
      {int maxRetries = 15}) async {
    for (int i = 0; i < maxRetries; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final resp = await _dio.post(
          '$_apiBase/api/car/getControlInfo',
          data: 'token=$_accessToken&carId=$_carId&id=$taskId&isNev=0',
          options: Options(
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          ),
        );
        final data = ApiResponse.fromJson(resp.data);
        if (data.code == 0 && data.data != null) {
          final status = data.data['handleStatus'];
          if (status == 'Completed') {
            return ApiResponse(code: 0, data: data.data);
          }
          if (status == 'Failed') {
            return ApiResponse(
                code: -1, msg: data.data['handleStatusDesc'] ?? '指令执行失败');
          }
        }
      } catch (e) {
        // 继续重试
      }
    }
    return ApiResponse(code: -1, msg: '指令执行超时');
  }

  // 车辆诊断
  Future<ApiResponse> getDiagnosis() async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.post('$_apiBase/dg/app/api/check/result',
          data: 'carId=$_carId&token=$_accessToken&accessToken=$_accessToken',
          options: Options(
            headers: {
              'vcs-app-id': 'inCall',
              'Content-Type': 'application/x-www-form-urlencoded',
              'X-Requested-With': 'cn.com.changan.cvim',
              'Authorization': 'Bearer $_accessToken',
            },
          ));
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 行驶记录
  Future<ApiResponse> getDrivingHistory(
      String startDate, String endDate) async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.get(
          '$_apiBase/app2/api/driving?carId=$_carId&startDate=$startDate&endDate=$endDate&loading=false&toast=false&ErrorAutoProjectile=false&token=$_accessToken');
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 全景照片
  Future<ApiResponse> getPanoramaPhotos(
      {int pageIndex = 0, int pageSize = 20}) async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.post(
          '$_apiBase/appserver/api/file/getMediaFilesByUserIdAndCarId?pageIndex=$pageIndex&pageSize=$pageSize&carId=$_carId&fileType=1&ErrorAutoProjectile=false&token=$_accessToken&isNev=0&deviceId=00000000-4627-0c29-ffff-ffffef05ac4a');
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 操作记录
  Future<ApiResponse> getControlHistory(
      {int page = 0, int pageSize = 20}) async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final endDate = DateTime.now();
      final startDate = DateTime(endDate.year, endDate.month - 6, endDate.day);
      String fmtDate(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}+${d.hour.toString().padLeft(2, '0')}%3A${d.minute.toString().padLeft(2, '0')}%3A${d.second.toString().padLeft(2, '0')}';
      final resp = await _dio.post(
          '$_apiBase/appserver/api/car/getControlActionHistory?carId=$_carId&pageSize=$pageSize&page=$page&startTime=${fmtDate(startDate)}&endTime=${fmtDate(endDate)}&toast=false&ErrorAutoProjectile=false&token=$_accessToken&isNev=0');
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 获取车辆位置
  Future<ApiResponse> getCarLocation() async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      final resp = await _dio.post(
        '$_apiBase/appserver/api/cardata/getCarLocation?carId=$_carId&mapType=AMap&loading=false&ErrorAutoProjectile=false&token=$_accessToken',
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  // 更新车辆信息
  Future<ApiResponse> updateCar({String? carName, String? plateNumber}) async {
    if (!await ensureToken()) {
      return ApiResponse(code: -1, msg: '登录已过期');
    }
    try {
      var params = 'carId=$_carId&token=$_accessToken';
      if (carName != null) {
        params += '&carName=${Uri.encodeComponent(carName)}';
      }
      if (plateNumber != null) {
        params += '&plateNumber=${Uri.encodeComponent(plateNumber)}';
      }
      final resp = await _dio.post(
        '$_apiBase/app2/api/car/update',
        data: params,
        options: Options(
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'vcs-app-id': 'inCall',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
      return ApiResponse.fromJson(resp.data);
    } on DioException catch (e) {
      return ApiResponse(code: -1, msg: _getErrorMessage(e));
    }
  }

  String _getErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '网络超时，请稍后重试';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '网络连接失败，请检查网络';
    }
    return '网络错误，请稍后重试';
  }
}

class ApiResponse {
  final int code;
  final String? msg;
  final dynamic data;

  ApiResponse({required this.code, this.msg, this.data});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      code: json['code'] ?? json['status_code'] ?? -1,
      msg: json['msg'] ?? json['message'],
      data: json['data'],
    );
  }
}
