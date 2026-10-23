package com.demo

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import com.demo.core.ui.glass.GlassLevel
import com.demo.core.ui.theme.ReaderTheme
import com.demo.assembly.navigation.AppNavHost

class MainActivity : ComponentActivity() {

    private var permissionGranted by mutableStateOf(false)

    private val requestPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> permissionGranted = granted || !needStoragePermission() }

    private val requestPermissions = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result -> permissionGranted = result.values.any { it } || !needStoragePermission() }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        permissionGranted = !needStoragePermission() || hasStoragePermission()

        setContent {
            val container = (application as App).container
            val settings by container.settingsRepository.observe()
                .collectAsStateWithLifecycle(initialValue = com.demo.core.model.AppSettings())

            // Android 13+ 使用 READ_MEDIA_*；Android 12 及以下使用 READ_EXTERNAL_STORAGE。
            // Android 11+ 直接扫描公共目录还需"所有文件访问权限"（由首页/设置引导授权）。
            LaunchedEffect(Unit) {
                val missing = com.demo.core.common.util.StorageAccess.missingPermissions(this@MainActivity)
                if (missing.isNotEmpty()) {
                    if (missing.size == 1) {
                        requestPermission.launch(missing.first())
                    } else {
                        requestPermissions.launch(missing.toTypedArray())
                    }
                }
            }

            ReaderTheme(
                themeMode = settings.themeMode,
                dynamicColor = settings.dynamicColor,
                glassLevel = GlassLevel.from(settings.glassLevel),
                animationsEnabled = settings.animationsEnabled,
                frameRateMode = settings.frameRateMode
            ) {
                AppNavHost(factory = container)
            }
        }
    }

    private fun needStoragePermission(): Boolean = Build.VERSION.SDK_INT <= Build.VERSION_CODES.S_V2

    private fun hasStoragePermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED
}
