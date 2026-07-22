import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class IdentityVerificationScreen extends StatefulWidget {
  final String? initialType;
  final String? initialBusinessRole;

  const IdentityVerificationScreen({
    super.key,
    this.initialType,
    this.initialBusinessRole,
  });

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  late String _type;
  late String _businessRole;

  @override
  void initState() {
    super.initState();
    _type = _normalizeType(widget.initialType);
    _businessRole = _normalizeBusinessRole(widget.initialBusinessRole);
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await BackendApiService.fetchMyVerifications();
      if (!mounted) return;
      setState(() {
        _requests = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final contact = _contactCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('请填写名称');
      return;
    }
    if (_type == 'business' && contact.isEmpty) {
      _showSnack('请填写联系方式');
      return;
    }

    setState(() => _submitting = true);
    try {
      await BackendApiService.submitVerification(
        type: _type,
        materials: {
          'display_name': name,
          if (contact.isNotEmpty) 'contact': contact,
          if (note.isNotEmpty) 'note': note,
          if (_type == 'business') 'requested_role': _businessRole,
        },
      );
      if (!mounted) return;
      _nameCtrl.clear();
      _contactCtrl.clear();
      _noteCtrl.clear();
      _showSnack('已提交审核');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic>? get _latest {
    if (_requests.isEmpty) return null;
    return _requests.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        elevation: 0,
        foregroundColor: context.artC.ink,
        title: const Text(
          '身份认证',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        color: kCobalt,
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: kCobalt,
                  strokeWidth: 2.5,
                ),
              )
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                    children: [
                      _StatusPanel(request: _latest),
                      const SizedBox(height: 14),
                      _Section(
                        title: '申请类型',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _typeOptions.entries
                              .map(
                                (entry) => _ChoicePill(
                                  label: entry.value,
                                  selected: _type == entry.key,
                                  onTap: () =>
                                      setState(() => _type = entry.key),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      if (_type == 'business') ...[
                        const SizedBox(height: 14),
                        _Section(
                          title: '机构类型',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _businessRoleOptions.entries
                                .map(
                                  (entry) => _ChoicePill(
                                    label: entry.value,
                                    selected: _businessRole == entry.key,
                                    onTap: () => setState(
                                      () => _businessRole = entry.key,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _Section(
                        title: '资料',
                        child: Column(
                          children: [
                            _Field(
                              controller: _nameCtrl,
                              label: _type == 'business' ? '机构名称' : '显示名称',
                            ),
                            const SizedBox(height: 10),
                            _Field(
                              controller: _contactCtrl,
                              label: '联系方式',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 10),
                            _Field(
                              controller: _noteCtrl,
                              label: '补充说明',
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: kCobalt,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  '提交审核',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _HistoryPanel(requests: _requests),
                    ],
                  ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final Map<String, dynamic>? request;

  const _StatusPanel({required this.request});

  @override
  Widget build(BuildContext context) {
    final status = _text(request?['status'], fallback: 'none');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.artC.deepPanel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _statusIcon(status),
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle(status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request == null
                      ? '还没有提交过认证申请'
                      : '${_typeLabel(_text(request?['type']))} · ${_statusLabel(status)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kCobalt : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? kCobalt
                : context.artC.silver.withValues(alpha: 0.38),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.artC.ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      style: TextStyle(
        color: context.artC.ink,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: context.artC.ink.withValues(alpha: 0.45),
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: context.artC.silver.withValues(alpha: 0.28),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: context.artC.silver.withValues(alpha: 0.24),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kCobalt, width: 1.3),
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  final List<Map<String, dynamic>> requests;

  const _HistoryPanel({required this.requests});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '审核记录',
      child: requests.isEmpty
          ? Text(
              '暂无记录',
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.48),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            )
          : Column(
              children: requests
                  .take(5)
                  .map((item) => _HistoryRow(request: item))
                  .toList(),
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> request;

  const _HistoryRow({required this.request});

  @override
  Widget build(BuildContext context) {
    final status = _text(request['status']);
    final createdAt = _text(request['created_at']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_statusIcon(status), color: kCobalt, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _typeLabel(_text(request['type'])),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            createdAt.length >= 10 ? createdAt.substring(0, 10) : '',
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.42),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          _StatusTag(label: _statusLabel(status)),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;

  const _StatusTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCobalt.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kCobalt,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.error_outline_rounded,
          size: 42,
          color: context.artC.ink.withValues(alpha: 0.32),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.artC.ink.withValues(alpha: 0.58),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ),
      ],
    );
  }
}

const _typeOptions = {
  'student': '学生',
  'artist': '艺术家',
  'collector': '收藏者',
  'business': '机构入驻',
};

const _businessRoleOptions = {
  'gallery_exhibition': '画廊 / 美术馆 / 展览机构',
  'official_association': '官方协会 / 行业组织',
  'school_official': '院校官方 / 招生部门',
  'official_partner': '官方合作组织',
  'event_organizer': '活动主办方',
  'hotel_culture_space': '文旅空间',
  'brand_partner': '品牌合作方',
  'art_media_community': '艺术媒体',
  'other_service': '其他服务商',
};

String _normalizeType(String? value) {
  if (value != null && _typeOptions.containsKey(value)) return value;
  return 'student';
}

String _normalizeBusinessRole(String? value) {
  if (value != null && _businessRoleOptions.containsKey(value)) return value;
  return 'gallery_exhibition';
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _typeLabel(String type) => _typeOptions[type] ?? type;

String _statusLabel(String status) {
  switch (status) {
    case 'approved':
      return '已通过';
    case 'rejected':
      return '未通过';
    case 'pending':
      return '审核中';
    default:
      return '未提交';
  }
}

String _statusTitle(String status) {
  switch (status) {
    case 'approved':
      return '认证已通过';
    case 'rejected':
      return '认证未通过';
    case 'pending':
      return '认证审核中';
    default:
      return '提交认证申请';
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'approved':
      return Icons.verified_outlined;
    case 'rejected':
      return Icons.report_gmailerrorred_outlined;
    case 'pending':
      return Icons.hourglass_top_outlined;
    default:
      return Icons.badge_outlined;
  }
}
