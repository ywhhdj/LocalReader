package com.demo.feature.reader

import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument

import com.demo.feature.reader.comic.ComicReaderScreen
import com.demo.feature.reader.comic.ComicReaderViewModel
import com.demo.feature.reader.novel.NovelReaderScreen
import com.demo.feature.reader.novel.NovelReaderViewModel

object ReaderRoute {
    const val ARG_BOOK_ID = "bookId"
    const val NOVEL = "reader/novel/{$ARG_BOOK_ID}"
    const val COMIC = "reader/comic/{$ARG_BOOK_ID}"
    fun novel(bookId: Long): String = "reader/novel/$bookId"
    fun comic(bookId: Long): String = "reader/comic/$bookId"
}

fun NavGraphBuilder.readerGraph(
    factory: ViewModelProvider.Factory,
    onBack: () -> Unit
) {
    composable(
        route = ReaderRoute.NOVEL,
        arguments = listOf(navArgument(ReaderRoute.ARG_BOOK_ID) { type = NavType.LongType })
    ) { entry ->
        val bookId = entry.arguments?.getLong(ReaderRoute.ARG_BOOK_ID) ?: 0L
        val vm: NovelReaderViewModel = viewModel(factory = factory)
        LaunchedEffect(bookId) { vm.load(bookId) }
        NovelReaderScreen(viewModel = vm, onBack = onBack)
    }
    composable(
        route = ReaderRoute.COMIC,
        arguments = listOf(navArgument(ReaderRoute.ARG_BOOK_ID) { type = NavType.LongType })
    ) { entry ->
        val bookId = entry.arguments?.getLong(ReaderRoute.ARG_BOOK_ID) ?: 0L
        val vm: ComicReaderViewModel = viewModel(factory = factory)
        LaunchedEffect(bookId) { vm.load(bookId) }
        ComicReaderScreen(viewModel = vm, onBack = onBack)
    }
}
