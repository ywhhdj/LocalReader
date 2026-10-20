package com.demo.data.remote

import com.demo.core.common.util.Logger
import com.demo.core.common.util.SimpleHttp

import java.net.URLEncoder

/**
 * 极简 WebDAV 客户端（HttpURLConnection，零第三方依赖）。
 * 仅实现备份需要的：MKCOL / PROPFIND / PUT / GET / DELETE。
 */
class WebDavClient {

    data class DavEntry(
        val href: String,
        val name: String,
        val isDirectory: Boolean,
        val sizeBytes: Long,
        val modifiedAt: Long
    )

    fun baseUrl(config: com.demo.domain.repository.SyncConfig): String {
        var url = config.url.trim().trimEnd('/')
        val dir = config.remoteDir.trim().trim('/')
        if (dir.isNotEmpty()) url += "/" + dir.split('/').joinToString("/") { encode(it) }
        return url + "/"
    }

    fun mkcol(url: String, auth: String?): Boolean {
        val res = SimpleHttp.request("MKCOL", url.trimEnd('/'), headers(auth))
        return res.code in 200..299 || res.code == 405 // 405 = 已存在
    }

    fun put(url: String, auth: String?, bytes: ByteArray): Boolean {
        val res = SimpleHttp.request(
            method = "PUT",
            url = url,
            headers = headers(auth) + ("Content-Type" to "application/json;charset=utf-8"),
            body = bytes
        )
        return res.isSuccess || res.code == 204
    }

    fun get(url: String, auth: String?): ByteArray? {
        val res = SimpleHttp.request("GET", url, headers(auth))
        return if (res.isSuccess) res.bytes else null
    }

    fun delete(url: String, auth: String?): Boolean {
        val res = SimpleHttp.request("DELETE", url, headers(auth))
        return res.isSuccess || res.code == 204 || res.code == 404
    }

    /** PROPFIND 列目录（Depth 1） */
    fun propfind(url: String, auth: String?): List<DavEntry> {
        val res = SimpleHttp.request(
            method = "PROPFIND",
            url = url.trimEnd('/') + "/",
            headers = headers(auth) + ("Depth" to "1")
        )
        if (!res.isSuccess && res.code != 207) return emptyList()
        val xml = res.text()
        return parsePropfind(xml)
    }

    private fun headers(auth: String?): Map<String, String> =
        if (auth.isNullOrBlank()) emptyMap() else mapOf("Authorization" to auth)

    private fun parsePropfind(xml: String): List<DavEntry> {
        val result = ArrayList<DavEntry>()
        val responses = Regex("""<(?:d:)?response(?:\s[^>]*)?>([\s\S]*?)</(?:d:)?response>""", RegexOption.IGNORE_CASE)
            .findAll(xml)
        for (r in responses) {
            val body = r.groupValues[1]
            val href = Regex("""<(?:d:)?href>([\s\S]*?)</(?:d:)?href>""", RegexOption.IGNORE_CASE)
                .find(body)?.groupValues?.get(1)?.trim().orEmpty()
            if (href.isBlank()) continue
            val isDir = Regex("""<(?:d:)?collection\s*/>""", RegexOption.IGNORE_CASE).containsMatchIn(body)
            val size = Regex("""<(?:d:)?getcontentlength>([\s\S]*?)</(?:d:)?getcontentlength>""", RegexOption.IGNORE_CASE)
                .find(body)?.groupValues?.get(1)?.trim()?.toLongOrNull() ?: 0L
            val modified = Regex("""<(?:d:)?getlastmodified>([\s\S]*?)</(?:d:)?getlastmodified>""", RegexOption.IGNORE_CASE)
                .find(body)?.groupValues?.get(1)?.trim()?.let { parseHttpDate(it) } ?: 0L
            val name = href.trimEnd('/').substringAfterLast('/')
            if (name.isBlank()) continue
            result.add(DavEntry(href, decode(name), isDir, size, modified))
        }
        Logger.d("WebDAV 列目录：${result.size} 项", "WebDavClient")
        return result
    }

    private fun parseHttpDate(value: String): Long = runCatching {
        java.text.SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", java.util.Locale.US).parse(value)?.time
    }.getOrNull() ?: 0L

    private fun encode(segment: String): String =
        URLEncoder.encode(segment, "UTF-8").replace("+", "%20")

    private fun decode(value: String): String = runCatching {
        java.net.URLDecoder.decode(value, "UTF-8")
    }.getOrDefault(value)
}
