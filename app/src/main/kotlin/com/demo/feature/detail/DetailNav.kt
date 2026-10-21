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
    const val ARG_BOOK_CHAPTER = "chapter"
    // chapter 作为可选 query 参数，缺省 -1 表示「从进度继续」
    const val ROUTE = "detail/{$ARG_BOOK_ID}?$ARG_BOOK_CHAPTER={$ARG_BOOK_CHAPTER}"

    fun path(bookId: Long, chapter: Int? = null): String =
        "detail/$bookId?$ARG_BOOK_CHAPTER=${chapter ?: -1}"
}

fun NavGraphBuilder.detailGraph(
    factory: ViewModelProvider.Factory,
    onBack: () -> Unit,
    onRead: (Book, Int?) -> Unit
) {
    composable(
        route = DetailRoute.ROUTE,
        arguments = listOf(
            navArgument(DetailRoute.ARG_BOOK_ID) { type = NavType.LongType },
            navArgument(DetailRoute.ARG_BOOK_CHAPTER) {
                type = NavType.IntType
                defaultValue = -1
            }
        )
    ) { entry ->
        val bookId = entry.arguments?.getLong(DetailRoute.ARG_BOOK_ID) ?: 0L
        val chapterArg = entry.arguments?.getInt(DetailRoute.ARG_BOOK_CHAPTER) ?: -1
        val chapter = chapterArg.takeIf { it >= 0 }
        val vm: DetailViewModel = viewModel(factory = factory)
        LaunchedEffect(bookId) { vm.load(bookId, chapter) }
        DetailScreen(viewModel = vm, onBack = onBack, onRead = onRead)
    }
}
