package com.demo

import android.os.Bundle
import androidx.compose.runtime.getValue
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import com.demo.core.model.AppSettings
import com.demo.core.ui.glass.GlassLevel
import com.demo.core.ui.theme.ReaderTheme
import com.demo.assembly.navigation.AppNavHost

class MainActivity : ComponentActivity() {

    private val requestPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) {  }

    private val requestPermissions = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) {  }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        setContent {
            val container = (application as App).container
            val settings by container.settingsRepository.observe()
                .collectAsStateWithLifecycle(initialValue = AppSettings())

            // Android 13+ 只申请 READ_MEDIA_IMAGES；Android 12 及以下使用 READ_EXTERNAL_STORAGE。
            // Android 11+ 直接扫描公共目录还需"所有文件访问权限"（由首页/设置引导授权）。
            // 权限状态由 StorageAccess 实时判断，不在这里缓存（旧实现的 permissionGranted 是死字段）。
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
}
