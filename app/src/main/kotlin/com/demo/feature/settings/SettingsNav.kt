package com.demo.feature.settings

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable

object SettingsRoute {
  const val SETTINGS = "settings"
}

fun NavGraphBuilder.settingsGraph(
  factory: ViewModelProvider.Factory,
  onBack: () -> Unit
) {
  composable(SettingsRoute.SETTINGS) {
    val vm: SettingsViewModel = viewModel(factory = factory)
    SettingsScreen(viewModel = vm, onBack = onBack)
  }
}
