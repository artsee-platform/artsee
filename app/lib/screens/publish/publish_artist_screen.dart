import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/backend_api_service.dart';
import '../../theme/artsee_ui_colors.dart';
import '../../utils/auth_gate.dart';
import '../../utils/submission_review_feedback.dart';
import '../../widgets/common.dart';

class PublishArtistScreen extends StatefulWidget {
  const PublishArtistScreen({super.key});

  @override
  State<PublishArtistScreen> createState() => _PublishArtistScreenState();
}

class _PublishArtistScreenState extends State<PublishArtistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _realNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();
  final _exhibitionCtrl = TextEditingController();
  final _awardsCtrl = TextEditingController();
  final _cooperationIntentCtrl = TextEditingController();

  String _careerStage = 'emerging';
  String _cooperationStatus = 'available';
  final List<String> _selectedFields = [];
  final List<String> _selectedCooperationTypes = [];
  final List<String> _portfolioImages = [];
  String? _avatarPath;
  String? _coverWorkPath;
  bool _submitting = false;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _realNameCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    _educationCtrl.dispose();
    _exhibitionCtrl.dispose();
    _awardsCtrl.dispose();
    _cooperationIntentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _avatarPath = image.path);
    }
  }

  Future<void> _pickCoverWork() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _coverWorkPath = image.path);
    }
  }

  Future<void> _pickPortfolioImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _portfolioImages.addAll(images.map((e) => e.path));
      });
    }
  }

  Future<void> _submit() async {
    if (!await ensureLoggedIn(context, message: '请先登录后创建艺术家档案')) return;
    if (!mounted) return;
    if (!_formKey.currentState!.validate() || _submitting) return;

    if (_selectedFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一个艺术方向')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await BackendApiService.upsertArtistProfile({
        'display_name': _displayNameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'art_fields': _selectedFields,
        'career_stage': _careerStage,
        'cooperation_status': _cooperationStatus,
        'bio': _bioCtrl.text.trim(),
        'cooperation_intent': _cooperationIntentCtrl.text.trim(),
        'status': 'reviewing',
        'metadata': {
          'real_name': _realNameCtrl.text.trim(),
          'education': _educationCtrl.text.trim(),
          'exhibitions': _exhibitionCtrl.text.trim(),
          'awards': _awardsCtrl.text.trim(),
          'cooperation_types': _selectedCooperationTypes,
          'portfolio_count': _portfolioImages.length,
        },
      });

      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop(true);
      showSubmissionReviewSnackBar(
        messenger: messenger,
        navigator: navigator,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '艺术家入驻',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '提交审核',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ProgressIndicator(currentStep: 1, totalSteps: 4),
            const SizedBox(height: 24),
            _SectionTitle(
              title: '基本信息',
              subtitle: '创建你的艺术家档案',
            ),
            const SizedBox(height: 12),
            _FormField(
              label: '显示名称',
              controller: _displayNameCtrl,
              hint: '公开展示的艺术家名称',
              required: true,
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '真实姓名',
              controller: _realNameCtrl,
              hint: '仅用于认证，不公开',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    label: '所在城市',
                    controller: _cityCtrl,
                    hint: '上海',
                    required: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FormDropdown(
                    label: '职业阶段',
                    value: _careerStage,
                    items: const [
                      ('student', '学生'),
                      ('emerging', '新锐'),
                      ('independent', '独立艺术家'),
                      ('established', '资深艺术家'),
                    ],
                    onChanged: (val) => setState(() => _careerStage = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _MultiSelectField(
              label: '艺术方向',
              required: true,
              selectedItems: _selectedFields,
              allItems: const [
                '绘画',
                '插画',
                '摄影',
                '装置',
                '新媒体',
                '视觉设计',
                '雕塑',
                '陶艺',
                '纺织',
                '传统工艺',
              ],
              onChanged: (items) => setState(() {
                _selectedFields.clear();
                _selectedFields.addAll(items);
              }),
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: '个人简介',
              subtitle: '展示你的创作理念和经历',
            ),
            const SizedBox(height: 12),
            _FormField(
              label: '一句话介绍',
              controller: _bioCtrl,
              hint: '简短描述你的创作方向和特点',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '教育背景',
              controller: _educationCtrl,
              hint: '例如：2020-2024 中央美术学院 雕塑系',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '展览经历',
              controller: _exhibitionCtrl,
              hint: '个展、群展、艺博会等',
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '获奖经历',
              controller: _awardsCtrl,
              hint: '重要奖项和荣誉',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: '作品集',
              subtitle: '上传至少3件代表作品',
            ),
            const SizedBox(height: 12),
            _ImagePicker(
              label: '头像',
              imagePath: _avatarPath,
              onPick: _pickAvatar,
              aspectRatio: 1.0,
            ),
            const SizedBox(height: 16),
            _ImagePicker(
              label: '代表作品封面',
              imagePath: _coverWorkPath,
              onPick: _pickCoverWork,
              aspectRatio: 1.5,
            ),
            const SizedBox(height: 16),
            _PortfolioGrid(
              images: _portfolioImages,
              onAdd: _pickPortfolioImages,
              onRemove: (index) {
                setState(() => _portfolioImages.removeAt(index));
              },
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: '合作意向',
              subtitle: '设置你的合作状态和方向',
            ),
            const SizedBox(height: 12),
            _FormDropdown(
              label: '合作状态',
              value: _cooperationStatus,
              items: const [
                ('available', '可合作'),
                ('busy', '档期紧张'),
                ('unavailable', '暂不接单'),
              ],
              onChanged: (val) => setState(() => _cooperationStatus = val!),
            ),
            const SizedBox(height: 16),
            _MultiSelectField(
              label: '合作方向',
              selectedItems: _selectedCooperationTypes,
              allItems: const [
                '品牌联名',
                '展览邀约',
                '驻留项目',
                '空间装置',
                '教学工作坊',
                '定制创作',
              ],
              onChanged: (items) => setState(() {
                _selectedCooperationTypes.clear();
                _selectedCooperationTypes.addAll(items);
              }),
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '合作说明',
              controller: _cooperationIntentCtrl,
              hint: '描述你希望的合作方式、项目类型等',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _InfoCard(
              title: '认证资料',
              content: '提交后可在个人主页申请实名认证、学历认证和职业认证，提升可信度。',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _ProgressIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < totalSteps - 1 ? 8 : 0),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF2563EB)
                  : context.artC.silver.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: context.artC.ink,
            fontFamily: kAppFontFamily,
            fontFamilyFallback: kAppFontFallback,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.artC.ink.withOpacity(0.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;

  const _FormField({
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.artC.ink.withOpacity(0.7),
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: context.artC.cardIconBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: context.artC.silver.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: context.artC.silver.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
          ),
          validator: required
              ? (val) => val == null || val.trim().isEmpty ? '请填写$label' : null
              : null,
        ),
      ],
    );
  }
}

class _FormDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;

  const _FormDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.artC.ink.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: context.artC.cardIconBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: context.artC.silver.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: context.artC.silver.withOpacity(0.3)),
            ),
          ),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item.$1,
                    child: Text(item.$2),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MultiSelectField extends StatelessWidget {
  final String label;
  final bool required;
  final List<String> selectedItems;
  final List<String> allItems;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelectField({
    required this.label,
    this.required = false,
    required this.selectedItems,
    required this.allItems,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.artC.ink.withOpacity(0.7),
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.red.shade400,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allItems.map((item) {
            final isSelected = selectedItems.contains(item);
            return GestureDetector(
              onTap: () {
                final newList = List<String>.from(selectedItems);
                if (isSelected) {
                  newList.remove(item);
                } else {
                  newList.add(item);
                }
                onChanged(newList);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB).withOpacity(0.08)
                      : context.artC.cardIconBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB).withOpacity(0.28)
                        : context.artC.silver.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : context.artC.ink.withOpacity(0.7),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final String label;
  final String? imagePath;
  final VoidCallback onPick;
  final double aspectRatio;

  const _ImagePicker({
    required this.label,
    required this.imagePath,
    required this.onPick,
    this.aspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.artC.ink.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: context.artC.cardIconBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: context.artC.silver.withOpacity(0.3),
                ),
              ),
              child: imagePath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: context.artC.ink.withOpacity(0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击上传',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.artC.ink.withOpacity(0.5),
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: context.artC.ink.withOpacity(0.3),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PortfolioGrid extends StatelessWidget {
  final List<String> images;
  final VoidCallback onAdd;
  final Function(int) onRemove;

  const _PortfolioGrid({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '作品集图片',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.artC.ink.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${images.length}/10)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.artC.ink.withOpacity(0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: images.length + 1,
          itemBuilder: (context, index) {
            if (index == images.length) {
              return GestureDetector(
                onTap: images.length < 10 ? onAdd : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.artC.cardIconBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.artC.silver.withOpacity(0.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 32,
                    color: context.artC.ink.withOpacity(0.3),
                  ),
                ),
              );
            }
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: context.artC.silver.withOpacity(0.2),
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: context.artC.ink.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String content;

  const _InfoCard({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.artC.ink.withOpacity(0.6),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
