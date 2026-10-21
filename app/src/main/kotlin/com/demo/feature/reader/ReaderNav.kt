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
    const val ARG_CHAPTER = "chapter"

    const val NOVEL = "reader/novel/{$ARG_BOOK_ID}"
    // 漫画：chapter 为可选 query，缺省 -1 表示「按阅读进度继续」
    const val COMIC = "reader/comic/{$ARG_BOOK_ID}?$ARG_CHAPTER={$ARG_CHAPTER}"

    fun novel(bookId: Long): String = "reader/novel/$bookId"

    fun comic(bookId: Long, chapter: Int? = null): String =
        "reader/comic/$bookId?$ARG_CHAPTER=${chapter ?: -1}"
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
        arguments = listOf(
            navArgument(ReaderRoute.ARG_BOOK_ID) { type = NavType.LongType },
            navArgument(ReaderRoute.ARG_CHAPTER) {
                type = NavType.IntType
                defaultValue = -1
            }
        )
    ) { entry ->
        val bookId = entry.arguments?.getLong(ReaderRoute.ARG_BOOK_ID) ?: 0L
        val chapterArg = entry.arguments?.getInt(ReaderRoute.ARG_CHAPTER) ?: -1
        val chapter = chapterArg.takeIf { it >= 0 }
        val vm: ComicReaderViewModel = viewModel(factory = factory)
        LaunchedEffect(bookId, chapter) { vm.load(bookId, chapter) }
        ComicReaderScreen(viewModel = vm, onBack = onBack)
    }
}
