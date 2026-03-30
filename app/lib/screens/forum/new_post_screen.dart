import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String _type = 'question';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose(); _contentCtrl.dispose(); _tagsCtrl.dispose();
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
      await SupabaseService.createPost(
        title: _titleCtrl.text,
        type: _type,
        content: _contentCtrl.text,
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
      appBar: AppBar(title: const Text('发布帖子', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type selection
            const Text('帖子类型 *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            for (final opt in [
              ('question', '❓ 问答', '提出你的问题，获取社区解答'),
              ('discussion', '💬 讨论', '发起话题讨论，交流经验'),
              ('news', '📰 资讯', '分享行业资讯和最新消息'),
            ])
              GestureDetector(
                onTap: () => setState(() => _type = opt.$1),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _type == opt.$1 ? const Color(0xFFFFF7ED) : Colors.white,
                    border: Border.all(color: _type == opt.$1 ? kPrimary : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _type == opt.$1 ? kPrimary : Colors.black87)),
                          Text(opt.$3, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      )),
                      if (_type == opt.$1) const Icon(Icons.radio_button_checked, color: kPrimary, size: 18)
                      else Icon(Icons.radio_button_off, color: Colors.grey.shade300, size: 18),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),
            const Text('标题 *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleCtrl,
              validator: (v) => v!.isEmpty ? '请填写标题' : null,
              decoration: _deco('例：牛津MFA面试是怎么准备的？'),
            ),

            const SizedBox(height: 12),
            const Text('标签（逗号分隔）', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            TextFormField(controller: _tagsCtrl, decoration: _deco('例：牛津,面试,作品集')),

            const SizedBox(height: 12),
            const Text('内容 *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _contentCtrl,
              validator: (v) => v!.isEmpty ? '请填写内容' : null,
              maxLines: 8,
              decoration: _deco('详细描述你的问题或想分享的内容...'),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red)),
              ),
            ],

            const SizedBox(height: 16),
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
                  : const Text('发布帖子', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: kPrimary)),
    );
  }
}
