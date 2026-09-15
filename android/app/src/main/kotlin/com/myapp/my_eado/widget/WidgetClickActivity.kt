package com.myapp.my_eado.widget

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import android.view.WindowManager
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.myapp.my_eado.MainActivity
import com.myapp.my_eado.R
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.KeyFactory
import java.security.PublicKey
import java.security.spec.X509EncodedKeySpec
import java.util.concurrent.Executors
import javax.crypto.Cipher

/**
 * 小组件按钮点击入口：透明 Activity，比 BroadcastReceiver 更可靠。
 * 处理完自动 finish()，用户几乎看不到界面。
 */
class WidgetClickActivity : Activity() {

    @Volatile private var finished = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val cmd = intent?.getStringExtra("command")
        val label = labelOf(cmd ?: "")
        Log.i(TAG, "click cmd=$cmd")

        if (cmd.isNullOrEmpty()) {
            finishSafe()
            return
        }

        // 不弹任何提示（MIUI Toast 也会变成居中遮罩）
        Executors.newSingleThreadExecutor().execute {
            try {
                handle(cmd)
            } catch (e: Exception) {
                Log.e(TAG, "fail $cmd", e)
            }
        }
        finishSafe()
    }

    private fun finishSafe() {
        if (finished) return
        finished = true
        try { finish() } catch (_: Exception) {}
    }

    private fun labelOf(cmd: String): String = when (cmd) {
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
        "ctrl_ac_on" -> "开空调"
        "ctrl_ac_off" -> "关空调"
        else -> "控车"
    }

    private fun handle(cmd: String): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val openToken = pref(prefs, "open_access_token")
        val carId = pref(prefs, "carId")
        if (carId.isEmpty()) {
            startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return false
        }

        // 空调：开放平台
        val oscarAc = when (cmd) {
            "ctrl_ac_on" -> "openAir"
            "ctrl_ac_off" -> "closeAir"
            else -> null
        }
        if (oscarAc != null && openToken.isNotEmpty()) {
            return postOscar(openToken, carId, oscarAc)
        }

        // 其它：只走 v5
        val v5Cmd = when (cmd) {
            "ctrl_lock" -> "LockDoor"
            "ctrl_unlock" -> "UnLockDoor"
            "ctrl_ignition_on" -> "OpenEngine"
            "ctrl_ignition_off" -> "CloseEngine"
            "ctrl_window_open" -> "OpenWindow"
            "ctrl_window_half" -> "WindowSlit"
            "ctrl_window_close" -> "CloseWindow"
            "ctrl_sunroof_open" -> "SkyWindowLiftUp"
            "ctrl_sunroof_tilt" -> "SkyWindowLiftUp"
            "ctrl_sunroof_close" -> "CloseDormer"
            else -> null
        }
        if (v5Cmd != null) {
            return postV5(prefs, carId, v5Cmd)
        }
        return false
    }

    private fun postOscar(token: String, carId: String, cmd: String): Boolean {
        val body = JSONObject()
            .put("mapArgsJson", "{}")
            .put("senderType", "APP")
            .put("cmd", cmd)
            .put("carId", carId)
            .toString()
        val url = URL("$OPEN_BASE/openc-apigw/vrtm-agent/api/v2/open/car-control/$cmd")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.connectTimeout = 15000
        conn.readTimeout = 15000
        conn.doOutput = true
        conn.setRequestProperty("Host", "open.iov.changan.com.cn")
        conn.setRequestProperty("x-vcs-nonce", "WYYL")
        conn.setRequestProperty("x-vcs-user-access-token", token)
        conn.setRequestProperty("x-vcs-timestamp", System.currentTimeMillis().toString())
        conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
        conn.setRequestProperty("User-Agent", "okhttp/3.10.0")
        OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }
        val code = conn.responseCode
        val text = readBody(conn)
        Log.i(TAG, "oscar $cmd http=$code $text")
        conn.disconnect()
        return code in 200..299 && text.contains("\"success\":true")
    }

    private fun postV5(prefs: android.content.SharedPreferences, carId: String, cmd: String): Boolean {
        val at = pref(prefs, "access_token")
        val pin = pref(prefs, "pin")
        val deviceId = DEVICE_ID

        val pinCode = httpForm(
            "$MIOV/app2/api/control/createPinVerifyCode",
            mapOf("token" to at),
            mapOf("User-Agent" to "okhttp/4.9.0", "vcs-app-id" to "inCall")
        )?.let { JSONObject(it).optString("data") }
        if (pinCode.isNullOrEmpty()) {
            Log.w(TAG, "pinVerifyCode fail atEmpty=${at.isEmpty()}")
            return false
        }

        val keyJson = httpGet(
            "$MIOV/app2/api/v2/security/key?carId=$carId&moblie=&token=${URLEncoder.encode(at, "UTF-8")}",
            mapOf("User-Agent" to "okhttp/4.9.0", "vcs-app-id" to "inCall")
        )
        val pubB64 = keyJson?.let { JSONObject(it).optString("data") }
        if (pubB64.isNullOrEmpty()) {
            Log.w(TAG, "security key fail")
            return false
        }

        val plain = JSONObject()
            .put("pinVerifyCode", pinCode)
            .put("cmd", cmd)
            .put("type", cmd)
            .put("pin", pin)
            .put("wifiPassword", "")
            .toString()
        val s = rsaOaepSha256(plain, pubB64)

        val pinTokJson = httpPost(
            "$MIOV/app2/api/v5/control/get-pin-token?token=${URLEncoder.encode(at, "UTF-8")}&s=${URLEncoder.encode(s, "UTF-8")}",
            JSONObject().put("carId", carId).put("deviceId", deviceId).toString(),
            mapOf(
                "Content-Type" to "application/json; charset=utf-8",
                "User-Agent" to "okhttp/4.9.0",
                "vcs-app-id" to "inCall"
            )
        )
        val pinToken = pinTokJson?.let { JSONObject(it).optString("data") }
        if (pinToken.isNullOrEmpty()) {
            Log.w(TAG, "pinToken fail $pinTokJson")
            return false
        }

        val form = linkedMapOf(
            "s" to s,
            "isNev" to "0",
            "token" to at,
            "carId" to carId,
            "pinToken" to pinToken,
            "deviceId" to deviceId
        )
        val trace = "tlv_cmd_req_${System.currentTimeMillis()}-${java.util.UUID.randomUUID().toString().take(6)}"
        val exec = httpForm(
            "$MIOV/app2/api/v5/control/execute",
            form,
            mapOf(
                "User-Agent" to "okhttp/4.9.0",
                "vcs-app-id" to "inCall",
                "control-trace-id" to trace
            )
        )
        Log.i(TAG, "v5 $cmd => $exec")
        return exec != null && exec.contains("\"code\":0")
    }

    private fun rsaOaepSha256(plaintext: String, publicKeyB64: String): String {
        val b64 = publicKeyB64
            .replace("-----BEGIN PUBLIC KEY-----", "")
            .replace("-----END PUBLIC KEY-----", "")
            .replace("\\s".toRegex(), "")
        val decoded = Base64.decode(b64, Base64.DEFAULT)
        val key: PublicKey = KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(decoded))
        val cipher = Cipher.getInstance("RSA/ECB/OAEPWithSHA-256AndMGF1Padding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        return Base64.encodeToString(cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8)), Base64.NO_WRAP)
    }

    private fun readBody(conn: HttpURLConnection): String {
        val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
        return stream?.bufferedReader()?.use { it.readText() } ?: ""
    }

    private fun httpGet(url: String, headers: Map<String, String>): String? {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        conn.connectTimeout = 15000
        conn.readTimeout = 15000
        headers.forEach { (k, v) -> conn.setRequestProperty(k, v) }
        val code = conn.responseCode
        val text = readBody(conn)
        conn.disconnect()
        return if (code in 200..299) text else null
    }

    private fun httpPost(url: String, body: String, headers: Map<String, String>): String? {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.connectTimeout = 15000
        conn.readTimeout = 15000
        conn.doOutput = true
        headers.forEach { (k, v) -> conn.setRequestProperty(k, v) }
        OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }
        val code = conn.responseCode
        val text = readBody(conn)
        conn.disconnect()
        return if (code in 200..299) text else null
    }

    private fun httpForm(url: String, form: Map<String, String>, headers: Map<String, String> = emptyMap()): String? {
        val body = form.entries.joinToString("&") { (k, v) ->
            "${URLEncoder.encode(k, "UTF-8")}=${URLEncoder.encode(v, "UTF-8")}"
        }
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.connectTimeout = 15000
        conn.readTimeout = 15000
        conn.doOutput = true
        conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
        headers.forEach { (k, v) -> conn.setRequestProperty(k, v) }
        OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body) }
        val code = conn.responseCode
        val text = readBody(conn)
        conn.disconnect()
        return if (code in 200..299) text else null
    }

    private fun pref(prefs: android.content.SharedPreferences, key: String): String {
        if (key == "pin") {
            return prefs.getString("flutter.preset_pin_value", "")
                ?: prefs.getString("flutter.pin", "")
                ?: prefs.getString("pin", "")
                ?: ""
        }
        return prefs.getString("flutter.$key", "") ?: prefs.getString(key, "") ?: ""
    }

    private fun notifyTip(context: Context, title: String, text: String) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val ch = NotificationChannel(CHANNEL_ID, "控车提示", NotificationManager.IMPORTANCE_DEFAULT)
                ch.setShowBadge(false)
                nm.createNotificationChannel(ch)
            }
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val n = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(text)
                .setAutoCancel(true)
                .setContentIntent(open)
                .build()
            nm.notify(System.currentTimeMillis().toInt(), n)
        } catch (e: Exception) {
            Log.e(TAG, "notify fail", e)
        }
    }

    companion object {
        private const val TAG = "WidgetClick"
        private const val OPEN_BASE = "https://open.iov.changan.com.cn"
        private const val MIOV = "https://m.iov.changan.com.cn"
        private const val DEVICE_ID = "00000000-4627-0c29-ffff-ffffef05ac4a"
        private const val CHANNEL_ID = "widget_control"
    }
}
