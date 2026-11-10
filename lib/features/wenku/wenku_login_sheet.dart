import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/wenku/wenku8_compliance.dart';
import '../../core/wenku/wenku8_hosts.dart';
import '../../core/wenku/wenku8_session.dart';
import '../../core/widgets/glass.dart';
import '../../core/content/lr_localizations.dart';

/// Wenku8 网页表单登录（第二十五轮）。
///
/// 按用户提供的清单：POST `login.php`（username / password / submit），
/// 302 不自动跟随，登录态由 Cookie 维持，之后可读 `bookcase.php` 个人书架。
/// 面板只收集凭据并交给 `Wenku8Session`，自己不碰网络、不打印密码、不写文件。
///
/// 三条产品口径钉死在界面上：
/// 1. 纯本地模式锁定态不允许登录（全应用零请求）；
/// 2. 来源返回站点关闭公告时不会提交账号密码；
/// 3. 路径按提供的页面清单配置，尚未经页面解析验证，需真机核对。
class Wenku8LoginSheet extends StatefulWidget {
  const Wenku8LoginSheet({super.key});

  static Future<void> open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => const Wenku8LoginSheet(),
    );
  }

  @override
  State<Wenku8LoginSheet> createState() => _Wenku8LoginSheetState();
}

class _Wenku8LoginSheetState extends State<Wenku8LoginSheet> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String _bookcaseNote = '';

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Wenku8Session? session = state.wenku8Session;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          LrSpacing.l, LrSpacing.m, LrSpacing.l,
          MediaQuery.of(context).viewInsets.bottom + LrSpacing.l),
      child: SingleChildScrollView(
        child: GlassPanel(
          child: Padding(
            padding: const EdgeInsets.all(LrSpacing.m),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(context.t('wenkuLoginTitle'), style: text.headlineSmall),
                const SizedBox(height: LrSpacing.m),
                if (!state.onlineEnabled) ...<Widget>[
                  _Note(icon: Icons.lock_outline, text: context.t('wenkuLockedBody')),
                  const SizedBox(height: LrSpacing.s),
                  FilledButton.tonal(
                    onPressed: state.enableOnlineDirectory,
                    child: Text(context.t('wenkuUnlockButton')),
                  ),
                  const SizedBox(height: LrSpacing.m),
                ],
                if (session == null)
                  _Note(icon: Icons.cloud_off_outlined,
                      text: context.t('wenkuLoginNoSession'))
                else
                  AnimatedBuilder(
                    animation: session,
                    builder: (BuildContext ctx, Widget? _) =>
                        _SessionBody(
                      session: session,
                      state: state,
                      username: _username,
                      password: _password,
                      busy: _busy,
                      bookcaseNote: _bookcaseNote,
                      onLogin: () => _doLogin(ctx, state, session),
                      onLogout: () => session.logout(),
                      onHostChanged: (String h) => session.switchHost(h),
                      onBookcase: () => _doBookcase(state),
                    ),
                  ),
                const SizedBox(height: LrSpacing.m),
                _Note(icon: Icons.security_outlined,
                    text: context.t('wenkuLoginCredentialNote')),
                const SizedBox(height: LrSpacing.xs),
                _Note(icon: Icons.public_outlined,
                    text: context.t('wenkuLoginHostNote')),
                const SizedBox(height: LrSpacing.xs),
                _Note(icon: Icons.rule_folder_outlined,
                    text: context.t('wenkuEndpointsPendingNote')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doLogin(
      BuildContext context, AppState state, Wenku8Session session) async {
    if (!state.onlineEnabled || _busy) return;
    setState(() => _busy = true);
    final Wenku8LoginOutcome outcome =
        await session.login(_username.text, _password.text);
    // 密码只在此次调用中存在；无论成功失败，输入框都清空，不留在屏幕上。
    _password.clear();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Wenku8Compliance.redact(outcome.note))),
    );
  }

  Future<void> _doBookcase(AppState state) async {
    if (_busy) return;
    setState(() => _busy = true);
    final listing = await state.wenku8Bookcase();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _bookcaseNote = listing == null
          ? lrText('uiOnlineDirectoryIsOffNoRequestWasMade')
          : lrTextArgs('uiItemsShelfBooks', <Object?>[listing.books.length, listing.note]);
    });
  }
}

/// 会话主体：只读 `Wenku8Session`，不持有跨页设置的影子副本。
class _SessionBody extends StatelessWidget {
  const _SessionBody({
    required this.session,
    required this.state,
    required this.username,
    required this.password,
    required this.busy,
    required this.bookcaseNote,
    required this.onLogin,
    required this.onLogout,
    required this.onHostChanged,
    required this.onBookcase,
  });

  final Wenku8Session session;
  final AppState state;
  final TextEditingController username;
  final TextEditingController password;
  final bool busy;
  final String bookcaseNote;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final ValueChanged<String> onHostChanged;
  final VoidCallback onBookcase;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool locked = !state.onlineEnabled;
    final bool loggedIn = session.isAuthenticated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.language_outlined, size: 18),
            const SizedBox(width: LrSpacing.s),
            Text(context.t('uiSourceDomain'), style: text.labelLarge),
            const SizedBox(width: LrSpacing.m),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: Wenku8Hosts.allowed.contains(session.endpoints.authority)
                    ? session.endpoints.authority
                    : Wenku8Hosts.authorityOf(Wenku8Hosts.defaultHost),
                items: <DropdownMenuItem<String>>[
                  for (final String h in Wenku8Hosts.authorities.values)
                    DropdownMenuItem<String>(
                        value: h, child: Text(Wenku8Hosts.labels[Wenku8Hosts.fromAuthority(h)]!)),
                ],
                onChanged: (String? h) => h == null ? null : onHostChanged(h),
              ),
            ),
          ],
        ),
        const SizedBox(height: LrSpacing.s),
        _Note(icon: Icons.info_outline, text: _stateNote(session.state, session.note)),
        if (session.state == Wenku8AuthState.sourceClosed) ...<Widget>[
          const SizedBox(height: LrSpacing.xs),
          _Note(icon: Icons.report_gmailerrorred_outlined,
              text: context.t('wenkuSourceClosedNote')),
        ],
        const SizedBox(height: LrSpacing.m),
        TextField(
          controller: username,
          enabled: !locked && !busy && !loggedIn,
          decoration: InputDecoration(
            labelText: context.t('wenkuLoginUsername'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.username],
        ),
        const SizedBox(height: LrSpacing.s),
        TextField(
          controller: password,
          enabled: !locked && !busy && !loggedIn,
          obscureText: true,
          decoration: InputDecoration(
            labelText: context.t('wenkuLoginPassword'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.password],
          onSubmitted: (_) => onLogin(),
        ),
        const SizedBox(height: LrSpacing.m),
        Wrap(
          spacing: LrSpacing.s,
          runSpacing: LrSpacing.s,
          children: <Widget>[
            FilledButton(
              onPressed: locked || busy || loggedIn ? null : onLogin,
              child: Text(busy ? context.t('uiPleaseWait') : context.t('wenkuLoginAction')),
            ),
            OutlinedButton(
              onPressed: loggedIn ? onLogout : null,
              child: Text(context.t('wenkuLogoutAction')),
            ),
            OutlinedButton(
              onPressed: locked || busy || !loggedIn ? null : onBookcase,
              child: Text(context.t('uiReadPersonalBookcase')),
            ),
          ],
        ),
        if (bookcaseNote.isNotEmpty) ...<Widget>[
          const SizedBox(height: LrSpacing.s),
          _Note(icon: Icons.menu_book_outlined, text: bookcaseNote),
        ],
      ],
    );
  }

  String _stateNote(Wenku8AuthState s, String note) {
    switch (s) {
      case Wenku8AuthState.loggedOut:
        return lrText('wenkuLoginLoggedOut');
      case Wenku8AuthState.inspecting:
      case Wenku8AuthState.submitting:
        return note.isEmpty ? lrText('uiWorking') : note;
      case Wenku8AuthState.loggedIn:
        return note.isEmpty ? lrText('uiSignedInLaterRequestsCarryTheSessionCookieIssu') : note;
      case Wenku8AuthState.failed:
        return lrText('wenkuLoginFailed');
      case Wenku8AuthState.sessionExpired:
        return lrText('wenkuLoginSessionExpired');
      case Wenku8AuthState.sourceClosed:
        return lrText('wenkuSourceClosedNote');
      case Wenku8AuthState.upstreamChanged:
        return lrText('wenkuUpstreamChangedNote');
      case Wenku8AuthState.challenge:
        return lrText('wenkuChallengeNote');
      case Wenku8AuthState.unavailable:
        return lrText('wenkuUnavailableNote');
    }
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: LrSpacing.s),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      );
}
