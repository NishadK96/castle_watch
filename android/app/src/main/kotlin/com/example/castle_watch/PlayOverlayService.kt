package com.example.castle_watch

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.ArrayAdapter
import android.widget.AutoCompleteTextView
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class PlayOverlayService : Service() {
    private lateinit var windowManager: WindowManager
    private var overlay: LinearLayout? = null
    private lateinit var params: WindowManager.LayoutParams
    private var sessionId = ""
    private var secret = ""
    private var supabaseUrl = ""
    private var anonKey = ""
    private val accountIds = mutableMapOf<String, String>()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        sessionId = intent?.getStringExtra("sessionId").orEmpty()
        secret = intent?.getStringExtra("secret").orEmpty()
        supabaseUrl = intent?.getStringExtra("supabaseUrl").orEmpty()
        anonKey = intent?.getStringExtra("anonKey").orEmpty()
        accountIds.clear()
        val rows = JSONArray(intent?.getStringExtra("accounts") ?: "[]")
        for (index in 0 until rows.length()) {
            val row = rows.getJSONObject(index)
            accountIds[row.getString("name")] = row.getString("id")
        }
        startForegroundNotification()
        showOverlay()
        return START_STICKY
    }

    private fun startForegroundNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    "play_overlay",
                    "Play overlay",
                    NotificationManager.IMPORTANCE_LOW
                )
            )
        }
        startForeground(
            91043,
            NotificationCompat.Builder(this, "play_overlay")
                .setSmallIcon(applicationInfo.icon)
                .setContentTitle("Castle Watch picker active")
                .setContentText("Use the floating picker to mark played accounts.")
                .setOngoing(true)
                .build()
        )
    }

    private fun showOverlay() {
        overlay?.let { windowManager.removeView(it) }
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(10), dp(14), dp(12))
            setBackgroundColor(Color.rgb(18, 29, 47))
        }
        val header = TextView(this).apply {
            text = "Castle Watch  •  drag"
            setTextColor(Color.WHITE)
            textSize = 15f
            setPadding(0, 0, 0, dp(8))
        }
        val picker = AutoCompleteTextView(this).apply {
            hint = "Search account"
            setTextColor(Color.WHITE)
            setHintTextColor(Color.LTGRAY)
            threshold = 1
            setSingleLine()
            setAdapter(
                ArrayAdapter(
                    this@PlayOverlayService,
                    android.R.layout.simple_dropdown_item_1line,
                    accountIds.keys.toList()
                )
            )
        }
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }
        val close = Button(this).apply {
            text = "Close"
            setOnClickListener { stopSelf() }
        }
        val played = Button(this).apply {
            text = "Mark played"
            setOnClickListener {
                val name = picker.text.toString().trim()
                val accountId = accountIds[name]
                if (accountId == null) {
                    Toast.makeText(context, "Select an account from the list", Toast.LENGTH_SHORT).show()
                } else {
                    markPlayed(accountId, name) { picker.setText("") }
                }
            }
        }
        actions.addView(close)
        actions.addView(played)
        panel.addView(header)
        panel.addView(picker, LinearLayout.LayoutParams(dp(300), dp(52)))
        panel.addView(actions)

        params = WindowManager.LayoutParams(
            dp(330),
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(100)
        }
        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        header.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = startX + (event.rawX - touchX).toInt()
                    params.y = startY + (event.rawY - touchY).toInt()
                    windowManager.updateViewLayout(panel, params)
                    true
                }
                else -> false
            }
        }
        overlay = panel
        windowManager.addView(panel, params)
    }

    private fun markPlayed(accountId: String, name: String, success: () -> Unit) {
        thread {
            try {
                val connection = URL(
                    "$supabaseUrl/rest/v1/rpc/mark_played_from_session"
                ).openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("apikey", anonKey)
                connection.setRequestProperty("Authorization", "Bearer $anonKey")
                connection.doOutput = true
                connection.outputStream.use {
                    it.write(
                        JSONObject(
                            mapOf(
                                "p_session_id" to sessionId,
                                "p_secret" to secret,
                                "p_account_id" to accountId
                            )
                        ).toString().toByteArray()
                    )
                }
                if (connection.responseCode !in 200..299) {
                    throw IllegalStateException(connection.errorStream?.bufferedReader()?.readText())
                }
                overlay?.post {
                    success()
                    Toast.makeText(this, "$name marked as played", Toast.LENGTH_SHORT).show()
                }
                connection.disconnect()
            } catch (error: Exception) {
                overlay?.post {
                    Toast.makeText(this, "Check-in failed: ${error.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    override fun onDestroy() {
        overlay?.let { windowManager.removeView(it) }
        overlay = null
        super.onDestroy()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
