package com.trailcapsule.trail_capsule

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.view.Gravity
import android.widget.*
import java.io.File
import java.util.concurrent.Executors

/** Render one bounded-resolution page at a time; never decode a whole PDF into RAM. */
class PdfActivity : Activity() {
    private var renderer: PdfRenderer? = null
    private var descriptor: ParcelFileDescriptor? = null
    private val worker=Executors.newSingleThreadExecutor()
    private var page=0
    private var bitmap:Bitmap?=null
    private lateinit var image:CapsulePdfImageView
    private lateinit var label:TextView
    private lateinit var previous:Button
    private lateinit var next:Button
    private var loading=false
    override fun onCreate(state:Bundle?) {
        super.onCreate(state)
        val root=LinearLayout(this).apply {orientation=LinearLayout.VERTICAL;setBackgroundColor(Color.rgb(247,246,240));setPadding(16,48,16,28)}
        root.setOnApplyWindowInsetsListener { view, insets ->
            val padding=(16*resources.displayMetrics.density).toInt()
            if(android.os.Build.VERSION.SDK_INT>=30){
                val bars=insets.getInsets(android.view.WindowInsets.Type.systemBars())
                view.setPadding(padding,bars.top+padding,padding,bars.bottom+padding)
            }else{
                @Suppress("DEPRECATION")
                view.setPadding(padding,insets.systemWindowInsetTop+padding,padding,insets.systemWindowInsetBottom+padding)
            }
            insets
        }
        val close=Button(this).apply {text="‹ 返回资料袋";setOnClickListener{finish()}}
        root.addView(close)
        root.addView(TextView(this).apply{text=intent.getStringExtra("title")?:"PDF";textSize=18f;setPadding(8,16,8,16)})
        image=CapsulePdfImageView(this).apply {contentDescription="PDF 当前页，可双指缩放并拖动"}
        root.addView(image,LinearLayout.LayoutParams(-1,0,1f))
        val bar=LinearLayout(this).apply{gravity=Gravity.CENTER;orientation=LinearLayout.HORIZONTAL}
        previous=Button(this).apply{text="上一页";setOnClickListener{render(page-1)}}
        next=Button(this).apply{text="下一页";setOnClickListener{render(page+1)}}
        label=TextView(this).apply{setPadding(16,0,16,0)}
        bar.addView(previous);bar.addView(label);bar.addView(next);root.addView(bar);setContentView(root)
        try {
            val path=intent.getStringExtra("path")?:throw IllegalArgumentException()
            val file=AppFilePolicy.resolveReadable(
                path,
                listOf(filesDir,noBackupFilesDir,cacheDir,File(applicationInfo.dataDir)),
                requiredExtension="pdf",
            )?:throw IllegalArgumentException()
            descriptor=ParcelFileDescriptor.open(file,ParcelFileDescriptor.MODE_READ_ONLY)
            renderer=PdfRenderer(descriptor!!)
            render(state?.getInt("page")?:0)
        } catch(e:Exception){label.text="无法打开 PDF（可能损坏或有密码）";previous.isEnabled=false;next.isEnabled=false}
    }
    private fun render(index:Int) {
        val pdf=renderer?:return
        if(loading||index<0||index>=pdf.pageCount)return
        loading=true;previous.isEnabled=false;next.isEnabled=false;label.text="加载中…"
        worker.execute {
            try {
                val b=pdf.openPage(index).use { p ->
                    val scale=minOf(2f,1800f/maxOf(p.width,p.height))
                    val b=Bitmap.createBitmap(maxOf(1,(p.width*scale).toInt()),maxOf(1,(p.height*scale).toInt()),Bitmap.Config.ARGB_8888)
                    b.eraseColor(Color.WHITE);p.render(b,null,null,PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);b
                }
                runOnUiThread {
                    if(isFinishing||isDestroyed){b.recycle();return@runOnUiThread}
                    page=index;image.showPage(b);bitmap?.recycle();bitmap=b
                    label.text="${index+1} / ${pdf.pageCount}";loading=false;previous.isEnabled=index>0;next.isEnabled=index<pdf.pageCount-1
                }
            }catch(e:Exception){runOnUiThread{loading=false;label.text="此页无法显示";previous.isEnabled=index>0;next.isEnabled=index<pdf.pageCount-1}}
        }
    }
    override fun onSaveInstanceState(out:Bundle){out.putInt("page",page);super.onSaveInstanceState(out)}
    override fun onDestroy(){worker.execute{renderer?.close();descriptor?.close()};worker.shutdown();super.onDestroy()}
}

class CapsulePdfImageView(context:android.content.Context):ImageView(context) {
    private val transform=android.graphics.Matrix()
    private var zoom=1f
    private var lastX=0f
    private var lastY=0f
    private val scaleDetector=android.view.ScaleGestureDetector(context,object:android.view.ScaleGestureDetector.SimpleOnScaleGestureListener(){
        override fun onScale(detector:android.view.ScaleGestureDetector):Boolean {
            val next=(zoom*detector.scaleFactor).coerceIn(1f,5f)
            val factor=next/zoom;zoom=next
            transform.postScale(factor,factor,detector.focusX,detector.focusY);imageMatrix=transform;return true
        }
    })
    init{scaleType=ScaleType.MATRIX}
    fun showPage(bitmap:Bitmap){setImageBitmap(bitmap);resetTransform()}
    override fun onSizeChanged(w:Int,h:Int,oldw:Int,oldh:Int){super.onSizeChanged(w,h,oldw,oldh);resetTransform()}
    private fun resetTransform(){
        val image=drawable?:return
        if(width==0||height==0)return
        val fit=minOf(width.toFloat()/image.intrinsicWidth,height.toFloat()/image.intrinsicHeight)
        transform.reset();transform.postScale(fit,fit);transform.postTranslate((width-image.intrinsicWidth*fit)/2,(height-image.intrinsicHeight*fit)/2)
        zoom=1f;imageMatrix=transform
    }
    override fun onTouchEvent(event:android.view.MotionEvent):Boolean {
        scaleDetector.onTouchEvent(event)
        when(event.actionMasked){
            android.view.MotionEvent.ACTION_DOWN->{lastX=event.x;lastY=event.y}
            android.view.MotionEvent.ACTION_MOVE->{if(!scaleDetector.isInProgress&&zoom>1f){transform.postTranslate(event.x-lastX,event.y-lastY);imageMatrix=transform};lastX=event.x;lastY=event.y}
            android.view.MotionEvent.ACTION_UP->performClick()
        }
        return true
    }
    override fun performClick():Boolean{super.performClick();return true}
}
