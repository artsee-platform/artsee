import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/dev_test_account.dart';
import '../../services/auth_service.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../services/tencent_captcha_service.dart';
import '../../widgets/common.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _emailOtpCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _smsCodeCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nicknameFocus = FocusNode();
  final _emailOtpFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _smsCodeFocus = FocusNode();

  bool _isLogin = true;
  bool _usePhoneOtp = false;
  bool _loading = false;
  bool _sendingEmailOtp = false;
  bool _sendingSmsOtp = false;
  bool _isColorful = false;
  int _smsCountdown = 0;
  String? _error;
  String? _emailOtpHint;
  Timer? _smsTimer;

  @override
  void initState() {
    super.initState();

    _emailCtrl.addListener(_updateColorfulState);
    _passwordCtrl.addListener(_updateColorfulState);
    _nicknameCtrl.addListener(_updateColorfulState);
    _emailOtpCtrl.addListener(_updateColorfulState);
    _phoneCtrl.addListener(_updateColorfulState);
    _smsCodeCtrl.addListener(_updateColorfulState);

    _emailFocus.addListener(_updateColorfulState);
    _passwordFocus.addListener(_updateColorfulState);
    _nicknameFocus.addListener(_updateColorfulState);
    _emailOtpFocus.addListener(_updateColorfulState);
    _phoneFocus.addListener(_updateColorfulState);
    _smsCodeFocus.addListener(_updateColorfulState);
  }

  void _updateColorfulState() {
    final hasFocus = _emailFocus.hasFocus ||
        _passwordFocus.hasFocus ||
        _nicknameFocus.hasFocus ||
        _emailOtpFocus.hasFocus ||
        _phoneFocus.hasFocus ||
        _smsCodeFocus.hasFocus;
    final hasText = _emailCtrl.text.isNotEmpty ||
        _passwordCtrl.text.isNotEmpty ||
        _nicknameCtrl.text.isNotEmpty ||
        _emailOtpCtrl.text.isNotEmpty ||
        _phoneCtrl.text.isNotEmpty ||
        _smsCodeCtrl.text.isNotEmpty;
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
    _emailOtpCtrl.removeListener(_updateColorfulState);
    _phoneCtrl.removeListener(_updateColorfulState);
    _smsCodeCtrl.removeListener(_updateColorfulState);

    _emailFocus.removeListener(_updateColorfulState);
    _passwordFocus.removeListener(_updateColorfulState);
    _nicknameFocus.removeListener(_updateColorfulState);
    _emailOtpFocus.removeListener(_updateColorfulState);
    _phoneFocus.removeListener(_updateColorfulState);
    _smsCodeFocus.removeListener(_updateColorfulState);

    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    _emailOtpCtrl.dispose();
    _phoneCtrl.dispose();
    _smsCodeCtrl.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nicknameFocus.dispose();
    _emailOtpFocus.dispose();
    _phoneFocus.dispose();
    _smsCodeFocus.dispose();
    _smsTimer?.cancel();
    super.dispose();
  }

  String? _mainlandPhone() {
    var phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s()\-]'), '');
    if (phone.startsWith('+86')) phone = phone.substring(3);
    if (phone.startsWith('0086')) phone = phone.substring(4);
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(phone) ? phone : null;
  }

  void _selectLoginMethod(bool usePhoneOtp) {
    if (_usePhoneOtp == usePhoneOtp) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _usePhoneOtp = usePhoneOtp;
      _error = null;
    });
  }

  void _startSmsCountdown() {
    _smsTimer?.cancel();
    setState(() => _smsCountdown = 60);
    _smsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_smsCountdown <= 1) {
        timer.cancel();
        setState(() => _smsCountdown = 0);
      } else {
        setState(() => _smsCountdown -= 1);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isLogin && _usePhoneOtp) {
        final phone = _mainlandPhone();
        if (phone == null) throw Exception('请填写有效的中国大陆手机号');
        final result = await AuthService().verifySmsCode(
          phone,
          _smsCodeCtrl.text.trim(),
        );
        if (result['success'] != true) {
          throw Exception(result['error'] ?? '验证码登录失败');
        }
        if (mounted) Navigator.pop(context);
      } else if (_isLogin) {
        final res = await SupabaseService.signIn(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
        if (res.user == null) throw Exception('登录失败，请检查邮箱和密码');
        if (mounted) Navigator.pop(context);
      } else {
        if (_nicknameCtrl.text.trim().isEmpty) throw Exception('请填写昵称');
        if (_emailOtpCtrl.text.trim().isEmpty) {
          throw Exception('请填写邮箱验证码');
        }

        // 通过 API 注册（统一处理 Auth 和 user_profiles）
        final result = await BackendApiService.signup(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          nickname: _nicknameCtrl.text.trim(),
          emailOtp: _emailOtpCtrl.text.trim(),
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

  Future<void> _sendSmsOtp() async {
    final phone = _mainlandPhone();
    if (phone == null) {
      setState(() => _error = '请先填写有效的中国大陆手机号');
      FocusScope.of(context).requestFocus(_phoneFocus);
      return;
    }
    setState(() {
      _sendingSmsOtp = true;
      _error = null;
    });
    try {
      var result = await AuthService().sendSmsCode(phone);
      if (result['captcha_required'] == true) {
        if (!mounted) return;
        final proof = await TencentCaptchaService.verify(context);
        if (proof == null) return;
        result = await AuthService().sendSmsCode(phone, captcha: proof);
      }
      if (result['success'] != true) {
        throw Exception(result['error'] ?? '验证码发送失败');
      }
      if (!mounted) return;
      _startSmsCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码已发送，请注意查收')),
      );
      FocusScope.of(context).requestFocus(_smsCodeFocus);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _sendingSmsOtp = false);
    }
  }

  Future<void> _sendEmailOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = '请先填写有效邮箱');
      FocusScope.of(context).requestFocus(_emailFocus);
      return;
    }
    setState(() {
      _sendingEmailOtp = true;
      _error = null;
      _emailOtpHint = null;
    });
    try {
      final result = await BackendApiService.sendEmailOtp(
        email: email,
        nickname: _nicknameCtrl.text.trim(),
      );
      final code = result['code']?.toString();
      if (!mounted) return;
      setState(() {
        _emailOtpHint =
            code == null || code.isEmpty ? '验证码已发送，请查看邮箱' : '开发验证码：$code';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_emailOtpHint!)),
      );
      FocusScope.of(context).requestFocus(_emailOtpFocus);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _sendingEmailOtp = false);
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
                        color: context.artC.silver.withValues(alpha: 0.35),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _isColorful ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: ColorFiltered(
                        colorFilter: _greyscale,
                        child: Image.asset(
                          'assets/images/login_hero.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: context.artC.silver.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.artC.ink.withValues(alpha: 0.45),
                            context.artC.ink.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.4, 1.0],
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
                                _AuthPressable(
                                  onTap: () => Navigator.pop(context),
                                  pressedScale: 0.95,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: context.artC.porcelain
                                          .withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 20,
                                      color: context.artC.porcelain
                                          .withValues(alpha: 0.92),
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
                                letterSpacing: 0,
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
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_isLogin)
                            _AuthPressable(
                              onTap: () => setState(() {
                                _isLogin = true;
                                _usePhoneOtp = false;
                                _emailOtpHint = null;
                                _error = null;
                              }),
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
                            duration: const Duration(milliseconds: 190),
                            switchOutCurve: Curves.easeOutCubic,
                            switchInCurve: Curves.easeOutCubic,
                            transitionBuilder: (child, animation) {
                              final scale = Tween<double>(
                                begin: 0.97,
                                end: 1,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: scale,
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              _isLogin ? '登录' : '注册',
                              key: ValueKey<bool>(_isLogin),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: context.artC.ink,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isLogin) ...[
                              _AuthLoginModeSwitch(
                                usePhoneOtp: _usePhoneOtp,
                                onChanged: _loading ? null : _selectLoginMethod,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_isLogin && _usePhoneOtp) ...[
                              _buildInput(
                                controller: _phoneCtrl,
                                focusNode: _phoneFocus,
                                hint: '手机号（中国大陆 +86）',
                                icon: Icons.phone_iphone_outlined,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9+\s()\-]'),
                                  ),
                                ],
                                validator: (_) => _mainlandPhone() == null
                                    ? '手机号格式不正确'
                                    : null,
                                onFieldSubmitted: () => FocusScope.of(context)
                                    .requestFocus(_smsCodeFocus),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildInput(
                                      controller: _smsCodeCtrl,
                                      focusNode: _smsCodeFocus,
                                      hint: '6位短信验证码',
                                      icon: Icons.sms_outlined,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      maxLength: 6,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      validator: (v) =>
                                          !RegExp(r'^\d{6}$').hasMatch(v ?? '')
                                              ? '请输入6位验证码'
                                              : null,
                                      onFieldSubmitted: _submit,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _AuthOtpButton(
                                    loading: _sendingSmsOtp,
                                    onTap: _sendingSmsOtp ||
                                            _loading ||
                                            _smsCountdown > 0
                                        ? null
                                        : _sendSmsOtp,
                                    semanticLabel: '发送短信验证码',
                                    label: _smsCountdown > 0
                                        ? '${_smsCountdown}s'
                                        : '发送',
                                    width: 82,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '未注册手机号验证后将自动创建账号',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      context.artC.ink.withValues(alpha: 0.42),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ] else ...[
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
                                validator: (v) =>
                                    v!.length < 6 ? '密码至少6位' : null,
                              ),
                              if (!_isLogin) ...[
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildInput(
                                        controller: _emailOtpCtrl,
                                        focusNode: _emailOtpFocus,
                                        hint: '邮箱验证码',
                                        icon: Icons.mark_email_read_outlined,
                                        keyboardType: TextInputType.number,
                                        validator: (v) => v!.trim().isEmpty
                                            ? '请填写邮箱验证码'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _AuthOtpButton(
                                      loading: _sendingEmailOtp,
                                      onTap: _sendingEmailOtp || _loading
                                          ? null
                                          : _sendEmailOtp,
                                      semanticLabel: '发送邮箱验证码',
                                    ),
                                  ],
                                ),
                                if (_emailOtpHint != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _emailOtpHint!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.artC.ink
                                          .withValues(alpha: 0.45),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ],
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
                            const SizedBox(height: 28),
                            _AuthPrimaryButton(
                              label: _isLogin
                                  ? (_usePhoneOtp ? '验证码登录' : '登录')
                                  : '注册',
                              loading: _loading,
                              onTap: _loading ? null : _submit,
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.artC.cardIconBg
                                    .withValues(alpha: 0.74),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: context.artC.silver
                                      .withValues(alpha: 0.26),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _AuthSecondaryAction(
                                    icon: _isLogin
                                        ? Icons.person_add_alt_1_outlined
                                        : Icons.login_rounded,
                                    title: _isLogin ? '还没有账号？' : '已有账号？',
                                    subtitle:
                                        _isLogin ? '创建你的艺术身份档案' : '返回邮箱密码登录',
                                    action: _isLogin ? '去注册' : '去登录',
                                    onTap: () => setState(() {
                                      _isLogin = !_isLogin;
                                      _usePhoneOtp = false;
                                      _emailOtpHint = null;
                                      _error = null;
                                    }),
                                  ),
                                  if (_isLogin) ...[
                                    const SizedBox(height: 10),
                                    Divider(
                                      height: 1,
                                      color: context.artC.silver
                                          .withValues(alpha: 0.38),
                                    ),
                                    const SizedBox(height: 10),
                                    _AuthSecondaryAction(
                                      icon: Icons.chat_bubble_outline,
                                      title: '微信登录',
                                      subtitle: '后续接入微信授权',
                                      action: '预留',
                                      onTap: () {
                                        // TODO: 微信登录
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _AuthPressable(
                                    onTap: () =>
                                        Navigator.of(context).maybePop(),
                                    pressedScale: 0.98,
                                    child: Container(
                                      height: 42,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: context.artC.silver
                                            .withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '先随便看看',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.artC.ink
                                              .withValues(alpha: 0.48),
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (devLoginShortcutsEnabled) ...[
                                  const SizedBox(width: 8),
                                  _AuthDevLoginButton(
                                    onTap: _loading ? null : _devQuickLogin,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 30),
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
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    VoidCallback? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(focusNode);
      },
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction ??
            (obscureText ? TextInputAction.done : TextInputAction.next),
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        onTap: () {
          if (!focusNode.hasFocus) {
            FocusScope.of(context).requestFocus(focusNode);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SystemChannels.textInput.invokeMethod('TextInput.show');
          });
        },
        onFieldSubmitted: (_) {
          if (onFieldSubmitted != null) {
            onFieldSubmitted();
          } else if (obscureText) {
            _submit();
          } else {
            FocusScope.of(context).requestFocus(_passwordFocus);
          }
        },
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 14,
            color: context.artC.ink.withValues(alpha: 0.35),
          ),
          filled: true,
          fillColor: context.artC.cardIconBg.withValues(alpha: 0.72),
          prefixIcon: Icon(icon,
              size: 20, color: context.artC.ink.withValues(alpha: 0.38)),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: context.artC.silver.withValues(alpha: 0.36)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: kCobalt.withValues(alpha: 0.45), width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: context.artC.silver.withValues(alpha: 0.32)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFC62828), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: kCobalt.withValues(alpha: 0.45), width: 1.2),
          ),
        ),
        style: TextStyle(fontSize: 15, color: context.artC.ink),
      ),
    );
  }
}

class _AuthLoginModeSwitch extends StatelessWidget {
  final bool usePhoneOtp;
  final ValueChanged<bool>? onChanged;

  const _AuthLoginModeSwitch({
    required this.usePhoneOtp,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.artC.silver.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _AuthLoginModeOption(
            label: '邮箱登录',
            selected: !usePhoneOtp,
            onTap: onChanged == null ? null : () => onChanged!(false),
          ),
          _AuthLoginModeOption(
            label: '手机验证码',
            selected: usePhoneOtp,
            onTap: onChanged == null ? null : () => onChanged!(true),
          ),
        ],
      ),
    );
  }
}

class _AuthLoginModeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _AuthLoginModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        selected: selected,
        label: label,
        child: _AuthPressable(
          onTap: onTap,
          pressedScale: 0.98,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? context.artC.porcelain : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: context.artC.ink.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: selected
                    ? kCobalt
                    : context.artC.ink.withValues(alpha: 0.46),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const _AuthPressable({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<_AuthPressable> createState() => _AuthPressableState();
}

class _AuthPressableState extends State<_AuthPressable> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed || widget.onTap == null) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _AuthPrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: _AuthPressable(
        onTap: onTap,
        child: AnimatedContainer(
          height: 54,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color:
                enabled ? kCobalt : context.artC.silver.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(8),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: kCobalt.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: loading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    key: ValueKey<String>(label),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AuthOtpButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  final String semanticLabel;
  final String label;
  final double width;

  const _AuthOtpButton({
    required this.loading,
    required this.onTap,
    required this.semanticLabel,
    this.label = '发送',
    this.width = 72,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: _AuthPressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: AnimatedContainer(
          width: width,
          height: 56,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: enabled
                ? kCobalt.withValues(alpha: 0.07)
                : context.artC.silver.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? kCobalt.withValues(alpha: 0.24)
                  : context.artC.silver.withValues(alpha: 0.3),
            ),
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: kCobalt,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

class _AuthDevLoginButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AuthDevLoginButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _AuthPressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        width: 96,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.artC.cardIconBg.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.artC.silver.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_outlined,
              size: 14,
              color: context.artC.ink.withValues(alpha: 0.42),
            ),
            const SizedBox(width: 6),
            Text(
              '测试登录',
              style: TextStyle(
                fontSize: 10,
                color: context.artC.ink.withValues(alpha: 0.42),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthSecondaryAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback? onTap;

  const _AuthSecondaryAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _AuthPressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: kCobalt),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.artC.ink.withValues(alpha: 0.36),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kCobalt.withValues(alpha: 0.18)),
            ),
            child: Text(
              action,
              style: const TextStyle(
                color: kCobalt,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
