/// 对应原项目 `core/common/Result`：把成功 / 失败收成可穷举的类型。
///
/// 纯 Dart，无 Flutter 依赖；数据层解析、网络、文件扫描都可用它返回结构化结果，
/// 不用把异常字符串一路抛到页面。
sealed class LrResult<T> {
  const LrResult();

  bool get isSuccess => this is LrSuccess<T>;
  bool get isFailure => this is LrFailure<T>;

  R fold<R>(R Function(T value) onSuccess, R Function(Object error) onFailure);

  LrResult<R> map<R>(R Function(T value) transform) => switch (this) {
        LrSuccess<T>(:final T value) => LrSuccess<R>(transform(value)),
        LrFailure<T>(:final Object error) => LrFailure<R>(error),
      };
}

class LrSuccess<T> extends LrResult<T> {
  const LrSuccess(this.value);

  final T value;

  @override
  R fold<R>(R Function(T value) onSuccess, R Function(Object error) onFailure) =>
      onSuccess(value);
}

class LrFailure<T> extends LrResult<T> {
  const LrFailure(this.error);

  final Object error;

  @override
  R fold<R>(R Function(T value) onSuccess, R Function(Object error) onFailure) =>
      onFailure(error);
}
