package com.demo.feature.shelf

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable

object ShelfRoute {
    const val HOME = "shelf/home"
    const val SEARCH = "shelf/search"
}

/** 书架导航：导航目标由 app 层注入，feature 之间互不依赖 */
fun NavGraphBuilder.shelfGraph(
    navController: NavHostController,
    factory: ViewModelProvider.Factory,
    onSettings: () -> Unit,
    onBookClick: (Long) -> Unit
) {
    composable(ShelfRoute.HOME) {
        val vm: ShelfViewModel = viewModel(factory = factory)
        ShelfScreen(
            viewModel = vm,
            onBookClick = onBookClick,
            onSearch = { navController.navigate(ShelfRoute.SEARCH) },
            onSettings = onSettings
        )
    }
    composable(ShelfRoute.SEARCH) {
        val vm: ShelfViewModel = viewModel(factory = factory)
        SearchScreen(
            viewModel = vm,
            onBack = { navController.popBackStack() },
            onBookClick = onBookClick
        )
    }
}
