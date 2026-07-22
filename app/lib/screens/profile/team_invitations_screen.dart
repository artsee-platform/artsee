import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

class TeamInvitationsScreen extends StatefulWidget {
  const TeamInvitationsScreen({super.key});

  @override
  State<TeamInvitationsScreen> createState() => _TeamInvitationsScreenState();
}

class _TeamInvitationsScreenState extends State<TeamInvitationsScreen> {
  List<Map<String, dynamic>> _invitations = [];
  bool _loading = true;
  String? _error;
  String? _respondingId;

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
      final result = await BackendApiService.fetchWorkbenchTeamInvitations();
      if (!mounted) return;
      setState(() {
        _invitations = result.data;
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

  Future<void> _respond(Map<String, dynamic> invitation, String action) async {
    final id = _text(invitation['id']);
    if (id.isEmpty || _respondingId != null) return;
    setState(() => _respondingId = id);
    try {
      await BackendApiService.respondWorkbenchTeamInvitation(
        memberId: id,
        action: action,
      );
      if (!mounted) return;
      setState(() {
        _invitations.removeWhere((item) => _text(item['id']) == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'accept' ? '已加入机构团队' : '已拒绝邀请')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理邀请失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _respondingId = null);
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
          '团队邀请',
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
            _InvitationHeader(count: _invitations.length),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 88),
                child: Center(child: CircularProgressIndicator(color: kCobalt)),
              )
            else if (_error != null)
              _InvitationEmptyState(
                title: '邀请加载失败',
                body: _error!,
                actionLabel: '重试',
                onAction: _load,
              )
            else if (_invitations.isEmpty)
              const _InvitationEmptyState(
                title: '暂无待处理邀请',
                body: '机构团队邀请会显示在这里。接受后，你会获得该机构的工作台访问权限。',
              )
            else
              ..._invitations.map(
                (invitation) => _InvitationCard(
                  invitation: invitation,
                  responding: _respondingId == _text(invitation['id']),
                  onAccept: () => _respond(invitation, 'accept'),
                  onDecline: () => _respond(invitation, 'decline'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InvitationHeader extends StatelessWidget {
  final int count;

  const _InvitationHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _invitationPanelDecoration(context),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.group_add_outlined, color: kCobalt),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '机构团队邀请',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  count == 0 ? '没有等待处理的邀请' : '$count 个邀请等待确认',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.artC.ink.withValues(alpha: 0.48),
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

class _InvitationCard extends StatelessWidget {
  final Map<String, dynamic> invitation;
  final bool responding;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationCard({
    required this.invitation,
    required this.responding,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final organization = _map(invitation['organization']);
    final inviter = _map(invitation['inviter']);
    final orgName = _text(organization['name'], fallback: '未命名机构');
    final orgType = _organizationTypeLabel(_text(organization['type']));
    final role = _roleLabel(_text(invitation['role']));
    final inviterName = _text(inviter['nickname'], fallback: '机构管理员');
    final createdAt = _shortDate(_text(invitation['created_at']));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _invitationPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: kCobalt.withValues(alpha: 0.1),
                child: Text(
                  orgName.isEmpty ? '机' : orgName.characters.first,
                  style: const TextStyle(
                    color: kCobalt,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orgName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$orgType · 邀请你成为$role',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.artC.ink.withValues(alpha: 0.46),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$inviterName 发出邀请${createdAt == null ? '' : ' · $createdAt'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: responding ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.artC.ink.withValues(alpha: 0.72),
                    side: BorderSide(
                      color: context.artC.silver.withValues(alpha: 0.34),
                    ),
                  ),
                  child: const Text('拒绝'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: responding ? null : onAccept,
                  style: FilledButton.styleFrom(backgroundColor: kCobalt),
                  icon: responding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(responding ? '处理中' : '接受'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvitationEmptyState extends StatelessWidget {
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InvitationEmptyState({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _invitationPanelDecoration(context),
      child: Column(
        children: [
          const Icon(Icons.group_add_outlined, color: kCobalt, size: 32),
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

BoxDecoration _invitationPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: context.artC.cardIconBg,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: context.artC.silver.withValues(alpha: 0.22)),
    boxShadow: [
      BoxShadow(
        color: context.artC.ink.withValues(alpha: 0.026),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _roleLabel(String role) {
  switch (role) {
    case 'admin':
      return '管理员';
    case 'advisor':
      return '顾问';
    case 'member':
    default:
      return '成员';
  }
}

String _organizationTypeLabel(String type) {
  switch (type) {
    case 'official_association':
      return '官方协会';
    case 'school_official':
      return '院校官方';
    case 'official_partner':
      return '官方合作组织';
    case 'study_abroad_agency':
      return '留学服务（已下线）';
    case 'portfolio_training':
      return '作品集服务（已下线）';
    case 'gallery_exhibition':
      return '画廊展览';
    case 'event_organizer':
      return '活动主办';
    default:
      return type.isEmpty ? '机构' : type;
  }
}

String? _shortDate(String value) {
  if (value.length < 10) return null;
  return value.substring(0, 10);
}
