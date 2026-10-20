package com.demo.core.common.util

import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.GZIPInputStream
import java.util.zip.InflaterInputStream

/**
 * 极简 HTTP 客户端（仅系统 HttpURLConnection，零第三方依赖）。
 * 供 WebDAV 备份与（默认关闭的）在线书源使用。
 */
object SimpleHttp {

    class Response(
        val code: Int,
        val bytes: ByteArray,
        val headers: Map<String, String>
    ) {
        val isSuccess: Boolean get() = code in 200..299
        fun text(): String {
            val charset = charsetFromHeaders(headers) ?: detectCharset(bytes)
            return String(bytes, charset)
        }

        private fun charsetFromHeaders(headers: Map<String, String>): java.nio.charset.Charset? {
            val contentType = headers.entries.firstOrNull {
                it.key.equals("Content-Type", true) || it.key.equals("content-type", true)
            }?.value ?: return null
            val charsetName = Regex("""charset\s*=\s*([^;\s]+)""", RegexOption.IGNORE_CASE)
                .find(contentType)?.groupValues?.get(1)?.trim('"') ?: return null
            return runCatching { java.nio.charset.Charset.forName(charsetName) }.getOrNull()
        }

        private fun detectCharset(bytes: ByteArray): java.nio.charset.Charset {
            val head = String(bytes, 0, minOf(bytes.size, 4096), java.nio.charset.StandardCharsets.ISO_8859_1)
            val meta = Regex("""charset\s*=\s*["']?([A-Za-z0-9\-_]+)""", RegexOption.IGNORE_CASE).find(head)
            meta?.groupValues?.get(1)?.let {
                runCatching { return java.nio.charset.Charset.forName(it) }
            }
            return java.nio.charset.StandardCharsets.UTF_8
        }
    }

    fun request(
        method: String,
        url: String,
        headers: Map<String, String> = emptyMap(),
        body: ByteArray? = null,
        timeoutMs: Int = 15_000
    ): Response {
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = timeoutMs
                readTimeout = timeoutMs
                instanceFollowRedirects = true
                setRequestProperty("Accept-Encoding", "gzip, deflate")
                headers.forEach { (k, v) -> setRequestProperty(k, v) }
                if (body != null) {
                    doOutput = true
                    setRequestProperty("Content-Length", body.size.toString())
                    outputStream.use { it.write(body) }
                }
            }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val bytes = if (stream == null) ByteArray(0) else {
                val encoding = conn.getHeaderField("Content-Encoding")?.lowercase()
                val input = when {
                    encoding?.contains("gzip") == true -> GZIPInputStream(stream)
                    encoding?.contains("deflate") == true -> InflaterInputStream(stream)
                    else -> stream
                }
                input.use { readAll(it) }
            }
            Response(code, bytes, conn.headerFields.filterKeys { it != null }.mapKeys { it.key!! }
                .mapValues { it.value.firstOrNull().orEmpty() })
        } finally {
            conn?.disconnect()
        }
    }

    fun get(url: String, headers: Map<String, String> = emptyMap()): Response =
        request("GET", url, headers)

    fun getText(url: String, headers: Map<String, String> = emptyMap()): String = get(url, headers).text()

    fun basicAuth(user: String, password: String): String {
        val raw = "$user:$password"
        val encoded = android.util.Base64.encodeToString(
            raw.toByteArray(java.nio.charset.StandardCharsets.UTF_8),
            android.util.Base64.NO_WRAP
        )
        return "Basic $encoded"
    }

    private fun readAll(input: java.io.InputStream): ByteArray {
        val out = ByteArrayOutputStream()
        val buf = ByteArray(8192)
        while (true) {
            val read = input.read(buf)
            if (read <= 0) break
            out.write(buf, 0, read)
        }
        return out.toByteArray()
    }
}
