package com.demo.assembly.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController

import com.demo.core.model.BookType
import com.demo.core.ui.glass.BottomItem
import com.demo.core.ui.glass.GlassBottomBar

import com.demo.feature.detail.detailGraph
import com.demo.feature.profile.ProfileRoute
import com.demo.feature.profile.profileGraph
import com.demo.feature.reader.ReaderRoute
import com.demo.feature.reader.readerGraph
import com.demo.feature.settings.SettingsRoute
import com.demo.feature.settings.settingsGraph
import com.demo.feature.shelf.ShelfRoute
import com.demo.feature.shelf.shelfGraph

@Composable
fun AppNavHost(
    factory: ViewModelProvider.Factory,
    modifier: Modifier = Modifier,
    navController: NavHostController = rememberNavController()
) {
    val entry by navController.currentBackStackEntryAsState()
    val currentRoute = entry?.destination?.route
    val showBottomBar = currentRoute == ShelfRoute.HOME || currentRoute == ProfileRoute.PROFILE

    androidx.compose.foundation.layout.Box(modifier = modifier) {
        NavHost(
            navController = navController,
            startDestination = ShelfRoute.HOME
        ) {
            shelfGraph(
                navController = navController,
                factory = factory,
                onSettings = { navController.navigate(SettingsRoute.SETTINGS) },
                onBookClick = { bookId ->
                    navController.navigate(com.demo.feature.detail.DetailRoute.path(bookId))
                }
            )
            detailGraph(
                factory = factory,
                onBack = { navController.popBackStack() },
                onRead = { book ->
                    val route = if (book.type == BookType.NOVEL) {
                        ReaderRoute.novel(book.id)
                    } else {
                        ReaderRoute.comic(book.id)
                    }
                    navController.navigate(route)
                }
            )
            readerGraph(
                factory = factory,
                onBack = { navController.popBackStack() }
            )
            profileGraph(
                factory = factory,
                onBookClick = { bookId ->
                    navController.navigate(com.demo.feature.detail.DetailRoute.path(bookId))
                }
            )
            settingsGraph(
                factory = factory,
                onBack = { navController.popBackStack() }
            )
        }

        if (showBottomBar) {
            GlassBottomBar(
                items = listOf(
                    BottomItem(
                        label = "书架",
                        icon = Icons.Default.Home,
                        selected = currentRoute == ShelfRoute.HOME,
                        onClick = {
                            navController.navigate(ShelfRoute.HOME) {
                                popUpTo(ShelfRoute.HOME) { inclusive = false }
                                launchSingleTop = true
                            }
                        }
                    ),
                    BottomItem(
                        label = "我的",
                        icon = Icons.Default.Person,
                        selected = currentRoute == ProfileRoute.PROFILE,
                        onClick = {
                            navController.navigate(ProfileRoute.PROFILE) {
                                popUpTo(ShelfRoute.HOME)
                                launchSingleTop = true
                            }
                        }
                    )
                ),
                modifier = androidx.compose.ui.Modifier.align(androidx.compose.ui.Alignment.BottomCenter)
            )
        }
    }
}
