import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/backend_api_service.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// 小红书风格图文发布编辑器
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final List<XFile> _images = [];
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();
  final TextEditingController _tagCtrl = TextEditingController();
  String _postType = 'artwork';
  String _visibility = 'public';
  bool _syncToPortfolio = false;
  bool _publishing = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => _images.addAll(picked));
    }
  }

  Future<void> _publish() async {
    if (_images.isEmpty &&
        _titleCtrl.text.trim().isEmpty &&
        _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一张图片或输入一些内容')),
      );
      return;
    }
    if (!SupabaseService.isLoggedIn) {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!SupabaseService.isLoggedIn && loggedIn != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录后发布')),
        );
        return;
      }
    }
    setState(() => _publishing = true);
    try {
      final imageUrls = <String>[];
      for (var i = 0; i < _images.length; i++) {
        final file = _images[i];
        final ext = _safeExtension(file.name);
        final bytes = await file.readAsBytes();
        final url = await StorageService.uploadUserObject(
          relativePath:
              'community/${DateTime.now().millisecondsSinceEpoch}_$i.$ext',
          bytes: bytes,
          contentType: _mimeForExt(ext),
        );
        imageUrls.add(url);
      }

      final tags = _tagCtrl.text
          .split(RegExp(r'[,，、\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final created = await BackendApiService.createPlazaPost(
        title: _titleCtrl.text.trim(),
        body: _contentCtrl.text.trim(),
        imageUrls: imageUrls,
        kind: 'post',
        group: _postType,
        tags: tags,
        metadata: {
          'kind': 'post',
          'post_type': _postType,
          'tags': tags,
          'visibility': _visibility,
          'sync_to_portfolio': _syncToPortfolio,
        },
      );
      if (!mounted) return;
      setState(() => _publishing = false);
      final message = switch (created['status']?.toString()) {
        'published' => '发布成功',
        'reviewing' => '已提交审核，通过后会公开展示',
        'rejected' => '内容未通过安全审核，请调整后再试',
        _ => '已提交',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      if (created['status']?.toString() != 'rejected') {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败：$e')),
      );
    }
  }

  String _safeExtension(String name) {
    final raw = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    return ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(raw) ? raw : 'jpg';
  }

  String _mimeForExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '发布动态',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.artC.ink),
        ),
        actions: [
          TextButton(
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kCobalt),
                  )
                : Text(
                    '发布',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kCobalt,
                    ),
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片选择区
              _PostTypeSelector(
                value: _postType,
                onChanged: (value) => setState(() => _postType = value),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    if (i == _images.length) {
                      return _buildAddImageBox();
                    }
                    return _ImageThumb(
                      file: _images[i],
                      onRemove: () => setState(() => _images.removeAt(i)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              // 标题
              _EditorTextField(
                controller: _titleCtrl,
                hint: _titleHint(_postType),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              // 正文
              _EditorTextField(
                controller: _contentCtrl,
                hint: _bodyHint(_postType),
                minLines: 6,
                maxLines: null,
              ),
              const SizedBox(height: 14),
              _EditorTextField(
                controller: _tagCtrl,
                hint: '添加标签，例如：作品集、RCA、插画',
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              _VisibilityRow(
                visibility: _visibility,
                syncToPortfolio: _syncToPortfolio,
                onVisibilityChanged: (value) =>
                    setState(() => _visibility = value),
                onSyncChanged: (value) =>
                    setState(() => _syncToPortfolio = value),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String _titleHint(String type) {
    return switch (type) {
      'artwork' => '作品标题',
      'study_note' => '学习笔记标题',
      'process' => '创作过程标题',
      'opinion' => '观点标题',
      'question' => '问题标题',
      'event' => '活动召集标题',
      _ => '填写标题',
    };
  }

  String _bodyHint(String type) {
    return switch (type) {
      'artwork' => '作品年份、媒介、尺寸、创作说明...',
      'study_note' => '记录课程、院校、申请经验或学习方法...',
      'process' => '记录草图、材料实验、阶段反馈...',
      'opinion' => '分享行业观察、展览观点或创作思考...',
      'question' => '描述你的问题、背景和希望获得的建议...',
      'event' => '说明活动时间、地点、对象和报名方式...',
      _ => '添加正文...',
    };
  }

  Widget _buildAddImageBox() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: context.artC.silver.withOpacity(0.25),
          borderRadius: BorderRadius.circular(kRadiusMedium),
          border:
              Border.all(color: context.artC.silver.withOpacity(0.6), width: 1),
        ),
        child: Icon(Icons.add_photo_alternate_outlined,
            color: kCobaltMuted, size: 32),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _ImageThumb({
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusMedium),
      child: Stack(
        children: [
          FutureBuilder(
            future: file.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  width: 110,
                  height: 110,
                  color: context.artC.silver.withOpacity(0.25),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return Image.memory(
                snapshot.data!,
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 110,
                  height: 110,
                  color: context.artC.silver.withOpacity(0.35),
                  child: Icon(Icons.broken_image_outlined,
                      color: context.artC.silver),
                ),
              );
            },
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PostTypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('artwork', '作品展示'),
      ('study_note', '学习笔记'),
      ('process', '创作过程'),
      ('opinion', '行业观点'),
      ('question', '求助提问'),
      ('event', '活动召集'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final selected = value == item.$1;
        return GestureDetector(
          onTap: () => onChanged(item.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? kCobalt.withOpacity(0.08)
                  : context.artC.cardIconBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? kCobalt.withOpacity(0.28)
                    : context.artC.silver.withOpacity(0.42),
              ),
            ),
            child: Text(
              item.$2,
              style: TextStyle(
                color: selected ? kCobalt : context.artC.ink.withOpacity(0.68),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EditorTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLines;
  final int minLines;
  final double fontSize;
  final FontWeight fontWeight;

  const _EditorTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.minLines = 1,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 16,
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.55,
          fontWeight: fontWeight,
          color: context.artC.ink,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: fontSize,
            color: context.artC.ink.withOpacity(0.42),
            fontWeight: fontWeight,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _VisibilityRow extends StatelessWidget {
  final String visibility;
  final bool syncToPortfolio;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<bool> onSyncChanged;

  const _VisibilityRow({
    required this.visibility,
    required this.syncToPortfolio,
    required this.onVisibilityChanged,
    required this.onSyncChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '可见范围',
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: visibility,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'public', child: Text('公开')),
                  DropdownMenuItem(value: 'followers', child: Text('关注者')),
                  DropdownMenuItem(value: 'private', child: Text('仅自己')),
                ],
                onChanged: (value) {
                  if (value != null) onVisibilityChanged(value);
                },
              ),
            ],
          ),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: syncToPortfolio,
              onChanged: onSyncChanged,
              title: const Text(
                '同步到作品集',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
