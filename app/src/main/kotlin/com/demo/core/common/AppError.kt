package com.demo.core.common

/** 统一错误模型，分层之间只传递此类型，便于 UI 友好提示 */
sealed class AppError(message: String, cause: Throwable? = null) : Exception(message, cause) {
    class ParseError(val path: String, cause: Throwable? = null) : AppError("解析失败：$path", cause)
    class UnsupportedFormat(val ext: String) : AppError("暂不支持的格式：$ext")
    class IoError(val path: String, cause: Throwable? = null) : AppError("读写失败：$path", cause)
    class NotFound(val what: String) : AppError("未找到：$what")
    class PermissionDenied(val what: String) : AppError("无权限访问：$what")
    class DatabaseError(cause: Throwable? = null) : AppError("数据库错误", cause)
    class Unknown(cause: Throwable? = null) : AppError("未知错误", cause)
}

/** 结果封装 */
sealed interface Outcome<out T> {
    data class Success<T>(val data: T) : Outcome<T>
    data class Failure(val error: AppError) : Outcome<Nothing>

    companion object {
        inline fun <T> runCatching(block: () -> T): Outcome<T> = try {
            Success(block())
        } catch (e: AppError) {
            Failure(e)
        } catch (e: Exception) {
            Failure(AppError.Unknown(e))
        }
    }
}

inline fun <T, R> Outcome<T>.map(transform: (T) -> R): Outcome<R> = when (this) {
    is Outcome.Success -> Outcome.Success(transform(data))
    is Outcome.Failure -> this
}

inline fun <T> Outcome<T>.onFailure(block: (AppError) -> Unit): Outcome<T> {
    if (this is Outcome.Failure) block(error)
    return this
}
