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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: _CreateIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
            tooltip: '返回',
          ),
        ),
        title: Text(
          '发布动态',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: context.artC.ink,
            letterSpacing: 0,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CreatePublishButton(
              publishing: _publishing,
              onTap: _publishing ? null : _publish,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CreateSectionLabel(title: '类型'),
              _PostTypeSelector(
                value: _postType,
                onChanged: (value) => setState(() => _postType = value),
              ),
              const SizedBox(height: 18),
              _CreateSectionLabel(
                title: '素材',
                trailing: _images.isEmpty ? '可选' : '${_images.length} 张',
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 22),
              const _CreateSectionLabel(title: '内容'),
              const SizedBox(height: 10),
              _EditorTextField(
                controller: _titleCtrl,
                hint: _titleHint(_postType),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _EditorTextField(
                controller: _contentCtrl,
                hint: _bodyHint(_postType),
                minLines: 6,
                maxLines: null,
              ),
              const SizedBox(height: 14),
              const _CreateSectionLabel(title: '标签'),
              const SizedBox(height: 10),
              _EditorTextField(
                controller: _tagCtrl,
                hint: '添加标签，例如：作品集、RCA、插画',
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
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
    return _CreatePressable(
      onTap: _pickImages,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.artC.silver.withValues(alpha: 0.34),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              color: kCobaltMuted,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              '添加图片',
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.42),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const _CreatePressable({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<_CreatePressable> createState() => _CreatePressableState();
}

class _CreatePressableState extends State<_CreatePressable> {
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

class _CreateIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _CreateIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _CreatePressable(
        onTap: onTap,
        pressedScale: 0.95,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: context.artC.ink, size: 20),
        ),
      ),
    );
  }
}

class _CreatePublishButton extends StatelessWidget {
  final bool publishing;
  final VoidCallback? onTap;

  const _CreatePublishButton({
    required this.publishing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return _CreatePressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: AnimatedContainer(
        height: 36,
        width: 66,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: enabled ? kCobalt : context.artC.silver.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: kCobalt.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
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
          child: publishing
              ? const SizedBox(
                  key: ValueKey('publishing'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '发布',
                  key: ValueKey('publish'),
                  style: TextStyle(
                    color: Colors.white,
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

class _CreateSectionLabel extends StatelessWidget {
  final String title;
  final String? trailing;

  const _CreateSectionLabel({
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing!,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ],
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
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          FutureBuilder(
            future: file.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  width: 110,
                  height: 110,
                  color: context.artC.silver.withValues(alpha: 0.25),
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
                  color: context.artC.silver.withValues(alpha: 0.35),
                  child: Icon(Icons.broken_image_outlined,
                      color: context.artC.silver),
                ),
              );
            },
          ),
          Positioned(
            top: 4,
            right: 4,
            child: _CreatePressable(
              onTap: onRemove,
              pressedScale: 0.92,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
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
        return _CreatePressable(
          onTap: () => onChanged(item.$1),
          pressedScale: 0.98,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? kCobalt.withValues(alpha: 0.08)
                  : context.artC.cardIconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? kCobalt.withValues(alpha: 0.28)
                    : context.artC.silver.withValues(alpha: 0.34),
              ),
            ),
            child: Text(
              item.$2,
              style: TextStyle(
                color: selected
                    ? kCobalt
                    : context.artC.ink.withValues(alpha: 0.68),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: 8,
      color: context.artC.cardIconBg.withValues(alpha: 0.78),
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
            color: context.artC.ink.withValues(alpha: 0.42),
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
    const visibilityItems = [
      ('public', '公开'),
      ('followers', '关注者'),
      ('private', '仅自己'),
    ];
    return ArtseeSurface(
      padding: const EdgeInsets.all(14),
      radius: 8,
      color: context.artC.cardIconBg.withValues(alpha: 0.78),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(width: 8),
              Text(
                '发布后可修改',
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.36),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibilityItems.map((item) {
              return _VisibilityChip(
                label: item.$2,
                selected: visibility == item.$1,
                onTap: () => onVisibilityChanged(item.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _CreatePressable(
            onTap: () => onSyncChanged(!syncToPortfolio),
            pressedScale: 0.98,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              decoration: BoxDecoration(
                color: syncToPortfolio
                    ? kCobalt.withValues(alpha: 0.06)
                    : context.artC.silver.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: syncToPortfolio
                      ? kCobalt.withValues(alpha: 0.22)
                      : context.artC.silver.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    syncToPortfolio
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: syncToPortfolio
                        ? kCobalt
                        : context.artC.ink.withValues(alpha: 0.28),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '同步到作品集',
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  Text(
                    syncToPortfolio ? '已开启' : '未开启',
                    style: TextStyle(
                      color: context.artC.ink.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CreatePressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kCobalt : context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                selected ? kCobalt : context.artC.silver.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.artC.ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}
