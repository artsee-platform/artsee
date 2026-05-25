import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/dev_test_account.dart';
import '../../services/supabase_service.dart';
import '../../services/backend_api_service.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

const _greyscale = ColorFilter.matrix([
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);

class _LoginScreenState extends State<LoginScreen> {
  static const _graphite = Color(0xFF111111);
  static const _fieldFill = Color(0xFFF7F7F5);

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nicknameFocus = FocusNode();

  bool _isLogin = true;
  bool _loading = false;
  bool _isColorful = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _emailCtrl.addListener(_updateColorfulState);
    _passwordCtrl.addListener(_updateColorfulState);
    _nicknameCtrl.addListener(_updateColorfulState);

    _emailFocus.addListener(_updateColorfulState);
    _passwordFocus.addListener(_updateColorfulState);
    _nicknameFocus.addListener(_updateColorfulState);
  }

  void _updateColorfulState() {
    final hasFocus = _emailFocus.hasFocus ||
        _passwordFocus.hasFocus ||
        _nicknameFocus.hasFocus;
    final hasText = _emailCtrl.text.isNotEmpty ||
        _passwordCtrl.text.isNotEmpty ||
        _nicknameCtrl.text.isNotEmpty;
    final colorful = hasFocus || hasText;
    if (colorful != _isColorful) {
      setState(() => _isColorful = colorful);
    }
  }

  @override
  void dispose() {
    _emailCtrl.removeListener(_updateColorfulState);
    _passwordCtrl.removeListener(_updateColorfulState);
    _nicknameCtrl.removeListener(_updateColorfulState);

    _emailFocus.removeListener(_updateColorfulState);
    _passwordFocus.removeListener(_updateColorfulState);
    _nicknameFocus.removeListener(_updateColorfulState);

    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isLogin) {
        final res = await SupabaseService.signIn(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
        if (res.user == null) throw Exception('登录失败，请检查邮箱和密码');
        if (mounted) Navigator.pop(context);
      } else {
        if (_nicknameCtrl.text.trim().isEmpty) throw Exception('请填写昵称');

        // 通过 API 注册（统一处理 Auth 和 user_profiles）
        final result = await BackendApiService.signup(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          nickname: _nicknameCtrl.text.trim(),
        );

        if (result['success'] != true) {
          throw Exception(result['error'] ?? '注册失败');
        }

        // 注册成功后自动登录
        final res = await SupabaseService.signIn(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
        if (res.user == null) throw Exception('注册成功，但登录失败，请手动登录');

        if (mounted) Navigator.pop(context);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(
        () => _error = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _devQuickLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.signIn(
        DevTestAccount.email,
        DevTestAccount.password,
      );
      if (res.user == null) throw Exception('登录失败');
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() {
        _error =
            '测试账号无法登录。请在项目根执行：npm run ensure:dev-user（需配置 SUPABASE_SERVICE_ROLE_KEY）。\n${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final imageHeight = size.height * 0.42;

    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/login_hero.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: context.artC.silver.withValues(alpha: 0.35)),
                    ),
                    AnimatedOpacity(
                      opacity: _isColorful ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      child: ColorFiltered(
                        colorFilter: _greyscale,
                        child: Image.asset(
                          'assets/images/login_hero.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color:
                                  context.artC.silver.withValues(alpha: 0.35)),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.artC.ink.withValues(alpha: 0.5),
                            context.artC.ink.withValues(alpha: 0.12),
                            context.artC.ink.withValues(alpha: 0.18),
                            context.artC.ink.withValues(alpha: 0.58),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.38, 0.62, 1.0],
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: context.artC.porcelain
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 20,
                                      color: context.artC.porcelain
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              'Artiqore',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    color: context.artC.ink
                                        .withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '连接先锋创作与奢侈品收藏的桥梁',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.4,
                                shadows: [
                                  Shadow(
                                    color: context.artC.ink
                                        .withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: ColoredBox(color: context.artC.porcelain)),
            ],
          ),
          Positioned(
            top: imageHeight - 28,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: context.artC.porcelain,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 42, 28, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_isLogin)
                            GestureDetector(
                              onTap: () => setState(() => _isLogin = true),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.arrow_back_ios,
                                  size: 18,
                                  color:
                                      context.artC.ink.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          if (!_isLogin) const SizedBox(width: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.08),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _isLogin ? '登录' : '注册',
                              key: ValueKey<bool>(_isLogin),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: context.artC.ink,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 34),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_isLogin) ...[
                              _buildInput(
                                controller: _nicknameCtrl,
                                focusNode: _nicknameFocus,
                                hint: '昵称',
                                icon: Icons.person_outline,
                                validator: (v) => v!.isEmpty ? '请填写昵称' : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildInput(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              hint: '邮箱',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v!.isEmpty
                                  ? '请填写邮箱'
                                  : (!v.contains('@') ? '邮箱格式不正确' : null),
                            ),
                            const SizedBox(height: 16),
                            _buildInput(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocus,
                              hint: '密码',
                              icon: Icons.lock_outline,
                              obscureText: true,
                              validator: (v) => v!.length < 6 ? '密码至少6位' : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFC62828),
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 30),
                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _graphite,
                                  disabledBackgroundColor:
                                      _graphite.withValues(alpha: 0.46),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isLogin ? '登录' : '注册',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: context.artC.silver,
                                    thickness: 1,
                                    height: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    '其他登录方式',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.artC.ink
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: context.artC.silver,
                                    thickness: 1,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _SecondaryAuthButton(
                              icon: Icons.phone_iphone_rounded,
                              label: '手机验证码登录',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('手机验证码登录即将开放'),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            GestureDetector(
                              onTap: () => setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin ? '还没有账号？去注册' : '已有账号？去登录',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      context.artC.ink.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                onLongPress: devLoginShortcutsEnabled
                                    ? (_loading ? null : _devQuickLogin)
                                    : null,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    '先去逛逛  →',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: context.artC.ink
                                          .withValues(alpha: 0.46),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: context.artC.ink.withValues(alpha: 0.35),
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: _fieldFill,
        prefixIcon: Icon(icon,
            size: 20, color: context.artC.ink.withValues(alpha: 0.35)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: context.artC.silver.withValues(alpha: 0.38),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _graphite, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: context.artC.silver.withValues(alpha: 0.38),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC62828), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.2),
        ),
      ),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: context.artC.ink,
      ),
    );
  }
}

class _SecondaryAuthButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SecondaryAuthButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: context.artC.silver.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18, color: context.artC.ink.withValues(alpha: 0.64)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.artC.ink.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
