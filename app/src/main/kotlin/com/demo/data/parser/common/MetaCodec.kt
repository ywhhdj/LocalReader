package com.demo.data.parser.common

internal object MetaCodec {
    const val FIELD = "\u0001"
    const val ROW = "\u0002"
    const val SECTION = "\u0003"

    fun sanitize(value: String): String =
        value.replace(FIELD, " ").replace(ROW, " ").replace(SECTION, " ")
}