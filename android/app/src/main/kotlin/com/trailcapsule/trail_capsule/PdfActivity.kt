package com.trailcapsule.trail_capsule

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.animation.OvershootInterpolator
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.util.concurrent.Executors

/** Render one bounded-resolution page at a time; never decode a whole PDF into RAM. */
class PdfActivity : Activity() {
    private val backgroundColor = Color.rgb(255, 250, 243)
    private val inkColor = Color.rgb(53, 37, 30)
    private val oceanColor = Color.rgb(217, 119, 48)
    private val mutedColor = Color.rgb(129, 114, 105)
    private val skyColor = Color.rgb(240, 233, 255)
    private val lineColor = Color.rgb(240, 230, 219)
    private val disabledColor = Color.rgb(249, 241, 232)

    private var renderer: PdfRenderer? = null
    private var descriptor: ParcelFileDescriptor? = null
    private val worker = Executors.newSingleThreadExecutor()
    private var page = 0
    private var bitmap: Bitmap? = null
    private lateinit var image: CapsulePdfImageView
    private lateinit var label: TextView
    private lateinit var previous: TextView
    private lateinit var next: TextView
    private var loading = false

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(backgroundColor)
        }
        root.setOnApplyWindowInsetsListener { view, insets ->
            val horizontal = dp(18)
            val vertical = dp(14)
            if (Build.VERSION.SDK_INT >= 30) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars())
                view.setPadding(
                    horizontal,
                    bars.top + vertical,
                    horizontal,
                    bars.bottom + vertical,
                )
            } else {
                @Suppress("DEPRECATION")
                view.setPadding(
                    horizontal,
                    insets.systemWindowInsetTop + vertical,
                    horizontal,
                    insets.systemWindowInsetBottom + vertical,
                )
            }
            insets
        }

        val header = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            orientation = LinearLayout.HORIZONTAL
        }
        val close = TextView(this).apply {
            text = "‹  返回资料袋"
            textSize = 15f
            setTextColor(oceanColor)
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
            minHeight = dp(44)
            setPadding(dp(16), dp(10), dp(16), dp(10))
            background = ripple(skyColor, dp(16))
            isClickable = true
            isFocusable = true
            contentDescription = "返回资料袋"
            setOnClickListener { finish() }
            addPressBounce(this)
        }
        val offline = TextView(this).apply {
            text = "离线阅读"
            textSize = 12f
            setTextColor(mutedColor)
            gravity = Gravity.CENTER_VERTICAL or Gravity.END
            setPadding(dp(12), 0, dp(4), 0)
        }
        header.addView(close)
        header.addView(offline, LinearLayout.LayoutParams(0, -2, 1f))
        root.addView(header)

        val title = TextView(this).apply {
            text = intent.getStringExtra("title") ?: "PDF 资料"
            textSize = 22f
            setTextColor(inkColor)
            setTypeface(typeface, Typeface.BOLD)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
        }
        root.addView(
            title,
            LinearLayout.LayoutParams(-1, -2).apply {
                topMargin = dp(18)
                bottomMargin = dp(14)
            },
        )

        image = CapsulePdfImageView(this).apply {
            contentDescription = "PDF 当前页，可双指缩放并拖动"
            background = shape(Color.WHITE, dp(20), lineColor)
            clipToOutline = true
            elevation = dp(2).toFloat()
        }
        root.addView(
            image,
            LinearLayout.LayoutParams(-1, 0, 1f).apply { bottomMargin = dp(14) },
        )

        val bar = LinearLayout(this).apply {
            gravity = Gravity.CENTER
            orientation = LinearLayout.HORIZONTAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
            background = shape(Color.WHITE, dp(20), lineColor)
            elevation = dp(2).toFloat()
        }
        previous = pageControl("上一页") { render(page - 1) }
        next = pageControl("下一页") { render(page + 1) }
        label = TextView(this).apply {
            text = "准备中…"
            textSize = 14f
            setTextColor(inkColor)
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
            minWidth = dp(70)
            setPadding(dp(12), dp(8), dp(12), dp(8))
            maxLines = 2
        }
        bar.addView(previous, LinearLayout.LayoutParams(0, -2, 1f))
        bar.addView(label)
        bar.addView(next, LinearLayout.LayoutParams(0, -2, 1f))
        root.addView(bar)
        setContentView(root)
        // Android 15 requires the window decor to exist before its insets controller is read.
        configureSystemBars()

        try {
            val path = intent.getStringExtra("path") ?: throw IllegalArgumentException()
            val file = AppFilePolicy.resolveReadable(
                path,
                listOf(filesDir, noBackupFilesDir, cacheDir, File(applicationInfo.dataDir)),
                requiredExtension = "pdf",
            ) ?: throw IllegalArgumentException()
            descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            renderer = PdfRenderer(descriptor!!)
            render(state?.getInt("page") ?: 0)
        } catch (_: Exception) {
            label.text = "无法预览"
            updatePageControls(0, 0)
            Toast.makeText(this, "无法打开 PDF，文件可能已损坏或设有密码。", Toast.LENGTH_LONG).show()
        }
    }

    private fun render(index: Int) {
        val pdf = renderer ?: return
        if (loading || index < 0 || index >= pdf.pageCount) return
        loading = true
        stylePageControl(previous, filled = false, enabled = false)
        stylePageControl(next, filled = true, enabled = false)
        label.text = "加载中…"
        worker.execute {
            try {
                val rendered = pdf.openPage(index).use { pdfPage ->
                    val scale = minOf(2f, 1800f / maxOf(pdfPage.width, pdfPage.height))
                    Bitmap.createBitmap(
                        maxOf(1, (pdfPage.width * scale).toInt()),
                        maxOf(1, (pdfPage.height * scale).toInt()),
                        Bitmap.Config.ARGB_8888,
                    ).also { target ->
                        target.eraseColor(Color.WHITE)
                        pdfPage.render(target, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    }
                }
                runOnUiThread {
                    if (isFinishing || isDestroyed) {
                        rendered.recycle()
                        return@runOnUiThread
                    }
                    page = index
                    image.animate().cancel()
                    image.alpha = 0f
                    image.showPage(rendered)
                    bitmap?.recycle()
                    bitmap = rendered
                    image.animate().alpha(1f).setDuration(180).start()
                    label.text = "${index + 1} / ${pdf.pageCount}"
                    loading = false
                    updatePageControls(index, pdf.pageCount)
                }
            } catch (_: Exception) {
                runOnUiThread {
                    loading = false
                    label.text = "此页无法显示"
                    updatePageControls(index, pdf.pageCount)
                }
            }
        }
    }

    private fun pageControl(textValue: String, onClick: () -> Unit) = TextView(this).apply {
        text = textValue
        textSize = 14f
        setTypeface(typeface, Typeface.BOLD)
        gravity = Gravity.CENTER
        minHeight = dp(48)
        setPadding(dp(12), dp(12), dp(12), dp(12))
        isClickable = true
        isFocusable = true
        setOnClickListener { onClick() }
        addPressBounce(this)
    }

    private fun addPressBounce(view: View) {
        view.setOnTouchListener { target, event ->
            if (!target.isEnabled) return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    target.animate().cancel()
                    target.animate().scaleX(.96f).scaleY(.96f).setDuration(90).start()
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    target.animate().cancel()
                    target.animate().scaleX(1f).scaleY(1f).setDuration(340)
                        .setInterpolator(OvershootInterpolator(1.8f)).start()
                }
            }
            false // Keep Android's click and accessibility behavior.
        }
    }

    private fun updatePageControls(index: Int, pageCount: Int) {
        stylePageControl(previous, filled = false, enabled = pageCount > 0 && index > 0)
        stylePageControl(next, filled = true, enabled = pageCount > 0 && index < pageCount - 1)
    }

    private fun stylePageControl(control: TextView, filled: Boolean, enabled: Boolean) {
        control.isEnabled = enabled
        when {
            !enabled -> {
                control.setTextColor(Color.rgb(160, 145, 133))
                control.background = shape(disabledColor, dp(14))
            }
            filled -> {
                control.setTextColor(inkColor)
                control.background = ripple(oceanColor, dp(14))
            }
            else -> {
                control.setTextColor(oceanColor)
                control.background = ripple(Color.WHITE, dp(14), oceanColor)
            }
        }
    }

    private fun shape(fill: Int, radius: Int, stroke: Int? = null) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(fill)
        cornerRadius = radius.toFloat()
        if (stroke != null) setStroke(dp(1), stroke)
    }

    private fun ripple(fill: Int, radius: Int, stroke: Int? = null): RippleDrawable {
        val content = shape(fill, radius, stroke)
        val mask = shape(Color.WHITE, radius)
        return RippleDrawable(ColorStateList.valueOf(Color.argb(38, 116, 82, 209)), content, mask)
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun configureSystemBars() {
        window.statusBarColor = backgroundColor
        window.navigationBarColor = backgroundColor
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.setSystemBarsAppearance(
                android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
                android.view.WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    android.view.WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
            )
        } else {
            @Suppress("DEPRECATION")
            run {
                window.decorView.systemUiVisibility =
                    View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            }
        }
    }

    override fun onSaveInstanceState(out: Bundle) {
        out.putInt("page", page)
        super.onSaveInstanceState(out)
    }

    override fun onDestroy() {
        worker.execute {
            renderer?.close()
            descriptor?.close()
        }
        worker.shutdown()
        super.onDestroy()
    }
}

class CapsulePdfImageView(context: android.content.Context) : ImageView(context) {
    private val transform = android.graphics.Matrix()
    private var zoom = 1f
    private var lastX = 0f
    private var lastY = 0f
    private val scaleDetector = android.view.ScaleGestureDetector(
        context,
        object : android.view.ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: android.view.ScaleGestureDetector): Boolean {
                val next = (zoom * detector.scaleFactor).coerceIn(1f, 5f)
                val factor = next / zoom
                zoom = next
                transform.postScale(factor, factor, detector.focusX, detector.focusY)
                imageMatrix = transform
                return true
            }
        },
    )

    init {
        scaleType = ScaleType.MATRIX
    }

    fun showPage(bitmap: Bitmap) {
        setImageBitmap(bitmap)
        resetTransform()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        resetTransform()
    }

    private fun resetTransform() {
        val image = drawable ?: return
        if (width == 0 || height == 0) return
        val fit = minOf(
            width.toFloat() / image.intrinsicWidth,
            height.toFloat() / image.intrinsicHeight,
        )
        transform.reset()
        transform.postScale(fit, fit)
        transform.postTranslate(
            (width - image.intrinsicWidth * fit) / 2,
            (height - image.intrinsicHeight * fit) / 2,
        )
        zoom = 1f
        imageMatrix = transform
    }

    override fun onTouchEvent(event: android.view.MotionEvent): Boolean {
        scaleDetector.onTouchEvent(event)
        when (event.actionMasked) {
            android.view.MotionEvent.ACTION_DOWN -> {
                lastX = event.x
                lastY = event.y
            }
            android.view.MotionEvent.ACTION_MOVE -> {
                if (!scaleDetector.isInProgress && zoom > 1f) {
                    transform.postTranslate(event.x - lastX, event.y - lastY)
                    imageMatrix = transform
                }
                lastX = event.x
                lastY = event.y
            }
            android.view.MotionEvent.ACTION_UP -> performClick()
        }
        return true
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }
}
