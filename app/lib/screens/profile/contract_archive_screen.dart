import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class ContractArchiveScreen extends StatefulWidget {
  final String? initialOrganizationId;
  final String? initialOrganizationName;
  final bool openCreateOnLoad;

  const ContractArchiveScreen({
    super.key,
    this.initialOrganizationId,
    this.initialOrganizationName,
    this.openCreateOnLoad = false,
  });

  @override
  State<ContractArchiveScreen> createState() => _ContractArchiveScreenState();
}

class _ContractArchiveScreenState extends State<ContractArchiveScreen> {
  List<Map<String, dynamic>> _contracts = [];
  int? _count;
  String _status = 'all';
  bool _loading = true;
  String? _error;

  static const _statuses = [
    ('all', '全部'),
    ('pending', '待确认'),
    ('confirmed', '已确认'),
    ('disputed', '有争议'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.openCreateOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCreateSheet();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.fetchMyContracts(
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

  Future<void> _openCreateSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContractCreateSheet(
        initialOrganizationId: widget.initialOrganizationId,
        initialOrganizationName: widget.initialOrganizationName,
      ),
    );
    if (saved == true && mounted) {
      await _load();
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '合同存档',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.artC.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '新增存档',
            icon: Icon(Icons.add, color: context.artC.ink),
            onPressed: _openCreateSheet,
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
              child:
                  CircularProgressIndicator(color: kCobalt, strokeWidth: 2.5),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.description_outlined,
              size: 42, color: context.artC.ink.withValues(alpha: 0.18)),
          const SizedBox(height: 14),
          Text(
            '合同加载失败',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.artC.ink.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _load, child: const Text('重试')),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildStatusChips(),
        const SizedBox(height: 12),
        if (_contracts.isEmpty)
          _EmptyContracts(onCreate: _openCreateSheet)
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
            child: Text(
              '共 ${_count ?? _contracts.length} 份存档',
              style: TextStyle(
                fontSize: 12,
                color: context.artC.ink.withValues(alpha: 0.52),
              ),
            ),
          ),
          for (final contract in _contracts) ...[
            _ContractCard(contract: contract),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _buildStatusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in _statuses) ...[
            ChoiceChip(
              label: Text(item.$2),
              selected: _status == item.$1,
              onSelected: (_) {
                if (_status == item.$1) return;
                setState(() => _status = item.$1);
                _load();
              },
              showCheckmark: false,
              selectedColor: kCobalt.withValues(alpha: 0.12),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _status == item.$1
                    ? kCobalt.withValues(alpha: 0.35)
                    : context.artC.silver.withValues(alpha: 0.24),
              ),
              labelStyle: TextStyle(
                color: _status == item.$1
                    ? kCobalt
                    : context.artC.ink.withValues(alpha: 0.68),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Map<String, dynamic> contract;

  const _ContractCard({required this.contract});

  @override
  Widget build(BuildContext context) {
    final organization = _map(contract['organization']);
    final consultation = _map(contract['consultation']);
    final orgName = _text(organization['name'], fallback: '机构');
    final targetName = _text(consultation['target_name']);
    final status = _text(contract['status'], fallback: 'pending');
    final contractId = _text(contract['id']);
    final fileUrl = _text(contract['file_url']);
    final notes = _text(contract['notes']);
    final signedAt = _dateText(contract['signed_at']);
    final createdAt = _dateText(contract['created_at']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  orgName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: status),
            ],
          ),
          if (targetName.isNotEmpty) ...[
            const SizedBox(height: 8),
            _MetaLine(icon: Icons.school_outlined, text: targetName),
          ],
          const SizedBox(height: 8),
          _MetaLine(
            icon: Icons.event_available_outlined,
            text: signedAt.isNotEmpty ? '签约 $signedAt' : '存档 $createdAt',
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notes,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: context.artC.ink.withValues(alpha: 0.66),
              ),
            ),
          ],
          if (fileUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openPrivateFile(
                  context,
                  fileUrl,
                  contractId: contractId,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('查看文件'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContractCreateSheet extends StatefulWidget {
  final String? initialOrganizationId;
  final String? initialOrganizationName;

  const _ContractCreateSheet({
    this.initialOrganizationId,
    this.initialOrganizationName,
  });

  @override
  State<_ContractCreateSheet> createState() => _ContractCreateSheetState();
}

class _ContractCreateSheetState extends State<_ContractCreateSheet> {
  late final TextEditingController _organizationCtrl;
  late final TextEditingController _consultationCtrl;
  late final TextEditingController _notesCtrl;
  String _fileUrl = '';
  DateTime? _signedAt;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _organizationCtrl = TextEditingController(
      text: _text(widget.initialOrganizationId),
    );
    _consultationCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _organizationCtrl.dispose();
    _consultationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_uploading) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = '无法读取所选文件');
      return;
    }
    if (bytes.length > 10 * 1024 * 1024) {
      setState(() => _error = '文件大小不能超过 10MB');
      return;
    }

    final organizationId = _organizationCtrl.text.trim();
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.uploadFile(
        bytes: bytes,
        filename: file.name,
        contentType: _mimeForFileName(file.name),
        folder:
            'contracts/${organizationId.isEmpty ? 'manual' : organizationId}',
      );
      final url = _text(result['url']);
      if (url.isEmpty) throw Exception('上传结果缺少文件链接');
      if (!mounted) return;
      setState(() => _fileUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('合同文件已上传')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '上传失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final organizationId = _organizationCtrl.text.trim();
    if (organizationId.isEmpty) {
      setState(() => _error = '请填写机构 ID');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiService.createContractArchive(
        organizationId: organizationId,
        consultationId: _consultationCtrl.text.trim(),
        fileUrl: _fileUrl,
        signedAt: _signedAt?.toIso8601String(),
        notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('合同存档已创建')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '创建失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickSignedAt() async {
    if (_saving) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _signedAt ?? now,
      firstDate: DateTime(now.year - 8),
      lastDate: DateTime(now.year + 1),
      helpText: '选择签约日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) {
      setState(() => _signedAt = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: context.artC.porcelain,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '新增合同存档',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: context.artC.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_text(widget.initialOrganizationName).isNotEmpty) ...[
                  _MetaLine(
                    icon: Icons.storefront_outlined,
                    text: _text(widget.initialOrganizationName),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _organizationCtrl,
                  decoration: const InputDecoration(
                    labelText: '机构 ID',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _consultationCtrl,
                  decoration: const InputDecoration(
                    labelText: '咨询 ID（可选）',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                const _MetaLine(
                  icon: Icons.fact_check_outlined,
                  text: '提交后状态为待确认，由机构工作台确认或标记争议',
                ),
                const SizedBox(height: 12),
                _SignedDatePickerRow(
                  value: _signedAt,
                  onPick: _pickSignedAt,
                  onClear: _signedAt == null
                      ? null
                      : () => setState(() => _signedAt = null),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickFile,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(_uploading ? '上传中' : '上传合同文件'),
                ),
                if (_fileUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _MetaLine(icon: Icons.attach_file, text: '文件已上传'),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '保存中' : '保存存档'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignedDatePickerRow extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  const _SignedDatePickerRow({
    required this.value,
    required this.onPick,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_available_outlined,
            color: context.artC.ink.withValues(alpha: 0.48),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '签约日期（可选）',
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.48),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value == null ? '未填写' : _dateText(value!.toIso8601String()),
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: '清除日期',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          TextButton(
            onPressed: onPick,
            child: const Text('选择'),
          ),
        ],
      ),
    );
  }
}

class _EmptyContracts extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyContracts({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 42, 18, 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: [
          Icon(Icons.description_outlined,
              size: 42, color: context.artC.ink.withValues(alpha: 0.18)),
          const SizedBox(height: 12),
          Text(
            '暂无合同存档',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新增存档'),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'confirmed' => '已确认',
      'disputed' => '有争议',
      _ => '待确认',
    };
    final color = switch (status) {
      'confirmed' => const Color(0xFF188A54),
      'disputed' => const Color(0xFFD06124),
      _ => kCobalt,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: context.artC.ink.withValues(alpha: 0.42)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: context.artC.ink.withValues(alpha: 0.58),
            ),
          ),
        ),
      ],
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _dateText(Object? value) {
  final text = _text(value);
  if (text.length < 10) return text;
  return text.substring(0, 10);
}

String _mimeForFileName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/png';
}

Future<void> _openPrivateFile(
  BuildContext context,
  String url, {
  String? contractId,
}) async {
  try {
    final signedUrl = await BackendApiService.signSubmissionMaterial(
      url,
      contractId: contractId,
    );
    final uri = Uri.tryParse(signedUrl);
    if (uri == null) throw Exception('文件链接无效');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) throw Exception('无法打开合同文件');
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('打开文件失败：$error')),
    );
  }
}
