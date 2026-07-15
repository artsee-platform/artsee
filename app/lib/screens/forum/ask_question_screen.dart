import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../utils/auth_gate.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class AskQuestionScreen extends StatefulWidget {
  final String? initialTitle;
  final String? initialCategory;
  final String? searchKeyword;
  final String? initialSchool;
  final String? initialSchoolId;
  final String? initialProgram;
  final String? sourceCircle;

  const AskQuestionScreen({
    super.key,
    this.initialTitle,
    this.initialCategory,
    this.searchKeyword,
    this.initialSchool,
    this.initialSchoolId,
    this.initialProgram,
    this.sourceCircle,
  });

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen> {
  static const _categories = ['艺术留学', '作品集', '行业就业', '艺术市场', '版权法律'];

  late final TextEditingController _titleCtrl;
  final TextEditingController _bodyCtrl = TextEditingController();
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _programCtrl = TextEditingController();
  late String _category;
  bool _anonymous = false;
  bool _submitting = false;

  void _safePop([String? result]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  @override
  void initState() {
    super.initState();
    final search = widget.searchKeyword?.trim();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _category = widget.initialCategory != null &&
            _categories.contains(widget.initialCategory)
        ? widget.initialCategory!
        : '艺术留学';
    if (search != null && search.isNotEmpty && _titleCtrl.text.isEmpty) {
      _titleCtrl.text = '想问关于「$search」的问题';
    }
    _schoolCtrl.text = widget.initialSchool ?? '';
    _programCtrl.text = widget.initialProgram ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _schoolCtrl.dispose();
    _programCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final loggedIn = await ensureLoggedIn(context, message: '请先登录后发布问题');
    if (!mounted || !loggedIn) return;
    final title = _titleCtrl.text.trim();
    if (title.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题再具体一点，会更容易获得有效回答')),
      );
      return;
    }
    if (['求助', '问一下', '有人知道吗'].contains(title)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题再具体一点，会更容易获得有效回答')),
      );
      return;
    }
    if (_bodyCtrl.text.trim().isEmpty) {
      final shouldPublish = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('补充背景后，回答会更具体'),
          content: const Text('建议说明你的目标学校、作品集进度和最想解决的问题。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续补充'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('直接发布'),
            ),
          ],
        ),
      );
      if (shouldPublish != true) return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await BackendApiService.createPlazaPost(
        title: title,
        body: _bodyCtrl.text.trim(),
        kind: 'qa',
        group: widget.sourceCircle?.trim().isNotEmpty == true
            ? widget.sourceCircle!.trim()
            : _category,
        tags: [
          _category,
          if (_schoolCtrl.text.trim().isNotEmpty) _schoolCtrl.text.trim(),
          if (_programCtrl.text.trim().isNotEmpty) _programCtrl.text.trim(),
        ],
        metadata: {
          'kind': 'qa',
          'category': _category,
          'source': 'plaza_question',
          'promote_to_plaza': true,
          if (_schoolCtrl.text.trim().isNotEmpty)
            'school': _schoolCtrl.text.trim(),
          if (widget.initialSchoolId?.trim().isNotEmpty == true)
            'school_id': widget.initialSchoolId!.trim(),
          if (_programCtrl.text.trim().isNotEmpty)
            'program': _programCtrl.text.trim(),
          if (widget.sourceCircle?.trim().isNotEmpty == true)
            'source_circle': widget.sourceCircle!.trim(),
          'anonymous': _anonymous,
        },
      );
      if (!mounted) return;
      _safePop(title);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.artC.ink, size: 20),
          onPressed: () => _safePop(),
        ),
        centerTitle: true,
        title: Text(
          '发布问题',
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            style: TextButton.styleFrom(
              foregroundColor: kCobalt,
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            child: Text(_submitting ? '发布中' : '发布'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 34),
          children: [
            _QuestionSection(
              title: '问题标题',
              child: TextField(
                controller: _titleCtrl,
                autofocus: _titleCtrl.text.isEmpty,
                maxLength: 60,
                minLines: 2,
                maxLines: 3,
                cursorColor: kCobalt,
                decoration: const InputDecoration(
                  hintText: '例如：RCA 作品集一般需要几个完整项目？',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  counterText: '',
                ),
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 23,
                  height: 1.22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(height: 34),
            _QuestionSection(
              title: '问题方向',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories
                    .map(
                      (item) => _QuestionCategoryChip(
                        label: item,
                        selected: _category == item,
                        onTap: () => setState(() => _category = item),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 38),
            _QuestionSection(
              title: '补充说明',
              child: TextField(
                controller: _bodyCtrl,
                minLines: 7,
                maxLines: 12,
                cursorColor: kCobalt,
                decoration: InputDecoration(
                  hintText: '分享你的申请背景、作品集进度和目前最卡住的地方...',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.30),
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 15,
                  height: 1.65,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(height: 38),
            _QuestionSection(
              title: '相关学校 / 项目',
              child: Column(
                children: [
                  _QuietInputLine(
                    controller: _schoolCtrl,
                    hint: '相关学校，如 Royal College of Art',
                  ),
                  const SizedBox(height: 16),
                  _QuietInputLine(
                    controller: _programCtrl,
                    hint: '相关专业 / 项目，如 MA Design Products',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '匿名提问',
                        style: TextStyle(
                          color: context.artC.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '其他用户不会看到你的昵称和头像。',
                        style: TextStyle(
                          color: context.artC.ink.withValues(alpha: 0.42),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _anonymous,
                  activeThumbColor: kCobalt,
                  activeTrackColor: kCobalt.withValues(alpha: 0.18),
                  onChanged: (value) => setState(() => _anonymous = value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _QuestionSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 15),
        child,
      ],
    );
  }
}

class _QuestionCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuestionCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? context.artC.ink.withValues(alpha: 0.055)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? context.artC.ink
                : context.artC.ink.withValues(alpha: 0.28),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _QuietInputLine extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _QuietInputLine({
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: kCobalt,
      decoration: InputDecoration(
        hintText: hint,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 11),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: context.artC.ink.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: context.artC.ink.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        hintStyle: TextStyle(
          color: context.artC.ink.withValues(alpha: 0.30),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      style: TextStyle(
        color: context.artC.ink,
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}
