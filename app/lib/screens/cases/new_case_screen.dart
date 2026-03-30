import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';

const _schools = ['牛津大学', '剑桥大学', '帝国理工+RCA', 'UCL', '爱丁堡大学', '中央圣马丁', '坎伯韦尔艺术学院', '皇家艺术学院', '其他'];
const _programs = ['MFA Fine Art', 'MA Fine Art', 'MPhil Architecture', 'Innovation Design Engineering', 'Fine Art MFA', 'Contemporary Art Practice MA', '其他'];

class NewCaseScreen extends StatefulWidget {
  const NewCaseScreen({super.key});

  @override
  State<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends State<NewCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _undergradCtrl = TextEditingController();
  final _gpaCtrl = TextEditingController();
  final _excerptCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String _selectedSchool = _schools[0];
  String _selectedProgram = _programs[0];
  String _result = 'admitted';
  bool _isAnonymous = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose(); _undergradCtrl.dispose(); _gpaCtrl.dispose();
    _excerptCtrl.dispose(); _contentCtrl.dispose(); _yearCtrl.dispose(); _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!SupabaseService.isLoggedIn) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final tags = _tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      await SupabaseService.createCase(
        title: _titleCtrl.text,
        targetSchool: _selectedSchool,
        targetProgram: _selectedProgram,
        result: _result,
        content: _contentCtrl.text,
        undergrad: _undergradCtrl.text.isNotEmpty ? _undergradCtrl.text : null,
        gpa: _gpaCtrl.text.isNotEmpty ? _gpaCtrl.text : null,
        excerpt: _excerptCtrl.text.isNotEmpty ? _excerptCtrl.text : null,
        year: _yearCtrl.text.isNotEmpty ? _yearCtrl.text : null,
        isAnonymous: _isAnonymous,
        tags: tags,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分享申请案例', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Field(label: '案例标题 *', child: TextFormField(
              controller: _titleCtrl,
              validator: (v) => v!.isEmpty ? '请填写标题' : null,
              decoration: _inputDeco('例：牛津MFA录取经历分享'),
            )),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: _Field(label: '本科院校', child: TextFormField(controller: _undergradCtrl, decoration: _inputDeco('例：中央美术学院')))),
              const SizedBox(width: 10),
              Expanded(child: _Field(label: 'GPA', child: TextFormField(controller: _gpaCtrl, decoration: _inputDeco('例：3.8')))),
            ]),
            const SizedBox(height: 12),

            _Field(label: '目标院校 *', child: DropdownButtonFormField<String>(
              value: _selectedSchool,
              decoration: _inputDeco(''),
              items: _schools.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _selectedSchool = v!),
            )),
            const SizedBox(height: 12),

            _Field(label: '申请专业 *', child: DropdownButtonFormField<String>(
              value: _selectedProgram,
              decoration: _inputDeco(''),
              items: _programs.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _selectedProgram = v!),
            )),
            const SizedBox(height: 12),

            _Field(label: '申请结果 *', child: Row(
              children: [
                for (final r in [('admitted', '🎉 录取'), ('waitlisted', '⏳ 等候'), ('rejected', '❌ 拒绝')])
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _result = r.$1),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _result == r.$1 ? const Color(0xFFFFF7ED) : Colors.white,
                        border: Border.all(color: _result == r.$1 ? kPrimary : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(r.$2, style: TextStyle(fontSize: 11, color: _result == r.$1 ? kPrimary : Colors.grey, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                    ),
                  )),
              ],
            )),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: _Field(label: '申请年份', child: TextFormField(controller: _yearCtrl, decoration: _inputDeco('例：2025'), keyboardType: TextInputType.number))),
              const SizedBox(width: 10),
              Expanded(child: _Field(label: '标签（逗号分隔）', child: TextFormField(controller: _tagsCtrl, decoration: _inputDeco('例：纯艺,作品集')))),
            ]),
            const SizedBox(height: 12),

            _Field(label: '一句话摘要', child: TextFormField(controller: _excerptCtrl, decoration: _inputDeco('在列表页展示的简短描述'))),
            const SizedBox(height: 12),

            _Field(label: '申请心得 *', child: TextFormField(
              controller: _contentCtrl,
              validator: (v) => v!.isEmpty ? '请填写内容' : null,
              maxLines: 8,
              decoration: _inputDeco('分享你的备考经历、作品集准备、面试经验...'),
            )),
            const SizedBox(height: 8),

            Row(children: [
              Checkbox(value: _isAnonymous, onChanged: (v) => setState(() => _isAnonymous = v!), activeColor: kPrimary),
              const Text('匿名发布（隐藏用户名）', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
              ),

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
                  : const Text('发布案例', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary)),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
