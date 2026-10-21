package com.demo.core.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

/** 现代化大圆角体系：8 / 12 / 16 / 24 / 32 */
object ReaderRadius {
    val XS = 8.dp
    val S = 12.dp
    val M = 16.dp
    val L = 24.dp
    val XL = 32.dp
    val FULL = 50.dp
}

val CardShape = RoundedCornerShape(ReaderRadius.XS)
val SheetShape = RoundedCornerShape(topStart = ReaderRadius.S, topEnd = ReaderRadius.S)
val ChipShape = RoundedCornerShape(ReaderRadius.FULL)
val CoverShape = RoundedCornerShape(ReaderRadius.XS)

val ReaderShapes = Shapes(
    extraSmall = RoundedCornerShape(ReaderRadius.XS),
    small = RoundedCornerShape(ReaderRadius.S),
    medium = RoundedCornerShape(ReaderRadius.M),
    large = RoundedCornerShape(ReaderRadius.L),
    extraLarge = RoundedCornerShape(ReaderRadius.XL)
)
