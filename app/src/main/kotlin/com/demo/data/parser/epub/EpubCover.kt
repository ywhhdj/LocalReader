package com.demo.data.parser.epub

import com.demo.core.common.util.FileUtil
import com.demo.core.model.Chapter
import com.demo.data.cover.CoverStore
import com.demo.data.cover.TextCoverFactory
import com.demo.data.parser.common.PathUtils
import com.demo.data.parser.common.XmlUtils
import com.demo.data.parser.common.ZipUtils
import java.io.File
import java.util.zip.ZipFile

internal object EpubCover {

    fun resolve(
        zip: ZipFile,
        opf: Opf,
        basePath: String,
        file: File,
        chapters: List<Chapter>,
        coverStore: CoverStore,
        textCoverFactory: TextCoverFactory
    ): String? {
        val hrefs = ArrayList<String>()
        opf.coverId?.let { opf.manifest[it]?.href }?.let { hrefs.add(PathUtils.joinPath(basePath, it)) }
        opf.manifest.values.firstOrNull { it.mediaType.startsWith("image/") }
            ?.let { hrefs.add(PathUtils.joinPath(basePath, it.href)) }
        chapters.firstNotNullOfOrNull { ch ->
            val entry = zip.getEntry(ch.href)
            if (entry == null) null
            else {
                val bytes = ZipUtils.readEntryBytes(zip, entry)
                val html = bytes?.let { String(it, XmlUtils.detectHtmlCharset(it)) }
                html?.let {
                    Regex("""<img[^>]*src\s*=\s*["']([^"']+)["']""", RegexOption.IGNORE_CASE).find(it)
                        ?.groupValues?.get(1)
                }?.let { PathUtils.joinPath(entry.name.substringBeforeLast('/', ""), it) }
            }
        }?.let { hrefs.add(it) }

        for (href in hrefs) {
            val entry = zip.getEntry(href) ?: zip.getEntry(PathUtils.decodePath(href)) ?: continue
            val cover = runCatching { coverStore.save(zip.getInputStream(entry), file.absolutePath) }.getOrNull()
            if (cover != null) return cover
        }
        return runCatching {
            coverStore.save(textCoverFactory.create(FileUtil.humanTitle(file.name)), file.absolutePath)
        }.getOrNull()
    }
}