package com.demo.data.parser.common

import java.net.URLDecoder

internal object PathUtils {

    fun stripFragment(href: String): String {
        val i = href.indexOf('#')
        return (if (i >= 0) href.substring(0, i) else href).trim()
    }

    fun decodePath(path: String): String = runCatching {
        URLDecoder.decode(path, "UTF-8")
    }.getOrDefault(path)

    fun joinPath(basePath: String, href: String): String {
        val decoded = decodePath(href).trim().trimStart('/')
        if (decoded.startsWith(basePath) && basePath.isNotBlank()) return decoded
        return if (basePath.isBlank()) decoded else "$basePath/$decoded"
    }
}