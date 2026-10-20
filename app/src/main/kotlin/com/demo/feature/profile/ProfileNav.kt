package com.demo.feature.profile

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable

object ProfileRoute {
    const val PROFILE = "profile"
}

fun NavGraphBuilder.profileGraph(
    factory: ViewModelProvider.Factory,
    onBookClick: (Long) -> Unit
) {
    composable(ProfileRoute.PROFILE) {
        val vm: ProfileViewModel = viewModel(factory = factory)
        ProfileScreen(viewModel = vm, onBookClick = onBookClick)
    }
}
