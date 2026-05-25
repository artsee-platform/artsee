import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/backend_api_service.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
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
  String? _locationLabel;
  String? _topicLabel;
  String? _visibilityLabel;
  bool _publishing = false;

  bool get _hasDraft =>
      _images.isNotEmpty ||
      _titleCtrl.text.trim().isNotEmpty ||
      _contentCtrl.text.trim().isNotEmpty;

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

      await BackendApiService.createCommunityPost(
        title: _titleCtrl.text.trim(),
        body: _contentCtrl.text.trim(),
        imageUrls: imageUrls,
      );
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发布成功')),
      );
      Navigator.of(context).pop(true);
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

  Future<void> _showChoiceSheet({
    required String title,
    required List<String> options,
    required ValueChanged<String?> onSelected,
    bool allowClear = true,
  }) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (option) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      option,
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(option),
                  ),
                ),
                if (allowClear)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '不添加',
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.62),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(null),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() => onSelected(selected));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.artC.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const SizedBox.shrink(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _PublishPillButton(
              enabled: _hasDraft && !_publishing,
              publishing: _publishing,
              onPressed: _publish,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(18, 10, 18, keyboardOpen ? 86 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 122,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: _images.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                  const SizedBox(height: 26),
                  TextField(
                    controller: _titleCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '请输入标题...',
                      hintStyle: TextStyle(
                        fontSize: 22,
                        color: context.artC.silver.withValues(alpha: 0.42),
                        fontWeight: FontWeight.w800,
                      ),
                      isCollapsed: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.artC.ink,
                    ),
                    maxLines: 2,
                    textInputAction: TextInputAction.next,
                  ),
                  Container(
                    height: 0.5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    color: context.artC.silver.withValues(alpha: 0.34),
                  ),
                  TextField(
                    controller: _contentCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '分享你的想法、灵感、申请经验...',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFBBBBBB),
                      ),
                      isCollapsed: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: context.artC.ink,
                      fontWeight: FontWeight.w500,
                    ),
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 24),
                  _ComposeOptionRow(
                    icon: Icons.place_outlined,
                    title: '添加位置 / 展厅',
                    value: _locationLabel,
                    onTap: () => _showChoiceSheet(
                      title: '添加位置 / 展厅',
                      options: const ['热门展厅', '皇家艺术学院', '伦敦', '线上展厅'],
                      onSelected: (value) => _locationLabel = value,
                    ),
                  ),
                  _ComposeOptionRow(
                    icon: Icons.tag,
                    title: '添加话题',
                    value: _topicLabel,
                    onTap: () => _showChoiceSheet(
                      title: '添加话题',
                      options: const ['申请经验', '录取案例', '作品集准备', '院校资讯', '展览现场'],
                      onSelected: (value) => _topicLabel = value,
                    ),
                  ),
                  _ComposeOptionRow(
                    icon: Icons.visibility_outlined,
                    title: '可见范围',
                    value: _visibilityLabel ?? '公开',
                    onTap: () => _showChoiceSheet(
                      title: '可见范围',
                      options: const ['公开', '关注可见', '仅自己可见'],
                      allowClear: false,
                      onSelected: (value) => _visibilityLabel = value ?? '公开',
                    ),
                  ),
                ],
              ),
            ),
            if (keyboardOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _KeyboardToolbar(
                  onImageTap: _pickImages,
                  onTopicTap: () => _showChoiceSheet(
                    title: '添加话题',
                    options: const ['申请经验', '录取案例', '作品集准备', '院校资讯', '展览现场'],
                    onSelected: (value) => _topicLabel = value,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddImageBox() {
    return GestureDetector(
      onTap: _pickImages,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: context.artC.silver.withValues(alpha: 0.72),
          radius: 22,
        ),
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: context.artC.ink, size: 28),
              const SizedBox(height: 6),
              Text(
                '添加图片',
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.66),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishPillButton extends StatelessWidget {
  final bool enabled;
  final bool publishing;
  final VoidCallback onPressed;

  const _PublishPillButton({
    required this.enabled,
    required this.publishing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(68, 36),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        backgroundColor: enabled ? kCobalt : const Color(0xFFECEFF3),
        disabledBackgroundColor: const Color(0xFFECEFF3),
        foregroundColor: Colors.white,
        disabledForegroundColor: const Color(0xFFAEB4BD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: publishing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              '发布',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _ComposeOptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  const _ComposeOptionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 58,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.artC.silver.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: context.artC.ink.withValues(alpha: 0.66), size: 21),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value ?? '',
              style: TextStyle(
                color: value == null ? context.artC.silver : context.artC.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: context.artC.silver, size: 20),
          ],
        ),
      ),
    );
  }
}

class _KeyboardToolbar extends StatelessWidget {
  final VoidCallback onImageTap;
  final VoidCallback onTopicTap;

  const _KeyboardToolbar({
    required this.onImageTap,
    required this.onTopicTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: context.artC.silver.withValues(alpha: 0.22)),
        ),
      ),
      child: Row(
        children: [
          _ToolbarIcon(icon: Icons.image_outlined, onTap: onImageTap),
          _ToolbarIcon(icon: Icons.tag, onTap: onTopicTap),
          _ToolbarIcon(
            icon: Icons.alternate_email,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('好友提及稍后开放')),
            ),
          ),
          _ToolbarIcon(
            icon: Icons.mood_outlined,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('表情功能稍后开放')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ToolbarIcon({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: context.artC.ink, size: 23),
      visualDensity: VisualDensity.compact,
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
                  width: 112,
                  height: 112,
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
                width: 112,
                height: 112,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 112,
                  height: 112,
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

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRRectPainter({
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
