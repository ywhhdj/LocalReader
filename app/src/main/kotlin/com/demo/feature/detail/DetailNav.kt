package com.demo.feature.detail

import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument

import com.demo.core.model.Book

object DetailRoute {
    const val ARG_BOOK_ID = "bookId"
    const val ROUTE = "detail/{$ARG_BOOK_ID}"
    fun path(bookId: Long): String = "detail/$bookId"
}

fun NavGraphBuilder.detailGraph(
    factory: ViewModelProvider.Factory,
    onBack: () -> Unit,
    onRead: (Book) -> Unit
) {
    composable(
        route = DetailRoute.ROUTE,
        arguments = listOf(navArgument(DetailRoute.ARG_BOOK_ID) { type = NavType.LongType })
    ) { entry ->
        val bookId = entry.arguments?.getLong(DetailRoute.ARG_BOOK_ID) ?: 0L
        val vm: DetailViewModel = viewModel(factory = factory)
        LaunchedEffect(bookId) { vm.load(bookId) }
        DetailScreen(viewModel = vm, onBack = onBack, onRead = onRead)
    }
}
