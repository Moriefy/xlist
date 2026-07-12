package io.xlist

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "io.xlist/share"
    private var channel: MethodChannel? = null

    // Cached shared file data
    private var sharedFilePath: String? = null
    private var sharedFileName: String? = null
    private var sharedFileSize: Long = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // 1. Process the launch intent BEFORE engine starts
        handleShareIntent(intent)

        // 2. Set up bidirectional method channel BEFORE super
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter → Native: get cached shared file
                "getSharedFile" -> {
                    if (sharedFilePath != null) {
                        val map = HashMap<String, Any>()
                        map["filePath"] = sharedFilePath!!
                        map["fileName"] = sharedFileName ?: ""
                        map["fileSize"] = sharedFileSize
                        result.success(map)
                        // Clear after reading
                        sharedFilePath = null
                        sharedFileName = null
                        sharedFileSize = 0
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 3. Start Flutter engine
        super.configureFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // App is already running, user shared a new file
        handleShareIntent(intent)
        // Push data directly to Dart (bidirectional)
        sendSharedDataToFlutter()
    }

    /// Process ACTION_SEND intent: copy shared file to cache
    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE) return

        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return

        try {
            val inputStream = contentResolver.openInputStream(uri) ?: return
            val fileName = getFileName(uri)
            val cacheDir = File(cacheDir, "shared_files")
            cacheDir.mkdirs()
            val tempFile = File(cacheDir, fileName)

            FileOutputStream(tempFile).use { output ->
                inputStream.copyTo(output)
            }
            inputStream.close()

            sharedFilePath = tempFile.absolutePath
            sharedFileName = fileName
            sharedFileSize = tempFile.length()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /// Native → Dart: push shared file data (for warm start / onNewIntent)
    private fun sendSharedDataToFlutter() {
        if (sharedFilePath == null) return

        val map = HashMap<String, Any>()
        map["filePath"] = sharedFilePath!!
        map["fileName"] = sharedFileName ?: ""
        map["fileSize"] = sharedFileSize

        try {
            channel?.invokeMethod("onSharedFile", map)
        } catch (e: Exception) {
            // Channel not ready, data stays cached for Dart to poll later
        }

        // Clear after sending
        sharedFilePath = null
        sharedFileName = null
        sharedFileSize = 0
    }

    private fun getFileName(uri: Uri): String {
        var name = "shared_file"
        val cursor = contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) {
                    name = it.getString(index)
                }
            }
        }
        return name
    }
}
