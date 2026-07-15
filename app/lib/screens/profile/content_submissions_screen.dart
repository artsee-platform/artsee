import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class ContentSubmissionsScreen extends StatefulWidget {
  const ContentSubmissionsScreen({super.key});

  @override
  State<ContentSubmissionsScreen> createState() =>
      _ContentSubmissionsScreenState();
}

class _ContentSubmissionsScreenState extends State<ContentSubmissionsScreen> {
  List<Map<String, dynamic>> _items = [];
  int? _count;
  String _type = 'all';
  String _status = 'all';
  bool _loading = true;
  String? _error;
  final Set<String> _resubmittingIds = {};

  static const _types = [
    ('all', '全部'),
    ('events', '活动'),
    ('opportunities', '机会'),
    ('artworks', '作品'),
    ('artists', '艺术家'),
    ('marketplace', '商品'),
  ];

  static const _statuses = [
    ('all', '全部状态'),
    ('reviewing', '审核中'),
    ('published', '已发布'),
    ('rejected', '未通过'),
    ('archived', '已归档'),
    ('draft', '草稿'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.fetchMyContentSubmissions(
        type: _type,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _items = result.data;
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

  Future<void> _resubmit(Map<String, dynamic> item) async {
    final type = _text(item['type']);
    final id = _text(item['id']);
    final key = _submissionKey(item);
    if (type.isEmpty || id.isEmpty || _resubmittingIds.contains(key)) return;
    setState(() => _resubmittingIds.add(key));
    try {
      await BackendApiService.resubmitMyContentSubmission(type: type, id: id);
      if (!mounted) return;
      setState(() {
        _items = _items.map((row) {
          if (_text(row['id']) != id || _text(row['type']) != type) return row;
          return {
            ...row,
            'status': 'reviewing',
            'review_decision': 'resubmitted',
            'updated_at': DateTime.now().toIso8601String(),
          };
        }).toList();
        _resubmittingIds.remove(key);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重新提交审核')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _resubmittingIds.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重新提交失败：$e')),
      );
    }
  }

  Future<void> _editAndSubmit(Map<String, dynamic> item) async {
    final type = _text(item['type']);
    final id = _text(item['id']);
    final key = _submissionKey(item);
    if (type.isEmpty || id.isEmpty || _resubmittingIds.contains(key)) return;
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmissionEditSheet(item: item),
    );
    if (payload == null || !mounted) return;
    setState(() => _resubmittingIds.add(key));
    try {
      await BackendApiService.updateMyContentSubmission(
        type: type,
        id: id,
        fields: Map<String, dynamic>.from(payload['fields'] as Map),
        note: _text(payload['note']),
        supplementalMaterials: _stringList(payload['supplemental_materials']),
        submit: payload['submit'] != false,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() => _resubmittingIds.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(payload['submit'] == false ? '已保存草稿' : '已修改并提交审核'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _resubmittingIds.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('修改提交失败：$e')),
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
        title: const Text(
          '发布记录',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            _FilterStrip(
              items: _types,
              value: _type,
              onChanged: (value) {
                setState(() => _type = value);
                _load();
              },
            ),
            const SizedBox(height: 8),
            _FilterStrip(
              items: _statuses,
              value: _status,
              onChanged: (value) {
                setState(() => _status = value);
                _load();
              },
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 88),
                child: Center(child: CircularProgressIndicator(color: kCobalt)),
              )
            else if (_error != null)
              _SubmissionEmptyState(
                title: '发布记录加载失败',
                body: _error!,
                actionLabel: '重试',
                onAction: _load,
              )
            else if (_items.isEmpty)
              const _SubmissionEmptyState(
                title: '暂无发布记录',
                body: '提交活动、合作机会、作品或艺术家档案后，审核状态会显示在这里。',
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                child: Text(
                  '共 ${_count ?? _items.length} 条记录',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink.withValues(alpha: 0.42),
                  ),
                ),
              ),
              ..._items.map(
                (item) => _SubmissionCard(
                  item: item,
                  resubmitting: _resubmittingIds.contains(_submissionKey(item)),
                  onEdit: () => _editAndSubmit(item),
                  onResubmit: () => _resubmit(item),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool resubmitting;
  final VoidCallback onEdit;
  final VoidCallback onResubmit;

  const _SubmissionCard({
    required this.item,
    required this.resubmitting,
    required this.onEdit,
    required this.onResubmit,
  });

  @override
  Widget build(BuildContext context) {
    final status = _text(item['status'], fallback: 'draft');
    final reviewDecision = _text(item['review_decision']);
    final reviewNote = _text(item['review_note']);
    final reviewedAt = _text(item['reviewed_at']);
    final canResubmit = _canResubmit(status, reviewDecision);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kCobalt.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(item['type']), color: kCobalt, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(item['title'], fallback: '未命名内容'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text(item['summary'],
                          fallback: _typeLabel(item['type'])),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.artC.ink.withValues(alpha: 0.42),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: status, decision: reviewDecision),
            ],
          ),
          if (reviewNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor(status, reviewDecision)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '审核备注：$reviewNote',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink.withValues(alpha: 0.58),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 14,
                      color: context.artC.ink.withValues(alpha: 0.34),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        reviewedAt.isNotEmpty
                            ? '审核于 ${_dateText(reviewedAt)}'
                            : '更新于 ${_dateText(_text(item['updated_at'], fallback: item['created_at']?.toString() ?? ''))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.artC.ink.withValues(alpha: 0.38),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (canResubmit) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: resubmitting ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.artC.ink.withValues(alpha: 0.72),
                    side: BorderSide(
                      color: context.artC.silver.withValues(alpha: 0.32),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text(
                    '修改',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: resubmitting ? null : onResubmit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCobalt,
                    side: BorderSide(color: kCobalt.withValues(alpha: 0.26)),
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: resubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kCobalt,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    '重新提交',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmissionEditSheet extends StatefulWidget {
  final Map<String, dynamic> item;

  const _SubmissionEditSheet({required this.item});

  @override
  State<_SubmissionEditSheet> createState() => _SubmissionEditSheetState();
}

class _SubmissionEditSheetState extends State<_SubmissionEditSheet> {
  final _noteCtrl = TextEditingController();
  final _materialsCtrl = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  late final List<Map<String, dynamic>> _fields;
  String? _error;
  bool _uploadingMaterial = false;
  String? _openingMaterial;

  @override
  void initState() {
    super.initState();
    _fields = _editableFields(widget.item);
    _materialsCtrl.text =
        _stringList(widget.item['supplemental_materials']).join('\n');
    _materialsCtrl.addListener(_handleMaterialsChanged);
    for (final field in _fields) {
      final key = _text(field['key']);
      if (key.isEmpty) continue;
      _controllers[key] = TextEditingController(
        text: _fieldInitialValue(field['value']),
      );
    }
  }

  @override
  void dispose() {
    _materialsCtrl.removeListener(_handleMaterialsChanged);
    _noteCtrl.dispose();
    _materialsCtrl.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _materialLinks => _materialsCtrl.text
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  void _handleMaterialsChanged() {
    if (mounted) setState(() {});
  }

  void _removeMaterial(String material) {
    final materials = _materialLinks;
    materials.remove(material);
    _materialsCtrl.text = materials.join('\n');
    _materialsCtrl.selection = TextSelection.collapsed(
      offset: _materialsCtrl.text.length,
    );
  }

  Future<void> _openMaterial(String material) async {
    if (_openingMaterial != null) return;
    setState(() {
      _openingMaterial = material;
      _error = null;
    });
    try {
      final signedUrl =
          await BackendApiService.signSubmissionMaterial(material);
      final uri = Uri.parse(signedUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('无法打开材料链接');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '打开材料失败：$e');
    } finally {
      if (mounted) setState(() => _openingMaterial = null);
    }
  }

  void _submit({required bool submit}) {
    final fields = <String, dynamic>{};
    for (final field in _fields) {
      final key = _text(field['key']);
      if (key.isEmpty) continue;
      final required = field['required'] == true;
      final type = _text(field['type'], fallback: 'text');
      final text = _controllers[key]?.text.trim() ?? '';
      if (required && text.isEmpty) {
        setState(() => _error = '${_text(field['label'], fallback: key)}不能为空');
        return;
      }
      fields[key] = type == 'number' && text.isNotEmpty
          ? int.tryParse(text) ?? text
          : text;
    }
    Navigator.of(context).pop({
      'fields': fields,
      'note': _noteCtrl.text.trim(),
      'supplemental_materials': _materialsCtrl.text
          .split('\n')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'submit': submit,
    });
  }

  Future<void> _uploadMaterialFile() async {
    if (_uploadingMaterial) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'gif'],
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
    setState(() {
      _uploadingMaterial = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.uploadFile(
        bytes: bytes,
        filename: file.name,
        contentType: _mimeForFileName(file.name),
        folder:
            'submission-materials/${_text(widget.item['type'], fallback: 'content')}/${_text(widget.item['id'], fallback: 'draft')}',
      );
      final url = _text(result['url']);
      if (url.isEmpty) throw Exception('上传结果缺少文件链接');
      if (!mounted) return;
      final current = _materialsCtrl.text.trim();
      _materialsCtrl.text = current.isEmpty ? url : '$current\n$url';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('补充材料已上传')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '上传材料失败：$e');
    } finally {
      if (mounted) setState(() => _uploadingMaterial = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialLinks = _materialLinks;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 22,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.artC.silver.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: kCobalt),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '修改发布内容',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _text(widget.item['title'],
                              fallback: _typeLabel(widget.item['type'])),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.artC.ink.withValues(alpha: 0.46),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (_text(widget.item['review_note']).isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '审核备注：${_text(widget.item['review_note'])}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: context.artC.ink.withValues(alpha: 0.62),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_fields.isEmpty)
                Text(
                  '当前内容暂不支持在 App 内编辑。',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink.withValues(alpha: 0.52),
                  ),
                )
              else
                ..._fields.map((field) {
                  final key = _text(field['key']);
                  final type = _text(field['type'], fallback: 'text');
                  final multiline = type == 'multiline';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _controllers[key],
                      keyboardType: type == 'number'
                          ? TextInputType.number
                          : multiline
                              ? TextInputType.multiline
                              : TextInputType.text,
                      minLines: multiline ? 3 : 1,
                      maxLines: multiline ? 6 : 1,
                      decoration: InputDecoration(
                        labelText: _text(field['label'], fallback: key),
                        helperText: type == 'datetime'
                            ? '可填写 ISO 时间，例如 2026-06-13T10:00:00Z'
                            : null,
                        filled: true,
                        fillColor:
                            context.artC.porcelain.withValues(alpha: 0.72),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: context.artC.silver.withValues(alpha: 0.28),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: context.artC.silver.withValues(alpha: 0.28),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: kCobalt.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  );
                }),
              _SubmissionEditNoteField(controller: _noteCtrl),
              const SizedBox(height: 12),
              _SubmissionEditNoteField(
                controller: _materialsCtrl,
                label: '补充材料链接',
                hint: '可上传 PDF / 图片，或手动填写材料链接；每行一个',
              ),
              if (materialLinks.isNotEmpty) ...[
                const SizedBox(height: 10),
                _SubmissionMaterialList(
                  materials: materialLinks,
                  openingMaterial: _openingMaterial,
                  onOpen: _openMaterial,
                  onRemove: _removeMaterial,
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _uploadingMaterial ? null : _uploadMaterialFile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCobalt,
                    side: BorderSide(color: kCobalt.withValues(alpha: 0.26)),
                  ),
                  icon: _uploadingMaterial
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kCobalt,
                          ),
                        )
                      : const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(_uploadingMaterial ? '上传中' : '上传文件材料'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.redAccent,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _fields.isEmpty ? null : () => _submit(submit: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            context.artC.ink.withValues(alpha: 0.72),
                        side: BorderSide(
                          color: context.artC.silver.withValues(alpha: 0.34),
                        ),
                      ),
                      child: const Text('保存草稿'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          _fields.isEmpty ? null : () => _submit(submit: true),
                      style: FilledButton.styleFrom(backgroundColor: kCobalt),
                      child: const Text('提交审核'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionMaterialList extends StatelessWidget {
  final List<String> materials;
  final String? openingMaterial;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onRemove;

  const _SubmissionMaterialList({
    required this.materials,
    required this.openingMaterial,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.artC.porcelain.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已添加材料',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: context.artC.ink.withValues(alpha: 0.64),
            ),
          ),
          const SizedBox(height: 8),
          ...materials.map(
            (material) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _materialIcon(material),
                      color: kCobalt,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _materialLabel(material),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          material,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: context.artC.ink.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '打开材料',
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        openingMaterial == null ? () => onOpen(material) : null,
                    icon: openingMaterial == material
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kCobalt,
                            ),
                          )
                        : Icon(
                            Icons.open_in_new_rounded,
                            color: kCobalt.withValues(alpha: 0.82),
                            size: 18,
                          ),
                  ),
                  IconButton(
                    tooltip: '移除材料',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onRemove(material),
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.artC.ink.withValues(alpha: 0.38),
                      size: 18,
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

class _SubmissionEditNoteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _SubmissionEditNoteField({
    required this.controller,
    this.label = '修改说明',
    this.hint = '例如：已补充活动地址和合作要求',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 2,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: context.artC.porcelain.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: context.artC.silver.withValues(alpha: 0.28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: context.artC.silver.withValues(alpha: 0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: kCobalt.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final String decision;

  const _StatusPill({required this.status, required this.decision});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status, decision);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        _statusLabel(status, decision),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  final List<(String, String)> items;
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterStrip({
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(item.$2),
                  selected: value == item.$1,
                  onSelected: (_) => onChanged(item.$1),
                  selectedColor: kCobalt.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: value == item.$1
                        ? kCobalt
                        : context.artC.ink.withValues(alpha: 0.56),
                  ),
                  side: BorderSide(
                    color: value == item.$1
                        ? kCobalt.withValues(alpha: 0.24)
                        : context.artC.silver.withValues(alpha: 0.32),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SubmissionEmptyState extends StatelessWidget {
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SubmissionEmptyState({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          const Icon(Icons.assignment_outlined, color: kCobalt, size: 32),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: context.artC.ink.withValues(alpha: 0.48),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(backgroundColor: kCobalt),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

bool _canResubmit(String status, String decision) {
  return status == 'draft' ||
      status == 'rejected' ||
      decision == 'rejected' ||
      (status == 'archived' && decision == 'rejected');
}

String _submissionKey(Map<String, dynamic> item) {
  return '${_text(item['type'])}:${_text(item['id'])}';
}

List<Map<String, dynamic>> _editableFields(Map<String, dynamic> item) {
  final raw = item['editable_fields'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((field) => Map<String, dynamic>.from(field))
      .where((field) => _text(field['key']).isNotEmpty)
      .toList();
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _fieldInitialValue(dynamic value) {
  if (value == null) return '';
  if (value is DateTime) return value.toIso8601String();
  return value.toString();
}

String _mimeForFileName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'image/jpeg';
}

IconData _materialIcon(String material) {
  final lower = material.toLowerCase();
  if (lower.contains('.pdf')) return Icons.picture_as_pdf_outlined;
  if (lower.contains('.png') ||
      lower.contains('.jpg') ||
      lower.contains('.jpeg') ||
      lower.contains('.webp') ||
      lower.contains('.gif')) {
    return Icons.image_outlined;
  }
  return Icons.link_rounded;
}

String _materialLabel(String material) {
  final uri = Uri.tryParse(material);
  final segments = uri?.pathSegments ?? const <String>[];
  if (segments.isNotEmpty) {
    final last = Uri.decodeComponent(segments.last);
    if (last.isNotEmpty) return last;
  }
  return material.length > 36 ? '${material.substring(0, 36)}...' : material;
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString() ?? '';
  return text.trim().isEmpty ? fallback : text.trim();
}

String _typeLabel(dynamic type) {
  switch (_text(type)) {
    case 'events':
      return '活动';
    case 'opportunities':
      return '合作机会';
    case 'artworks':
      return '作品';
    case 'artists':
      return '艺术家档案';
    case 'marketplace':
      return '市集商品';
    default:
      return '内容';
  }
}

IconData _typeIcon(dynamic type) {
  switch (_text(type)) {
    case 'events':
      return Icons.event_available_outlined;
    case 'opportunities':
      return Icons.business_center_outlined;
    case 'artworks':
      return Icons.image_outlined;
    case 'artists':
      return Icons.person_pin_circle_outlined;
    case 'marketplace':
      return Icons.storefront_outlined;
    default:
      return Icons.assignment_outlined;
  }
}

String _statusLabel(String status, String decision) {
  if (decision == 'rejected') return '未通过';
  switch (status) {
    case 'reviewing':
      return '审核中';
    case 'published':
      return '已发布';
    case 'rejected':
      return '未通过';
    case 'archived':
      return decision == 'rejected' ? '未通过' : '已归档';
    case 'draft':
      return '草稿';
    case 'closed':
      return '已关闭';
    default:
      return status;
  }
}

Color _statusColor(String status, String decision) {
  if (decision == 'rejected' || status == 'rejected') {
    return const Color(0xFFE11D48);
  }
  switch (status) {
    case 'reviewing':
      return const Color(0xFFD97706);
    case 'published':
      return const Color(0xFF059669);
    case 'archived':
    case 'closed':
      return const Color(0xFF64748B);
    default:
      return kCobalt;
  }
}

String _dateText(String value) {
  if (value.isEmpty) return '-';
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '-';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}
