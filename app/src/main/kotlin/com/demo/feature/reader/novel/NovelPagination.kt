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
 * 把「块内硬换行」拆成独立段落。
 *
 * 为什么必须拆：TextStyle.textIndent 只作用于**段落首行**，而 TXT / 部分 EPUB
 * 经常整章只解析出一个 block、靠 '\n' 分行（TXT 常见"一行一段"格式）。
 * 不拆分的话，整章只有第一行会缩进，跨页后续块还会被判成续块 —— 也就是
 * "只有第一页有缩进、其余页全都没缩进"。
 *
 * 拆分后每个自然行都是独立 block：每段各自首行缩进，复制正文依旧不带多余空格。
 */
fun splitParagraphLines(blocks: List<BookBlock>): List<BookBlock> {
    val out = ArrayList<BookBlock>(blocks.size + 16)
    var changed = false
    for (block in blocks) {
        val text = when (block) {
            is BookBlock.Heading -> block.text
            is BookBlock.Paragraph -> block.text
            is BookBlock.Quote -> block.text
            else -> null
        }
        if (text == null || !text.contains('\n')) {
            out.add(block)
            continue
        }
        val lines = text.split('\n').map { it.trim() }.filter { it.isNotBlank() }
        if (lines.size <= 1 || out.size + lines.size > MAX_SPLIT_BLOCKS) {
            out.add(block)
            continue
        }
        changed = true
        for (line in lines) out.add(block.copyText(line))
    }
    return if (changed) out else blocks
}

/**
 * 将整章 blocks 按 [pageWidth] × [pageHeight] 切成多页。
 *
 * 处理规则：
 * - Paragraph / Quote：可切分（一次测量拿到高度，放不下时用 getLineEnd 找切点）；
 * - 单段在本页只剩 1 行空间时整体挪到下一页（避免"孤儿行"，也让下一页的段落能正常首行缩进）；
 * - Heading / Image / Break：不可切分，放不下则先 flush 到新页；
 * - Image：独占一页（高度未知，避免估算误差）；
 *   例外：章节正文**一开始就是图片**时并入首页，否则首页只剩一行章节名、图片被挤到第二页；
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
    /** 当前页是否已含"正文内容"（标题与分隔不算）：决定图片能否并入本页 */
    var hasBody = false

    val baseStyle = TextStyle(
        fontSize = fontSize.sp,
        lineHeight = (fontSize * lineHeightMultiplier).sp
    )
    /**
     * 段落首行缩进：交给 TextStyle.textIndent，而不是往文本里塞全角空格。
     * 文本塞空格会让复制正文带出多余字符、续页出现"半截缩进"、字号变化时缩进宽度不跟随。
     */
    val indentStyle = baseStyle.copy(
        textIndent = TextIndent(firstLine = (fontSize * 2).sp)
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
        hasBody = false
    }

    /** 往当前页追加一个块；只有正文块（段落 / 引用 / 图片）才置位 [hasBody] */
    fun append(item: PageItem, height: Float, body: Boolean = true) {
        current.add(item)
        used += height
        if (body) hasBody = true
    }

    /** 可切分文本：Paragraph / Quote 共用；缩进由 [indentStyle] 承担，续页不再缩进 */
    fun paginateText(block: BookBlock, text: String, isQuote: Boolean) {
        var remaining = text
        var firstChunk = true
        var splits = 0
        /**
         * 单页可容纳的字符数估算值：命中的话直接按字符切，省掉一次整段测量。
         *
         * 超长段落（几万字不断行）会走 [MAX_SPLITS_PER_BLOCK] 次"测量 → 取切点 → 再测量"，
         * 每次测量都是对剩余全文的排版，复杂度接近 O(n²) —— 大章节切页时明显卡顿。
         * 有了估算值后，多数切分一次都不用测量。
         */
        var charsPerPage = 0
        val vPad = if (isQuote) quoteVPad else paragraphVPad
        val hPad = if (isQuote) quoteHPad else 0f
        val contentWidth = (pageWidth - hPad * 2).toInt().coerceAtLeast(1)

        while (remaining.isNotEmpty()) {
            // 已有估算值且剩余文本足够长：直接按字符切，跳过整段测量
            if (charsPerPage > 0 && remaining.length > charsPerPage * 2 &&
                splits >= FAST_SPLIT_AFTER
            ) {
                // 取"一页能放下"的字符数作为本页内容，其余留到后续页
                val cut = charsPerPage.coerceAtMost(remaining.length)
                val head = remaining.substring(0, cut)
                val tail = remaining.substring(cut).trimStart('\n', '\r')
                if (head.isNotBlank()) {
                    append(PageItem(block.copyText(head), isContinuation = !firstChunk), 0f)
                }
                flush()
                remaining = tail
                firstChunk = false
                splits++
                continue
            }

            // 引用不缩进；段落只有首块缩进，跨页续块与正文保持一致（不加缩进符）
            val style = if (!isQuote && firstChunk) indentStyle else baseStyle
            val availableHeight = (pageHeight - used - vPad).coerceAtLeast(0f)
            val layout = measurer.measure(
                text = AnnotatedString(remaining),
                style = style,
                constraints = Constraints(maxWidth = contentWidth)
            )
            val blockHeight = layout.size.height.toFloat() + vPad

            if (blockHeight <= pageHeight - used || (availableHeight <= 0f && current.isEmpty())) {
                append(PageItem(block.copyText(remaining), isContinuation = !firstChunk), blockHeight)
                remaining = ""
            } else {
                val fitLines = fitLines(layout, availableHeight)
                if (fitLines <= 0) {
                    if (current.isNotEmpty()) {
                        flush()
                    } else {
                        append(PageItem(block.copyText(remaining), isContinuation = !firstChunk), blockHeight)
                        remaining = ""
                    }
                } else {
                    // 孤儿行控制：本页只剩 1 行、而该段还有更多行时，整段挪到下一页。
                    // 1) 观感：页脚单独吊一行很难看；
                    // 2) 缩进：下一页开头就是完整段落，能正常首行缩进，而不是"续块不缩进"。
                    if (fitLines < MIN_LINES_ON_PAGE && layout.lineCount > fitLines + 1 &&
                        current.isNotEmpty() && splits < MAX_SPLITS_PER_BLOCK
                    ) {
                        flush()
                        continue
                    }
                    val end = layout.getLineEnd(fitLines - 1)
                    val head = remaining.substring(0, end)
                    val tail = remaining.substring(end).trimStart('\n', '\r')
                    // 记住"一页能放多少字"，后续切分直接复用
                    if (end > 0) charsPerPage = end
                    if (head.isNotEmpty()) {
                        append(PageItem(block.copyText(head), isContinuation = !firstChunk), 0f)
                    }
                    flush()
                    remaining = tail
                    firstChunk = false
                    splits++
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
                // 章节标题不算"正文"，图片仍可并入本页
                append(PageItem(block), h, body = false)
            }
            is BookBlock.Paragraph -> paginateText(block, block.text, isQuote = false)
            is BookBlock.Quote -> paginateText(block, block.text, isQuote = true)
            is BookBlock.Image -> {
                // 章节正文以图片开头时并入首页（首页只剩标题会很空）；
                // 已经排了正文才另起一页，避免把段落和图片挤在一起。
                if (hasBody) flush()
                append(PageItem(block), 0f)
                flush()
            }
            is BookBlock.Break -> {
                if (used + breakHeight > pageHeight && current.isNotEmpty()) flush()
                append(PageItem(block), breakHeight, body = false)
            }
        }
    }
    flush()
    return pages.ifEmpty { listOf(NovelPage(emptyList())) }
}

/**
 * 渲染侧使用的段落首行缩进，必须与分页测量时的 [paginateNovel] 保持一致：
 * 段落首块缩进两个字符，跨页续块不缩进（否则续页看起来像新段落）。
 */
fun paragraphIndent(fontSize: Int, isContinuation: Boolean): TextIndent =
    if (isContinuation) TextIndent.None else TextIndent(firstLine = (fontSize * 2).sp)

/** 一个段落留在当前页的最小行数：不足则整段挪到下一页（孤儿行控制） */
private const val MIN_LINES_ON_PAGE = 2
/** 单个段落最多切分次数：超长段落（几万字不断行）不至于把分页拖成 O(n²) */
private const val MAX_SPLITS_PER_BLOCK = 40
/** 切分次数超过该值后改用"按字符估算"快切，不再逐次整段测量 */
private const val FAST_SPLIT_AFTER = 6
/** 按行拆分后的整章块数上限，避免异常文本生成海量 Composable */
private const val MAX_SPLIT_BLOCKS = 3000

/**
 * 分页请求的键。
 * 用**引用相等**比较 blocks：整章几千块做值相等比较本身就是一笔开销。
 */
class PaginationKey(
    val chapterIndex: Int,
    val blocks: List<BookBlock>,
    val fontSize: Int,
    val lineHeightMultiplier: Float,
    val pageWidth: Int,
    val pageHeight: Int
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        val o = other as? PaginationKey ?: return false
        return chapterIndex == o.chapterIndex && blocks === o.blocks &&
            fontSize == o.fontSize && lineHeightMultiplier == o.lineHeightMultiplier &&
            pageWidth == o.pageWidth && pageHeight == o.pageHeight
    }

    override fun hashCode(): Int {
        var h = chapterIndex
        h = 31 * h + fontSize
        h = 31 * h + lineHeightMultiplier.toBits()
        h = 31 * h + pageWidth
        h = 31 * h + pageHeight
        return h
    }
}

/**
 * 分页结果缓存。
 *
 * 场景：字号滑杆来回拖动、切章后又切回、屏幕旋转回到同一尺寸 ——
 * 这些情况下排版参数完全一致，没必要重新跑一遍整章测量（长章节数百毫秒）。
 * 只保留最近几份结果，容量很小。
 */
object NovelPaginationCache {
    private const val MAX_ENTRIES = 6
    private val map = LinkedHashMap<PaginationKey, List<NovelPage>>(MAX_ENTRIES + 1, 0.75f, true)

    @Synchronized
    fun get(key: PaginationKey): List<NovelPage>? = map[key]

    @Synchronized
    fun put(key: PaginationKey, pages: List<NovelPage>) {
        map[key] = pages
        if (map.size > MAX_ENTRIES) {
            val it = map.keys.iterator()
            it.next()
            it.remove()
        }
    }

    @Synchronized
    fun clear() = map.clear()
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