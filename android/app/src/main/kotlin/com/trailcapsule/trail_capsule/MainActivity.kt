package com.trailcapsule.trail_capsule

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val inbox: File get() = File(noBackupFilesDir, "inbox").apply { mkdirs() }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) receive(intent)
    }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); setIntent(intent); receive(intent) }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.trailcapsule.app/native")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "protectStorage" -> result.success(null)
                "readInbox" -> worker.execute {
                    try {
                        val jobs = inbox.listFiles()?.filter { it.extension == "json" }?.map { file ->
                            val json = JSONObject(file.readText())
                            json.keys().asSequence().associateWith { json.get(it) }
                        } ?: emptyList()
                        runOnUiThread { result.success(jobs) }
                    } catch (e: Exception) { runOnUiThread { result.error("INBOX", "无法读取分享收件箱", null) } }
                }
                "ackInbox" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    worker.execute {
                        ids.filter { it.matches(Regex("[a-fA-F0-9-]+")) }.forEach { id ->
                            val manifest = File(inbox, "$id.json")
                            if (manifest.exists()) {
                                val json = JSONObject(manifest.readText())
                                if (json.has("path")) {
                                    val file = File(json.getString("path"))
                                    if (file.canonicalFile.parentFile == inbox.canonicalFile) file.delete()
                                }
                                manifest.delete()
                            }
                        }
                        runOnUiThread { result.success(null) }
                    }
                }
                "openPdf" -> {
                    val file = AppFilePolicy.resolveReadable(
                        call.argument<String>("path"),
                        appStorageRoots(),
                        requiredExtension = "pdf",
                    )
                    if (file == null) {
                        result.error("PATH", "文件路径无效", null)
                    } else {
                        startActivity(Intent(this, PdfActivity::class.java).putExtra("path", file.path).putExtra("title", call.argument<String>("title")))
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun appStorageRoots(): List<File> = listOf(
        filesDir,
        noBackupFilesDir,
        cacheDir,
        File(applicationInfo.dataDir),
    )
    @Suppress("DEPRECATION")
    private fun receive(incoming: Intent?) {
        if (incoming == null || incoming.action !in listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE)) return
        val uris = mutableListOf<Uri>()
        if (incoming.action == Intent.ACTION_SEND_MULTIPLE) uris.addAll(incoming.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList())
        else incoming.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { uris.add(it) }
        val text = incoming.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        val subject = incoming.getStringExtra(Intent.EXTRA_SUBJECT) ?: "分享的文字"
        setIntent(Intent(this, MainActivity::class.java))
        worker.execute {
            var saved = 0
            try {
                if (uris.size > 10) throw IllegalArgumentException("一次最多接收 10 个附件")
                for (uri in uris) {
                    var name = "资料"
                    contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) name = cursor.getString(0) ?: name
                    }
                    val ext = name.substringAfterLast('.', "").lowercase()
                    if (ext !in listOf("pdf", "jpg", "jpeg", "png", "webp", "heic", "heif")) throw IllegalArgumentException("支持图片和 PDF，请在文件应用选择原文件")
                    val id = UUID.randomUUID().toString()
                    val target = File(inbox, "$id.$ext")
                    val tmp = File(inbox, "$id.part")
                    try {
                        var total = 0L
                        val input = contentResolver.openInputStream(uri) ?: throw IllegalArgumentException("文件无法读取")
                        input.use { source -> tmp.outputStream().use { out ->
                            val buffer = ByteArray(65536)
                            while (true) { val n=source.read(buffer);if(n<0)break;total+=n;if(total>50L*1024*1024)throw IllegalArgumentException("单文件最大 50 MB");out.write(buffer,0,n) }
                            out.fd.sync()
                        } }
                        if (total == 0L) throw IllegalArgumentException("文件为空")
                        if (!tmp.renameTo(target)) throw IllegalStateException("无法保存文件")
                        saveJob(id, JSONObject().put("id",id).put("path",target.path).put("name",name))
                        saved++
                    } catch(e:Exception) { tmp.delete();target.delete();throw e }
                }
                if (uris.isEmpty() && !text.isNullOrBlank()) {
                    if(text.length>100000)throw IllegalArgumentException("文字过长，请改为文件导入")
                    val id=UUID.randomUUID().toString();saveJob(id,JSONObject().put("id",id).put("text",text).put("name",subject));saved++
                }
                runOnUiThread { Toast.makeText(this,"已保存 $saved 份资料到收件箱",Toast.LENGTH_LONG).show();channel?.invokeMethod("inboxChanged",null) }
            } catch(e:Exception) {
                runOnUiThread { Toast.makeText(this,"已保存 $saved 份；${e.message ?: "分享接收失败，请重试"}",Toast.LENGTH_LONG).show();channel?.invokeMethod("inboxChanged",null) }
            }
        }
    }
    private fun saveJob(id:String,json:JSONObject) {
        val tmp=File(inbox,"$id.json.part")
        tmp.outputStream().use { it.write(json.toString().toByteArray());it.fd.sync() }
        if(!tmp.renameTo(File(inbox,"$id.json")))throw IllegalStateException("无法写入收件箱")
    }
}
