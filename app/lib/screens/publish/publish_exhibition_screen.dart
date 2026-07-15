import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/backend_api_service.dart';
import '../../theme/artsee_ui_colors.dart';
import '../../utils/auth_gate.dart';
import '../../utils/submission_review_feedback.dart';

class PublishExhibitionScreen extends StatefulWidget {
  const PublishExhibitionScreen({super.key});

  @override
  State<PublishExhibitionScreen> createState() =>
      _PublishExhibitionScreenState();
}

class _PublishExhibitionScreenState extends State<PublishExhibitionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _quotaCtrl = TextEditingController();
  final _feeAmountCtrl = TextEditingController();
  final _requirementsCtrl = TextEditingController();

  String _eventType = 'exhibition';
  bool _isReservationOnly = false;
  bool _isFree = true;
  DateTime? _startTime;
  DateTime? _endTime;
  String? _coverImagePath;
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _descriptionCtrl.dispose();
    _cityCtrl.dispose();
    _venueCtrl.dispose();
    _quotaCtrl.dispose();
    _feeAmountCtrl.dispose();
    _requirementsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _coverImagePath = image.path);
    }
  }

  Future<void> _selectDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startTime = dateTime;
      } else {
        _endTime = dateTime;
      }
    });
  }

  Future<void> _submit() async {
    if (!await ensureLoggedIn(context, message: '请先登录后发布活动')) return;
    if (!mounted) return;
    if (!_formKey.currentState!.validate() || _submitting) return;

    setState(() => _submitting = true);

    try {
      await BackendApiService.createEvent({
        'title': _titleCtrl.text.trim(),
        'type': _eventType,
        'city': _cityCtrl.text.trim(),
        'venue': _venueCtrl.text.trim(),
        'summary': _summaryCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        if (_startTime != null) 'start_time': _startTime!.toIso8601String(),
        if (_endTime != null) 'end_time': _endTime!.toIso8601String(),
        if (!_isFree && _feeAmountCtrl.text.trim().isNotEmpty)
          'fee_amount': int.tryParse(_feeAmountCtrl.text.trim()) ?? 0,
        if (_quotaCtrl.text.trim().isNotEmpty)
          'quota': int.tryParse(_quotaCtrl.text.trim()),
        'metadata': {
          'is_reservation_only': _isReservationOnly,
          'requirements': _requirementsCtrl.text.trim(),
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
          '发布活动',
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
            _SectionTitle(title: '基础信息'),
            const SizedBox(height: 12),
            _FormField(
              label: '活动标题',
              controller: _titleCtrl,
              hint: '例如：上海 · 艺术留学规划工作坊',
              required: true,
            ),
            const SizedBox(height: 16),
            _FormDropdown(
              label: '活动类型',
              value: _eventType,
              items: const [
                ('exhibition', '展览'),
                ('salon', '沙龙'),
                ('workshop', '工作坊'),
                ('lecture', '讲座/分享会'),
                ('open_day', '开放日'),
                ('briefing', '说明会'),
                ('tour', '导览'),
                ('fair', '艺博会'),
                ('online', '线上活动'),
              ],
              onChanged: (val) => setState(() => _eventType = val!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    label: '城市',
                    controller: _cityCtrl,
                    hint: '上海',
                    required: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FormField(
                    label: '地点/场馆',
                    controller: _venueCtrl,
                    hint: 'Artiqore 上海办公室',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: '时间与报名'),
            const SizedBox(height: 12),
            _DateTimeField(
              label: '开始时间',
              dateTime: _startTime,
              onTap: () => _selectDateTime(true),
            ),
            const SizedBox(height: 16),
            _DateTimeField(
              label: '结束时间',
              dateTime: _endTime,
              onTap: () => _selectDateTime(false),
            ),
            const SizedBox(height: 16),
            _SwitchField(
              label: '预约制',
              value: _isReservationOnly,
              onChanged: (val) => setState(() => _isReservationOnly = val),
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '名额上限',
              controller: _quotaCtrl,
              hint: '留空表示不限',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _SwitchField(
              label: '免费活动',
              value: _isFree,
              onChanged: (val) => setState(() => _isFree = val),
            ),
            if (!_isFree) ...[
              const SizedBox(height: 16),
              _FormField(
                label: '票价（元）',
                controller: _feeAmountCtrl,
                hint: '0',
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 24),
            _SectionTitle(title: '内容介绍'),
            const SizedBox(height: 12),
            _FormField(
              label: '一句话简介',
              controller: _summaryCtrl,
              hint: '简短描述活动亮点',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '详细介绍',
              controller: _descriptionCtrl,
              hint: '活动内容、流程、收获等',
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '适合人群 / 报名须知',
              controller: _requirementsCtrl,
              hint: '例如：艺术留学申请者、需提前预约',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: '封面图'),
            const SizedBox(height: 12),
            _CoverImagePicker(
              imagePath: _coverImagePath,
              onPick: _pickCoverImage,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: context.artC.ink,
      ),
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

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? dateTime;
  final VoidCallback onTap;

  const _DateTimeField({
    required this.label,
    required this.dateTime,
    required this.onTap,
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
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.artC.cardIconBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.artC.silver.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 18, color: context.artC.ink.withOpacity(0.5)),
                const SizedBox(width: 12),
                Text(
                  dateTime == null
                      ? '选择时间'
                      : '${dateTime!.year}-${dateTime!.month.toString().padLeft(2, '0')}-${dateTime!.day.toString().padLeft(2, '0')} ${dateTime!.hour.toString().padLeft(2, '0')}:${dateTime!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: dateTime == null
                        ? context.artC.ink.withOpacity(0.4)
                        : context.artC.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchField extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withOpacity(0.8),
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF2563EB),
        ),
      ],
    );
  }
}

class _CoverImagePicker extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onPick;

  const _CoverImagePicker({
    required this.imagePath,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.artC.silver.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: imagePath == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: context.artC.ink.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '点击上传封面图',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.artC.ink.withOpacity(0.5),
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: context.artC.ink.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
