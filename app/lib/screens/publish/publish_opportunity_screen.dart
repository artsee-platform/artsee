import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../theme/artsee_ui_colors.dart';
import '../../utils/auth_gate.dart';
import '../../utils/submission_review_feedback.dart';

class PublishOpportunityScreen extends StatefulWidget {
  const PublishOpportunityScreen({super.key});

  @override
  State<PublishOpportunityScreen> createState() =>
      _PublishOpportunityScreenState();
}

class _PublishOpportunityScreenState extends State<PublishOpportunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _requirementsCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _budgetMinCtrl = TextEditingController();
  final _budgetMaxCtrl = TextEditingController();
  final _organizationCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _deliverableCtrl = TextEditingController();
  final _deliveryFormatCtrl = TextEditingController();

  String _opportunityType = 'collaboration';
  String _publisherType = 'brand';
  bool _isRemote = false;
  bool _showOrganization = true;
  bool _requiresOffline = false;
  bool _copyrightBuyout = false;
  bool _allowCredit = true;
  DateTime? _deadline;
  final List<String> _selectedMaterials = [];
  final List<String> _selectedFields = [];
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _requirementsCtrl.dispose();
    _cityCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _organizationCtrl.dispose();
    _contactCtrl.dispose();
    _durationCtrl.dispose();
    _deliverableCtrl.dispose();
    _deliveryFormatCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _deadline = date);
    }
  }

  Future<void> _submit() async {
    if (!await ensureLoggedIn(context, message: '请先登录后发布合作')) return;
    if (!mounted) return;
    if (!_formKey.currentState!.validate() || _submitting) return;

    setState(() => _submitting = true);

    try {
      final budgetMin = int.tryParse(_budgetMinCtrl.text.trim());
      final budgetMax = int.tryParse(_budgetMaxCtrl.text.trim());

      await BackendApiService.createOpportunity({
        'title': _titleCtrl.text.trim(),
        'type': _opportunityType,
        'city': _cityCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'requirements': _requirementsCtrl.text.trim(),
        if (_deadline != null) 'deadline': _deadline!.toIso8601String(),
        if (budgetMin != null) 'budget_min': budgetMin,
        if (budgetMax != null) 'budget_max': budgetMax,
        'metadata': {
          'is_remote': _isRemote,
          'required_materials': _selectedMaterials,
          'art_fields': _selectedFields,
          'organization': _organizationCtrl.text.trim(),
          'publisher_type': _publisherType,
          'show_organization': _showOrganization,
          'contact': _contactCtrl.text.trim(),
          'duration': _durationCtrl.text.trim(),
          'deliverable': _deliverableCtrl.text.trim(),
          'delivery_format': _deliveryFormatCtrl.text.trim(),
          'requires_offline': _requiresOffline,
          'copyright_buyout': _copyrightBuyout,
          'allow_credit': _allowCredit,
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
          '发布合作',
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
              label: '机会标题',
              controller: _titleCtrl,
              hint: '例如：爱马仕：传统手工艺现代转化研究员',
              required: true,
            ),
            const SizedBox(height: 16),
            _FormDropdown(
              label: '合作类型',
              value: _opportunityType,
              items: const [
                ('collaboration', '品牌联名'),
                ('research', '研究类'),
                ('residency', '驻留项目'),
                ('competition', '竞赛征集'),
                ('exhibition', '展览邀约'),
                ('workshop', '工作坊'),
                ('commission', '定制创作'),
                ('space', '商业空间'),
              ],
              onChanged: (val) => setState(() => _opportunityType = val!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    label: '城市',
                    controller: _cityCtrl,
                    hint: '北京',
                    required: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SwitchField(
                    label: '支持远程',
                    value: _isRemote,
                    onChanged: (val) => setState(() => _isRemote = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DateField(
              label: '截止时间',
              date: _deadline,
              onTap: _selectDeadline,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    label: '预算下限（元）',
                    controller: _budgetMinCtrl,
                    hint: '30000',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FormField(
                    label: '预算上限（元）',
                    controller: _budgetMaxCtrl,
                    hint: '50000',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _BudgetQuickSelect(
              onSelect: (min, max) {
                setState(() {
                  _budgetMinCtrl.text = min.toString();
                  _budgetMaxCtrl.text = max.toString();
                });
              },
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: '项目需求'),
            const SizedBox(height: 12),
            _FormField(
              label: '项目介绍',
              controller: _descriptionCtrl,
              hint: '描述项目背景、目标、预期成果等',
              maxLines: 5,
              required: true,
            ),
            const SizedBox(height: 16),
            _MultiSelectField(
              label: '适合艺术方向',
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
            const SizedBox(height: 16),
            _FormField(
              label: '申请要求',
              controller: _requirementsCtrl,
              hint: '例如：需要传统纹样设计经验，熟悉数字化工具',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '交付物',
              controller: _deliverableCtrl,
              hint: '例如：3 张主视觉 / 1 套装置方案 / 7 天驻留创作',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '交付格式',
              controller: _deliveryFormatCtrl,
              hint: '例如：PDF 提案、高清图片、现场执行、源文件',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _MultiSelectField(
              label: '需要提交材料',
              selectedItems: _selectedMaterials,
              allItems: const [
                '作品集',
                '简历',
                '方案',
                '报价单',
                '过往案例',
                '艺术家陈述',
                '视频介绍',
              ],
              onChanged: (items) => setState(() {
                _selectedMaterials.clear();
                _selectedMaterials.addAll(items);
              }),
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '预计合作周期',
              controller: _durationCtrl,
              hint: '例如：3个月 / 6-12个月',
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: '发布方信息'),
            const SizedBox(height: 12),
            _FormField(
              label: '机构名称',
              controller: _organizationCtrl,
              hint: '例如：爱马仕中国',
            ),
            const SizedBox(height: 16),
            _FormDropdown(
              label: '发布方类型',
              value: _publisherType,
              items: const [
                ('brand', '品牌'),
                ('hotel', '酒店 / 商业空间'),
                ('gallery', '画廊'),
                ('museum', '美术馆'),
                ('agency', '设计机构'),
                ('curator', '策展人'),
              ],
              onChanged: (val) => setState(() => _publisherType = val!),
            ),
            const SizedBox(height: 16),
            _SwitchField(
              label: '公开显示机构名称',
              value: _showOrganization,
              onChanged: (val) => setState(() => _showOrganization = val),
            ),
            const SizedBox(height: 16),
            _FormField(
              label: '联系方式',
              controller: _contactCtrl,
              hint: '邮箱或微信',
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: '版权与执行'),
            const SizedBox(height: 12),
            _SwitchField(
              label: '需要线下执行',
              value: _requiresOffline,
              onChanged: (val) => setState(() => _requiresOffline = val),
            ),
            const SizedBox(height: 16),
            _SwitchField(
              label: '涉及版权买断',
              value: _copyrightBuyout,
              onChanged: (val) => setState(() => _copyrightBuyout = val),
            ),
            const SizedBox(height: 16),
            _SwitchField(
              label: '允许艺术家署名',
              value: _allowCredit,
              onChanged: (val) => setState(() => _allowCredit = val),
            ),
            const SizedBox(height: 20),
            _AuditNotice(),
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

class _AuditNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.14)),
      ),
      child: Text(
        '提交后将进入平台审核，审核通过后展示给艺术家。请确保预算、周期、版权和交付要求真实清晰。',
        style: TextStyle(
          color: const Color(0xFF2563EB).withOpacity(0.86),
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w800,
        ),
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
            hintStyle: TextStyle(color: context.artC.ink.withOpacity(0.38)),
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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
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
                  date == null
                      ? '选择截止日期'
                      : '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: date == null
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
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withOpacity(0.7),
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

class _BudgetQuickSelect extends StatelessWidget {
  final Function(int, int) onSelect;

  const _BudgetQuickSelect({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _QuickChip(label: '1w以下', onTap: () => onSelect(0, 10000)),
        _QuickChip(label: '1w-3w', onTap: () => onSelect(10000, 30000)),
        _QuickChip(label: '3w-5w', onTap: () => onSelect(30000, 50000)),
        _QuickChip(label: '5w-15w', onTap: () => onSelect(50000, 150000)),
        _QuickChip(label: '15w+', onTap: () => onSelect(150000, 500000)),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.artC.silver.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.artC.silver.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: context.artC.ink.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}

class _MultiSelectField extends StatelessWidget {
  final String label;
  final List<String> selectedItems;
  final List<String> allItems;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelectField({
    required this.label,
    required this.selectedItems,
    required this.allItems,
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
