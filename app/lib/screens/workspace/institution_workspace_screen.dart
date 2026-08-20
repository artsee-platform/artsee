import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import '../consultation/organization_list_screen.dart';
import '../home/home_screen.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';
import 'workbench_consultation_detail_screen.dart';
import 'workbench_team_screen.dart';

enum _InstitutionWorkbenchSection {
  overview,
  leads,
  bookings,
  orders,
  management,
}

class InstitutionWorkspaceScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const InstitutionWorkspaceScreen({
    super.key,
    this.profile,
  });

  @override
  State<InstitutionWorkspaceScreen> createState() =>
      _InstitutionWorkspaceScreenState();
}

class _InstitutionWorkspaceScreenState
    extends State<InstitutionWorkspaceScreen> {
  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _serviceBookings = [];
  List<Map<String, dynamic>> _organizations = [];
  bool _loading = true;
  bool _bookingLoading = true;
  bool _orgLoading = true;
  String? _error;
  String? _bookingError;
  String? _orgError;
  int _selectedWorkspaceTab = 0;
  _InstitutionWorkbenchSection _selectedWorkbenchSection =
      _InstitutionWorkbenchSection.overview;
  String? _actingLeadId;

  @override
  void initState() {
    super.initState();
    _loadLeads();
    _loadServiceBookings();
    _loadOrganizations();
  }

  @override
  void didUpdateWidget(covariant InstitutionWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?['id'] != widget.profile?['id']) {
      _loadLeads();
      _loadServiceBookings();
      _loadOrganizations();
    }
  }

  Future<void> _loadLeads() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.fetchWorkbenchConsultations();
      if (!mounted) return;
      setState(() {
        _leads = result.data;
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

  Future<void> _loadOrganizations() async {
    setState(() {
      _orgLoading = true;
      _orgError = null;
    });
    try {
      final result = await BackendApiService.fetchMyOrganizations();
      if (!mounted) return;
      setState(() {
        _organizations = result.data;
        _orgLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orgError = e.toString();
        _orgLoading = false;
      });
    }
  }

  Future<void> _loadServiceBookings() async {
    setState(() {
      _bookingLoading = true;
      _bookingError = null;
    });
    try {
      final result = await BackendApiService.fetchWorkbenchServiceBookings();
      if (!mounted) return;
      setState(() {
        _serviceBookings = result.data;
        _bookingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bookingError = e.toString();
        _bookingLoading = false;
      });
    }
  }

  int _countStatus(String status) {
    return _leads.where((lead) => lead['status']?.toString() == status).length;
  }

  int get _leadUnreadCount {
    return _leads.fold<int>(
      0,
      (sum, lead) => sum + _intValue(lead['unread_count']),
    );
  }

  int get _requestedBookingCount {
    return _serviceBookings
        .where((booking) => booking['status']?.toString() == 'requested')
        .length;
  }

  int get _unassignedLeadCount {
    return _leads
        .where((lead) =>
            lead['status']?.toString() != 'closed' &&
            lead['status']?.toString() != 'converted' &&
            _leadAssignmentKey(lead) == 'unassigned')
        .length;
  }

  int get _activePlanningCount {
    return _leads
        .where(
          (lead) =>
              lead['status']?.toString() == 'active' &&
              _conversionType(lead) == null,
        )
        .length;
  }

  int get _quotedOrderCount {
    return _leads.where((lead) => _conversionType(lead) == 'order').length;
  }

  _OrganizationMembership? get _primaryOrganization {
    return _firstOrganization(_organizations);
  }

  Future<void> _openLead(Map<String, dynamic> lead) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkbenchConsultationDetailScreen(
          consultation: lead,
        ),
      ),
    );
    if (mounted) {
      _loadLeads();
      _loadServiceBookings();
    }
  }

  Future<void> _assignLead(Map<String, dynamic> lead) async {
    final id = lead['id']?.toString();
    if (id == null || id.isEmpty || _actingLeadId != null) return;
    setState(() => _actingLeadId = id);
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
        builder: (_) => _BulkAssignmentSheet(members: team.data),
      );
      if (!mounted || member == null) return;
      await BackendApiService.assignWorkbenchConsultation(
        id: id,
        memberId: member['id']?.toString(),
        memberUserId: member['user_id']?.toString(),
      );
      if (!mounted) return;
      await _loadLeads();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已分配给 ${_workbenchMemberName(member)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分配失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _actingLeadId = null);
    }
  }

  Future<void> _closeLead(Map<String, dynamic> lead) async {
    final id = lead['id']?.toString();
    if (id == null || id.isEmpty || _actingLeadId != null) return;
    final targetName = lead['target_name']?.toString() ?? '这条咨询';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关闭咨询'),
        content: Text('确认将「$targetName」标记为已关闭？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actingLeadId = id);
    try {
      await BackendApiService.updateWorkbenchConsultation(
        id: id,
        status: 'closed',
      );
      if (!mounted) return;
      await _loadLeads();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已关闭咨询')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('关闭失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _actingLeadId = null);
    }
  }

  Future<void> _openOrganizationProfile() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrganizationProfileSheet(
        organizations: _organizations,
        loading: _orgLoading,
        error: _orgError,
        onRetry: _loadOrganizations,
        onCreated: _loadOrganizations,
      ),
    );
  }

  Future<void> _openPublicOrganizationPreview() async {
    final organization = _primaryOrganization;
    if (organization == null) {
      await _openOrganizationProfile();
      return;
    }
    final initialOrg = _organizationPreviewPayload(organization.organization);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrganizationDetailScreen(initialOrg: initialOrg),
      ),
    );
    if (mounted) {
      _loadOrganizations();
    }
  }

  Future<void> _openTeamManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WorkbenchTeamScreen(
          leads: _leads,
          serviceBookings: _serviceBookings,
        ),
      ),
    );
    if (mounted) {
      _loadLeads();
      _loadServiceBookings();
    }
  }

  Future<void> _openLeadList(_WorkbenchListMode mode) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _WorkbenchListSheet(
        mode: mode,
        leads: _leads,
        serviceBookings: _serviceBookings,
        loading: _loading,
        bookingLoading: _bookingLoading,
        error: _error,
        bookingError: _bookingError,
        onRetry: _loadLeads,
        onBookingRetry: _loadServiceBookings,
        onOpen: (lead) {
          Navigator.of(sheetContext).pop();
          _openLead(lead);
        },
      ),
    );
  }

  void _handleServiceBookingUpdated(Map<String, dynamic> booking) {
    final id = booking['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      final index =
          _serviceBookings.indexWhere((item) => item['id']?.toString() == id);
      if (index < 0) {
        _serviceBookings.insert(0, booking);
      } else {
        _serviceBookings[index] = booking;
      }
    });
  }

  Future<void> _openServiceBooking(Map<String, dynamic> booking) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServiceBookingDetailSheet(
        booking: booking,
        onChanged: _handleServiceBookingUpdated,
        onOpenConsultation: _openLead,
      ),
    );
  }

  String _conversionSubtitle(String type, String fallback) {
    if (type == 'service_booking') {
      if (_bookingLoading) return '同步预约记录';
      if (_serviceBookings.isEmpty) return '暂无$fallback记录';
      return '${_serviceBookings.length} 条$fallback记录';
    }
    final count = _leads.where((lead) => _conversionType(lead) == type).length;
    return count == 0 ? '暂无$fallback记录' : '$count 条$fallback记录';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InstitutionWorkspaceTabs(
          selectedIndex: _selectedWorkspaceTab,
          onChanged: (index) => setState(() => _selectedWorkspaceTab = index),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedWorkspaceTab,
            children: [
              _buildWorkbenchView(context),
              HomeScreen(
                compactTopChrome: true,
                institutionLeadMode: true,
                onReturnToMain: () => setState(() => _selectedWorkspaceTab = 0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkbenchView(BuildContext context) {
    final verified = widget.profile?['is_verified'] == true;
    final primaryOrganization = _primaryOrganization;
    final completeness = primaryOrganization == null
        ? null
        : _organizationCompleteness(primaryOrganization.organization);
    final analytics = _WorkbenchAnalyticsSnapshot.from(
      leads: _leads,
      serviceBookings: _serviceBookings,
    );
    final leadTodoItems = [
      _WorkbenchTodoItem(
        label: '新线索',
        count: _countStatus('new'),
        caption: '刚分配',
        onTap: () => _openLeadList(_WorkbenchListMode.leads),
      ),
      _WorkbenchTodoItem(
        label: '待分配',
        count: _unassignedLeadCount,
        caption: '需要指定顾问',
        onTap: _openTeamManagement,
      ),
      _WorkbenchTodoItem(
        label: '待回复',
        count: _countStatus('pending'),
        caption: '等待组织响应',
        onTap: () => _openLeadList(_WorkbenchListMode.leads),
      ),
      _WorkbenchTodoItem(
        label: '待出方案',
        count: _activePlanningCount,
        caption: '需求确认后',
        onTap: () => _openLeadList(_WorkbenchListMode.leads),
      ),
    ];
    final bookingTodoItems = [
      _WorkbenchTodoItem(
        label: '待确认预约',
        count: _requestedBookingCount,
        caption: '短咨询',
        onTap: () => _openLeadList(_WorkbenchListMode.bookings),
      ),
    ];
    final orderTodoItems = [
      _WorkbenchTodoItem(
        label: '待支付订单',
        count: _quotedOrderCount,
        caption: '已报价',
        onTap: () => _openLeadList(_WorkbenchListMode.orders),
      ),
    ];
    final todoItems = [
      ...leadTodoItems,
      ...bookingTodoItems,
      ...orderTodoItems,
    ];
    final orderLeads =
        _leads.where((lead) => _conversionType(lead) == 'order').toList();
    final managementBadge = primaryOrganization == null
        ? 1
        : completeness == null || completeness.complete
            ? 0
            : completeness.missingLabels.length;
    final leadBadge =
        _leadUnreadCount > 0 ? _leadUnreadCount : _countStatus('new');
    final totalTodoCount =
        todoItems.fold<int>(0, (sum, item) => sum + item.count);
    final allActions = _buildWorkbenchActions();
    final leadActions = [
      allActions[1],
      allActions[6],
      allActions[5],
    ];
    final bookingActions = [
      allActions[4],
      allActions[6],
      allActions[5],
    ];
    final orderActions = [
      allActions[2],
      allActions[1],
      allActions[6],
    ];
    final managementActions = [
      allActions[0],
      allActions[3],
      allActions[5],
    ];
    final sectionItems = [
      _WorkbenchSectionItem(
        section: _InstitutionWorkbenchSection.overview,
        label: '总览',
        badgeCount: totalTodoCount,
      ),
      _WorkbenchSectionItem(
        section: _InstitutionWorkbenchSection.leads,
        label: '线索',
        badgeCount: leadBadge,
      ),
      _WorkbenchSectionItem(
        section: _InstitutionWorkbenchSection.bookings,
        label: '预约',
        badgeCount: _requestedBookingCount,
      ),
      _WorkbenchSectionItem(
        section: _InstitutionWorkbenchSection.orders,
        label: '订单',
        badgeCount: _quotedOrderCount,
      ),
      _WorkbenchSectionItem(
        section: _InstitutionWorkbenchSection.management,
        label: '管理',
        badgeCount: managementBadge,
      ),
    ];

    List<Widget> sectionSlivers() {
      switch (_selectedWorkbenchSection) {
        case _InstitutionWorkbenchSection.overview:
          return [
            _workbenchBlock(
              _WorkspaceIdentityPanel(
                profile: widget.profile,
                organization: primaryOrganization,
                organizationCount: _organizations.length,
                loading: _orgLoading,
                error: _orgError,
                onManage: _openOrganizationProfile,
                onPreview: _openPublicOrganizationPreview,
                onRetry: _loadOrganizations,
              ),
              top: 8,
            ),
            _workbenchBlock(
              _WorkbenchTodayPanel(
                items: todoItems,
                loading: _loading || _bookingLoading,
                onEmptyAction: _openOrganizationProfile,
              ),
            ),
            _workbenchBlock(
              _WorkbenchAnalyticsPanel(
                snapshot: analytics,
                loading: _loading || _bookingLoading,
                onOpenLeads: () => _openLeadList(_WorkbenchListMode.leads),
                onOpenBookings: () =>
                    _openLeadList(_WorkbenchListMode.bookings),
              ),
              top: 14,
            ),
            _workbenchBlock(
              _LeadInboxPreview(
                verified: verified,
                leads: _leads,
                loading: _loading,
                error: _error,
                onRetry: _loadLeads,
                onViewAll: () => _openLeadList(_WorkbenchListMode.leads),
                onOpen: _openLead,
                onAssign: _assignLead,
                onPlan: _openLead,
                onClose: _closeLead,
                actingLeadId: _actingLeadId,
              ),
            ),
            _workbenchBlock(
              _WorkspaceActionGrid(items: allActions),
              top: 14,
            ),
          ];
        case _InstitutionWorkbenchSection.leads:
          return [
            _workbenchBlock(
              _WorkbenchTodayPanel(
                items: leadTodoItems,
                loading: _loading,
                onEmptyAction: () => _openLeadList(_WorkbenchListMode.leads),
              ),
              top: 14,
            ),
            _workbenchBlock(
              _LeadInboxPreview(
                title: '线索队列',
                subtitle: '分配、回复与方案推进',
                emptyText:
                    verified ? '暂无咨询线索。学生发起咨询后会进入这里。' : '完成机构认证后，平台线索会进入这里。',
                emptyActionLabel: verified ? '刷新线索 →' : '完善机构主页 →',
                onEmptyAction: verified ? _loadLeads : _openOrganizationProfile,
                verified: verified,
                leads: _leads,
                loading: _loading,
                error: _error,
                onRetry: _loadLeads,
                onViewAll: () => _openLeadList(_WorkbenchListMode.leads),
                onOpen: _openLead,
                onAssign: _assignLead,
                onPlan: _openLead,
                onClose: _closeLead,
                actingLeadId: _actingLeadId,
              ),
            ),
            _workbenchBlock(
              _WorkspaceActionGrid(
                title: '线索操作',
                subtitle: '计划 · 分配 · 协作',
                items: leadActions,
              ),
              top: 14,
            ),
          ];
        case _InstitutionWorkbenchSection.bookings:
          return [
            _workbenchBlock(
              _WorkbenchTodayPanel(
                items: bookingTodoItems,
                loading: _bookingLoading,
                onEmptyAction: () => _openLeadList(_WorkbenchListMode.bookings),
              ),
              top: 14,
            ),
            _workbenchBlock(
              _ServiceBookingPreview(
                bookings: _serviceBookings,
                loading: _bookingLoading,
                error: _bookingError,
                onRetry: _loadServiceBookings,
                onViewAll: () => _openLeadList(_WorkbenchListMode.bookings),
                onEmptyAction: () => _openLeadList(_WorkbenchListMode.leads),
                onOpen: _openServiceBooking,
              ),
            ),
            _workbenchBlock(
              _WorkspaceActionGrid(
                title: '预约操作',
                subtitle: '确认 · 排期 · 协作',
                items: bookingActions,
              ),
              top: 14,
            ),
          ];
        case _InstitutionWorkbenchSection.orders:
          return [
            _workbenchBlock(
              _WorkbenchTodayPanel(
                items: orderTodoItems,
                loading: _loading,
                onEmptyAction: () => _openLeadList(_WorkbenchListMode.orders),
              ),
              top: 14,
            ),
            _workbenchBlock(
              _LeadInboxPreview(
                title: '订单转化',
                subtitle: '已报价与转订单咨询',
                idleStatusLabel: '待成交',
                emptyText: '暂无转订单记录。顾问在咨询详情里点击“转订单”后会出现在这里。',
                emptyActionLabel: '查看咨询线索 →',
                onEmptyAction: () => _openLeadList(_WorkbenchListMode.leads),
                verified: verified,
                leads: orderLeads,
                loading: _loading,
                error: _error,
                onRetry: _loadLeads,
                onViewAll: () => _openLeadList(_WorkbenchListMode.orders),
                onOpen: _openLead,
                onAssign: _assignLead,
                onPlan: _openLead,
                onClose: _closeLead,
                actingLeadId: _actingLeadId,
              ),
            ),
            _workbenchBlock(
              _WorkspaceActionGrid(
                title: '成交操作',
                subtitle: '方案 · 报价 · 跟进',
                items: orderActions,
              ),
              top: 14,
            ),
          ];
        case _InstitutionWorkbenchSection.management:
          return [
            _workbenchBlock(
              _WorkspaceIdentityPanel(
                profile: widget.profile,
                organization: primaryOrganization,
                organizationCount: _organizations.length,
                loading: _orgLoading,
                error: _orgError,
                onManage: _openOrganizationProfile,
                onPreview: _openPublicOrganizationPreview,
                onRetry: _loadOrganizations,
              ),
              top: 8,
            ),
            _workbenchBlock(
              _WorkspaceActionGrid(
                title: '经营管理',
                subtitle: '资料 · 展示 · 团队',
                items: managementActions,
              ),
              top: 14,
            ),
          ];
      }
    }

    return ColoredBox(
      color: const Color(0xFFF7F8FA),
      child: Column(
        children: [
          _WorkbenchSectionStrip(
            items: sectionItems,
            selected: _selectedWorkbenchSection,
            onChanged: (section) =>
                setState(() => _selectedWorkbenchSection = section),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                ...sectionSlivers(),
                SliverToBoxAdapter(
                  child: SizedBox(height: mainTabBottomInset(context) + 96),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _workbenchBlock(Widget child, {double top = 12}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, top, 18, 0),
        child: _WorkbenchSurfaceCard(child: child),
      ),
    );
  }

  List<_WorkbenchAction> _buildWorkbenchActions() {
    return [
      _WorkbenchAction(
        icon: Icons.edit_note_rounded,
        title: '信息输入',
        subtitle: _organizationActionSubtitle(
          _organizations,
          _orgLoading,
        ),
        onTap: _openOrganizationProfile,
      ),
      _WorkbenchAction(
        icon: Icons.auto_awesome_outlined,
        title: '做计划',
        subtitle: _leads.isEmpty ? '基于用户画像生成申请节奏' : '${_leads.length} 个用户可跟进计划',
        badgeCount: _leadUnreadCount,
        onTap: () => _openLeadList(_WorkbenchListMode.leads),
      ),
      _WorkbenchAction(
        icon: Icons.map_outlined,
        title: '留学方案',
        subtitle: _conversionSubtitle('order', '方案/订单'),
        onTap: () => _openLeadList(_WorkbenchListMode.orders),
      ),
      _WorkbenchAction(
        icon: Icons.storefront_outlined,
        title: '机构显示',
        subtitle: _organizations.isEmpty ? '先创建公开机构页' : '预览并优化机构主页',
        onTap: _openPublicOrganizationPreview,
      ),
      _WorkbenchAction(
        icon: Icons.schedule_outlined,
        title: '免费咨询',
        subtitle: _conversionSubtitle('service_booking', '短咨询'),
        onTap: () => _openLeadList(_WorkbenchListMode.bookings),
      ),
      _WorkbenchAction(
        icon: Icons.groups_2_outlined,
        title: '团队协作',
        subtitle: '成员角色、邀请与工作量',
        onTap: _openTeamManagement,
      ),
      _WorkbenchAction(
        icon: Icons.support_agent_outlined,
        title: '线索管理',
        subtitle: _leadUnreadCount > 0
            ? '$_leadUnreadCount 条未读 · 可分配团队'
            : '咨询分配与协作记录',
        badgeCount: _leadUnreadCount,
        onTap: () => _openLeadList(_WorkbenchListMode.leads),
      ),
    ];
  }
}

class _InstitutionWorkspaceTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _InstitutionWorkspaceTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.artC.cardIconBg,
        border: Border(
          bottom: BorderSide(
            color: context.artC.silver.withValues(alpha: 0.28),
          ),
        ),
      ),
      child: SizedBox(
        height: 68,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InstitutionWorkspaceTab(
                label: '工作台',
                selected: selectedIndex == 0,
                onTap: () => onChanged(0),
              ),
              _InstitutionWorkspaceTab(
                label: '广场',
                selected: selectedIndex == 1,
                onTap: () => onChanged(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstitutionWorkspaceTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _InstitutionWorkspaceTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        selected ? context.artC.ink : context.artC.ink.withValues(alpha: 0.42);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: label.length > 2 ? 74 : 58,
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                height: 1.08,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: selected ? (label.length > 2 ? 38 : 30) : 0,
              height: 3.5,
              decoration: BoxDecoration(
                color: kCobalt,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchSurfaceCard extends StatelessWidget {
  final Widget child;

  const _WorkbenchSurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.artC.ink.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _WorkbenchSectionStrip extends StatelessWidget {
  final List<_WorkbenchSectionItem> items;
  final _InstitutionWorkbenchSection selected;
  final ValueChanged<_InstitutionWorkbenchSection> onChanged;

  const _WorkbenchSectionStrip({
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      color: const Color(0xFFF7F8FA),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _WorkbenchSectionChip(
                item: items[i],
                selected: selected == items[i].section,
                onTap: () => onChanged(items[i].section),
              ),
              if (i != items.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkbenchSectionChip extends StatelessWidget {
  final _WorkbenchSectionItem item;
  final bool selected;
  final VoidCallback onTap;

  const _WorkbenchSectionChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeCount = item.badgeCount;
    final badgeLabel = badgeCount > 99 ? '99+' : '$badgeCount';
    final foreground =
        selected ? Colors.white : context.artC.ink.withValues(alpha: 0.76);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          height: 38,
          padding: EdgeInsets.fromLTRB(16, 0, badgeCount > 0 ? 10 : 16, 0),
          decoration: BoxDecoration(
            color: selected ? kCobalt : const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 7),
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : kCobalt.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? Colors.white : kCobalt,
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchTodayPanel extends StatelessWidget {
  final List<_WorkbenchTodoItem> items;
  final bool loading;
  final VoidCallback onEmptyAction;

  const _WorkbenchTodayPanel({
    required this.items,
    required this.loading,
    required this.onEmptyAction,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, item) => sum + item.count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '今日待处理',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.artC.ink,
                ),
              ),
            ),
            _StatusPill(
              label: loading ? '同步中' : '$total 项',
              strong: total > 0,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!loading && total == 0)
          _WorkbenchQuietEmpty(
            text: '暂无待处理事项。可以先完善机构主页，让学生更愿意发起咨询。',
            actionLabel: '完善机构主页 →',
            onAction: onEmptyAction,
          )
        else
          Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _WorkbenchTodoRow(item: items[index]),
                if (index != items.length - 1)
                  Divider(
                    height: 1,
                    color: context.artC.silver.withValues(alpha: 0.2),
                  ),
              ],
            ],
          ),
      ],
    );
  }
}

class _WorkbenchTodoRow extends StatelessWidget {
  final _WorkbenchTodoItem item;

  const _WorkbenchTodoRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  '${item.count}',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: context.artC.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: context.artC.ink.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: context.artC.ink.withValues(alpha: 0.22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchAnalyticsPanel extends StatelessWidget {
  final _WorkbenchAnalyticsSnapshot snapshot;
  final bool loading;
  final VoidCallback onOpenLeads;
  final VoidCallback onOpenBookings;

  const _WorkbenchAnalyticsPanel({
    required this.snapshot,
    required this.loading,
    required this.onOpenLeads,
    required this.onOpenBookings,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _WorkbenchAnalyticsMetric(
        label: '本周新增',
        value: '${snapshot.weeklyNewLeads}',
        onTap: onOpenLeads,
      ),
      _WorkbenchAnalyticsMetric(
        label: '跟进率',
        value: snapshot.followUpRateLabel,
        onTap: onOpenLeads,
      ),
      _WorkbenchAnalyticsMetric(
        label: '待回复',
        value: '${snapshot.replyPressure}',
        onTap: onOpenLeads,
      ),
      _WorkbenchAnalyticsMetric(
        label: '预约转化',
        value: snapshot.bookingRateLabel,
        onTap: onOpenBookings,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '数据看板',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.artC.ink,
                ),
              ),
            ),
            _StatusPill(
              label: loading ? '同步中' : '近 7 天',
              strong: !loading && snapshot.weeklyNewLeads > 0,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '线索 · 回复 · 转化',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.artC.ink.withValues(alpha: 0.38),
          ),
        ),
        const SizedBox(height: 14),
        _WorkbenchAnalyticsGrid(metrics: metrics),
        if (snapshot.totalLeads > 0) ...[
          const SizedBox(height: 14),
          _WorkbenchAnalyticsFlow(snapshot: snapshot),
        ],
      ],
    );
  }
}

class _WorkbenchAnalyticsGrid extends StatelessWidget {
  final List<_WorkbenchAnalyticsMetric> metrics;

  const _WorkbenchAnalyticsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _WorkbenchAnalyticsGridCell(metric: metrics[0]),
            const SizedBox(width: 10),
            _WorkbenchAnalyticsGridCell(metric: metrics[1]),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _WorkbenchAnalyticsGridCell(metric: metrics[2]),
            const SizedBox(width: 10),
            _WorkbenchAnalyticsGridCell(metric: metrics[3]),
          ],
        ),
      ],
    );
  }
}

class _WorkbenchAnalyticsGridCell extends StatelessWidget {
  final _WorkbenchAnalyticsMetric metric;

  const _WorkbenchAnalyticsGridCell({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: _WorkbenchAnalyticsMetricTile(
          metric: metric,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        ),
      ),
    );
  }
}

class _WorkbenchAnalyticsMetricTile extends StatelessWidget {
  final _WorkbenchAnalyticsMetric metric;
  final EdgeInsets padding;

  const _WorkbenchAnalyticsMetricTile({
    required this.metric,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: metric.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: context.artC.ink,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  color: context.artC.ink.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchAnalyticsFlow extends StatelessWidget {
  final _WorkbenchAnalyticsSnapshot snapshot;

  const _WorkbenchAnalyticsFlow({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final segments = [
      (label: '新线索', value: snapshot.totalLeads),
      (label: '沟通中', value: snapshot.activeLeads),
      (label: '预约', value: snapshot.bookingCount),
      (label: '订单', value: snapshot.orderCount),
    ];
    final maxValue = segments
        .fold<int>(0, (max, item) => item.value > max ? item.value : max)
        .clamp(1, 999999);
    return Column(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  segments[i].label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: context.artC.ink.withValues(alpha: 0.42),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuietProgressLine(
                  value: segments[i].value / maxValue,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 28,
                child: Text(
                  '${segments[i].value}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink.withValues(alpha: 0.58),
                  ),
                ),
              ),
            ],
          ),
          if (i != segments.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _WorkbenchQuietEmpty extends StatelessWidget {
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _WorkbenchQuietEmpty({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: context.artC.ink.withValues(alpha: 0.06)),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: kCobalt,
              size: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.52),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: kCobalt,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: onAction,
            child: Text(
              actionLabel.replaceAll(' →', ''),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationCompletenessInline extends StatelessWidget {
  final _OrganizationCompleteness completeness;
  final bool hasOrganization;
  final bool verified;
  final bool subscribed;
  final VoidCallback onManage;

  const _OrganizationCompletenessInline({
    required this.completeness,
    required this.hasOrganization,
    required this.verified,
    required this.subscribed,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final stages = [
      (label: '建档', done: hasOrganization),
      (label: '认证', done: verified),
      (label: '入驻曝光', done: subscribed),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '主页完成度 ${completeness.completed}/${completeness.total}',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink,
                ),
              ),
            ),
            if (!completeness.complete)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: kCobalt,
                  backgroundColor: kCobalt.withValues(alpha: 0.08),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: onManage,
                child: const Text(
                  '补资料',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _QuietProgressLine(
          value: completeness.ratio,
          height: 6,
          foregroundColor: kCobalt,
          backgroundColor: const Color(0xFFE8ECF2),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < stages.length; index++) ...[
              Expanded(
                child: Text(
                  stages[index].label,
                  textAlign: index == 0
                      ? TextAlign.left
                      : index == stages.length - 1
                          ? TextAlign.right
                          : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight:
                        stages[index].done ? FontWeight.w900 : FontWeight.w700,
                    color: context.artC.ink
                        .withValues(alpha: stages[index].done ? 0.68 : 0.34),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (!completeness.complete) ...[
          const SizedBox(height: 8),
          Text(
            '待补：${completeness.missingLabels.take(3).join('、')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.44),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrganizationCompletenessCard extends StatelessWidget {
  final _OrganizationCompleteness completeness;
  final VoidCallback? onTap;

  const _OrganizationCompletenessCard({
    required this.completeness,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '公开主页完成度',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${(completeness.ratio * 100).round()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: context.artC.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _QuietProgressLine(value: completeness.ratio),
              const SizedBox(height: 9),
              if (completeness.complete)
                Text(
                  '核心信息已完整。后续可继续补充案例与视觉素材。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: context.artC.ink.withValues(alpha: 0.52),
                  ),
                )
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final label in completeness.missingLabels)
                      _MiniLeadTag(label: label),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietProgressLine extends StatelessWidget {
  final double value;
  final double height;
  final Color? foregroundColor;
  final Color? backgroundColor;

  const _QuietProgressLine({
    required this.value,
    this.height = 2,
    this.foregroundColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: backgroundColor ??
                    context.artC.silver.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Container(
              height: height,
              width: constraints.maxWidth * clamped,
              decoration: BoxDecoration(
                color:
                    foregroundColor ?? context.artC.ink.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WorkspaceIdentityPanel extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final _OrganizationMembership? organization;
  final int organizationCount;
  final bool loading;
  final String? error;
  final Future<void> Function() onManage;
  final Future<void> Function() onPreview;
  final Future<void> Function() onRetry;

  const _WorkspaceIdentityPanel({
    required this.profile,
    required this.organization,
    required this.organizationCount,
    required this.loading,
    required this.error,
    required this.onManage,
    required this.onPreview,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final org = organization?.organization;
    final name = _cleanText(org?['name']).isNotEmpty
        ? _cleanText(org?['name'])
        : '尚未创建机构档案';
    final role =
        organization == null ? '个人账号' : _memberRoleLabel(organization!.role);
    final verification = org?['verification_status']?.toString();
    final subscription = org?['subscription_status']?.toString() ?? 'inactive';
    final status = org?['status']?.toString();
    final profileName = _cleanText(profile?['nickname']).isNotEmpty
        ? _cleanText(profile?['nickname'])
        : '个人账号';
    final canPreview = organization != null;
    final completeness = org == null ? null : _organizationCompleteness(org);
    final visibleStatusTags = <Widget>[
      if (verification != 'verified')
        _MiniLeadTag(
          label: _verificationLabel(verification),
          strong: true,
        ),
      if (status != null && status != 'active')
        _MiniLeadTag(label: _organizationStatusLabel(status)),
      if (subscription != 'active')
        _MiniLeadTag(
          label: _subscriptionStatusLabel(subscription, null),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '机构工作台',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.artC.ink.withValues(alpha: 0.42),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.04,
                      fontWeight: FontWeight.w900,
                      color: context.artC.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: kCobalt,
                    strokeWidth: 1.8,
                  ),
                ),
              )
            else if (error != null)
              _QuietTextAction(label: '重试', onTap: onRetry)
            else
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _StatusPill(
                  label: organization == null ? '待创建' : role,
                  strong: organization != null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _IdentitySegmentStrip(
          personalLabel: profileName,
          organizationLabel: name,
          organizationCount: organizationCount,
        ),
        const SizedBox(height: 14),
        if (error != null)
          _LeadInlineError(error: error!, onRetry: onRetry)
        else ...[
          if (visibleStatusTags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visibleStatusTags,
            ),
            const SizedBox(height: 15),
          ],
          if (completeness != null) ...[
            _OrganizationCompletenessInline(
              completeness: completeness,
              hasOrganization: organization != null,
              verified: verification == 'verified',
              subscribed: subscription == 'active',
              onManage: onManage,
            ),
          ],
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _QuietTextAction(
              label: canPreview ? '管理资料 →' : '创建机构 →',
              onTap: onManage,
            ),
            if (canPreview) _QuietTextAction(label: '预览主页 →', onTap: onPreview),
          ],
        ),
      ],
    );
  }
}

class _IdentitySegmentStrip extends StatelessWidget {
  final String personalLabel;
  final String organizationLabel;
  final int organizationCount;

  const _IdentitySegmentStrip({
    required this.personalLabel,
    required this.organizationLabel,
    required this.organizationCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _IdentitySegment(
            label: personalLabel,
            subtitle: '个人',
            icon: Icons.person_outline_rounded,
            selected: false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '/',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: context.artC.ink.withValues(alpha: 0.24),
            ),
          ),
        ),
        Expanded(
          child: _IdentitySegment(
            label: organizationLabel,
            subtitle:
                organizationCount > 1 ? '机构 · $organizationCount 个' : '机构',
            icon: Icons.apartment_rounded,
            selected: true,
          ),
        ),
      ],
    );
  }
}

class _IdentitySegment extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;

  const _IdentitySegment({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: context.artC.ink.withValues(alpha: selected ? 0.72 : 0.34),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: context.artC.ink.withValues(alpha: 0.44),
              ),
              children: [
                TextSpan(
                  text: '$subtitle ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: context.artC.ink.withValues(
                      alpha: selected ? 0.78 : 0.42,
                    ),
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

class _LeadInboxPreview extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? idleStatusLabel;
  final String emptyText;
  final String emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final bool verified;
  final List<Map<String, dynamic>> leads;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onViewAll;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>> onAssign;
  final ValueChanged<Map<String, dynamic>> onPlan;
  final ValueChanged<Map<String, dynamic>> onClose;
  final String? actingLeadId;

  const _LeadInboxPreview({
    this.title = '咨询线索',
    this.subtitle = '最近分配与未读消息',
    this.idleStatusLabel,
    this.emptyText = '暂无可处理咨询线索。平台分配或学生发起咨询后会出现在这里。',
    this.emptyActionLabel = '查看全部 →',
    this.onEmptyAction,
    required this.verified,
    required this.leads,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onViewAll,
    required this.onOpen,
    required this.onAssign,
    required this.onPlan,
    required this.onClose,
    required this.actingLeadId,
  });

  @override
  Widget build(BuildContext context) {
    final visibleLeads = leads.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.artC.ink,
                ),
              ),
            ),
            if (!loading && leads.isNotEmpty)
              _QuietTextAction(label: '查看全部 →', onTap: onViewAll)
            else
              _StatusPill(
                label: loading
                    ? '同步中'
                    : idleStatusLabel ?? (verified ? '等待分配' : '先完成认证'),
                strong: verified,
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.artC.ink.withValues(alpha: 0.38),
          ),
        ),
        if (loading || error != null || visibleLeads.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: CircularProgressIndicator(
                  color: kCobalt,
                  strokeWidth: 2.2,
                ),
              ),
            )
          else if (error != null)
            _LeadInlineError(error: error!, onRetry: onRetry)
          else
            Column(
              children: [
                for (var i = 0; i < visibleLeads.length; i++) ...[
                  _LeadPriorityCard(
                    lead: visibleLeads[i],
                    busy: actingLeadId == visibleLeads[i]['id']?.toString(),
                    onOpen: () => onOpen(visibleLeads[i]),
                    onAssign: () => onAssign(visibleLeads[i]),
                    onPlan: () => onPlan(visibleLeads[i]),
                    onClose: () => onClose(visibleLeads[i]),
                  ),
                  if (i != visibleLeads.length - 1)
                    Divider(
                      height: 1,
                      color: context.artC.silver.withValues(alpha: 0.22),
                    ),
                ],
              ],
            ),
        ] else ...[
          const SizedBox(height: 12),
          _WorkbenchQuietEmpty(
            text: emptyText,
            actionLabel: emptyActionLabel,
            onAction: onEmptyAction ?? onViewAll,
          ),
        ],
      ],
    );
  }
}

class _ServiceBookingPreview extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onViewAll;
  final VoidCallback onEmptyAction;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _ServiceBookingPreview({
    required this.bookings,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onViewAll,
    required this.onEmptyAction,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final visibleBookings = bookings.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '预约服务',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.artC.ink,
                ),
              ),
            ),
            if (!loading && bookings.isNotEmpty)
              _QuietTextAction(label: '查看全部 →', onTap: onViewAll)
            else
              _StatusPill(
                label: loading ? '同步中' : '待转预约',
                strong: bookings.isNotEmpty,
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '短咨询确认、排期与完成状态',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: context.artC.ink.withValues(alpha: 0.38),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: CircularProgressIndicator(
                color: kCobalt,
                strokeWidth: 2.2,
              ),
            ),
          )
        else if (error != null)
          _LeadInlineError(error: error!, onRetry: onRetry)
        else if (visibleBookings.isEmpty)
          _WorkbenchQuietEmpty(
            text: '暂无转预约记录。顾问在咨询详情里点击“转预约”后会出现在这里。',
            actionLabel: '查看咨询线索 →',
            onAction: onEmptyAction,
          )
        else
          Column(
            children: [
              for (var i = 0; i < visibleBookings.length; i++) ...[
                _ServiceBookingRow(
                  booking: visibleBookings[i],
                  onTap: () => onOpen(visibleBookings[i]),
                ),
                if (i != visibleBookings.length - 1)
                  Divider(
                    height: 1,
                    color: context.artC.silver.withValues(alpha: 0.22),
                  ),
              ],
            ],
          ),
      ],
    );
  }
}

class _LeadRow extends StatelessWidget {
  final Map<String, dynamic> lead;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectedChanged;

  const _LeadRow({
    required this.lead,
    required this.onTap,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final targetName = lead['target_name']?.toString() ?? '未命名咨询';
    final lastMessage = lead['last_message']?.toString();
    final status = lead['status']?.toString() ?? 'new';
    final topic = _topicLabel(lead['topic']?.toString());
    final assignmentName = _leadAssignmentName(lead);
    final updatedAt =
        _formatShortTime(lead['updated_at'] ?? lead['created_at']);
    final unread = _intValue(lead['unread_count']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: selectionMode ? onSelectedChanged : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              if (selectionMode)
                Checkbox(
                  value: selected,
                  onChanged: (_) => onSelectedChanged?.call(),
                  activeColor: kCobalt,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              else
                SizedBox(
                  width: 24,
                  child: Icon(
                    Icons.school_outlined,
                    color: context.artC.ink.withValues(alpha: 0.4),
                    size: 18,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            targetName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: context.artC.ink,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          _LeadUnreadBadge(count: unread),
                        ],
                        if (updatedAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            updatedAt,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: context.artC.ink.withValues(alpha: 0.36),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      (lastMessage == null || lastMessage.trim().isEmpty)
                          ? '暂无消息内容'
                          : lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.artC.ink.withValues(alpha: 0.52),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniLeadTag(label: _statusLabel(status), strong: true),
                        if (topic != null) _MiniLeadTag(label: topic),
                        _MiniLeadTag(label: assignmentName),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.artC.ink.withValues(alpha: 0.22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadPriorityCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAssign;
  final VoidCallback onPlan;
  final VoidCallback onClose;

  const _LeadPriorityCard({
    required this.lead,
    required this.busy,
    required this.onOpen,
    required this.onAssign,
    required this.onPlan,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final title = _leadStudentName(lead);
    final goal = _leadGoalSummary(lead);
    final lastMessage = lead['last_message']?.toString().trim();
    final status = lead['status']?.toString() ?? 'new';
    final updatedAt =
        _formatShortTime(lead['updated_at'] ?? lead['created_at']);
    final unread = _intValue(lead['unread_count']);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                      ),
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    _LeadUnreadBadge(count: unread),
                  ],
                  if (updatedAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      updatedAt,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.artC.ink.withValues(alpha: 0.34),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                goal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: context.artC.ink.withValues(alpha: 0.52),
                ),
              ),
              if (lastMessage != null && lastMessage.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  lastMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
                    color: context.artC.ink.withValues(alpha: 0.68),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MiniLeadTag(label: _statusLabel(status), strong: true),
                  _MiniLeadTag(label: _leadAssignmentName(lead)),
                  if (busy)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: kCobalt,
                        strokeWidth: 1.8,
                      ),
                    )
                  else ...[
                    _QuietTextAction(label: '回复 →', onTap: onOpen),
                    _QuietTextAction(label: '分配 →', onTap: onAssign),
                    _QuietTextAction(label: '做方案 →', onTap: onPlan),
                    _QuietTextAction(label: '关闭', onTap: onClose),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadInlineError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _LeadInlineError({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.artC.silver.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '线索加载失败',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.52),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: kCobalt),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}

class _MiniLeadTag extends StatelessWidget {
  final String label;
  final bool strong;

  const _MiniLeadTag({
    required this.label,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color:
            strong ? kCobalt.withValues(alpha: 0.08) : const Color(0xFFF1F3F6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: strong ? kCobalt : context.artC.ink.withValues(alpha: 0.54),
        ),
      ),
    );
  }
}

class _LeadUnreadBadge extends StatelessWidget {
  final int count;

  const _LeadUnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WorkspaceActionGrid extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_WorkbenchAction> items;

  const _WorkspaceActionGrid({
    this.title = '工作入口',
    this.subtitle = '输入 · 计划 · 咨询',
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: context.artC.ink.withValues(alpha: 0.36),
                ),
              ),
            ],
          ),
        ),
        Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _WorkspaceActionRow(
                item: items[index],
                showDivider: index != items.length - 1,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _WorkspaceActionRow extends StatelessWidget {
  final _WorkbenchAction item;
  final bool showDivider;

  const _WorkspaceActionRow({
    required this.item,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: showDivider
                ? context.artC.ink.withValues(alpha: 0.055)
                : Colors.transparent,
            width: 0.6,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                SizedBox(
                  width: 25,
                  child: IconTheme(
                    data: IconThemeData(
                      size: 18,
                      color: context.artC.ink.withValues(alpha: 0.42),
                    ),
                    child: Icon(item.icon),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: context.artC.ink,
                              ),
                            ),
                          ),
                          if ((item.badgeCount ?? 0) > 0) ...[
                            const SizedBox(width: 8),
                            _LeadUnreadBadge(count: item.badgeCount!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.22,
                          fontWeight: FontWeight.w500,
                          color: context.artC.ink.withValues(alpha: 0.42),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: context.artC.ink.withValues(alpha: 0.22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkbenchListSheet extends StatefulWidget {
  final _WorkbenchListMode mode;
  final List<Map<String, dynamic>> leads;
  final List<Map<String, dynamic>> serviceBookings;
  final bool loading;
  final bool bookingLoading;
  final String? error;
  final String? bookingError;
  final Future<void> Function() onRetry;
  final Future<void> Function() onBookingRetry;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _WorkbenchListSheet({
    required this.mode,
    required this.leads,
    required this.serviceBookings,
    required this.loading,
    required this.bookingLoading,
    required this.error,
    required this.bookingError,
    required this.onRetry,
    required this.onBookingRetry,
    required this.onOpen,
  });

  @override
  State<_WorkbenchListSheet> createState() => _WorkbenchListSheetState();
}

class _WorkbenchListSheetState extends State<_WorkbenchListSheet> {
  String _status = 'all';
  String _assignment = 'all';
  bool _selectionMode = false;
  bool _bulkAssigning = false;
  final Set<String> _selectedLeadIds = {};
  late List<Map<String, dynamic>> _bookings;

  @override
  void initState() {
    super.initState();
    _bookings = List<Map<String, dynamic>>.from(widget.serviceBookings);
  }

  void _handleBookingUpdated(Map<String, dynamic> booking) {
    final id = booking['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      final index =
          _bookings.indexWhere((item) => item['id']?.toString() == id);
      if (index == -1) {
        _bookings.insert(0, booking);
      } else {
        _bookings[index] = booking;
      }
    });
    widget.onBookingRetry();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedLeadIds.clear();
    });
  }

  void _toggleLeadSelected(Map<String, dynamic> lead) {
    final id = lead['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      if (_selectedLeadIds.contains(id)) {
        _selectedLeadIds.remove(id);
      } else {
        _selectedLeadIds.add(id);
      }
    });
  }

  Future<void> _bulkAssignSelected() async {
    if (_selectedLeadIds.isEmpty || _bulkAssigning) return;
    setState(() => _bulkAssigning = true);
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
        builder: (_) => _BulkAssignmentSheet(members: team.data),
      );
      if (!mounted || member == null) return;
      final selectedIds = _selectedLeadIds.toList();
      final successes = <String>[];
      final failures = <_BulkAssignmentFailure>[];
      for (final id in selectedIds) {
        try {
          await BackendApiService.assignWorkbenchConsultation(
            id: id,
            memberId: member['id']?.toString(),
            memberUserId: member['user_id']?.toString(),
          );
          successes.add(id);
        } catch (e) {
          failures.add(
            _BulkAssignmentFailure(
              id: id,
              title: _leadTitleForId(id),
              error: _bulkAssignmentErrorText(e),
            ),
          );
        }
      }
      if (!mounted) return;
      await widget.onRetry();
      if (!mounted) return;
      if (failures.isNotEmpty) {
        setState(() {
          _selectionMode = true;
          _selectedLeadIds
            ..clear()
            ..addAll(failures.map((failure) => failure.id));
        });
        await showDialog<void>(
          context: context,
          builder: (_) => _BulkAssignmentResultDialog(
            memberName: _workbenchMemberName(member),
            successCount: successes.length,
            failures: failures,
          ),
        );
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '已将 ${selectedIds.length} 条线索分配给 ${_workbenchMemberName(member)}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量分配失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _bulkAssigning = false);
    }
  }

  String _leadTitleForId(String id) {
    for (final lead in widget.leads) {
      if (lead['id']?.toString() != id) continue;
      final targetName = lead['target_name']?.toString().trim();
      if (targetName != null && targetName.isNotEmpty) return targetName;
      final topic = lead['topic']?.toString().trim();
      if (topic != null && topic.isNotEmpty) return topic;
      final targetMajor = lead['target_major']?.toString().trim();
      if (targetMajor != null && targetMajor.isNotEmpty) return targetMajor;
    }
    return '线索 $id';
  }

  List<Map<String, dynamic>> get _filteredLeads {
    final base = switch (widget.mode) {
      _WorkbenchListMode.leads => widget.leads,
      _WorkbenchListMode.bookings => const <Map<String, dynamic>>[],
      _WorkbenchListMode.orders =>
        widget.leads.where((lead) => _conversionType(lead) == 'order').toList(),
    };
    if (widget.mode != _WorkbenchListMode.leads) {
      return base;
    }
    return base.where((lead) {
      final statusMatched =
          _status == 'all' || lead['status']?.toString() == _status;
      if (!statusMatched) return false;
      final key = _leadAssignmentKey(lead);
      return switch (_assignment) {
        'all' => true,
        'unassigned' => key == 'unassigned',
        'assigned' => key != 'unassigned',
        _ => key == _assignment,
      };
    }).toList();
  }

  List<MapEntry<String, String>> get _assignmentOptions {
    final options = <String, String>{
      'all': '全部负责',
      'unassigned': '待分配',
      'assigned': '已分配',
    };
    for (final lead in widget.leads) {
      final key = _leadAssignmentKey(lead);
      if (key != 'unassigned') {
        options[key] = _leadAssignmentName(lead);
      }
    }
    return options.entries.toList();
  }

  @override
  Widget build(BuildContext context) {
    final config = _workbenchListConfig(widget.mode);
    final leads = _filteredLeads;
    final loading = widget.mode == _WorkbenchListMode.bookings
        ? widget.bookingLoading
        : widget.loading;
    final error = widget.mode == _WorkbenchListMode.bookings
        ? widget.bookingError
        : widget.error;
    final count = widget.mode == _WorkbenchListMode.bookings
        ? _bookings.length
        : leads.length;
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
                    child: Icon(config.icon, color: kCobalt),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          config.subtitle,
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
                  _StatusPill(
                    label: loading ? '同步中' : '$count 条',
                    strong: count > 0,
                  ),
                ],
              ),
            ),
            if (widget.mode == _WorkbenchListMode.leads)
              _WorkbenchStatusFilter(
                value: _status,
                onChanged: (value) => setState(() => _status = value),
              ),
            if (widget.mode == _WorkbenchListMode.leads)
              _WorkbenchAssignmentFilter(
                value: _assignment,
                options: _assignmentOptions,
                onChanged: (value) => setState(() => _assignment = value),
              ),
            if (widget.mode == _WorkbenchListMode.leads)
              _BulkSelectionBar(
                selectionMode: _selectionMode,
                selectedCount: _selectedLeadIds.length,
                assigning: _bulkAssigning,
                onToggleMode: _toggleSelectionMode,
                onAssign: _bulkAssignSelected,
              ),
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: kCobalt,
                        strokeWidth: 2.5,
                      ),
                    )
                  : error != null
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: _LeadInlineError(
                            error: error,
                            onRetry: widget.mode == _WorkbenchListMode.bookings
                                ? widget.onBookingRetry
                                : widget.onRetry,
                          ),
                        )
                      : widget.mode == _WorkbenchListMode.bookings
                          ? _ServiceBookingList(
                              bookings: _bookings,
                              emptyText: config.emptyText,
                              onChanged: _handleBookingUpdated,
                              onOpenConsultation: widget.onOpen,
                            )
                          : leads.isEmpty
                              ? _WorkbenchListEmpty(config.emptyText)
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 22),
                                  itemBuilder: (context, index) => _LeadRow(
                                    lead: leads[index],
                                    selectionMode: _selectionMode,
                                    selected: _selectedLeadIds.contains(
                                      leads[index]['id']?.toString(),
                                    ),
                                    onSelectedChanged: () =>
                                        _toggleLeadSelected(leads[index]),
                                    onTap: () => widget.onOpen(leads[index]),
                                  ),
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: context.artC.silver
                                        .withValues(alpha: 0.22),
                                  ),
                                  itemCount: leads.length,
                                ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchStatusFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _WorkbenchStatusFilter({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const options = {
      'all': '全部',
      'new': '新咨询',
      'pending': '待回复',
      'active': '沟通中',
      'converted': '已转化',
      'closed': '已关闭',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: options.entries.map((entry) {
          final selected = value == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) => onChanged(entry.key),
              selectedColor: kCobalt.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: selected
                    ? kCobalt
                    : context.artC.ink.withValues(alpha: 0.52),
              ),
              side: BorderSide(
                color: selected
                    ? kCobalt.withValues(alpha: 0.34)
                    : context.artC.silver.withValues(alpha: 0.28),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _WorkbenchAssignmentFilter extends StatelessWidget {
  final String value;
  final List<MapEntry<String, String>> options;
  final ValueChanged<String> onChanged;

  const _WorkbenchAssignmentFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: options.map((entry) {
          final selected = value == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) => onChanged(entry.key),
              selectedColor: kCobalt.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: selected
                    ? kCobalt
                    : context.artC.ink.withValues(alpha: 0.52),
              ),
              side: BorderSide(
                color: selected
                    ? kCobalt.withValues(alpha: 0.34)
                    : context.artC.silver.withValues(alpha: 0.28),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BulkSelectionBar extends StatelessWidget {
  final bool selectionMode;
  final int selectedCount;
  final bool assigning;
  final VoidCallback onToggleMode;
  final VoidCallback onAssign;

  const _BulkSelectionBar({
    required this.selectionMode,
    required this.selectedCount,
    required this.assigning,
    required this.onToggleMode,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: assigning ? null : onToggleMode,
            style: OutlinedButton.styleFrom(
              foregroundColor: selectionMode ? context.artC.ink : kCobalt,
              side: BorderSide(color: kCobalt.withValues(alpha: 0.26)),
            ),
            icon: Icon(
              selectionMode ? Icons.close_rounded : Icons.checklist_rtl_rounded,
              size: 18,
            ),
            label: Text(selectionMode ? '取消选择' : '批量分配'),
          ),
          if (selectionMode) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedCount == 0 ? '请选择线索' : '已选 $selectedCount 条',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.artC.ink.withValues(alpha: 0.46),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: selectedCount == 0 || assigning ? null : onAssign,
              style: FilledButton.styleFrom(backgroundColor: kCobalt),
              icon: assigning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.assignment_ind_outlined, size: 18),
              label: const Text('分配'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BulkAssignmentSheet extends StatelessWidget {
  final List<Map<String, dynamic>> members;

  const _BulkAssignmentSheet({required this.members});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
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
                    child: const Icon(
                      Icons.assignment_ind_outlined,
                      color: kCobalt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择负责老师',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '批量分配后，老师会收到站内通知',
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                itemBuilder: (context, index) {
                  final member = members[index];
                  return _BulkMemberRow(
                    member: member,
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

class _BulkAssignmentFailure {
  final String id;
  final String title;
  final String error;

  const _BulkAssignmentFailure({
    required this.id,
    required this.title,
    required this.error,
  });
}

class _BulkAssignmentResultDialog extends StatelessWidget {
  final String memberName;
  final int successCount;
  final List<_BulkAssignmentFailure> failures;

  const _BulkAssignmentResultDialog({
    required this.memberName,
    required this.successCount,
    required this.failures,
  });

  @override
  Widget build(BuildContext context) {
    final title = successCount > 0 ? '部分线索未分配' : '批量分配未完成';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              successCount > 0
                  ? '已将 $successCount 条线索分配给 $memberName，以下 ${failures.length} 条失败，已为你保留选中。'
                  : '以下 ${failures.length} 条线索未能分配给 $memberName，已为你保留选中。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: context.artC.ink.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final failure = failures[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.artC.porcelain,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.artC.silver.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          failure.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: context.artC.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          failure.error,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemCount: failures.length,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('保留失败项继续处理'),
        ),
      ],
    );
  }
}

class _BulkMemberRow extends StatelessWidget {
  final Map<String, dynamic> member;
  final VoidCallback onTap;

  const _BulkMemberRow({
    required this.member,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = _workbenchMemberName(member);
    final role = _memberRoleLabel(member['role']?.toString() ?? 'member');
    final organization = member['organization'];
    final orgName = organization is Map
        ? organization['name']?.toString() ?? '所属机构'
        : '所属机构';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: kCobalt.withValues(alpha: 0.1),
                child: Text(
                  name.isEmpty ? '成' : name.characters.first,
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$orgName · $role',
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
              Icon(
                Icons.chevron_right_rounded,
                color: context.artC.ink.withValues(alpha: 0.28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchListEmpty extends StatelessWidget {
  final String text;

  const _WorkbenchListEmpty(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w800,
            color: context.artC.ink.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _ServiceBookingList extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final String emptyText;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final ValueChanged<Map<String, dynamic>> onOpenConsultation;

  const _ServiceBookingList({
    required this.bookings,
    required this.emptyText,
    required this.onChanged,
    required this.onOpenConsultation,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return _WorkbenchListEmpty(emptyText);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _ServiceBookingRow(
          booking: booking,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _ServiceBookingDetailSheet(
              booking: booking,
              onChanged: onChanged,
              onOpenConsultation: onOpenConsultation,
            ),
          ),
        );
      },
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: context.artC.silver.withValues(alpha: 0.22),
      ),
      itemCount: bookings.length,
    );
  }
}

class _ServiceBookingDetailSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final ValueChanged<Map<String, dynamic>> onOpenConsultation;

  const _ServiceBookingDetailSheet({
    required this.booking,
    required this.onChanged,
    required this.onOpenConsultation,
  });

  @override
  State<_ServiceBookingDetailSheet> createState() =>
      _ServiceBookingDetailSheetState();
}

class _ServiceBookingDetailSheetState
    extends State<_ServiceBookingDetailSheet> {
  late Map<String, dynamic> _booking;
  String? _savingStatus;
  String? _error;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  Future<void> _setStatus(String status) async {
    final id = _booking['id']?.toString();
    if (id == null || id.isEmpty || _savingStatus != null) return;
    setState(() {
      _savingStatus = status;
      _error = null;
    });
    try {
      final updated = await BackendApiService.updateWorkbenchServiceBooking(
        id: id,
        status: status,
      );
      if (!mounted) return;
      setState(() => _booking = updated);
      widget.onChanged(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingStatus = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consultation = _consultationFromBooking(_booking);
    final title = _booking['title']?.toString() ?? '预约服务';
    final status = _booking['status']?.toString() ?? 'requested';
    final scheduledAt = _formatBookingTime(_booking['scheduled_at']);
    final updatedAt =
        _formatShortTime(_booking['updated_at'] ?? _booking['created_at']);
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
                    child: const Icon(
                      Icons.event_available_outlined,
                      color: kCobalt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '预约详情',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.artC.porcelain,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: context.artC.silver.withValues(alpha: 0.26),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniLeadTag(
                          label: _bookingStatusLabel(status),
                          strong: true,
                        ),
                        if (consultation != null)
                          _MiniLeadTag(
                            label: consultation['target_name']?.toString() ??
                                '关联咨询',
                          ),
                        if (scheduledAt != null)
                          _MiniLeadTag(label: '排期 $scheduledAt'),
                        if (updatedAt != null) _MiniLeadTag(label: updatedAt),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '预约状态',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BookingStatusButton(
                    label: '确认',
                    icon: Icons.check_circle_outline_rounded,
                    active: status == 'confirmed',
                    loading: _savingStatus == 'confirmed',
                    onPressed: () => _setStatus('confirmed'),
                  ),
                  _BookingStatusButton(
                    label: '标记排期',
                    icon: Icons.schedule_outlined,
                    active: status == 'scheduled',
                    loading: _savingStatus == 'scheduled',
                    onPressed: () => _setStatus('scheduled'),
                  ),
                  _BookingStatusButton(
                    label: '完成',
                    icon: Icons.done_all_rounded,
                    active: status == 'completed',
                    loading: _savingStatus == 'completed',
                    onPressed: () => _setStatus('completed'),
                  ),
                  _BookingStatusButton(
                    label: '取消',
                    icon: Icons.cancel_outlined,
                    active: status == 'canceled',
                    loading: _savingStatus == 'canceled',
                    onPressed: () => _setStatus('canceled'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.redAccent,
                  ),
                ),
              ],
              if (consultation != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kCobalt,
                      side: BorderSide(color: kCobalt.withValues(alpha: 0.26)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenConsultation(consultation);
                    },
                    icon: const Icon(Icons.forum_outlined, size: 18),
                    label: const Text('查看关联咨询'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingStatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool loading;
  final VoidCallback onPressed;

  const _BookingStatusButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? Colors.white : kCobalt,
        backgroundColor: active ? kCobalt : Colors.transparent,
        side: BorderSide(color: kCobalt.withValues(alpha: 0.28)),
      ),
      onPressed: loading ? null : onPressed,
      icon: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: active ? Colors.white : kCobalt,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _ServiceBookingRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  const _ServiceBookingRow({
    required this.booking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final consultation = _consultationFromBooking(booking);
    final title = booking['title']?.toString() ?? '预约服务';
    final status = booking['status']?.toString() ?? 'requested';
    final targetName = consultation?['target_name']?.toString() ??
        booking['service_type']?.toString();
    final updatedAt =
        _formatShortTime(booking['updated_at'] ?? booking['created_at']);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kCobalt.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  color: kCobalt,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: context.artC.ink,
                            ),
                          ),
                        ),
                        if (updatedAt != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            updatedAt,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: context.artC.ink.withValues(alpha: 0.36),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      targetName == null || targetName.isEmpty
                          ? '关联咨询'
                          : targetName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.artC.ink.withValues(alpha: 0.52),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniLeadTag(
                          label: _bookingStatusLabel(status),
                          strong: true,
                        ),
                        if (consultation != null)
                          _MiniLeadTag(
                            label: _statusLabel(
                              consultation['status']?.toString() ?? 'converted',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.artC.ink.withValues(alpha: 0.28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizationProfileSheet extends StatefulWidget {
  final List<Map<String, dynamic>> organizations;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onCreated;

  const _OrganizationProfileSheet({
    required this.organizations,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onCreated,
  });

  @override
  State<_OrganizationProfileSheet> createState() =>
      _OrganizationProfileSheetState();
}

class _OrganizationProfileSheetState extends State<_OrganizationProfileSheet> {
  final _name = TextEditingController();
  Map<String, dynamic>? _updatedOrganization;
  String _type = 'gallery_exhibition';
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _creating) {
      setState(() => _error = '请填写机构名称');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await BackendApiService.createOrganization(
        name: name,
        type: _type,
      );
      await widget.onCreated();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('机构资料已创建')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final originalOrganization = _firstOrganization(widget.organizations);
    final organization = originalOrganization == null
        ? null
        : (
            organization:
                _updatedOrganization ?? originalOrganization.organization,
            role: originalOrganization.role,
            status: originalOrganization.status,
          );
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
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
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: kCobalt,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '机构资料',
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
                const SizedBox(height: 18),
                if (widget.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: kCobalt,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                else if (widget.error != null)
                  _OrganizationErrorState(
                    error: widget.error!,
                    onRetry: widget.onRetry,
                  )
                else if (organization != null)
                  _OrganizationSummary(
                    organization: organization.organization,
                    role: organization.role,
                    memberStatus: organization.status,
                    onSubscriptionUpdated: widget.onCreated,
                    onOrganizationUpdated: (updated) async {
                      setState(() => _updatedOrganization = updated);
                      await widget.onCreated();
                    },
                  )
                else
                  _OrganizationCreateForm(
                    name: _name,
                    type: _type,
                    error: _error,
                    creating: _creating,
                    onTypeChanged: (value) => setState(() => _type = value),
                    onSubmit: _create,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganizationCreateForm extends StatelessWidget {
  final TextEditingController name;
  final String type;
  final String? error;
  final bool creating;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onSubmit;

  const _OrganizationCreateForm({
    required this.name,
    required this.type,
    required this.error,
    required this.creating,
    required this.onTypeChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: name,
          enabled: !creating,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: '机构名称',
            filled: true,
            fillColor: context.artC.porcelain,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 14),
        Text(
          '机构类型',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: context.artC.ink,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _organizationTypes.entries.map((entry) {
            final selected = type == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: creating ? null : (_) => onTypeChanged(entry.key),
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
            onPressed: creating ? null : onSubmit,
            icon: creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_business_outlined),
            label: Text(creating ? '创建中' : '创建机构资料'),
          ),
        ),
      ],
    );
  }
}

class _OrganizationSummary extends StatelessWidget {
  final Map<String, dynamic> organization;
  final String role;
  final String memberStatus;
  final Future<void> Function() onSubscriptionUpdated;
  final Future<void> Function(Map<String, dynamic> organization)
      onOrganizationUpdated;

  const _OrganizationSummary({
    required this.organization,
    required this.role,
    required this.memberStatus,
    required this.onSubscriptionUpdated,
    required this.onOrganizationUpdated,
  });

  Future<void> _openEditSheet(BuildContext context) async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrganizationEditSheet(organization: organization),
    );
    if (updated != null) {
      await onOrganizationUpdated(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = organization['name']?.toString() ?? '未命名机构';
    final type = organization['type']?.toString();
    final verification = organization['verification_status']?.toString();
    final status = organization['status']?.toString();
    final subscriptionStatus =
        organization['subscription_status']?.toString() ?? 'inactive';
    final subscriptionExpiresAt =
        _formatOrganizationDate(organization['subscription_expires_at']);
    final canManageOrganization = role == 'owner' || role == 'admin';
    final city = organization['city']?.toString();
    final focusAreas = _stringList(organization['focus_areas']);
    final supportsOnline = organization['supports_online'] == true;
    final supportsOffline = organization['supports_offline'] == true;
    final completeness = _organizationCompleteness(organization);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.artC.silver.withValues(alpha: 0.26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 12),
          _OrganizationCompletenessCard(
            completeness: completeness,
            onTap: canManageOrganization ? () => _openEditSheet(context) : null,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (type != null && type.isNotEmpty)
                _MiniLeadTag(label: _organizationTypeLabel(type), strong: true),
              _MiniLeadTag(label: _verificationLabel(verification)),
              _MiniLeadTag(label: _memberRoleLabel(role)),
              _MiniLeadTag(label: _organizationStatusLabel(status)),
              _MiniLeadTag(
                label: _subscriptionStatusLabel(
                  subscriptionStatus,
                  subscriptionExpiresAt,
                ),
                strong: subscriptionStatus == 'active',
              ),
              if (memberStatus != 'active') _MiniLeadTag(label: memberStatus),
            ],
          ),
          if ((city ?? '').trim().isNotEmpty || focusAreas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((city ?? '').trim().isNotEmpty)
                  _MiniLeadTag(label: city!.trim()),
                for (final area in focusAreas.take(4))
                  _MiniLeadTag(label: area),
                if (supportsOnline) const _MiniLeadTag(label: '线上咨询'),
                if (supportsOffline) const _MiniLeadTag(label: '线下见面'),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            '维护城市、专注领域与联系方式后，机构会出现在对应机构后台和线下联系入口中。',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.56),
            ),
          ),
          if (canManageOrganization) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openEditSheet(context),
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('编辑公开资料与联系方式'),
              ),
            ),
            const SizedBox(height: 14),
            _OrganizationSubscriptionButton(
              organizationId: organization['id']?.toString() ?? '',
              active: subscriptionStatus == 'active',
              onDone: onSubscriptionUpdated,
            ),
          ],
        ],
      ),
    );
  }
}

class _OrganizationEditSheet extends StatefulWidget {
  final Map<String, dynamic> organization;

  const _OrganizationEditSheet({required this.organization});

  @override
  State<_OrganizationEditSheet> createState() => _OrganizationEditSheetState();
}

class _OrganizationEditSheetState extends State<_OrganizationEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _province;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _focusAreas;
  late final TextEditingController _summary;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _wechatQrUrl;
  late final TextEditingController _contactNote;
  late String _type;
  late bool _supportsOnline;
  late bool _supportsOffline;
  bool _saving = false;
  bool _geocoding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final org = widget.organization;
    final metadata = _mapValue(org['metadata']);
    _name = TextEditingController(text: _cleanText(org['name']));
    _city = TextEditingController(text: _cleanText(org['city']));
    _province = TextEditingController(text: _cleanText(org['province']));
    _latitude = TextEditingController(text: _cleanText(org['latitude']));
    _longitude = TextEditingController(text: _cleanText(org['longitude']));
    _focusAreas =
        TextEditingController(text: _stringList(org['focus_areas']).join('，'));
    _summary = TextEditingController(
      text: _cleanText(metadata['summary']).isNotEmpty
          ? _cleanText(metadata['summary'])
          : _cleanText(metadata['description']),
    );
    _address = TextEditingController(text: _cleanText(metadata['address']));
    _phone = TextEditingController(text: _cleanText(metadata['phone']));
    _wechatQrUrl =
        TextEditingController(text: _cleanText(metadata['wechat_qr_url']));
    _contactNote =
        TextEditingController(text: _cleanText(metadata['contact_note']));
    _type = _cleanText(org['type']).isEmpty
        ? 'gallery_exhibition'
        : _cleanText(org['type']);
    _supportsOnline = org['supports_online'] != false;
    _supportsOffline = org['supports_offline'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _province.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _focusAreas.dispose();
    _summary.dispose();
    _address.dispose();
    _phone.dispose();
    _wechatQrUrl.dispose();
    _contactNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _geocoding) return;
    final id = widget.organization['id']?.toString() ?? '';
    if (id.isEmpty) {
      setState(() => _error = '机构 ID 缺失');
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请填写机构名称');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.updateOrganizationProfile(
        organizationId: id,
        name: name,
        type: _type,
        city: _city.text,
        province: _province.text,
        latitude: _latitude.text,
        longitude: _longitude.text,
        focusAreas: _splitTags(_focusAreas.text),
        supportsOnline: _supportsOnline,
        supportsOffline: _supportsOffline,
        metadata: {
          'summary': _summary.text.trim(),
          'address': _address.text.trim(),
          'phone': _phone.text.trim(),
          'wechat_qr_url': _wechatQrUrl.text.trim(),
          'contact_note': _contactNote.text.trim(),
        },
      );
      if (!mounted) return;
      final organization = result['organization'];
      Navigator.of(context).pop(
        organization is Map<String, dynamic> ? organization : result,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('机构资料已更新')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  Future<void> _geocodeAddress() async {
    if (_saving || _geocoding) return;
    final address = _address.text.trim();
    if (address.length < 2) {
      setState(() => _error = '请先填写完整的线下地址');
      return;
    }
    setState(() {
      _geocoding = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.geocodeAddressWithAmap(
        address: address,
        city: _city.text,
      );
      final latitude = result['latitude'];
      final longitude = result['longitude'];
      if (latitude is! num || longitude is! num) {
        throw Exception('高德地图未返回有效坐标');
      }
      _latitude.text = _coordinateText(latitude);
      _longitude.text = _coordinateText(longitude);
      final province = _cleanText(result['province']);
      final city = _cleanText(result['city']);
      if (_province.text.trim().isEmpty && province.isNotEmpty) {
        _province.text = province;
      }
      if (_city.text.trim().isEmpty && city.isNotEmpty) {
        _city.text = city;
      }
      if (!mounted) return;
      setState(() => _geocoding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已通过高德地图填入经纬度')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _geocoding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(
                      '编辑机构资料',
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '这些信息会用于机构后台资料、筛选和线下联系入口。',
                      style: TextStyle(
                        color: context.artC.ink.withValues(alpha: 0.52),
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _OrganizationTextField(
                      controller: _name,
                      label: '机构名称',
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '机构类型',
                      style: TextStyle(
                        color: context.artC.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _organizationTypes.entries.map((entry) {
                        final selected = _type == entry.key;
                        return ChoiceChip(
                          label: Text(entry.value),
                          selected: selected,
                          onSelected: _saving
                              ? null
                              : (_) => setState(() => _type = entry.key),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _OrganizationTextField(
                            controller: _province,
                            label: '省份',
                            enabled: !_saving && !_geocoding,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OrganizationTextField(
                            controller: _city,
                            label: '城市',
                            enabled: !_saving && !_geocoding,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _OrganizationTextField(
                            controller: _latitude,
                            label: '纬度',
                            enabled: !_saving && !_geocoding,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _OrganizationTextField(
                            controller: _longitude,
                            label: '经度',
                            enabled: !_saving && !_geocoding,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _OrganizationTextField(
                      controller: _focusAreas,
                      label: '专注领域',
                      hint: '英国留学，RCA，作品集',
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 12),
                    _OrganizationTextField(
                      controller: _summary,
                      label: '机构简介',
                      enabled: !_saving,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _OrganizationSwitchTile(
                      title: '支持线上咨询',
                      value: _supportsOnline,
                      enabled: !_saving,
                      onChanged: (value) =>
                          setState(() => _supportsOnline = value),
                    ),
                    const SizedBox(height: 8),
                    _OrganizationSwitchTile(
                      title: '支持线下见面',
                      value: _supportsOffline,
                      enabled: !_saving,
                      onChanged: (value) =>
                          setState(() => _supportsOffline = value),
                    ),
                    const SizedBox(height: 14),
                    _OrganizationTextField(
                      controller: _address,
                      label: '线下地址',
                      hint: '填写省、市、区和详细门牌地址',
                      enabled: !_saving && !_geocoding,
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed:
                            _saving || _geocoding ? null : _geocodeAddress,
                        icon: _geocoding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.location_searching_rounded),
                        label: Text(_geocoding ? '高德解析中' : '用高德地图定位'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _OrganizationTextField(
                      controller: _phone,
                      label: '联系电话',
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _OrganizationTextField(
                      controller: _wechatQrUrl,
                      label: '企业微信二维码链接',
                      enabled: !_saving,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    _OrganizationTextField(
                      controller: _contactNote,
                      label: '线下联系备注',
                      enabled: !_saving,
                      maxLines: 2,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kCobalt),
                    onPressed: _saving || _geocoding ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '保存中' : '保存机构资料'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizationTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool enabled;
  final int maxLines;
  final TextInputType? keyboardType;

  const _OrganizationTextField({
    required this.controller,
    required this.label,
    this.hint,
    required this.enabled,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: context.artC.porcelain,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _OrganizationSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _OrganizationSwitchTile({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.artC.porcelain,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SwitchListTile.adaptive(
          value: value,
          onChanged: enabled ? onChanged : null,
          dense: true,
          activeThumbColor: kCobalt,
          contentPadding: EdgeInsets.zero,
          title: Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganizationSubscriptionButton extends StatefulWidget {
  final String organizationId;
  final bool active;
  final Future<void> Function() onDone;

  const _OrganizationSubscriptionButton({
    required this.organizationId,
    required this.active,
    required this.onDone,
  });

  @override
  State<_OrganizationSubscriptionButton> createState() =>
      _OrganizationSubscriptionButtonState();
}

class _OrganizationSubscriptionButtonState
    extends State<_OrganizationSubscriptionButton> {
  bool _submitting = false;

  Future<void> _upgrade() async {
    if (_submitting || widget.organizationId.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final checkout =
          await BackendApiService.createOrganizationSubscriptionUpgrade(
        organizationId: widget.organizationId,
      );
      final checkoutUrl = checkout['checkoutUrl']?.toString() ?? '';
      final orderId = _checkoutOrderId(checkout);
      if (checkoutUrl.startsWith('/orders/') && orderId.isNotEmpty) {
        await BackendApiService.confirmExistingOrder(orderId);
        await widget.onDone();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('年度入驻已开通')),
        );
        return;
      }
      await widget.onDone();
      if (!mounted) return;
      if (checkoutUrl.isNotEmpty) {
        final url = checkoutUrl.startsWith('http')
            ? checkoutUrl
            : '${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}$checkoutUrl';
        final opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        if (!opened) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('请在浏览器打开：$url')),
          );
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('年度入驻订单已创建')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建年度入驻订单失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _submitting ? null : _upgrade,
        icon: _submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(widget.active
                ? Icons.workspace_premium_outlined
                : Icons.verified_outlined),
        label: Text(
          _submitting
              ? '创建中'
              : widget.active
                  ? '续费年度入驻'
                  : '开通年度入驻',
        ),
      ),
    );
  }
}

class _OrganizationErrorState extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const _OrganizationErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.artC.porcelain,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '机构资料加载失败',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: context.artC.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: context.artC.ink.withValues(alpha: 0.52),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: kCobalt),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}

typedef _OrganizationMembership = ({
  Map<String, dynamic> organization,
  String role,
  String status,
});

typedef _WorkbenchListConfig = ({
  IconData icon,
  String title,
  String subtitle,
  String emptyText,
});

enum _WorkbenchListMode {
  leads,
  bookings,
  orders,
}

_WorkbenchListConfig _workbenchListConfig(_WorkbenchListMode mode) {
  return switch (mode) {
    _WorkbenchListMode.leads => (
        icon: Icons.support_agent_outlined,
        title: '咨询线索',
        subtitle: '按状态处理分配给你的申请咨询',
        emptyText: '暂无可处理咨询线索。平台分配或学生发起咨询后会出现在这里。',
      ),
    _WorkbenchListMode.bookings => (
        icon: Icons.event_available_outlined,
        title: '预约服务',
        subtitle: '从咨询转出的预约服务跟进',
        emptyText: '暂无转预约记录。顾问在咨询详情里点击“转预约”后会出现在这里。',
      ),
    _WorkbenchListMode.orders => (
        icon: Icons.receipt_long_outlined,
        title: '订单转化',
        subtitle: '从咨询转出的订单成交线索',
        emptyText: '暂无转订单记录。顾问在咨询详情里点击“转订单”后会出现在这里。',
      ),
  };
}

String? _conversionType(Map<String, dynamic> lead) {
  final metadata = lead['metadata'];
  if (metadata is! Map) return null;
  final conversion = metadata['conversion'];
  if (conversion is! Map) return null;
  return conversion['type']?.toString();
}

String _leadAssignmentKey(Map<String, dynamic> lead) {
  final memberId = lead['assigned_to_member_id']?.toString().trim() ?? '';
  if (memberId.isNotEmpty) return 'member:$memberId';
  final userId = lead['assigned_to_user_id']?.toString().trim() ?? '';
  if (userId.isNotEmpty) return 'user:$userId';
  return 'unassigned';
}

String _leadAssignmentName(Map<String, dynamic> lead) {
  if (_leadAssignmentKey(lead) == 'unassigned') return '待分配';
  final metadata = lead['metadata'];
  if (metadata is Map) {
    final assignment = metadata['internal_assignment'];
    if (assignment is Map) {
      final name = assignment['member_name']?.toString().trim();
      if (name != null && name.isNotEmpty) return '负责 $name';
    }
  }
  return '已分配老师';
}

String _leadStudentName(Map<String, dynamic> lead) {
  final metadata = _mapValue(lead['metadata']);
  final profile = _mapValue(lead['profile']);
  final value = _firstCleanText(
    metadata['student_name'],
    metadata['student_nickname'],
    metadata['nickname'],
    metadata['display_name'],
    profile['nickname'],
    profile['display_name'],
    lead['student_name'],
    lead['target_name'],
  );
  return value.isEmpty ? '未命名咨询' : value;
}

String _leadGoalSummary(Map<String, dynamic> lead) {
  final metadata = _mapValue(lead['metadata']);
  final topic = _topicLabel(lead['topic']?.toString());
  final targetName = _cleanText(lead['target_name']);
  final major = _firstCleanText(
    lead['target_major'],
    metadata['target_major'],
    metadata['major'],
    metadata['intended_major'],
  );
  final country = _firstCleanText(
    metadata['target_country'],
    metadata['country'],
    metadata['destination'],
  );
  final intake = _firstCleanText(lead['intake'], metadata['intake']);
  final budget = _leadBudgetLabel(metadata);
  final parts = [
    if (targetName.isNotEmpty) targetName,
    if (country.isNotEmpty) country,
    if (major.isNotEmpty) major,
    if (budget.isNotEmpty) budget,
    if (intake.isNotEmpty) intake,
    if (topic != null) topic,
  ];
  return parts.isEmpty ? '申请目标待补充' : parts.join(' · ');
}

String _leadBudgetLabel(Map<String, dynamic> metadata) {
  final budget = _firstCleanText(
    metadata['budget'],
    metadata['budget_label'],
    metadata['target_budget'],
  );
  if (budget.isNotEmpty) return budget;
  final min = _cleanText(metadata['budget_min']);
  final max = _cleanText(metadata['budget_max']);
  if (min.isEmpty && max.isEmpty) return '';
  if (min.isNotEmpty && max.isNotEmpty) return '$min-$max';
  if (min.isNotEmpty) return '$min 起';
  return '$max 内';
}

_OrganizationCompleteness _organizationCompleteness(
  Map<String, dynamic> organization,
) {
  final metadata = _mapValue(organization['metadata']);
  final city = _firstCleanText(organization['city'], organization['province']);
  final summary = _firstCleanText(
    organization['summary'],
    metadata['summary'],
    metadata['description'],
  );
  final contact = _firstCleanText(
    metadata['phone'],
    metadata['wechat_qr_url'],
    metadata['contact_note'],
  );
  final hasServiceMode = organization['supports_online'] == true ||
      organization['supports_offline'] == true;
  return _OrganizationCompleteness([
    _OrganizationCompletenessItem(
      '机构名称',
      _cleanText(organization['name']).isNotEmpty,
    ),
    _OrganizationCompletenessItem(
      '机构类型',
      _cleanText(organization['type']).isNotEmpty,
    ),
    _OrganizationCompletenessItem('地区', city.isNotEmpty),
    _OrganizationCompletenessItem(
      '服务方向',
      _stringList(organization['focus_areas']).isNotEmpty,
    ),
    _OrganizationCompletenessItem('简介', summary.isNotEmpty),
    _OrganizationCompletenessItem('服务方式', hasServiceMode),
    _OrganizationCompletenessItem('联系方式', contact.isNotEmpty),
    _OrganizationCompletenessItem(
      '认证',
      organization['verification_status']?.toString() == 'verified',
    ),
  ]);
}

Map<String, dynamic>? _consultationFromBooking(Map<String, dynamic> booking) {
  final consultation = booking['consultation'];
  return consultation is Map<String, dynamic> ? consultation : null;
}

String _bookingStatusLabel(String status) {
  switch (status) {
    case 'requested':
      return '待确认';
    case 'confirmed':
      return '已确认';
    case 'scheduled':
      return '已排期';
    case 'completed':
      return '已完成';
    case 'canceled':
      return '已取消';
    default:
      return status;
  }
}

_OrganizationMembership? _firstOrganization(
  List<Map<String, dynamic>> organizations,
) {
  for (final row in organizations) {
    final organization = row['organization'];
    if (organization is Map<String, dynamic>) {
      return (
        organization: organization,
        role: row['role']?.toString() ?? 'member',
        status: row['status']?.toString() ?? 'active',
      );
    }
  }
  return null;
}

String _organizationActionSubtitle(
  List<Map<String, dynamic>> organizations,
  bool loading,
) {
  if (loading) return '同步机构资料';
  final organization = _firstOrganization(organizations);
  if (organization == null) return '创建机构资料并承接分配';
  return organization.organization['name']?.toString() ?? '查看机构资料';
}

Map<String, dynamic> _organizationPreviewPayload(
  Map<String, dynamic> organization,
) {
  final metadata = _mapValue(organization['metadata']);
  final summary = _firstCleanText(
    organization['summary'],
    metadata['summary'],
    metadata['description'],
  );
  final avatarUrl = _firstCleanText(
    organization['avatar_url'],
    organization['logo_url'],
    metadata['avatar_url'],
    metadata['logo_url'],
  );
  return {
    ...organization,
    if (summary.isNotEmpty) 'summary': summary,
    if (avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
    'metadata': {
      ...metadata,
      if (summary.isNotEmpty) 'summary': summary,
      if (avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
    },
  };
}

const _organizationTypes = {
  'gallery_exhibition': '画廊 / 美术馆',
  'official_association': '官方协会',
  'school_official': '院校官方',
  'official_partner': '官方合作',
  'study_abroad_agency': '留学服务（已下线）',
  'portfolio_training': '作品集服务（已下线）',
  'event_organizer': '活动主办',
  'other_service': '其他服务',
};

String _organizationTypeLabel(String type) {
  return _organizationTypes[type] ?? type;
}

String _verificationLabel(String? status) {
  switch (status) {
    case 'verified':
      return '已认证';
    case 'rejected':
      return '认证未通过';
    case 'pending':
    default:
      return '待认证';
  }
}

String _organizationStatusLabel(String? status) {
  switch (status) {
    case 'active':
      return '启用中';
    case 'inactive':
      return '未启用';
    case 'suspended':
      return '已暂停';
    default:
      return status ?? '未知状态';
  }
}

String _subscriptionStatusLabel(String status, String? expiresAt) {
  switch (status) {
    case 'active':
      return expiresAt == null || expiresAt.isEmpty ? '入驻有效' : '入驻至 $expiresAt';
    case 'expired':
      return '入驻已到期';
    case 'inactive':
    default:
      return '未开通入驻';
  }
}

String? _formatOrganizationDate(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.length < 10) return null;
  return text.substring(0, 10);
}

String _memberRoleLabel(String role) {
  switch (role) {
    case 'owner':
      return '所有者';
    case 'admin':
      return '管理员';
    case 'advisor':
      return '顾问';
    case 'member':
    default:
      return '成员';
  }
}

String _workbenchMemberName(Map<String, dynamic> member) {
  final profile = member['profile'];
  if (profile is Map) {
    final nickname = profile['nickname']?.toString().trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
  }
  final displayName = member['display_name']?.toString().trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final metadata = member['metadata'];
  if (metadata is Map) {
    final metadataName = metadata['display_name']?.toString().trim();
    if (metadataName != null && metadataName.isNotEmpty) return metadataName;
  }
  return '机构成员';
}

String _bulkAssignmentErrorText(Object error) {
  final text = error.toString().trim();
  if (text.isEmpty) return '未知错误';
  const exceptionPrefix = 'Exception: ';
  if (text.startsWith(exceptionPrefix)) {
    final cleaned = text.substring(exceptionPrefix.length).trim();
    return cleaned.isEmpty ? '未知错误' : cleaned;
  }
  return text;
}

class _QuietTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuietTextAction({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: context.artC.ink,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool strong;

  const _StatusPill({required this.label, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color:
            strong ? kCobalt.withValues(alpha: 0.08) : const Color(0xFFF1F3F6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: strong ? kCobalt : context.artC.ink.withValues(alpha: 0.54),
        ),
      ),
    );
  }
}

class _WorkbenchTodoItem {
  final String label;
  final int count;
  final String caption;
  final VoidCallback onTap;

  const _WorkbenchTodoItem({
    required this.label,
    required this.count,
    required this.caption,
    required this.onTap,
  });
}

class _WorkbenchAnalyticsMetric {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _WorkbenchAnalyticsMetric({
    required this.label,
    required this.value,
    required this.onTap,
  });
}

class _WorkbenchAnalyticsSnapshot {
  final int totalLeads;
  final int weeklyNewLeads;
  final int followedLeads;
  final int pendingLeads;
  final int unreadLeads;
  final int activeLeads;
  final int bookingCount;
  final int orderCount;

  const _WorkbenchAnalyticsSnapshot({
    required this.totalLeads,
    required this.weeklyNewLeads,
    required this.followedLeads,
    required this.pendingLeads,
    required this.unreadLeads,
    required this.activeLeads,
    required this.bookingCount,
    required this.orderCount,
  });

  factory _WorkbenchAnalyticsSnapshot.from({
    required List<Map<String, dynamic>> leads,
    required List<Map<String, dynamic>> serviceBookings,
  }) {
    final now = DateTime.now();
    final currentStart = now.subtract(const Duration(days: 7));
    var weeklyNew = 0;
    var followed = 0;
    var pending = 0;
    var unread = 0;
    var active = 0;
    var orders = 0;
    for (final lead in leads) {
      final createdAt = _dateValue(lead['created_at']);
      if (_dateInRange(createdAt, currentStart, now)) weeklyNew++;
      final status = lead['status']?.toString();
      if (status == 'pending') pending++;
      if (status == 'active') active++;
      if (status == 'active' || status == 'converted' || status == 'closed') {
        followed++;
      }
      unread += _intValue(lead['unread_count']);
      if (_conversionType(lead) == 'order') orders++;
    }
    final bookings = serviceBookings
        .where((booking) => booking['status']?.toString() != 'canceled')
        .length;
    return _WorkbenchAnalyticsSnapshot(
      totalLeads: leads.length,
      weeklyNewLeads: weeklyNew,
      followedLeads: followed,
      pendingLeads: pending,
      unreadLeads: unread,
      activeLeads: active,
      bookingCount: bookings,
      orderCount: orders,
    );
  }

  int get replyPressure => unreadLeads > 0 ? unreadLeads : pendingLeads;

  String get followUpRateLabel => _rateLabel(followedLeads, totalLeads);
  String get bookingRateLabel => _rateLabel(bookingCount, totalLeads);
}

class _OrganizationCompleteness {
  final List<_OrganizationCompletenessItem> items;

  const _OrganizationCompleteness(this.items);

  int get total => items.length;
  int get completed => items.where((item) => item.done).length;
  bool get complete => completed >= total;
  double get ratio => total == 0 ? 0 : completed / total;
  List<String> get missingLabels => items
      .where((item) => !item.done)
      .map((item) => item.label)
      .toList(growable: false);
}

class _OrganizationCompletenessItem {
  final String label;
  final bool done;

  const _OrganizationCompletenessItem(this.label, this.done);
}

class _WorkbenchAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final int? badgeCount;

  const _WorkbenchAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.badgeCount,
  });
}

class _WorkbenchSectionItem {
  final _InstitutionWorkbenchSection section;
  final String label;
  final int badgeCount;

  const _WorkbenchSectionItem({
    required this.section,
    required this.label,
    required this.badgeCount,
  });
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

String? _formatShortTime(dynamic raw) {
  final value = raw?.toString();
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)}';
}

String? _formatBookingTime(dynamic raw) {
  final value = raw?.toString();
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

DateTime? _dateValue(dynamic raw) {
  final value = raw?.toString();
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

bool _dateInRange(DateTime? value, DateTime start, DateTime end) {
  if (value == null) return false;
  return !value.isBefore(start) && value.isBefore(end);
}

String _rateLabel(int numerator, int denominator) {
  if (denominator <= 0) return '0%';
  final value = (numerator / denominator * 100).round().clamp(0, 999);
  return '$value%';
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _checkoutOrderId(Map<String, dynamic> checkout) {
  final direct = checkout['orderId']?.toString().trim() ?? '';
  if (direct.isNotEmpty) return direct;
  final order = checkout['order'];
  if (order is Map) return order['id']?.toString().trim() ?? '';
  return '';
}

String _cleanText(dynamic value) {
  return value?.toString().trim() ?? '';
}

String _coordinateText(num value) {
  return value
      .toDouble()
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _firstCleanText(
  Object? first, [
  Object? second,
  Object? third,
  Object? fourth,
  Object? fifth,
  Object? sixth,
  Object? seventh,
  Object? eighth,
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
  return value is Map<String, dynamic> ? value : const {};
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final text = _cleanText(value);
  if (text.isEmpty) return const [];
  return _splitTags(text);
}

List<String> _splitTags(String text) {
  final seen = <String>{};
  final result = <String>[];
  for (final item in text.split(RegExp(r'[,，、\s]+'))) {
    final tag = item.trim();
    if (tag.isEmpty || seen.contains(tag)) continue;
    seen.add(tag);
    result.add(tag);
  }
  return result;
}
