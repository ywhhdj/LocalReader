import 'package:flutter/foundation.dart';

/// 登录页结构检查（第二十五轮）。
///
/// **为什么要先 GET 再 POST**：用户给的 `www.wenku8.net/login.php` 在本轮实际
/// 读取时返回的不是登录表单，而是「本站正式关闭（2009.03.16–2015.12.24）」
/// 的公告页，页面里没有 `<form>` / `input`。若照着示例直接 POST，等于把账号密码
/// 发到一个根本没有表单的公告页上。所以登录前必须先看页面有没有可提交的表单；
/// 没有就明确报错，**一次都不提交凭据**。
enum Wenku8LoginPageIssue { ok, noForm, missingFields, sourceClosed, challenge, empty }

@immutable
class Wenku8LoginInspection {
  const Wenku8LoginInspection({
    required this.issue,
    required this.hasForm,
    required this.hasUsername,
    required this.hasPassword,
    required this.closureNotice,
  });

  final Wenku8LoginPageIssue issue;
  final bool hasForm;
  final bool hasUsername;
  final bool hasPassword;
  final bool closureNotice;

  bool get canSubmit => issue == Wenku8LoginPageIssue.ok;
}

/// 站点关闭 / 公告标记。命中即停，不重试、不绕过、不换域名反复试探。
const List<String> kWenku8ClosureMarkers = <String>[
  '本站正式关闭',
  '本站关闭',
  '正式关闭',
  '感谢每一位朋友的支持',
  '2009.03.16',
  '2015.12.24',
];

const List<String> kWenku8ChallengeMarkersLogin = <String>[
  '访问验证',
  '请完成验证',
  '人机验证',
  'cf-challenge',
  'just a moment',
];

@immutable
class Wenku8LoginPageInspector {
  const Wenku8LoginPageInspector();

  Wenku8LoginInspection inspect(String html) {
    if (html.trim().isEmpty) {
      return const Wenku8LoginInspection(
        issue: Wenku8LoginPageIssue.empty,
        hasForm: false, hasUsername: false, hasPassword: false,
        closureNotice: false,
      );
    }
    final bool closure =
        kWenku8ClosureMarkers.any((String m) => html.contains(m));
    final bool challenge = kWenku8ChallengeMarkersLogin
        .any((String m) => html.toLowerCase().contains(m.toLowerCase()));
    final String lower = html.toLowerCase();
    final bool hasForm = lower.contains('<form') &&
        (lower.contains('method=') || lower.contains('post'));
    final bool hasUsername = lower.contains('name=') &&
        (lower.contains('username') || lower.contains('name="uname"'));
    final bool hasPassword = lower.contains('type=') &&
        lower.contains('password');

    final Wenku8LoginPageIssue issue;
    if (closure) {
      issue = Wenku8LoginPageIssue.sourceClosed;
    } else if (challenge) {
      issue = Wenku8LoginPageIssue.challenge;
    } else if (!hasForm) {
      issue = Wenku8LoginPageIssue.noForm;
    } else if (!hasUsername || !hasPassword) {
      issue = Wenku8LoginPageIssue.missingFields;
    } else {
      issue = Wenku8LoginPageIssue.ok;
    }
    return Wenku8LoginInspection(
      issue: issue,
      hasForm: hasForm,
      hasUsername: hasUsername,
      hasPassword: hasPassword,
      closureNotice: closure,
    );
  }
}
