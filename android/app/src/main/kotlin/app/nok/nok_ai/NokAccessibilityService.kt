package app.nok.nok_ai
import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Locale
/** On-device reading only. No network, password reading, or automatic actions. */
class NokAccessibilityService : AccessibilityService(), TextToSpeech.OnInitListener {
    companion object { var instance: NokAccessibilityService? = null; private set }
    private data class Element(val label: String, val rect: Rect)
    private val handler = Handler(Looper.getMainLooper())
    private val elements = mutableListOf<Element>()
    private var panel: LinearLayout? = null
    private var status: TextView? = null
    private var highlight: Highlight? = null
    private var speech: TextToSpeech? = null
    private var ready = false
    private var visible = false
    private var automatic = false
    private var cursor = -1
    private var previous = ""
    private val wm get() = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val arabic get() = getSharedPreferences("nok_native", MODE_PRIVATE).getString("language", "ar") == "ar"
    private fun tr(ar: String, en: String) = if (arabic) ar else en
    private val inspectTask = Runnable { inspect() }
    override fun onServiceConnected() { instance = this; speech = TextToSpeech(this, this); showGuide() }
    override fun onInit(code: Int) { ready = code == TextToSpeech.SUCCESS }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!visible || event == null || event.packageName?.toString() == packageName) return
        handler.removeCallbacks(inspectTask); handler.postDelayed(inspectTask, 550)
    }
    private fun inspect() {
        if (!visible) return
        val root = rootInActiveWindow
        if (root == null) {
            elements.clear(); previous = ""; cursor = -1; highlight?.rect = null
            status?.text = tr("لا يوجد نص متاح", "No readable text")
            return
        }
        elements.clear(); cursor = -1; highlight?.rect = null
        if (root.packageName?.toString() != packageName) collect(root, 0)
        val text = elements.map { it.label }.distinct().joinToString(". ").take(3500)
        status?.text = if (text.isEmpty()) tr("لا يوجد نص متاح", "No readable text") else tr("${elements.size} عنصر", "${elements.size} elements")
        if (automatic && text.isNotEmpty() && text != previous) speak(text)
        previous = text
    }
    private fun collect(node: AccessibilityNodeInfo, depth: Int) {
        if (depth > 30 || elements.size >= 100 || node.isPassword || !node.isVisibleToUser) return
        val label = (node.text?.toString()?.takeIf { it.isNotBlank() } ?: node.contentDescription?.toString()?.takeIf { it.isNotBlank() })?.trim()
        if (label != null && label.length < 1500) {
            val rect = Rect(); node.getBoundsInScreen(rect)
            if (!rect.isEmpty && elements.none { it.label == label && it.rect == rect }) elements.add(Element(label, rect))
        }
        for (i in 0 until node.childCount) { val child = node.getChild(i) ?: continue; collect(child, depth + 1) }
    }
    private fun speak(text: String) {
        if (!ready) { status?.text = tr("انتظر تهيئة الصوت", "Voice is starting"); return }
        val result = speech?.setLanguage(if (arabic) Locale("ar") else Locale.US)
        if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
            status?.text = tr("ثبّت صوت العربية من إعدادات الجهاز", "Install a voice in device settings"); return
        }
        val prefs = getSharedPreferences("nok_native", MODE_PRIVATE)
        speech?.setSpeechRate(prefs.getFloat("rate", 0.48f).coerceIn(0.25f, 0.7f) * 2f)
        val params = Bundle().apply { putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, prefs.getFloat("volume", 0.85f).coerceIn(0f, 1f)) }
        speech?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "nok_screen")
    }
    fun showGuide() {
        hide(); visible = true
        highlight = Highlight(this)
        wm.addView(highlight, WindowManager.LayoutParams(-1, -1, WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN, PixelFormat.TRANSLUCENT))
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(16, 10, 16, 10); setBackgroundColor(Color.rgb(9,25,39)) }
        status = TextView(this).apply { text = "NOK"; textSize = 16f; setTextColor(Color.CYAN) }; layout.addView(status)
        fun button(text: String, action: () -> Unit) { layout.addView(Button(this).apply { this.text = text; textSize = 14f; minHeight = (48 * resources.displayMetrics.density).toInt(); setOnClickListener { action() } }) }
        button(tr("اقرأ الشاشة", "Read screen")) { inspect(); if (previous.isNotEmpty()) speak(previous) }
        button(tr("العنصر التالي", "Next element")) {
            if (elements.isEmpty()) inspect()
            if (elements.isNotEmpty()) { cursor = (cursor + 1) % elements.size; val e = elements[cursor]; highlight?.rect = e.rect; speak(e.label) }
        }
        button(tr("قراءة تلقائية: تشغيل / إيقاف", "Auto read: on / off")) { automatic = !automatic; if (automatic) { previous = ""; inspect() } else speech?.stop(); status?.text = if (automatic) tr("القراءة التلقائية تعمل", "Auto read on") else tr("القراءة التلقائية متوقفة", "Auto read off") }
        button(tr("إيقاف الصوت", "Stop speech")) { automatic = false; speech?.stop(); status?.text = tr("متوقف", "Stopped") }
        button(tr("إغلاق", "Close")) { hide() }
        panel = layout
        wm.addView(layout, WindowManager.LayoutParams((185 * resources.displayMetrics.density).toInt(), -2,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT).apply { gravity = Gravity.BOTTOM or Gravity.END; x = 8; y = 80 })
        handler.postDelayed(inspectTask, 500)
    }
    private fun hide() { visible = false; automatic = false; handler.removeCallbacks(inspectTask); speech?.stop(); panel?.let { wm.removeView(it) }; panel = null; highlight?.let { wm.removeView(it) }; highlight = null; status = null; elements.clear(); previous = "" }
    override fun onInterrupt() { speech?.stop() }
    override fun onDestroy() { hide(); speech?.shutdown(); instance = null; super.onDestroy() }
    private class Highlight(context: Context) : View(context) {
        var rect: Rect? = null
            set(value) { field = value; invalidate() }
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(91,203,255); strokeWidth = 6f; style = Paint.Style.STROKE }
        override fun onDraw(canvas: Canvas) { super.onDraw(canvas); rect?.let { canvas.drawRoundRect(it.left.toFloat(), it.top.toFloat(), it.right.toFloat(), it.bottom.toFloat(), 12f, 12f, paint) } }
    }
}
