package com.example.fis_uygulamasi

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private var pendingSave: PendingSave? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOCUMENTS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            saveFile(call, result)
        }
    }

    private fun saveFile(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val fileName = call.argument<String>("fileName")
        val mimeType = call.argument<String>("mimeType")
        if (sourcePath == null || fileName == null || mimeType == null) {
            result.error("invalid_arguments", "Kayıt bilgileri eksik.", null)
            return
        }

        val request = PendingSave(sourcePath, fileName, mimeType, result)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingSave = request
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                STORAGE_PERMISSION_REQUEST,
            )
            return
        }
        performSave(request)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != STORAGE_PERMISSION_REQUEST) return
        val request = pendingSave ?: return
        pendingSave = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            performSave(request)
        } else {
            request.result.error(
                "permission_denied",
                "Documents klasörüne kayıt izni verilmedi.",
                null,
            )
        }
    }

    private fun performSave(request: PendingSave) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveWithMediaStore(request)
            } else {
                saveToLegacyDocuments(request)
            }
            request.result.success(request.fileName)
        } catch (error: Exception) {
            request.result.error("save_failed", error.message, null)
        }
    }

    private fun saveWithMediaStore(request: PendingSave) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, request.fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, request.mimeType)
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                Environment.DIRECTORY_DOCUMENTS,
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Files.getContentUri("external"), values)
            ?: error("Documents klasöründe dosya oluşturulamadı.")
        try {
            FileInputStream(request.sourcePath).use { input ->
                resolver.openOutputStream(uri, "w").use { output ->
                    checkNotNull(output) { "Dosya yazma akışı açılamadı." }
                    input.copyTo(output)
                }
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun saveToLegacyDocuments(request: PendingSave) {
        val directory = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOCUMENTS,
        )
        check(directory.exists() || directory.mkdirs()) {
            "Documents klasörü oluşturulamadı."
        }
        FileInputStream(request.sourcePath).use { input ->
            File(directory, request.fileName).outputStream().use { output ->
                input.copyTo(output)
            }
        }
    }

    private data class PendingSave(
        val sourcePath: String,
        val fileName: String,
        val mimeType: String,
        val result: MethodChannel.Result,
    )

    private companion object {
        const val DOCUMENTS_CHANNEL = "com.example.fis_uygulamasi/documents"
        const val STORAGE_PERMISSION_REQUEST = 4107
    }
}
