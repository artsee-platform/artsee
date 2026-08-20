import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class WorkbenchContractsScreen extends StatefulWidget {
  final String initialStatus;

  const WorkbenchContractsScreen({
    super.key,
    this.initialStatus = 'all',
  });

  @override
  State<WorkbenchContractsScreen> createState() =>
      _WorkbenchContractsScreenState();
}

class _WorkbenchContractsScreenState extends State<WorkbenchContractsScreen> {
  List<Map<String, dynamic>> _contracts = [];
  int? _count;
  String _status = 'all';
  bool _loading = true;
  String? _error;
  String? _savingId;

  static const _statuses = [
    ('all', '全部'),
    ('pending', '待确认'),
    ('confirmed', '已确认'),
    ('disputed', '有争议'),
  ];

  @override
  void initState() {
    super.initState();
    if (_statuses.any((status) => status.$1 == widget.initialStatus)) {
      _status = widget.initialStatus;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.fetchWorkbenchContracts(
        status: _status == 'all' ? null : _status,
      );
      if (!mounted) return;
      setState(() {
        _contracts = result.data;
        _count = result.count;
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

  Future<void> _setStatus(Map<String, dynamic> contract, String status) async {
    final id = contract['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() => _savingId = '$id:$status');
    try {
      final updated = await BackendApiService.updateWorkbenchContractStatus(
        contractId: id,
        status: status,
        notes: contract['notes']?.toString(),
      );
      if (!mounted) return;
      setState(() {
        final index = _contracts.indexWhere((item) => item['id'] == id);
        if (index >= 0) {
          if (_status != 'all' && status != _status) {
            _contracts.removeAt(index);
            if (_count != null) {
              _count = _count! > 0 ? _count! - 1 : 0;
            }
          } else {
            _contracts[index] = updated;
          }
        }
        _savingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('合同已标记为${_statusLabel(status)}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openFile(String? url, {String? contractId}) async {
    String signedUrl;
    try {
      signedUrl = await BackendApiService.signSubmissionMaterial(
        url ?? '',
        contractId: contractId,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('合同文件签名失败：$error')),
      );
      return;
    }
    if (!mounted) return;
    final uri = Uri.tryParse(signedUrl);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('合同文件链接无效')),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开合同文件')),
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
        foregroundColor: context.artC.ink,
        title: const Text(
          '合同存档管理',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kCobalt,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: const Center(
              child: CircularProgressIndicator(
                color: kCobalt,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.description_outlined,
            size: 44,
            color: context.artC.ink.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 14),
          Text(
            '合同存档加载失败',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: kCobalt),
              child: const Text('重试'),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _StatusFilter(
          value: _status,
          statuses: _statuses,
          onChanged: (value) {
            setState(() => _status = value);
            _load();
          },
        ),
        const SizedBox(height: 12),
        _SummaryBar(
          count: _count ?? _contracts.length,
          pending: _contracts
              .where((item) => item['status']?.toString() == 'pending')
              .length,
        ),
        const SizedBox(height: 12),
        if (_contracts.isEmpty)
          const _EmptyContracts()
        else
          for (final contract in _contracts) ...[
            _ContractCard(
              contract: contract,
              savingId: _savingId,
              onOpenFile: (url) => _openFile(
                url,
                contractId: contract['id']?.toString(),
              ),
              onSetStatus: _setStatus,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final String value;
  final List<(String, String)> statuses;
  final ValueChanged<String> onChanged;

  const _StatusFilter({
    required this.value,
    required this.statuses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final status in statuses)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(status.$2),
                selected: value == status.$1,
                onSelected: (_) => onChanged(status.$1),
                selectedColor: kCobalt.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: value == status.$1
                      ? kCobalt
                      : context.artC.ink.withValues(alpha: 0.58),
                ),
                side: BorderSide(
                  color: value == status.$1
                      ? kCobalt.withValues(alpha: 0.32)
                      : context.artC.silver.withValues(alpha: 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int count;
  final int pending;

  const _SummaryBar({
    required this.count,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: kCobalt),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '共 $count 份合同存档',
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _SmallTag(label: '$pending 待确认'),
        ],
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Map<String, dynamic> contract;
  final String? savingId;
  final Future<void> Function(String? url) onOpenFile;
  final Future<void> Function(Map<String, dynamic> contract, String status)
      onSetStatus;

  const _ContractCard({
    required this.contract,
    required this.savingId,
    required this.onOpenFile,
    required this.onSetStatus,
  });

  @override
  Widget build(BuildContext context) {
    final id = _text(contract['id']);
    final status = _text(contract['status'], fallback: 'pending');
    final profile = _map(contract['user_profile']);
    final organization = _map(contract['organization']);
    final consultation = _map(contract['consultation']);
    final studentName = _text(profile?['nickname'], fallback: '未命名用户');
    final organizationName = _text(organization?['name'], fallback: '机构');
    final topic = _text(
      consultation?['target_name'],
      fallback: _text(consultation?['topic'], fallback: '线下签约'),
    );
    final signedAt = _dateText(contract['signed_at']);
    final notes = _text(contract['notes']);
    final fileUrl = _text(contract['file_url']);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kCobalt.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.article_outlined,
                  size: 20,
                  color: kCobalt,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$organizationName · $topic',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.52),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusTag(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (signedAt != null) _SmallTag(label: '签约 $signedAt'),
              if (fileUrl.isNotEmpty) const _SmallTag(label: '有合同文件'),
              if (notes.isNotEmpty) _SmallTag(label: notes),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (fileUrl.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onOpenFile(fileUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('查看文件'),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              _StatusButton(
                label: '确认',
                active: status == 'confirmed',
                loading: savingId == '$id:confirmed',
                onPressed: () => onSetStatus(contract, 'confirmed'),
              ),
              const SizedBox(width: 8),
              _StatusButton(
                label: '争议',
                active: status == 'disputed',
                loading: savingId == '$id:disputed',
                danger: true,
                onPressed: () => onSetStatus(contract, 'disputed'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final bool active;
  final bool loading;
  final bool danger;
  final VoidCallback onPressed;

  const _StatusButton({
    required this.label,
    required this.active,
    required this.loading,
    this.danger = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFD06124) : kCobalt;
    return SizedBox(
      height: 38,
      child: FilledButton(
        onPressed: active || loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.16),
          disabledForegroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: loading
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                active ? '已$label' : label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String status;

  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' => const Color(0xFF188A54),
      'disputed' => const Color(0xFFD06124),
      _ => kCobalt,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  final String label;

  const _SmallTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.artC.ink.withValues(alpha: 0.58),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyContracts extends StatelessWidget {
  const _EmptyContracts();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.description_outlined,
            size: 36,
            color: context.artC.ink.withValues(alpha: 0.24),
          ),
          const SizedBox(height: 10),
          Text(
            '暂无合同存档',
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '学生上传线下签约合同后，机构负责人可以在这里确认或标记争议。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic>? _map(Object? value) {
  return value is Map<String, dynamic> ? value : null;
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _dateText(Object? value) {
  final text = _text(value);
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text.length > 10 ? text.substring(0, 10) : text;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}

String _statusLabel(String status) {
  return switch (status) {
    'confirmed' => '已确认',
    'disputed' => '有争议',
    _ => '待确认',
  };
}
