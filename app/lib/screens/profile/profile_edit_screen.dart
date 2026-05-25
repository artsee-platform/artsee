import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class ProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;

  const ProfileEditScreen({super.key, this.initialProfile});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  String? _avatarUrl;
  bool _uploadingAvatar = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nicknameCtrl.text = (p?['nickname'] as String?) ?? '';
    _bioCtrl.text = (p?['bio'] as String?) ?? '';
    _locationCtrl.text = (p?['location'] as String?) ?? '';
    _avatarUrl = p?['avatar_url'] as String?;
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });
    try {
      final url = await StorageService.uploadAvatarFile(x);
      await SupabaseService.updateAvatarUrl(url);
      if (mounted) {
        setState(() => _avatarUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '头像上传失败: $e');
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SupabaseService.updateProfileFields(
        nickname: _nicknameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('资料已保存')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '保存失败: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.artC.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '编辑资料',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.artC.ink),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: kCobalt, strokeWidth: 2),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kCobalt,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: context.artC.silver.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: context.artC.porcelain, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: context.artC.ink.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                              ? Image.network(
                                  _avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _avatarFallback(),
                                )
                              : _avatarFallback(),
                        ),
                      ),
                      if (_uploadingAvatar)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black38,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: kCobalt,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: context.artC.porcelain, width: 3),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildLabel('昵称'),
              const SizedBox(height: 8),
              _buildInput(
                controller: _nicknameCtrl,
                hint: '请输入昵称',
              ),
              const SizedBox(height: 20),
              _buildLabel('简介'),
              const SizedBox(height: 8),
              _buildInput(
                controller: _bioCtrl,
                hint: '写点什么，让大家更了解你…',
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _buildLabel('所在地'),
              const SizedBox(height: 8),
              _buildInput(
                controller: _locationCtrl,
                hint: '例如：上海',
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFC62828),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    final ch = _nicknameCtrl.text.isNotEmpty
        ? _nicknameCtrl.text.substring(0, 1)
        : '艺';
    return Center(
      child: Text(
        ch,
        style: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: kCobalt,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.artC.ink.withValues(alpha: 0.75),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : 1,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: context.artC.ink.withValues(alpha: 0.35),
        ),
        filled: true,
        fillColor: context.artC.silver.withValues(alpha: 0.35),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(fontSize: 15, color: context.artC.ink),
    );
  }
}
