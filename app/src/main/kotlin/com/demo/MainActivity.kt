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

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        permissionGranted = !needStoragePermission() || hasStoragePermission()

        setContent {
            val container = (application as App).container
            val settings by container.settingsRepository.observe()
                .collectAsStateWithLifecycle(initialValue = com.demo.core.model.AppSettings())

            LaunchedEffect(Unit) {
                if (needStoragePermission() && !hasStoragePermission()) {
                    requestPermission.launch(Manifest.permission.READ_EXTERNAL_STORAGE)
                }
            }

            ReaderTheme(
                themeMode = settings.themeMode,
                dynamicColor = settings.dynamicColor,
                glassLevel = GlassLevel.from(settings.glassLevel)
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
