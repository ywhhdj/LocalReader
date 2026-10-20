package com.demo.core.common.util

/**
 * 自然排序：img2 < img10，避免漫画页序错乱
 */
object NaturalOrderComparator : Comparator<String> {
    override fun compare(a: String, b: String): Int {
        var i = 0
        var j = 0
        while (i < a.length && j < b.length) {
            val ca = a[i]
            val cb = b[j]
            if (ca.isDigit() && cb.isDigit()) {
                var na = 0L
                var nb = 0L
                while (i < a.length && a[i].isDigit() && na < Long.MAX_VALUE / 16) {
                    na = na * 10 + (a[i] - '0'); i++
                }
                while (j < b.length && b[j].isDigit() && nb < Long.MAX_VALUE / 16) {
                    nb = nb * 10 + (b[j] - '0'); j++
                }
                if (na != nb) return na.compareTo(nb)
            } else {
                if (ca != cb) return ca.compareTo(cb)
                i++; j++
            }
        }
        return (a.length - i).compareTo(b.length - j)
    }
}
