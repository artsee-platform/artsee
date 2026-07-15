import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class WorkbenchConsultationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> consultation;

  const WorkbenchConsultationDetailScreen({
    super.key,
    required this.consultation,
  });

  @override
  State<WorkbenchConsultationDetailScreen> createState() =>
      _WorkbenchConsultationDetailScreenState();
}

class _WorkbenchConsultationDetailScreenState
    extends State<WorkbenchConsultationDetailScreen> {
  late Map<String, dynamic> _consultation;
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _assessment;
  Map<String, dynamic>? _recommendation;
  bool _loading = true;
  bool _sending = false;
  bool _acting = false;
  bool _assigning = false;
  bool _collaborating = false;
  String? _error;

  String? get _id => _consultation['id']?.toString();

  @override
  void initState() {
    super.initState();
    _consultation = widget.consultation;
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _id;
    if (id == null || id.isEmpty) {
      setState(() {
        _loading = false;
        _error = '咨询记录缺少 ID';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final consultation =
          await BackendApiService.fetchWorkbenchConsultation(id);
      final messages =
          await BackendApiService.fetchWorkbenchConsultationMessages(
        consultationId: id,
      );
      final assessment =
          await BackendApiService.fetchWorkbenchConsultationAssessment(id);
      final recommendation =
          await BackendApiService.fetchWorkbenchConsultationRecommendation(id);
      if (!mounted) return;
      setState(() {
        _consultation = consultation;
        _messages = messages.data;
        _assessment = assessment;
        _recommendation = recommendation;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openAssessmentSheet() async {
    final id = _id;
    if (id == null || id.isEmpty) return;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssessmentSheet(
        consultationId: id,
        initial: _assessment,
      ),
    );
    if (updated != null && mounted) {
      setState(() => _assessment = updated);
    }
  }

  Future<void> _openRecommendationSheet() async {
    final id = _id;
    if (id == null || id.isEmpty) return;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecommendationSheet(
        consultationId: id,
        initial: _recommendation,
      ),
    );
    if (updated != null && mounted) {
      setState(() => _recommendation = updated);
    }
  }

  Future<void> _send() async {
    final id = _id;
    final text = _input.text.trim();
    if (id == null || id.isEmpty || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await BackendApiService.sendWorkbenchConsultationMessage(
        consultationId: id,
        body: text,
      );
      _input.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _runAction(
    String action, {
    int? orderAmountTotal,
    String? orderSubject,
  }) async {
    final id = _id;
    if (id == null || id.isEmpty || _acting) return;
    setState(() => _acting = true);
    try {
      final updated = await BackendApiService.updateWorkbenchConsultation(
        id: id,
        action: action,
        orderAmountTotal: orderAmountTotal,
        orderSubject: orderSubject,
      );
      if (!mounted) return;
      setState(() => _consultation = updated);
      final label = action == 'convert_to_order' ? '已创建待支付订单' : '已标记转预约';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(label)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _showOrderQuoteSheet() async {
    final targetName = _consultation['target_name']?.toString() ?? '申请咨询';
    final quote = await showModalBottomSheet<_OrderQuote>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderQuoteSheet(
        defaultSubject: '$targetName申请服务订单',
      ),
    );
    if (quote == null) return;
    await _runAction(
      'convert_to_order',
      orderAmountTotal: quote.amountTotal,
      orderSubject: quote.subject,
    );
  }

  Future<void> _openAssignmentSheet() async {
    final id = _id;
    if (id == null || id.isEmpty || _assigning) return;
    setState(() => _assigning = true);
    try {
      final team = await BackendApiService.fetchWorkbenchTeam();
      if (!mounted) return;
      if (team.data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无可分配成员')),
        );
        return;
      }
      final member = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AssignmentSheet(members: team.data),
      );
      if (member == null) return;
      final memberId = member['id']?.toString();
      if (memberId == null || memberId.isEmpty) return;
      final updated = await BackendApiService.assignWorkbenchConsultation(
        id: id,
        memberId: memberId,
      );
      if (!mounted) return;
      setState(() => _consultation = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已分配给 ${_memberDisplayName(member)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分配失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _openCollaboratorsSheet() async {
    final id = _id;
    if (id == null || id.isEmpty || _collaborating) return;
    setState(() => _collaborating = true);
    try {
      final team = await BackendApiService.fetchWorkbenchTeam();
      if (!mounted) return;
      if (team.data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无可协作成员')),
        );
        return;
      }
      final selectedIds = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CollaboratorsSheet(
          members: team.data,
          selectedMemberIds: _collaboratorMemberIds(_consultation),
          primaryMemberId: _consultation['assigned_to_member_id']?.toString(),
        ),
      );
      if (selectedIds == null) return;
      final updated =
          await BackendApiService.updateWorkbenchConsultationCollaborators(
        id: id,
        mode: 'replace',
        memberIds: selectedIds,
      );
      if (!mounted) return;
      setState(() => _consultation = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新 ${selectedIds.length} 位协作老师')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新协作失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _collaborating = false);
    }
  }

  Future<void> _closeConsultation() async {
    final id = _id;
    if (id == null || id.isEmpty || _acting) return;
    setState(() => _acting = true);
    try {
      final updated = await BackendApiService.updateWorkbenchConsultation(
        id: id,
        status: 'closed',
      );
      if (!mounted) return;
      setState(() => _consultation = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已关闭咨询')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _focusReply() {
    _scrollToBottom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inputFocus.requestFocus();
    });
  }

  List<Map<String, dynamic>> _displayMessages() {
    if (_messages.isNotEmpty) return _messages;
    final lastMessage = _consultation['last_message']?.toString();
    if (lastMessage == null || lastMessage.trim().isEmpty) return const [];
    return [
      {
        'sender_role': 'student',
        'body': lastMessage,
        'created_at': _consultation['created_at'],
      }
    ];
  }

  @override
  Widget build(BuildContext context) {
    final targetName = _consultation['target_name']?.toString() ?? '咨询详情';
    final status = _consultation['status']?.toString() ?? 'new';
    final topic = _topicLabel(_consultation['topic']?.toString());
    final assignment = _assignmentLabel(_consultation);
    final messages = _displayMessages();

    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        child: Column(
          children: [
            _WorkbenchDetailHeader(
              title: targetName,
              subtitle: [topic ?? '申请咨询线索', if (assignment != null) assignment]
                  .join(' · '),
              status: _statusLabel(status),
              onRefresh: _load,
              onAssign: _openAssignmentSheet,
              assigning: _assigning,
            ),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: kCobalt,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else if (_error != null)
              Expanded(
                child: _WorkbenchErrorState(
                  error: _error!,
                  onRetry: _load,
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  children: [
                    _WorkbenchPipelinePanel(
                      consultation: _consultation,
                      assessment: _assessment,
                      recommendation: _recommendation,
                      onReply: _focusReply,
                      onAssign: _openAssignmentSheet,
                      onEditAssessment: _openAssessmentSheet,
                      onEditRecommendation: _openRecommendationSheet,
                      onConvertOrder: _showOrderQuoteSheet,
                      onClose: _closeConsultation,
                      busy: _acting || _assigning,
                    ),
                    const SizedBox(height: 12),
                    _StudentDossierPanel(
                      consultation: _consultation,
                      assessment: _assessment,
                      recommendation: _recommendation,
                    ),
                    const SizedBox(height: 12),
                    _WorkbenchTeamPanel(
                      consultation: _consultation,
                      busy: _collaborating,
                      onEditCollaborators: _openCollaboratorsSheet,
                    ),
                    const SizedBox(height: 12),
                    _WorkbenchInsightPanel(
                      assessment: _assessment,
                      recommendation: _recommendation,
                      onEditAssessment: _openAssessmentSheet,
                      onEditRecommendation: _openRecommendationSheet,
                    ),
                    const SizedBox(height: 12),
                    ...messages.map(
                      (message) => _WorkbenchMessageBubble(
                        role: message['sender_role']?.toString() ?? 'student',
                        senderName: message['member_name']?.toString(),
                        body: message['body']?.toString() ?? '',
                        time: _formatTime(message['created_at']),
                      ),
                    ),
                  ],
                ),
              ),
            _WorkbenchActionBar(
              acting: _acting,
              enabled: status != 'closed' && status != 'converted',
              onConvertBooking: () => _runAction('convert_to_booking'),
              onConvertOrder: _showOrderQuoteSheet,
              onClose: _closeConsultation,
            ),
            _WorkbenchReplyBar(
              controller: _input,
              focusNode: _inputFocus,
              sending: _sending,
              enabled: status != 'closed' && status != 'converted',
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchPipelinePanel extends StatelessWidget {
  final Map<String, dynamic> consultation;
  final Map<String, dynamic>? assessment;
  final Map<String, dynamic>? recommendation;
  final VoidCallback onReply;
  final VoidCallback onAssign;
  final VoidCallback onEditAssessment;
  final VoidCallback onEditRecommendation;
  final VoidCallback onConvertOrder;
  final VoidCallback onClose;
  final bool busy;

  const _WorkbenchPipelinePanel({
    required this.consultation,
    required this.assessment,
    required this.recommendation,
    required this.onReply,
    required this.onAssign,
    required this.onEditAssessment,
    required this.onEditRecommendation,
    required this.onConvertOrder,
    required this.onClose,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final phase = _consultationPhase(
      consultation,
      assessment: assessment,
      recommendation: recommendation,
    );
    final actions = _pipelineActions(
      phase,
      onReply: onReply,
      onAssign: onAssign,
      onEditAssessment: onEditAssessment,
      onEditRecommendation: onEditRecommendation,
      onConvertOrder: onConvertOrder,
      onClose: onClose,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _detailPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '线索阶段',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                  ),
                ),
              ),
              _WorkbenchStatusChip(label: phase.currentLabel),
            ],
          ),
          const SizedBox(height: 14),
          _PipelineTimeline(currentIndex: phase.index),
          const SizedBox(height: 13),
          Text(
            phase.nextHint,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.42,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.58),
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: actions
                  .map(
                    (action) => _PipelineActionButton(
                      label: action.label,
                      onTap: busy ? null : action.onTap,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PipelineTimeline extends StatelessWidget {
  final int currentIndex;

  const _PipelineTimeline({required this.currentIndex});

  static const _labels = [
    '新线索',
    '已联系',
    '需求确认',
    '方案制定',
    '已报价',
    '成交/流失',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Expanded(
            child: _PipelineStep(
              label: _labels[i],
              done: i <= currentIndex,
              current: i == currentIndex,
            ),
          ),
          if (i != _labels.length - 1)
            Container(
              width: 14,
              height: 1,
              margin: const EdgeInsets.only(bottom: 18),
              color: i < currentIndex
                  ? context.artC.ink.withValues(alpha: 0.36)
                  : context.artC.silver.withValues(alpha: 0.3),
            ),
        ],
      ],
    );
  }
}

class _PipelineStep extends StatelessWidget {
  final String label;
  final bool done;
  final bool current;

  const _PipelineStep({
    required this.label,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: current ? 14 : 11,
          height: current ? 14 : 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? context.artC.ink : Colors.transparent,
            border: Border.all(
              color: done
                  ? context.artC.ink
                  : context.artC.silver.withValues(alpha: 0.52),
              width: 1,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9.5,
            height: 1.1,
            fontWeight: current ? FontWeight.w800 : FontWeight.w500,
            color: context.artC.ink.withValues(alpha: current ? 0.72 : 0.36),
          ),
        ),
      ],
    );
  }
}

class _PipelineActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PipelineActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: context.artC.ink,
        side: BorderSide(color: context.artC.silver.withValues(alpha: 0.36)),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

class _StudentDossierPanel extends StatelessWidget {
  final Map<String, dynamic> consultation;
  final Map<String, dynamic>? assessment;
  final Map<String, dynamic>? recommendation;

  const _StudentDossierPanel({
    required this.consultation,
    required this.assessment,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = _mapValue(consultation['metadata']);
    final facts = [
      _DossierFact('咨询对象', _studentDisplayName(consultation)),
      _DossierFact('目标', _firstCleanText(consultation['target_name'])),
      _DossierFact(
        '专业',
        _firstCleanText(
          consultation['target_major'],
          metadata['target_major'],
          metadata['major'],
          metadata['intended_major'],
        ),
      ),
      _DossierFact(
        '国家',
        _firstCleanText(
          metadata['target_country'],
          metadata['country'],
          metadata['destination'],
        ),
      ),
      _DossierFact('预算', _budgetLabel(metadata)),
      _DossierFact(
        '时间',
        _firstCleanText(consultation['intake'], metadata['intake']),
      ),
      _DossierFact(
        '阶段',
        _firstCleanText(consultation['stage'], metadata['stage']),
      ),
      _DossierFact('来源', _sourceLabel(consultation['source']?.toString())),
    ].where((fact) => fact.value.isNotEmpty).toList();
    final background = assessment?['background_summary']?.toString().trim();
    final notes = assessment?['notes']?.toString().trim();
    final schools = _jsonItemLabels(recommendation?['school_list']);
    final timeline = recommendation?['timeline']?.toString().trim();
    final services = _jsonItemLabels(recommendation?['recommended_services']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _detailPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学生档案',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 12),
          if (facts.isEmpty)
            Text(
              '学生目标与背景尚未补充。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: context.artC.ink.withValues(alpha: 0.48),
              ),
            )
          else
            _DossierFactGrid(facts: facts),
          if (_notBlank(background) || _notBlank(notes)) ...[
            const SizedBox(height: 13),
            _DossierTextSection(
              title: '背景资料',
              text: [
                if (_notBlank(background)) background!,
                if (_notBlank(notes)) notes!,
              ].join('\n'),
            ),
          ],
          if (schools.isNotEmpty ||
              _notBlank(timeline) ||
              services.isNotEmpty) ...[
            const SizedBox(height: 13),
            _DossierTextSection(
              title: '当前方案',
              text: [
                if (schools.isNotEmpty) '院校：${schools.join('、')}',
                if (_notBlank(timeline)) '时间线：$timeline',
                if (services.isNotEmpty) '服务：${services.join('、')}',
              ].join('\n'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DossierFactGrid extends StatelessWidget {
  final List<_DossierFact> facts;

  const _DossierFactGrid({required this.facts});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 260
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: facts
              .map(
                (fact) => SizedBox(
                  width: itemWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fact.label,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.15,
                          fontWeight: FontWeight.w500,
                          color: context.artC.ink.withValues(alpha: 0.36),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fact.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: context.artC.ink.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DossierTextSection extends StatelessWidget {
  final String title;
  final String text;

  const _DossierTextSection({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.artC.ink.withValues(alpha: 0.56),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: context.artC.ink.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }
}

class _WorkbenchActionBar extends StatelessWidget {
  final bool acting;
  final bool enabled;
  final VoidCallback onConvertBooking;
  final VoidCallback onConvertOrder;
  final VoidCallback onClose;

  const _WorkbenchActionBar({
    required this.acting,
    required this.enabled,
    required this.onConvertBooking,
    required this.onConvertOrder,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        border: Border(
          top: BorderSide(color: context.artC.silver.withValues(alpha: 0.22)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCobalt,
                  side: BorderSide(color: kCobalt.withValues(alpha: 0.26)),
                ),
                onPressed: enabled && !acting ? onConvertBooking : null,
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: const Text('转预约'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCobalt,
                  side: BorderSide(color: kCobalt.withValues(alpha: 0.26)),
                ),
                onPressed: enabled && !acting ? onConvertOrder : null,
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('转订单'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: '关闭咨询',
              style: IconButton.styleFrom(
                foregroundColor: context.artC.ink.withValues(alpha: 0.58),
                side: BorderSide(
                  color: context.artC.silver.withValues(alpha: 0.42),
                ),
              ),
              onPressed: enabled && !acting ? onClose : null,
              icon: acting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kCobalt,
                      ),
                    )
                  : const Icon(Icons.done_all_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchInsightPanel extends StatelessWidget {
  final Map<String, dynamic>? assessment;
  final Map<String, dynamic>? recommendation;
  final VoidCallback onEditAssessment;
  final VoidCallback onEditRecommendation;

  const _WorkbenchInsightPanel({
    required this.assessment,
    required this.recommendation,
    required this.onEditAssessment,
    required this.onEditRecommendation,
  });

  @override
  Widget build(BuildContext context) {
    final background = assessment?['background_summary']?.toString();
    final notes = assessment?['notes']?.toString();
    final timeline = recommendation?['timeline']?.toString();
    final portfolio = recommendation?['portfolio_strategy']?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.artC.silver.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_alt_outlined,
                color: kCobalt.withValues(alpha: 0.92),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '诊断与方案',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InsightActionChip(
                label: assessment == null ? '填写诊断' : '更新诊断',
                icon: Icons.assignment_turned_in_outlined,
                onTap: onEditAssessment,
              ),
              _InsightActionChip(
                label: recommendation == null ? '填写方案' : '更新方案',
                icon: Icons.route_outlined,
                onTap: onEditRecommendation,
              ),
            ],
          ),
          if (assessment != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _MiniInsightTag(
                  label:
                      '匹配 ${_matchLevelLabel(assessment?['match_level']?.toString())}',
                ),
                _MiniInsightTag(
                  label:
                      '风险 ${_riskLevelLabel(assessment?['risk_level']?.toString())}',
                ),
              ],
            ),
            if (_notBlank(background)) _InsightTextBlock(text: background!),
            if (_notBlank(notes)) _InsightTextBlock(text: notes!),
          ],
          if (recommendation != null) ...[
            const SizedBox(height: 12),
            if (_jsonItemLabels(recommendation?['school_list']).isNotEmpty)
              _InsightBulletBlock(
                title: '学校组合',
                items: _jsonItemLabels(recommendation?['school_list']),
              ),
            if (_notBlank(timeline))
              _InsightBulletBlock(title: '时间线', items: [timeline!]),
            if (_notBlank(portfolio))
              _InsightBulletBlock(title: '作品集策略', items: [portfolio!]),
            if (_jsonItemLabels(recommendation?['recommended_services'])
                .isNotEmpty)
              _InsightBulletBlock(
                title: '推荐服务',
                items: _jsonItemLabels(
                  recommendation?['recommended_services'],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InsightActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _InsightActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: kCobalt),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: kCobalt.withValues(alpha: 0.08),
      side: BorderSide(color: kCobalt.withValues(alpha: 0.22)),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: kCobalt,
      ),
    );
  }
}

class _MiniInsightTag extends StatelessWidget {
  final String label;

  const _MiniInsightTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.artC.silver.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: context.artC.ink.withValues(alpha: 0.56),
        ),
      ),
    );
  }
}

class _WorkbenchTeamPanel extends StatelessWidget {
  final Map<String, dynamic> consultation;
  final bool busy;
  final VoidCallback onEditCollaborators;

  const _WorkbenchTeamPanel({
    required this.consultation,
    required this.busy,
    required this.onEditCollaborators,
  });

  @override
  Widget build(BuildContext context) {
    final primaryName = _assignmentLabel(consultation)?.replaceFirst('负责 ', '');
    final collaborators = _collaboratorNames(consultation);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.artC.silver.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.groups_2_outlined, size: 18, color: kCobalt),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '服务团队',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _MiniInsightTag(
                        label:
                            primaryName == null ? '未分配主责' : '主责 $primaryName'),
                    if (collaborators.isEmpty)
                      const _MiniInsightTag(label: '暂无协作')
                    else
                      ...collaborators
                          .map((name) => _MiniInsightTag(label: '协作 $name')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: '编辑协作老师',
            style: IconButton.styleFrom(
              foregroundColor: kCobalt,
              side: BorderSide(color: kCobalt.withValues(alpha: 0.24)),
            ),
            onPressed: busy ? null : onEditCollaborators,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kCobalt,
                    ),
                  )
                : const Icon(Icons.edit_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

class _InsightTextBlock extends StatelessWidget {
  final String text;

  const _InsightTextBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.45,
          fontWeight: FontWeight.w700,
          color: context.artC.ink.withValues(alpha: 0.62),
        ),
      ),
    );
  }
}

class _InsightBulletBlock extends StatelessWidget {
  final String title;
  final List<String> items;

  const _InsightBulletBlock({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 5),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.38,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink.withValues(alpha: 0.58),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentSheet extends StatefulWidget {
  final String consultationId;
  final Map<String, dynamic>? initial;

  const _AssessmentSheet({
    required this.consultationId,
    required this.initial,
  });

  @override
  State<_AssessmentSheet> createState() => _AssessmentSheetState();
}

class _AssessmentSheetState extends State<_AssessmentSheet> {
  late final TextEditingController _background;
  late final TextEditingController _notes;
  String _matchLevel = 'moderate';
  String _riskLevel = 'medium';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _background = TextEditingController(
      text: widget.initial?['background_summary']?.toString() ?? '',
    );
    _notes = TextEditingController(
      text: widget.initial?['notes']?.toString() ?? '',
    );
    _matchLevel = widget.initial?['match_level']?.toString() ?? 'moderate';
    _riskLevel = widget.initial?['risk_level']?.toString() ?? 'medium';
  }

  @override
  void dispose() {
    _background.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated =
          await BackendApiService.saveWorkbenchConsultationAssessment(
        id: widget.consultationId,
        backgroundSummary: _background.text.trim(),
        matchLevel: _matchLevel,
        riskLevel: _riskLevel,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _InsightFormShell(
      title: '填写诊断',
      icon: Icons.assignment_turned_in_outlined,
      error: _error,
      saving: _saving,
      submitLabel: '保存诊断',
      onSubmit: _save,
      children: [
        _InsightTextField(
          controller: _background,
          label: '学生情况评估',
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        _LevelSelector(
          title: '目标匹配度',
          value: _matchLevel,
          options: const {
            'strong': '强匹配',
            'moderate': '中等匹配',
            'weak': '弱匹配',
          },
          onChanged: (value) => setState(() => _matchLevel = value),
        ),
        const SizedBox(height: 12),
        _LevelSelector(
          title: '风险等级',
          value: _riskLevel,
          options: const {
            'low': '低风险',
            'medium': '中风险',
            'high': '高风险',
          },
          onChanged: (value) => setState(() => _riskLevel = value),
        ),
        const SizedBox(height: 12),
        _InsightTextField(
          controller: _notes,
          label: '诊断备注',
          minLines: 3,
          maxLines: 5,
        ),
      ],
    );
  }
}

class _RecommendationSheet extends StatefulWidget {
  final String consultationId;
  final Map<String, dynamic>? initial;

  const _RecommendationSheet({
    required this.consultationId,
    required this.initial,
  });

  @override
  State<_RecommendationSheet> createState() => _RecommendationSheetState();
}

class _RecommendationSheetState extends State<_RecommendationSheet> {
  late final TextEditingController _schools;
  late final TextEditingController _timeline;
  late final TextEditingController _portfolio;
  late final TextEditingController _services;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _schools = TextEditingController(
      text: _jsonItemLabels(widget.initial?['school_list']).join('\n'),
    );
    _timeline = TextEditingController(
      text: widget.initial?['timeline']?.toString() ?? '',
    );
    _portfolio = TextEditingController(
      text: widget.initial?['portfolio_strategy']?.toString() ?? '',
    );
    _services = TextEditingController(
      text: _jsonItemLabels(widget.initial?['recommended_services']).join('\n'),
    );
  }

  @override
  void dispose() {
    _schools.dispose();
    _timeline.dispose();
    _portfolio.dispose();
    _services.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated =
          await BackendApiService.saveWorkbenchConsultationRecommendation(
        id: widget.consultationId,
        schoolList: _lineItems(_schools.text),
        timeline: _timeline.text.trim(),
        portfolioStrategy: _portfolio.text.trim(),
        recommendedServices: _lineItems(_services.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _InsightFormShell(
      title: '填写方案',
      icon: Icons.route_outlined,
      error: _error,
      saving: _saving,
      submitLabel: '保存方案',
      onSubmit: _save,
      children: [
        _InsightTextField(
          controller: _schools,
          label: '学校组合（每行一项）',
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        _InsightTextField(
          controller: _timeline,
          label: '时间线规划',
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        _InsightTextField(
          controller: _portfolio,
          label: '作品集策略',
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        _InsightTextField(
          controller: _services,
          label: '推荐服务（每行一项）',
          minLines: 2,
          maxLines: 4,
        ),
      ],
    );
  }
}

class _InsightFormShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? error;
  final bool saving;
  final String submitLabel;
  final VoidCallback onSubmit;

  const _InsightFormShell({
    required this.title,
    required this.icon,
    required this.children,
    required this.error,
    required this.saving,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      child: Icon(icon, color: kCobalt),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: context.artC.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed:
                          saving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...children,
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kCobalt),
                    onPressed: saving ? null : onSubmit,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(icon),
                    label: Text(saving ? '保存中' : submitLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int minLines;
  final int maxLines;

  const _InsightTextField({
    required this.controller,
    required this.label,
    required this.minLines,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        filled: true,
        fillColor: context.artC.porcelain,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _LevelSelector extends StatelessWidget {
  final String title;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  const _LevelSelector({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: context.artC.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.entries.map((entry) {
            final selected = value == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) => onChanged(entry.key),
              selectedColor: kCobalt.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: selected
                    ? kCobalt
                    : context.artC.ink.withValues(alpha: 0.58),
              ),
              side: BorderSide(
                color: selected
                    ? kCobalt.withValues(alpha: 0.32)
                    : context.artC.silver.withValues(alpha: 0.3),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _WorkbenchDetailHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onRefresh;
  final VoidCallback onAssign;
  final bool assigning;

  const _WorkbenchDetailHeader({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onRefresh,
    required this.onAssign,
    required this.assigning,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: context.artC.ink,
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.artC.ink.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _WorkbenchStatusChip(label: status),
          IconButton(
            tooltip: '分配老师',
            icon: assigning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kCobalt,
                    ),
                  )
                : const Icon(Icons.group_add_outlined, size: 20),
            color: context.artC.ink.withValues(alpha: 0.58),
            onPressed: assigning ? null : onAssign,
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: context.artC.ink.withValues(alpha: 0.58),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _WorkbenchMessageBubble extends StatelessWidget {
  final String role;
  final String? senderName;
  final String body;
  final String? time;

  const _WorkbenchMessageBubble({
    required this.role,
    this.senderName,
    required this.body,
    this.time,
  });

  bool get _isHandler =>
      role == 'advisor' || role == 'institution' || role == 'system';

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _isHandler ? context.artC.deepPanel : context.artC.cardIconBg,
        borderRadius: BorderRadius.circular(17).copyWith(
          bottomRight: _isHandler ? const Radius.circular(4) : null,
          bottomLeft: !_isHandler ? const Radius.circular(4) : null,
        ),
        border: _isHandler
            ? null
            : Border.all(color: context.artC.silver.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment:
            _isHandler ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (_isHandler && _notBlank(senderName)) ...[
            Text(
              senderName!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 5),
          ],
          Text(
            body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.48,
              fontWeight: FontWeight.w700,
              color: _isHandler
                  ? Colors.white
                  : context.artC.ink.withValues(alpha: 0.86),
            ),
          ),
          if (time != null) ...[
            const SizedBox(height: 5),
            Text(
              time!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _isHandler
                    ? Colors.white.withValues(alpha: 0.62)
                    : context.artC.ink.withValues(alpha: 0.36),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            _isHandler ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [bubble],
      ),
    );
  }
}

class _AssignmentSheet extends StatelessWidget {
  final List<Map<String, dynamic>> members;

  const _AssignmentSheet({required this.members});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.76,
      ),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.artC.silver.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.group_add_outlined, color: kCobalt),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '分配老师',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                itemBuilder: (context, index) {
                  final member = members[index];
                  final name = _memberDisplayName(member);
                  final role = _memberRoleLabel(member['role']?.toString());
                  final organization = member['organization'];
                  final orgName = organization is Map
                      ? organization['name']?.toString()
                      : null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: kCobalt.withValues(alpha: 0.1),
                      child: Text(
                        name.isEmpty ? '?' : name.substring(0, 1),
                        style: const TextStyle(
                          color: kCobalt,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                      ),
                    ),
                    subtitle: Text(
                      [role, if (_notBlank(orgName)) orgName].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.artC.ink.withValues(alpha: 0.48),
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: context.artC.ink.withValues(alpha: 0.28),
                    ),
                    onTap: () => Navigator.of(context).pop(member),
                  );
                },
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: context.artC.silver.withValues(alpha: 0.22),
                ),
                itemCount: members.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollaboratorsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final Set<String> selectedMemberIds;
  final String? primaryMemberId;

  const _CollaboratorsSheet({
    required this.members,
    required this.selectedMemberIds,
    required this.primaryMemberId,
  });

  @override
  State<_CollaboratorsSheet> createState() => _CollaboratorsSheetState();
}

class _CollaboratorsSheetState extends State<_CollaboratorsSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedMemberIds};
    final primary = widget.primaryMemberId;
    if (primary != null && primary.isNotEmpty) _selected.remove(primary);
  }

  void _toggle(String memberId, bool disabled) {
    if (disabled) return;
    setState(() {
      if (_selected.contains(memberId)) {
        _selected.remove(memberId);
      } else {
        _selected.add(memberId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.artC.silver.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kCobalt.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.groups_2_outlined, color: kCobalt),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '协作老师',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '已选择 ${_selected.length} 位',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.artC.ink.withValues(alpha: 0.46),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                itemBuilder: (context, index) {
                  final member = widget.members[index];
                  final memberId = member['id']?.toString() ?? '';
                  final selected = _selected.contains(memberId);
                  final primary = memberId == widget.primaryMemberId;
                  final name = _memberDisplayName(member);
                  final role = _memberRoleLabel(member['role']?.toString());
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: memberId.isNotEmpty && !primary,
                    leading: Checkbox(
                      value: primary ? true : selected,
                      onChanged: memberId.isEmpty || primary
                          ? null
                          : (_) => _toggle(memberId, false),
                      activeColor: kCobalt,
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: primary
                            ? context.artC.ink.withValues(alpha: 0.42)
                            : context.artC.ink,
                      ),
                    ),
                    subtitle: Text(
                      primary ? '$role · 主责老师' : role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.artC.ink.withValues(alpha: 0.48),
                      ),
                    ),
                    onTap: () => _toggle(memberId, primary || memberId.isEmpty),
                  );
                },
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: context.artC.silver.withValues(alpha: 0.22),
                ),
                itemCount: widget.members.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kCobalt),
                  onPressed: () => Navigator.of(context).pop(
                    _selected.toList(growable: false),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('保存协作'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderQuote {
  final int amountTotal;
  final String subject;

  const _OrderQuote({
    required this.amountTotal,
    required this.subject,
  });
}

class _OrderQuoteSheet extends StatefulWidget {
  final String defaultSubject;

  const _OrderQuoteSheet({required this.defaultSubject});

  @override
  State<_OrderQuoteSheet> createState() => _OrderQuoteSheetState();
}

class _OrderQuoteSheetState extends State<_OrderQuoteSheet> {
  late final TextEditingController _subject;
  final _amount = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(text: widget.defaultSubject);
  }

  @override
  void dispose() {
    _subject.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final subject = _subject.text.trim();
    final amountText = _amount.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountText);
    if (subject.isEmpty) {
      setState(() => _error = '请填写订单标题');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = '请填写有效报价金额');
      return;
    }
    Navigator.of(context).pop(
      _OrderQuote(
        amountTotal: (amount * 100).round(),
        subject: subject,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: kCobalt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '创建订单',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subject,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '订单标题',
                  filled: true,
                  fillColor: context.artC.porcelain,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '报价金额（元）',
                  prefixText: '¥ ',
                  filled: true,
                  fillColor: context.artC.porcelain,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submit(),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kCobalt),
                  onPressed: _submit,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('创建待支付订单'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchReplyBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  const _WorkbenchReplyBar({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        border: Border(
          top: BorderSide(color: context.artC.silver.withValues(alpha: 0.36)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled && !sending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: enabled ? '回复学生...' : '咨询已结束',
                    filled: true,
                    fillColor: context.artC.porcelain,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton.filled(
                  tooltip: '发送',
                  style: IconButton.styleFrom(backgroundColor: kCobalt),
                  onPressed: enabled && !sending ? onSend : null,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _WorkbenchErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: context.artC.ink.withValues(alpha: 0.38),
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: context.artC.ink.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kCobalt),
              onPressed: onRetry,
              child: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchStatusChip extends StatelessWidget {
  final String label;

  const _WorkbenchStatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: kCobalt.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: kCobalt,
        ),
      ),
    );
  }
}

class _ConsultationPhase {
  final int index;
  final String currentLabel;
  final String nextHint;

  const _ConsultationPhase({
    required this.index,
    required this.currentLabel,
    required this.nextHint,
  });
}

class _PipelineAction {
  final String label;
  final VoidCallback onTap;

  const _PipelineAction(this.label, this.onTap);
}

class _DossierFact {
  final String label;
  final String value;

  const _DossierFact(this.label, this.value);
}

_ConsultationPhase _consultationPhase(
  Map<String, dynamic> consultation, {
  required Map<String, dynamic>? assessment,
  required Map<String, dynamic>? recommendation,
}) {
  final status = consultation['status']?.toString() ?? 'new';
  final conversion = _conversionType(consultation);
  if (status == 'closed') {
    return const _ConsultationPhase(
      index: 5,
      currentLabel: '已流失',
      nextHint: '这条咨询已关闭，可保留记录用于复盘来源与流失原因。',
    );
  }
  if (status == 'converted') {
    return _ConsultationPhase(
      index: conversion == 'order' ? 4 : 5,
      currentLabel: conversion == 'order' ? '已报价' : '已转预约',
      nextHint: conversion == 'order'
          ? '订单已创建，下一步关注学生支付与服务启动。'
          : '预约已创建，下一步确认时间并准备短咨询。',
    );
  }
  if (recommendation != null) {
    return const _ConsultationPhase(
      index: 3,
      currentLabel: '方案制定',
      nextHint: '方案已形成，可以根据服务范围创建报价或继续补充院校组合。',
    );
  }
  if (assessment != null || status == 'active') {
    return const _ConsultationPhase(
      index: 2,
      currentLabel: '需求确认',
      nextHint: '先沉淀学生背景、目标、风险点，再输出申请方案。',
    );
  }
  if (status == 'pending') {
    return const _ConsultationPhase(
      index: 1,
      currentLabel: '已联系',
      nextHint: '已经进入跟进状态，建议尽快回复学生并确认申请目标。',
    );
  }
  return const _ConsultationPhase(
    index: 0,
    currentLabel: '新线索',
    nextHint: '先分配负责顾问或立即回复，避免新咨询停留太久。',
  );
}

List<_PipelineAction> _pipelineActions(
  _ConsultationPhase phase, {
  required VoidCallback onReply,
  required VoidCallback onAssign,
  required VoidCallback onEditAssessment,
  required VoidCallback onEditRecommendation,
  required VoidCallback onConvertOrder,
  required VoidCallback onClose,
}) {
  return switch (phase.index) {
    0 => [
        _PipelineAction('立即回复', onReply),
        _PipelineAction('分配顾问', onAssign),
        _PipelineAction('关闭', onClose),
      ],
    1 => [
        _PipelineAction('回复学生', onReply),
        _PipelineAction('填写背景', onEditAssessment),
        _PipelineAction('关闭', onClose),
      ],
    2 => [
        _PipelineAction('填写背景', onEditAssessment),
        _PipelineAction('做方案', onEditRecommendation),
        _PipelineAction('回复学生', onReply),
      ],
    3 => [
        _PipelineAction('更新方案', onEditRecommendation),
        _PipelineAction('创建报价', onConvertOrder),
        _PipelineAction('回复学生', onReply),
      ],
    4 => const [],
    _ => const [],
  };
}

String? _conversionType(Map<String, dynamic> consultation) {
  final metadata = consultation['metadata'];
  if (metadata is! Map) return null;
  final conversion = metadata['conversion'];
  if (conversion is! Map) return null;
  return conversion['type']?.toString();
}

String _studentDisplayName(Map<String, dynamic> consultation) {
  final metadata = _mapValue(consultation['metadata']);
  final profile = _mapValue(consultation['profile']);
  final value = _firstCleanText(
    metadata['student_name'],
    metadata['student_nickname'],
    metadata['nickname'],
    metadata['display_name'],
    profile['nickname'],
    profile['display_name'],
    consultation['student_name'],
    consultation['target_name'],
  );
  return value.isEmpty ? '未命名咨询' : value;
}

String _budgetLabel(Map<String, dynamic> metadata) {
  final direct = _firstCleanText(
    metadata['budget'],
    metadata['budget_label'],
    metadata['target_budget'],
  );
  if (direct.isNotEmpty) return direct;
  final min = _cleanText(metadata['budget_min']);
  final max = _cleanText(metadata['budget_max']);
  if (min.isEmpty && max.isEmpty) return '';
  if (min.isNotEmpty && max.isNotEmpty) return '$min-$max';
  if (min.isNotEmpty) return '$min 起';
  return '$max 内';
}

String _sourceLabel(String? source) {
  switch (source) {
    case 'school_detail':
      return '院校页';
    case 'organization':
    case 'organization_detail':
      return '机构主页';
    case 'plaza':
      return '广场';
    case 'ai':
      return 'AI 咨询';
    default:
      return source == null || source.trim().isEmpty ? '' : source;
  }
}

String _cleanText(dynamic value) {
  return value?.toString().trim() ?? '';
}

String _firstCleanText(
  dynamic first, [
  dynamic second,
  dynamic third,
  dynamic fourth,
  dynamic fifth,
  dynamic sixth,
  dynamic seventh,
  dynamic eighth,
]) {
  for (final value in [
    first,
    second,
    third,
    fourth,
    fifth,
    sixth,
    seventh,
    eighth,
  ]) {
    final text = _cleanText(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

BoxDecoration _detailPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: context.artC.cardIconBg,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: context.artC.silver.withValues(alpha: 0.28),
    ),
  );
}

String _memberDisplayName(Map<String, dynamic> member) {
  final direct = member['display_name']?.toString().trim();
  if (direct != null && direct.isNotEmpty) return direct;
  final profile = member['profile'];
  if (profile is Map) {
    final nickname = profile['nickname']?.toString().trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
  }
  final metadata = member['metadata'];
  if (metadata is Map) {
    final name = metadata['display_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
  }
  return '机构成员';
}

String? _assignmentLabel(Map<String, dynamic> consultation) {
  final metadata = consultation['metadata'];
  if (metadata is Map) {
    final assignment = metadata['internal_assignment'];
    if (assignment is Map) {
      final name = assignment['member_name']?.toString().trim();
      if (name != null && name.isNotEmpty) return '负责 $name';
    }
  }
  final userId = consultation['primary_advisor_id']?.toString();
  if (userId != null && userId.isNotEmpty) return '已分配老师';
  return null;
}

Set<String> _collaboratorMemberIds(Map<String, dynamic> consultation) {
  final collaborators = consultation['collaborator_ids'];
  if (collaborators is! List) return const {};
  return collaborators
      .map((item) {
        if (item is Map) return item['member_id']?.toString();
        return null;
      })
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
}

List<String> _collaboratorNames(Map<String, dynamic> consultation) {
  final collaborators = consultation['collaborator_ids'];
  if (collaborators is! List) return const [];
  return collaborators
      .map((item) {
        if (item is Map) {
          return (item['name'] ?? item['member_name'] ?? item['user_id'])
              ?.toString();
        }
        return item?.toString();
      })
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _memberRoleLabel(String? role) {
  switch (role) {
    case 'owner':
      return '所有者';
    case 'admin':
      return '管理员';
    case 'advisor':
      return '顾问老师';
    case 'member':
      return '成员';
    default:
      return role == null || role.isEmpty ? '成员' : role;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'new':
      return '新咨询';
    case 'pending':
      return '待回复';
    case 'active':
      return '沟通中';
    case 'closed':
      return '已关闭';
    case 'converted':
      return '已转化';
    default:
      return status;
  }
}

String? _topicLabel(String? topic) {
  switch (topic) {
    case 'portfolio':
      return '作品集';
    case 'major':
      return '专业选择';
    case 'timeline':
      return '申请时间线';
    case 'budget':
      return '费用预算';
    case 'language':
      return '语言要求';
    default:
      return topic == null || topic.isEmpty ? null : topic;
  }
}

String _matchLevelLabel(String? level) {
  switch (level) {
    case 'strong':
      return '强';
    case 'weak':
      return '弱';
    case 'moderate':
      return '中';
    default:
      return '未定';
  }
}

String _riskLevelLabel(String? level) {
  switch (level) {
    case 'low':
      return '低';
    case 'high':
      return '高';
    case 'medium':
      return '中';
    default:
      return '未定';
  }
}

bool _notBlank(String? value) => value != null && value.trim().isNotEmpty;

List<String> _jsonItemLabels(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is Map) {
          return (item['name'] ?? item['title'] ?? item['label'])?.toString();
        }
        return item?.toString();
      })
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> _lineItems(String text) {
  return text
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .map((item) => {'name': item})
      .toList();
}

String? _formatTime(dynamic raw) {
  final value = raw?.toString();
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
