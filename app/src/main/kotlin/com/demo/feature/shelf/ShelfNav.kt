package com.demo.feature.shelf

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable

import com.demo.core.common.util.Logger
import com.demo.core.common.util.StorageAccess

object ShelfRoute {
    const val HOME = "shelf/home"
    const val SEARCH = "shelf/search"
    const val ONLINE = "shelf/online"
}

/**
 * 书架导航：
 * - SAF 目录授权在这里发起（takePersistableUriPermission 后交给 ViewModel 扫描）
 * - 未获文件访问权限时，由首页引导跳转系统授权页
 */
fun NavGraphBuilder.shelfGraph(
    navController: NavHostController,
    factory: ViewModelProvider.Factory,
    onSettings: () -> Unit,
    onBookClick: (Long) -> Unit
) {
    composable(ShelfRoute.HOME) {
        val vm: ShelfViewModel = viewModel(factory = factory)
        val context = androidx.compose.ui.platform.LocalContext.current
        val pickDirectory = rememberDirectoryPicker(context) { uri ->
            vm.importFromUri(uri.toString())
        }
        ShelfScreen(
            viewModel = vm,
            onBookClick = onBookClick,
            onSearch = { navController.navigate(ShelfRoute.SEARCH) },
            onSettings = onSettings,
            onPickDirectory = pickDirectory,
            onRequestPermission = { StorageAccess.openAllFilesAccessSettings(context) }
        )
    }
    composable(ShelfRoute.SEARCH) {
        val vm: ShelfViewModel = viewModel(factory = factory)
        SearchScreen(
            viewModel = vm,
            onBack = { navController.popBackStack() },
            onBookClick = onBookClick,
            onOnlineSearch = { navController.navigate(ShelfRoute.ONLINE) }
        )
    }
    composable(ShelfRoute.ONLINE) {
        val vm: OnlineSearchViewModel = viewModel(factory = factory)
        OnlineSearchScreen(
            viewModel = vm,
            onBack = { navController.popBackStack() }
        )
    }
}

@androidx.compose.runtime.Composable
private fun rememberDirectoryPicker(
    context: Context,
    onPicked: (Uri) -> Unit
): () -> Unit {
    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        // 持久化授权：重启后仍可扫描该目录
        runCatching {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        }.onFailure { e ->
            Logger.w("持久化目录授权失败：${e.message}", "ShelfNav")
        }
        Logger.d("SAF 授权完成：$uri", "ShelfNav")
        onPicked(uri)
    }
    return { runCatching { launcher.launch(null) } }
}
