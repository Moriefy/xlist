package io.xlist

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: AudioServiceActivity() {
    private val TAG = "XlistShare"
    private val CHANNEL = "io.xlist/share"
    private var channel: MethodChannel? = null

    // Cached shared file data (survives across onNewIntent calls)
    @Volatile
    private var sharedFilePath: String? = null
    @Volatile
    private var sharedFileName: String? = null
    @Volatile
    private var sharedFileSize: Long = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        Log.d(TAG, "configureFlutterEngine called, action=${intent?.action}")

        // 1. Process the launch intent
        handleShareIntent(intent)
        Log.d(TAG, "After handleShareIntent: path=$sharedFilePath, name=$sharedFileName")

        // 2. Set up method channel (Dart polls this on cold start)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFile" -> {
                    Log.d(TAG, "getSharedFile called, path=$sharedFilePath")
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
        Log.d(TAG, "onNewIntent called, action=${intent.action}")

        // App already running, new share intent
        handleShareIntent(intent)

        // Push data directly to Dart (warm start)
        if (sharedFilePath != null) {
            sendSharedDataToFlutter()
        }
    }

    /// Process ACTION_SEND intent: copy shared file to app cache
    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) {
            Log.d(TAG, "handleShareIntent: intent is null")
            return
        }
        if (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE) {
            Log.d(TAG, "handleShareIntent: action is ${intent.action}, not SEND")
            return
        }

        val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        if (uri == null) {
            Log.d(TAG, "handleShareIntent: EXTRA_STREAM is null")
            return
        }

        Log.d(TAG, "handleShareIntent: processing URI=$uri")

        try {
            val inputStream = contentResolver.openInputStream(uri)
            if (inputStream == null) {
                Log.e(TAG, "handleShareIntent: openInputStream returned null")
                return
            }

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

            Log.d(TAG, "handleShareIntent: SUCCESS path=$sharedFilePath size=$sharedFileSize")
        } catch (e: Exception) {
            Log.e(TAG, "handleShareIntent: EXCEPTION", e)
            e.printStackTrace()
        }
    }

    /// Native → Dart: push shared file data (warm start)
    private fun sendSharedDataToFlutter() {
        if (sharedFilePath == null) return

        val map = HashMap<String, Any>()
        map["filePath"] = sharedFilePath!!
        map["fileName"] = sharedFileName ?: ""
        map["fileSize"] = sharedFileSize

        Log.d(TAG, "sendSharedDataToFlutter: path=$sharedFilePath")

        try {
            channel?.invokeMethod("onSharedFile", map)
        } catch (e: Exception) {
            Log.e(TAG, "sendSharedDataToFlutter: failed", e)
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
                    name = it.getString(index) ?: "shared_file"
                }
            }
        }
        return name
    }
}
