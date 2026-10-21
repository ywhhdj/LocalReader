package com.demo.feature.reader.novel

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextIndent
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

import com.demo.core.model.BookBlock

/** 一页：连续渲染的页内单元 */
data class NovelPage(val items: List<PageItem>)

/**
 * 页内渲染单元。
 * @param isContinuation 段落是否从上一页延续而来（true 时不加首行缩进）
 */
data class PageItem(
  val block: BookBlock,
  val isContinuation: Boolean = false
)

/**
 * 将整章 blocks 按 [pageWidth] × [pageHeight] 切成多页。
 *
 * 处理规则：
 * - Paragraph / Quote：可切分（一次测量拿到高度，放不下时用 getLineEnd 找切点）；
 * - Heading / Image / Break：不可切分，放不下则先 flush 到新页；
 * - Image：独占一页（高度未知，避免估算误差）；
 * - 分页算法不会产生空页（除非整章无内容）。
 */
fun paginateNovel(
    measurer: TextMeasurer,
    blocks: List<BookBlock>,
    pageWidth: Int,
    pageHeight: Int,
    fontSize: Int,
    lineHeightMultiplier: Float,
    density: Density
): List<NovelPage> {
    if (pageWidth <= 0 || pageHeight <= 0 || blocks.isEmpty()) {
        return listOf(NovelPage(emptyList()))
    }

    val pages = mutableListOf<NovelPage>()
    var current = mutableListOf<PageItem>()
    var used = 0f

    val baseStyle = TextStyle(
        fontSize = fontSize.sp,
        lineHeight = (fontSize * lineHeightMultiplier).sp
    )
    val headingStyle = baseStyle.copy(
        fontSize = (fontSize + 2).sp,
        fontWeight = FontWeight.Bold
    )

    val headingVPad = with(density) { 16.dp.toPx() }
    val paragraphVPad = with(density) { 12.dp.toPx() }
    val quoteVPad = with(density) { 12.dp.toPx() }
    val quoteHPad = with(density) { 8.dp.toPx() }
    val breakHeight = with(density) { 12.dp.toPx() }

    fun flush() {
        if (current.isNotEmpty()) {
            pages.add(NovelPage(current.toList()))
            current = mutableListOf()
        }
        used = 0f
    }

    /** 可切分文本：Paragraph / Quote 共用，缩进用全角空格前缀而不是 TextIndent */
    fun paginateText(block: BookBlock, text: String, isQuote: Boolean) {
        var remaining = text
        var firstChunk = true
        // 引用不加缩进；普通段落首块加两个全角空格
        val indentPrefix = if (isQuote) "" else "\u3000\u3000"
        val vPad = if (isQuote) quoteVPad else paragraphVPad
        val hPad = if (isQuote) quoteHPad else 0f
        val contentWidth = (pageWidth - hPad * 2).toInt().coerceAtLeast(1)

        while (remaining.isNotEmpty()) {
            val display = if (firstChunk) indentPrefix + remaining else remaining
            val availableHeight = (pageHeight - used - vPad).coerceAtLeast(0f)
            val layout = measurer.measure(
                text = AnnotatedString(display),
                style = baseStyle,
                constraints = Constraints(maxWidth = contentWidth)
            )
            val blockHeight = layout.size.height.toFloat() + vPad

            if (blockHeight <= pageHeight - used || (availableHeight <= 0f && current.isEmpty())) {
                current.add(PageItem(block.copyText(display), isContinuation = !firstChunk))
                used += blockHeight
                remaining = ""
            } else {
                val fitLines = fitLines(layout, availableHeight)
                if (fitLines <= 0) {
                    if (current.isNotEmpty()) {
                        flush()
                    } else {
                        current.add(PageItem(block.copyText(display), isContinuation = !firstChunk))
                        remaining = ""
                    }
                } else {
                    val end = layout.getLineEnd(fitLines - 1)
                    val head = display.substring(0, end)
                    val tail = display.substring(end).trimStart('\n', '\r')
                    if (head.isNotEmpty()) {
                        current.add(PageItem(block.copyText(head), isContinuation = !firstChunk))
                    }
                    flush()
                    remaining = tail
                    firstChunk = false
                }
            }
        }
    }

    for (block in blocks) {
        when (block) {
            is BookBlock.Heading -> {
                val layout = measurer.measure(
                    text = AnnotatedString(block.text),
                    style = headingStyle,
                    constraints = Constraints(maxWidth = pageWidth)
                )
                val h = layout.size.height.toFloat() + headingVPad
                if (used + h > pageHeight && current.isNotEmpty()) flush()
                current.add(PageItem(block))
                used += h
            }
            is BookBlock.Paragraph -> paginateText(block, block.text, isQuote = false)
            is BookBlock.Quote -> paginateText(block, block.text, isQuote = true)
            is BookBlock.Image -> {
                if (current.isNotEmpty()) flush()
                current.add(PageItem(block))
                flush()
            }
            is BookBlock.Break -> {
                if (used + breakHeight > pageHeight && current.isNotEmpty()) flush()
                current.add(PageItem(block))
                used += breakHeight
            }
        }
    }
    flush()
    return pages.ifEmpty { listOf(NovelPage(emptyList())) }
}

/** 在当前可用高度内最多能放下多少行（二分查找） */
private fun fitLines(layout: TextLayoutResult, availableHeight: Float): Int {
    if (layout.size.height <= availableHeight) return layout.lineCount
    if (availableHeight <= 0f) return 0
    var lo = 0
    var hi = layout.lineCount
    while (lo < hi) {
        val mid = (lo + hi + 1) / 2
        val bottom = layout.getLineBottom(mid - 1)
        if (bottom <= availableHeight) lo = mid else hi = mid - 1
    }
    return lo
}