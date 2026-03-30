import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose(); _passwordCtrl.dispose(); _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        final res = await SupabaseService.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
        if (res.user == null) throw Exception('登录失败，请检查邮箱和密码');
      } else {
        if (_nicknameCtrl.text.trim().isEmpty) throw Exception('请填写昵称');
        final res = await SupabaseService.signUp(_emailCtrl.text.trim(), _passwordCtrl.text, _nicknameCtrl.text.trim());
        if (res.user == null) throw Exception('注册失败');
      }
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Logo
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kPrimary, kPrimaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: Text('🎨', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 16),
              const Text('艺见心', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87)),
              const Text('英国艺术留学社区', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 40),

              // Tab toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _isLogin = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isLogin ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _isLogin ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)] : null,
                      ),
                      child: Text('登录', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _isLogin ? Colors.black87 : Colors.grey)),
                    ),
                  )),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _isLogin = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isLogin ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_isLogin ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)] : null,
                      ),
                      child: Text('注册', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: !_isLogin ? Colors.black87 : Colors.grey)),
                    ),
                  )),
                ]),
              ),

              const SizedBox(height: 24),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!_isLogin)
                      _InputField(controller: _nicknameCtrl, label: '昵称', hint: '请输入你的昵称', validator: (v) => v!.isEmpty ? '请填写昵称' : null),
                    if (!_isLogin) const SizedBox(height: 12),
                    _InputField(controller: _emailCtrl, label: '邮箱', hint: '请输入邮箱地址', keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? '请填写邮箱' : (!v.contains('@') ? '邮箱格式不正确' : null)),
                    const SizedBox(height: 12),
                    _InputField(controller: _passwordCtrl, label: '密码', hint: '请输入密码（至少6位）', obscureText: true,
                      validator: (v) => v!.length < 6 ? '密码至少6位' : null),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_isLogin ? '登录' : '注册', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('先逛逛，不登录', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: kPrimary)),
          ),
        ),
      ],
    );
  }
}
