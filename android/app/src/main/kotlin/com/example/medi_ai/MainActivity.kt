package com.example.medi_ai

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "medi_ai/export_share"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val text = call.argument<String>("text")
                        val subject = call.argument<String>("subject")
                        if (text.isNullOrBlank()) {
                            result.error("invalid_args", "Text is required", null)
                            return@setMethodCallHandler
                        }
                        shareText(text, subject)
                        result.success(null)
                    }

                    "shareFile" -> {
                        val path = call.argument<String>("path")
                        val mimeType = call.argument<String>("mimeType")
                        val subject = call.argument<String>("subject")
                        val text = call.argument<String>("text")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_args", "Path is required", null)
                            return@setMethodCallHandler
                        }
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("missing_file", "File not found", null)
                            return@setMethodCallHandler
                        }
                        shareFile(file, mimeType, subject, text)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun shareText(text: String, subject: String?) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (!subject.isNullOrBlank()) {
                putExtra(Intent.EXTRA_SUBJECT, subject)
            }
        }
        startActivity(Intent.createChooser(intent, subject))
    }

    private fun shareFile(
        file: File,
        mimeType: String?,
        subject: String?,
        text: String?
    ) {
        val uri = FileProvider.getUriForFile(
            this,
            "${BuildConfig.APPLICATION_ID}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType ?: "*/*"
            putExtra(Intent.EXTRA_STREAM, uri)
            if (!subject.isNullOrBlank()) {
                putExtra(Intent.EXTRA_SUBJECT, subject)
            }
            if (!text.isNullOrBlank()) {
                putExtra(Intent.EXTRA_TEXT, text)
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, subject))
    }
}
