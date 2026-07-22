import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../services/backend_api_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/artsee_ui_colors.dart';
import '../../utils/auth_gate.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import '../messages/light_message_screen.dart';
import '../profile/consultation_detail_screen.dart';
import '../profile/contract_archive_screen.dart';

class OrganizationListScreen extends StatefulWidget {
  final String? schoolId;
  final String? schoolName;

  const OrganizationListScreen({
    super.key,
    this.schoolId,
    this.schoolName,
  });

  @override
  State<OrganizationListScreen> createState() => _OrganizationListScreenState();
}

class _OrganizationListScreenState extends State<OrganizationListScreen> {
  final List<Map<String, dynamic>> _items = [];
  String? _city;
  String _focusArea = 'all';
  String _serviceMode = 'all';
  String _sort = 'comprehensive';
  Map<String, dynamic>? _membership;
  bool _loading = true;
  bool _membershipLoading = false;
  String? _error;

  bool get _isMember => _membership?['is_member'] == true;
  bool get _hasSchoolContext =>
      widget.schoolId != null || (widget.schoolName?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    await _loadProfileCity();
    await Future.wait([
      _loadMembership(),
      _loadOrganizations(),
    ]);
  }

  Future<void> _loadProfileCity() async {
    if (!SupabaseService.isLoggedIn) return;
    try {
      final profile = await SupabaseService.fetchProfile();
      final city = _extractCity(
        profile?['city'] ?? profile?['location'] ?? profile?['province'],
      );
      if (!mounted || city == null || city.isEmpty) return;
      setState(() => _city = city);
    } catch (_) {}
  }

  Future<void> _loadMembership() async {
    if (!SupabaseService.isLoggedIn) {
      if (mounted) setState(() => _membership = null);
      return;
    }
    if (mounted) setState(() => _membershipLoading = true);
    try {
      final membership = await BackendApiService.fetchMembership();
      if (!mounted) return;
      setState(() {
        _membership = membership;
        _membershipLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _membership = {'is_member': false, 'status': 'free'};
        _membershipLoading = false;
      });
    }
  }

  Future<void> _loadOrganizations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BackendApiService.fetchNearbyOrganizations(
        limit: 50,
        city: _city,
        focusArea: _focusArea == 'all' ? null : _focusArea,
        serviceMode: _serviceMode == 'all' ? null : _serviceMode,
        schoolId: widget.schoolId,
        schoolName: widget.schoolName,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.data);
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

  Future<void> _setCity(String? city) async {
    setState(() => _city = city);
    await _loadOrganizations();
  }

  Future<void> _editCity() async {
    final controller = TextEditingController(text: _city ?? '');
    final city = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('切换城市'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '城市',
            hintText: '例如：成都',
          ),
          onSubmitted: (_) {
            Navigator.of(dialogContext).pop(controller.text.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('全部城市'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_city),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || city == _city) return;
    await _setCity(city == null || city.isEmpty ? null : city);
  }

  Future<void> _setFocus(String value) async {
    setState(() => _focusArea = value);
    await _loadOrganizations();
  }

  Future<void> _setServiceMode(String value) async {
    setState(() => _serviceMode = value);
    await _loadOrganizations();
  }

  Future<void> _setSort(String value) async {
    setState(() => _sort = value);
    await _loadOrganizations();
  }

  Future<bool> _ensureMember() async {
    if (!await ensureLoggedIn(context, message: '请先登录后联系官方组织')) {
      return false;
    }
    if (_membership == null) await _loadMembership();
    if (_isMember) return true;
    if (!mounted) return false;
    await _showUpgradeSheet();
    return false;
  }

  Future<void> _startOnlineConsultation(Map<String, dynamic> org) async {
    if (!await _ensureMember()) return;
    final orgId = org['id']?.toString();
    if (orgId == null || orgId.isEmpty) return;
    final orgName = org['name']?.toString() ?? '官方组织';
    final targetName = widget.schoolName?.trim().isNotEmpty == true
        ? widget.schoolName!.trim()
        : '艺术申请咨询';
    try {
      final consultation = await BackendApiService.createConsultation(
        targetType: _hasSchoolContext ? 'school' : 'organization',
        targetId: widget.schoolId,
        targetName: targetName,
        source: _hasSchoolContext
            ? 'school_detail_organization'
            : 'organization_list',
        organizationId: orgId,
        channel: 'online',
        message: '我想咨询 $targetName，请 $orgName 的相关负责人帮我确认官方信息和申请路径。',
        metadata: {
          'entry': _hasSchoolContext ? 'school_detail' : 'organization_list',
          'organization_name': orgName,
          if (widget.schoolName != null) 'school_name': widget.schoolName,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已向 $orgName 发起线上咨询')),
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConsultationDetailScreen(consultation: consultation),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 402) {
        await _showUpgradeSheet();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发起咨询失败：$e')),
      );
    }
  }

  Future<void> _showOfflineContact(Map<String, dynamic> org) async {
    if (!await _ensureMember()) return;
    if (!mounted) return;
    final orgId = org['id']?.toString();
    var detail = org;
    if (orgId != null && orgId.isNotEmpty) {
      try {
        detail = await BackendApiService.fetchOrganization(orgId);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('联系方式加载失败：$e')),
        );
        return;
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfflineContactSheet(org: detail),
    );
  }

  void _openDetail(Map<String, dynamic> org) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrganizationDetailScreen(
          initialOrg: org,
          schoolId: widget.schoolId,
          schoolName: widget.schoolName,
        ),
      ),
    );
  }

  Future<void> _showUpgradeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MembershipUpgradeSheet(
        loading: _membershipLoading,
        onUpgrade: _openMembershipCheckout,
      ),
    );
  }

  Future<void> _openMembershipCheckout(String plan) async {
    try {
      final checkout = await BackendApiService.createMembershipUpgrade(
        plan: plan,
      );
      final rawUrl = checkout['checkoutUrl']?.toString();
      if (rawUrl == null || rawUrl.isEmpty) return;
      final orderId = _checkoutOrderId(checkout);
      if (_isInternalCheckoutUrl(rawUrl) && orderId.isNotEmpty) {
        await BackendApiService.confirmExistingOrder(orderId);
        await _loadMembership();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('会员已开通')),
        );
        return;
      }
      final url = rawUrl.startsWith('http')
          ? rawUrl
          : '${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}$rawUrl';
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请在浏览器打开：$url')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建会员订单失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        child: RefreshIndicator(
          color: kCobalt,
          onRefresh: () async {
            await Future.wait([
              _loadMembership(),
              _loadOrganizations(),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              _Header(
                schoolName: widget.schoolName,
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              _MembershipBanner(
                isMember: _isMember,
                loading: _membershipLoading,
                expiresAt: _membership?['expires_at']?.toString(),
                onTap: _isMember ? null : _showUpgradeSheet,
              ),
              const SizedBox(height: 14),
              _FilterSection(
                city: _city,
                focusArea: _focusArea,
                serviceMode: _serviceMode,
                sort: _sort,
                onCityChanged: _setCity,
                onCityEdit: _editCity,
                onFocusChanged: _setFocus,
                onServiceChanged: _setServiceMode,
                onSortChanged: _setSort,
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 96),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: kCobalt,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (_error != null)
                _StatePanel(
                  icon: Icons.cloud_off_outlined,
                  title: '官方组织加载失败',
                  subtitle: _error!,
                  action: '重试',
                  onTap: _loadOrganizations,
                )
              else if (_items.isEmpty)
                _StatePanel(
                  icon: Icons.domain_disabled_outlined,
                  title: '暂无匹配官方组织',
                  subtitle: '换一个城市、领域或服务方式再试试。',
                  action: '清空筛选',
                  onTap: () async {
                    setState(() {
                      _city = null;
                      _focusArea = 'all';
                      _serviceMode = 'all';
                      _sort = 'comprehensive';
                    });
                    await _loadOrganizations();
                  },
                )
              else
                ..._items.map(
                  (org) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OrganizationCard(
                      org: org,
                      memberLocked: !_isMember,
                      onTap: () => _openDetail(org),
                      onOnline: () => _startOnlineConsultation(org),
                      onOffline: () => _showOfflineContact(org),
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

class _Header extends StatelessWidget {
  final String? schoolName;
  final VoidCallback onBack;

  const _Header({
    required this.schoolName,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final hasSchool = schoolName?.trim().isNotEmpty == true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: context.artC.silver.withValues(alpha: 0.42),
            foregroundColor: context.artC.ink,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开始咨询',
                  style: TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: context.artC.ink,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasSchool ? '优先展示与 $schoolName 相关的官方组织' : '按城市、领域和官方认证找到合适组织',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.42),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _MembershipBanner extends StatelessWidget {
  final bool isMember;
  final bool loading;
  final String? expiresAt;
  final VoidCallback? onTap;

  const _MembershipBanner({
    required this.isMember,
    required this.loading,
    required this.expiresAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = loading
        ? '正在确认会员状态'
        : isMember
            ? '会员权益已开启'
            : '升级会员后可联系官方组织';
    final subtitle = isMember
        ? '线上会话与线下联系方式均已解锁${expiresAt == null ? '' : ' · 到期 $expiresAt'}'
        : '非会员可浏览官方组织信息，发起会话和查看联系方式需开通会员。';
    return ArtseeSurface(
      onTap: onTap,
      elevated: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      radius: 20,
      color:
          isMember ? kCobalt.withValues(alpha: 0.08) : context.artC.cardIconBg,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isMember
                  ? kCobalt
                  : context.artC.silver.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isMember ? Icons.verified_rounded : Icons.lock_outline_rounded,
              color: isMember
                  ? Colors.white
                  : context.artC.ink.withValues(alpha: 0.45),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.46),
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (!isMember && !loading)
            Icon(
              Icons.chevron_right_rounded,
              color: context.artC.ink.withValues(alpha: 0.32),
            ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String? city;
  final String focusArea;
  final String serviceMode;
  final String sort;
  final ValueChanged<String?> onCityChanged;
  final VoidCallback onCityEdit;
  final ValueChanged<String> onFocusChanged;
  final ValueChanged<String> onServiceChanged;
  final ValueChanged<String> onSortChanged;

  const _FilterSection({
    required this.city,
    required this.focusArea,
    required this.serviceMode,
    required this.sort,
    required this.onCityChanged,
    required this.onCityEdit,
    required this.onFocusChanged,
    required this.onServiceChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cityItems = _cityFilterItems(city);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipRow<String?>(
          label: '城市',
          value: city,
          items: cityItems,
          onChanged: onCityChanged,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onCityEdit,
            icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
            label: const Text('输入城市'),
          ),
        ),
        const SizedBox(height: 10),
        _ChipRow<String>(
          label: '领域',
          value: focusArea,
          items: const [
            (value: 'all', label: '全部'),
            (value: 'uk', label: '英国院校'),
            (value: 'us', label: '美国院校'),
            (value: 'portfolio', label: '作品集'),
            (value: 'rca', label: 'RCA'),
          ],
          onChanged: onFocusChanged,
        ),
        const SizedBox(height: 10),
        _ChipRow<String>(
          label: '方式',
          value: serviceMode,
          items: const [
            (value: 'all', label: '全部'),
            (value: 'online', label: '线上咨询'),
            (value: 'offline', label: '线下见面'),
          ],
          onChanged: onServiceChanged,
        ),
        const SizedBox(height: 10),
        _ChipRow<String>(
          label: '排序',
          value: sort,
          items: const [
            (value: 'comprehensive', label: '综合'),
            (value: 'distance', label: '最近'),
            (value: 'rating', label: '评分'),
            (value: 'match', label: '匹配'),
          ],
          onChanged: onSortChanged,
        ),
      ],
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<({T value, String label})> items;
  final ValueChanged<T> onChanged;

  const _ChipRow({
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
            color: context.artC.ink.withValues(alpha: 0.38),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items.map((item) {
              final selected = item.value == value;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(item.label),
                  selected: selected,
                  onSelected: (_) => onChanged(item.value),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? kCobalt
                        : context.artC.ink.withValues(alpha: 0.56),
                  ),
                  selectedColor: kCobalt.withValues(alpha: 0.1),
                  backgroundColor: context.artC.silver.withValues(alpha: 0.22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: selected
                          ? kCobalt.withValues(alpha: 0.28)
                          : context.artC.silver.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  final Map<String, dynamic> org;
  final bool memberLocked;
  final VoidCallback onTap;
  final VoidCallback onOnline;
  final VoidCallback onOffline;

  const _OrganizationCard({
    required this.org,
    required this.memberLocked,
    required this.onTap,
    required this.onOnline,
    required this.onOffline,
  });

  @override
  Widget build(BuildContext context) {
    final name = org['name']?.toString() ?? '未命名官方组织';
    final city = org['city']?.toString();
    final province = org['province']?.toString();
    final distance = org['distance_km'];
    final rating = (org['rating'] as num?)?.toDouble() ?? 0;
    final reviewCount = (org['review_count'] as num?)?.toInt() ?? 0;
    final contractCount = (org['contract_count'] as num?)?.toInt() ?? 0;
    final focusAreas = _stringList(org['focus_areas']).take(4).toList();
    final supportsOnline = org['supports_online'] != false;
    final supportsOffline = org['supports_offline'] == true;
    final avatarUrl = org['avatar_url']?.toString();
    final location = [
      if (city != null && city.isNotEmpty) city,
      if (province != null && province.isNotEmpty && province != city) province,
      if (distance is num) '${distance.toStringAsFixed(1)} km',
    ].join(' · ');

    return ArtseeSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: 22,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _OrgAvatar(name: name, avatarUrl: avatarUrl),
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
                        color: context.artC.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: context.artC.ink.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location.isEmpty ? '位置待完善' : location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.artC.ink.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _RatingPill(rating: rating, reviewCount: reviewCount),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              ...focusAreas.map(
                (tag) => _MiniTag(label: _focusLabel(tag), color: kCobalt),
              ),
              if (contractCount > 0)
                _MiniTag(
                    label: '$contractCount 条记录',
                    color: const Color(0xFF047857)),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (supportsOnline)
                const _ServiceTag(
                    icon: Icons.chat_bubble_outline_rounded, label: '线上咨询'),
              if (supportsOffline)
                const _ServiceTag(
                    icon: Icons.storefront_outlined, label: '支持线下见面'),
              if (memberLocked)
                const _ServiceTag(
                    icon: Icons.lock_outline_rounded, label: '会员解锁联系'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (supportsOnline)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOnline,
                    icon: Icon(
                      memberLocked
                          ? Icons.lock_open_outlined
                          : Icons.send_rounded,
                      size: 16,
                    ),
                    label: Text(memberLocked ? '解锁线上咨询' : '线上咨询'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kCobalt,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              if (supportsOnline && supportsOffline) const SizedBox(width: 10),
              if (supportsOffline)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOffline,
                    icon: Icon(
                      memberLocked
                          ? Icons.lock_outline_rounded
                          : Icons.place_outlined,
                      size: 16,
                    ),
                    label: Text(memberLocked ? '解锁线下方式' : '线下见面'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.artC.ink,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                      side: BorderSide(
                        color: context.artC.silver.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class OrganizationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> initialOrg;
  final String? schoolId;
  final String? schoolName;

  const OrganizationDetailScreen({
    super.key,
    required this.initialOrg,
    this.schoolId,
    this.schoolName,
  });

  @override
  State<OrganizationDetailScreen> createState() =>
      _OrganizationDetailScreenState();
}

class _OrganizationDetailScreenState extends State<OrganizationDetailScreen> {
  late Map<String, dynamic> _org;
  Map<String, dynamic>? _membership;
  bool _loading = true;
  bool _membershipLoading = false;
  bool _following = false;
  bool _messageOpening = false;
  int _profileTab = 0;
  String? _error;

  bool get _isMember => _membership?['is_member'] == true;
  bool get _hasSchoolContext =>
      widget.schoolId != null || (widget.schoolName?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _org = widget.initialOrg;
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      _loadDetail(),
      _loadMembership(),
    ]);
  }

  Future<void> _loadDetail() async {
    final id = _org['id']?.toString();
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await BackendApiService.fetchOrganization(id);
      if (!mounted) return;
      setState(() {
        _org = {..._org, ...detail};
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

  Future<void> _loadMembership() async {
    if (!SupabaseService.isLoggedIn) {
      if (mounted) setState(() => _membership = null);
      return;
    }
    if (mounted) setState(() => _membershipLoading = true);
    try {
      final membership = await BackendApiService.fetchMembership();
      if (!mounted) return;
      setState(() {
        _membership = membership;
        _membershipLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _membership = {'is_member': false, 'status': 'free'};
        _membershipLoading = false;
      });
    }
  }

  Future<bool> _ensureMember() async {
    if (!await ensureLoggedIn(context, message: '请先登录后联系官方组织')) {
      return false;
    }
    if (_membership == null) await _loadMembership();
    if (_isMember) return true;
    if (!mounted) return false;
    await _showUpgradeSheet();
    return false;
  }

  Future<void> _showUpgradeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MembershipUpgradeSheet(
        loading: _membershipLoading,
        onUpgrade: _openMembershipCheckout,
      ),
    );
  }

  Future<void> _openMembershipCheckout(String plan) async {
    try {
      final checkout = await BackendApiService.createMembershipUpgrade(
        plan: plan,
      );
      final rawUrl = checkout['checkoutUrl']?.toString();
      if (rawUrl == null || rawUrl.isEmpty) return;
      final orderId = _checkoutOrderId(checkout);
      if (_isInternalCheckoutUrl(rawUrl) && orderId.isNotEmpty) {
        await BackendApiService.confirmExistingOrder(orderId);
        await _loadMembership();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('会员已开通')),
        );
        return;
      }
      final url = rawUrl.startsWith('http')
          ? rawUrl
          : '${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}$rawUrl';
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请在浏览器打开：$url')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建会员订单失败：$e')),
      );
    }
  }

  Future<void> _startOnlineConsultation() async {
    if (!await _ensureMember()) return;
    final orgId = _org['id']?.toString();
    if (orgId == null || orgId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('官方组织资料创建后可接收咨询')),
      );
      return;
    }
    final orgName = _org['name']?.toString() ?? '官方组织';
    final targetName = widget.schoolName?.trim().isNotEmpty == true
        ? widget.schoolName!.trim()
        : '艺术申请咨询';
    try {
      final consultation = await BackendApiService.createConsultation(
        targetType: _hasSchoolContext ? 'school' : 'organization',
        targetId: widget.schoolId,
        targetName: targetName,
        source: _hasSchoolContext
            ? 'school_detail_organization'
            : 'organization_detail',
        organizationId: orgId,
        channel: 'online',
        message: '我想咨询 $targetName，请 $orgName 的相关负责人帮我确认官方信息和申请路径。',
        metadata: {
          'entry': _hasSchoolContext ? 'school_detail' : 'organization_detail',
          'organization_name': orgName,
          if (widget.schoolName != null) 'school_name': widget.schoolName,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已向 $orgName 发起线上咨询')),
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConsultationDetailScreen(consultation: consultation),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 402) {
        await _showUpgradeSheet();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发起咨询失败：$e')),
      );
    }
  }

  Future<void> _showOfflineContact() async {
    if (!await _ensureMember()) return;
    await _loadDetail();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfflineContactSheet(org: _org),
    );
  }

  Future<void> _openOrganizationMessage({
    required String name,
    required String? avatarUrl,
    required String responseSpeed,
  }) async {
    if (!await _ensureMember()) return;
    final orgId = _org['id']?.toString();
    if (orgId == null || orgId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('官方组织资料创建后可接收消息')),
      );
      return;
    }
    if (_messageOpening) return;
    setState(() => _messageOpening = true);
    try {
      final conversation =
          await BackendApiService.createOrganizationConversation(
        organizationId: orgId,
        title: name,
        metadata: {
          'source': _hasSchoolContext
              ? 'school_detail_organization_message'
              : 'organization_detail_message',
          'organization_name': name,
          if (avatarUrl != null) 'organization_avatar_url': avatarUrl,
          if (widget.schoolId != null) 'school_id': widget.schoolId,
          if (widget.schoolName != null) 'school_name': widget.schoolName,
        },
      );
      if (!mounted) return;
      setState(() => _messageOpening = false);
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LightMessageScreen(
            conversation: conversation,
            peer: LightMessagePeer.organization(
              name: name,
              avatarUrl: avatarUrl,
              identityLabel: '官方组织群聊',
              serviceStatus: '服务中',
              responseTime: responseSpeed,
              profileBuilder: (_) => OrganizationDetailScreen(
                initialOrg: _org,
                schoolId: widget.schoolId,
                schoolName: widget.schoolName,
              ),
            ),
            initialMessage: '你好，可以先说说想咨询的方向、申请阶段或合作需求。',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _messageOpening = false);
      if (e is ApiException && e.code == 402) {
        await _showUpgradeSheet();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开官方组织群聊失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _org['name']?.toString() ?? '未命名官方组织';
    final city = _org['city']?.toString();
    final province = _org['province']?.toString();
    final summary = _org['summary']?.toString();
    final focusAreas = _stringList(_org['focus_areas']).take(8).toList();
    final rating = (_org['rating'] as num?)?.toDouble() ?? 0;
    final reviewCount = (_org['review_count'] as num?)?.toInt() ?? 0;
    final reviews = _mapList(_org['reviews']).take(5).toList();
    final supportsOnline = _org['supports_online'] != false;
    final supportsOffline = _org['supports_offline'] == true;
    final typeLabel = _organizationTypeLabel(_org['type']?.toString());
    final verified = _organizationVerified(_org);
    final responseSpeed = _organizationResponseSpeed(_org);
    final services = _organizationServices(_org);
    final cases = _organizationCases(_org, schoolName: widget.schoolName);
    final team = _organizationTeam(_org);
    final activities = _organizationActivities(_org);
    final qas = _organizationQas(_org);
    final location = [
      if (city != null && city.isNotEmpty) city,
      if (province != null && province.isNotEmpty && province != city) province,
    ].join(' · ');

    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: SafeArea(
        child: RefreshIndicator(
          color: kCobalt,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon:
                        const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          context.artC.silver.withValues(alpha: 0.42),
                      foregroundColor: context.artC.ink,
                    ),
                  ),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: kCobalt,
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _OrganizationPublicHeader(
                name: name,
                logoUrl: _org['avatar_url']?.toString(),
                verified: verified,
                typeLabel: typeLabel,
                location: location.isEmpty ? '城市待完善' : location,
                summary: summary,
                rating: rating,
                reviewCount: reviewCount,
                responseSpeed: responseSpeed,
                serviceCount: services.length,
                caseCount: cases.length,
                focusAreas: focusAreas,
              ),
              const SizedBox(height: 14),
              _MembershipBanner(
                isMember: _isMember,
                loading: _membershipLoading,
                expiresAt: _membership?['expires_at']?.toString(),
                onTap: _isMember ? null : _showUpgradeSheet,
              ),
              const SizedBox(height: 14),
              _OrganizationPrimaryActions(
                following: _following,
                supportsOnline: supportsOnline,
                supportsOffline: supportsOffline,
                onConsult: supportsOnline
                    ? _startOnlineConsultation
                    : _showOfflineContact,
                onMessage: () {
                  _openOrganizationMessage(
                    name: name,
                    avatarUrl: _org['avatar_url']?.toString(),
                    responseSpeed: responseSpeed,
                  );
                },
                onFollow: () => setState(() => _following = !_following),
              ),
              const SizedBox(height: 16),
              _OrganizationProfileTabs(
                selectedIndex: _profileTab,
                onChanged: (index) => setState(() => _profileTab = index),
              ),
              const SizedBox(height: 12),
              _OrganizationTabContent(
                selectedIndex: _profileTab,
                services: services,
                cases: cases,
                team: team,
                activities: activities,
                reviews: reviews,
                qas: qas,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _StatePanel(
                  icon: Icons.cloud_off_outlined,
                  title: '详情加载失败',
                  subtitle: _error!,
                  action: '重试',
                  onTap: _loadDetail,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizationPublicHeader extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final bool verified;
  final String typeLabel;
  final String location;
  final String? summary;
  final double rating;
  final int reviewCount;
  final String responseSpeed;
  final int serviceCount;
  final int caseCount;
  final List<String> focusAreas;

  const _OrganizationPublicHeader({
    required this.name,
    required this.logoUrl,
    required this.verified,
    required this.typeLabel,
    required this.location,
    required this.summary,
    required this.rating,
    required this.reviewCount,
    required this.responseSpeed,
    required this.serviceCount,
    required this.caseCount,
    required this.focusAreas,
  });

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      elevated: true,
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrgAvatar(name: name, avatarUrl: logoUrl, size: 66),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.artC.ink,
                              fontSize: 22,
                              fontFamily: 'Noto Serif SC',
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.verified_rounded,
                              color: kCobalt, size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _MiniTag(
                            label: verified ? '官方认证' : '官方组织', color: kCobalt),
                        _MiniTag(
                            label: typeLabel, color: const Color(0xFF047857)),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: context.artC.ink.withValues(alpha: 0.34),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.artC.ink.withValues(alpha: 0.46),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (summary != null && summary!.isNotEmpty) ...[
            const SizedBox(height: 15),
            Text(
              summary!,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.66),
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _OrganizationMetricStrip(
            rating: rating,
            reviewCount: reviewCount,
            responseSpeed: responseSpeed,
            serviceCount: serviceCount,
            caseCount: caseCount,
          ),
          if (focusAreas.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: focusAreas
                  .map((tag) =>
                      _MiniTag(label: _focusLabel(tag), color: kCobalt))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrganizationMetricStrip extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final String responseSpeed;
  final int serviceCount;
  final int caseCount;

  const _OrganizationMetricStrip({
    required this.rating,
    required this.reviewCount,
    required this.responseSpeed,
    required this.serviceCount,
    required this.caseCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OrganizationMetric(
          label: '评分',
          value: rating > 0 ? rating.toStringAsFixed(1) : '新',
          helper: reviewCount > 0 ? '$reviewCount 条评价' : '暂无评价',
        ),
        const SizedBox(width: 8),
        _OrganizationMetric(
          label: '响应',
          value: responseSpeed,
          helper: '咨询速度',
        ),
        const SizedBox(width: 8),
        _OrganizationMetric(
          label: '服务',
          value: '$serviceCount',
          helper: '可咨询',
        ),
        const SizedBox(width: 8),
        _OrganizationMetric(
          label: '案例',
          value: '$caseCount',
          helper: '已展示',
        ),
      ],
    );
  }
}

class _OrganizationMetric extends StatelessWidget {
  final String label;
  final String value;
  final String helper;

  const _OrganizationMetric({
    required this.label,
    required this.value,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: context.artC.silver.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.26)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.38),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              helper,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.artC.ink.withValues(alpha: 0.34),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationPrimaryActions extends StatelessWidget {
  final bool following;
  final bool supportsOnline;
  final bool supportsOffline;
  final VoidCallback onConsult;
  final VoidCallback onMessage;
  final VoidCallback onFollow;

  const _OrganizationPrimaryActions({
    required this.following,
    required this.supportsOnline,
    required this.supportsOffline,
    required this.onConsult,
    required this.onMessage,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onConsult,
            icon: Icon(
              supportsOnline
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.place_outlined,
              size: 17,
            ),
            label: Text(supportsOnline ? '咨询' : '线下联系'),
            style: FilledButton.styleFrom(
              backgroundColor: kCobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('私信'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.artC.ink,
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
              side:
                  BorderSide(color: context.artC.silver.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onFollow,
            icon: Icon(
              following ? Icons.check_rounded : Icons.add_rounded,
              size: 18,
            ),
            label: Text(following ? '已关注' : '关注'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.artC.ink,
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
              side:
                  BorderSide(color: context.artC.silver.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrganizationProfileTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _OrganizationProfileTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const tabs = ['服务', '案例', '团队 / 艺术家', '动态', '评价', '问答'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final active = selectedIndex == index;
          return Padding(
            padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 8),
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 36,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: active ? kCobalt : context.artC.cardIconBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? kCobalt
                        : context.artC.silver.withValues(alpha: 0.42),
                  ),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    color: active ? Colors.white : context.artC.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _OrganizationTabContent extends StatelessWidget {
  final int selectedIndex;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> cases;
  final List<Map<String, dynamic>> team;
  final List<Map<String, dynamic>> activities;
  final List<Map<String, dynamic>> reviews;
  final List<Map<String, dynamic>> qas;

  const _OrganizationTabContent({
    required this.selectedIndex,
    required this.services,
    required this.cases,
    required this.team,
    required this.activities,
    required this.reviews,
    required this.qas,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (selectedIndex) {
        0 => _OrganizationListPanel(
            key: const ValueKey('services'),
            items: services,
            emptyTitle: '暂无服务',
            emptyText: '官方组织完善资料后会在这里展示可咨询项目。',
            itemBuilder: (item) => _OrganizationServiceCard(item: item),
          ),
        1 => _OrganizationListPanel(
            key: const ValueKey('cases'),
            items: cases,
            emptyTitle: '暂无案例',
            emptyText: '案例会用于判断组织擅长方向和服务人群。',
            itemBuilder: (item) => _OrganizationCaseCard(item: item),
          ),
        2 => _OrganizationListPanel(
            key: const ValueKey('team'),
            items: team,
            emptyTitle: '暂无团队信息',
            emptyText: '联系人、项目负责人和合作艺术家会在这里展示。',
            itemBuilder: (item) => _OrganizationTeamCard(item: item),
          ),
        3 => _OrganizationListPanel(
            key: const ValueKey('activities'),
            items: activities,
            emptyTitle: '暂无动态',
            emptyText: '课程、活动、展览和官方更新会沉淀在这里。',
            itemBuilder: (item) => _OrganizationTextCard(item: item),
          ),
        4 => reviews.isEmpty
            ? const _OrganizationEmptyPanel(
                key: ValueKey('reviews'),
                title: '暂无评价',
                text: '完成咨询或服务后，用户评价会展示在这里。',
              )
            : _OrganizationReviewsPanel(
                key: const ValueKey('reviews'),
                reviews: reviews,
              ),
        _ => _OrganizationListPanel(
            key: const ValueKey('qa'),
            items: qas,
            emptyTitle: '暂无问答',
            emptyText: '用户常问问题和官方组织回答会在这里展示。',
            itemBuilder: (item) => _OrganizationQaCard(item: item),
          ),
      },
    );
  }
}

class _OrganizationListPanel extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyTitle;
  final String emptyText;
  final Widget Function(Map<String, dynamic> item) itemBuilder;

  const _OrganizationListPanel({
    super.key,
    required this.items,
    required this.emptyTitle,
    required this.emptyText,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _OrganizationEmptyPanel(title: emptyTitle, text: emptyText);
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          itemBuilder(items[i]),
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _OrganizationEmptyPanel extends StatelessWidget {
  final String title;
  final String text;

  const _OrganizationEmptyPanel({
    super.key,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      radius: 8,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined,
              color: context.artC.ink.withValues(alpha: 0.28), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.5),
                    fontSize: 12,
                    height: 1.45,
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

class _OrganizationServiceCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _OrganizationServiceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = _itemText(item, ['title', 'name'], '服务项目');
    final subtitle = _itemText(item, ['subtitle', 'description', 'summary'],
        '适合需要确认官方信息、活动资源或申请节点的用户。');
    final meta = _itemText(item, ['meta', 'mode', 'delivery'], '线上 / 线下可咨询');
    return _OrganizationInfoCard(
      icon: Icons.design_services_outlined,
      title: title,
      subtitle: subtitle,
      trailing: meta,
    );
  }
}

class _OrganizationCaseCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _OrganizationCaseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = _itemText(item, ['title', 'name'], '服务案例');
    final subtitle = _itemText(
        item, ['subtitle', 'description', 'summary'], '展示官方项目、活动参与和资源对接结果。');
    final result = _itemText(item, ['result', 'tag', 'school'], '案例');
    return _OrganizationInfoCard(
      icon: Icons.collections_bookmark_outlined,
      title: title,
      subtitle: subtitle,
      trailing: result,
    );
  }
}

class _OrganizationTeamCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _OrganizationTeamCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = _itemText(item, ['name', 'title'], '团队成员');
    final role = _itemText(item, ['role', 'position'], '负责人 / 艺术家');
    final bio = _itemText(
        item, ['bio', 'description', 'summary'], '负责官方信息确认、资源对接或合作项目。');
    return _OrganizationInfoCard(
      icon: Icons.groups_2_outlined,
      title: name,
      subtitle: bio,
      trailing: role,
    );
  }
}

class _OrganizationTextCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _OrganizationTextCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = _itemText(item, ['title', 'name'], '官方动态');
    final text = _itemText(
        item, ['body', 'description', 'summary'], '活动、项目、资讯和团队动态会在这里更新。');
    return _OrganizationInfoCard(
      icon: Icons.campaign_outlined,
      title: title,
      subtitle: text,
      trailing: _itemText(item, ['date', 'created_at'], '更新'),
    );
  }
}

class _OrganizationQaCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _OrganizationQaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final question = _itemText(item, ['question', 'title'], '常见问题');
    final answer = _itemText(
        item, ['answer', 'body', 'description'], '官方组织会在这里回答用户关心的信息、活动和合作方式。');
    return _OrganizationInfoCard(
      icon: Icons.live_help_outlined,
      title: question,
      subtitle: answer,
      trailing: '问答',
    );
  }
}

class _OrganizationInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  const _OrganizationInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      radius: 8,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kCobalt.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: kCobalt, size: 19),
          ),
          const SizedBox(width: 12),
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
                          color: context.artC.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MiniTag(label: trailing, color: kCobalt),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.62),
                    fontSize: 12,
                    height: 1.48,
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

class _OrganizationReviewsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;

  const _OrganizationReviewsPanel({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return ArtseeSurface(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_outlined, size: 18, color: kCobalt),
              const SizedBox(width: 8),
              Text(
                '近期评价',
                style: TextStyle(
                  color: context.artC.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < reviews.length; i++) ...[
            _OrganizationReviewTile(review: reviews[i]),
            if (i != reviews.length - 1)
              Divider(
                height: 18,
                color: context.artC.silver.withValues(alpha: 0.32),
              ),
          ],
        ],
      ),
    );
  }
}

class _OrganizationReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;

  const _OrganizationReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final body = review['body']?.toString().trim();
    final targetName = review['target_name']?.toString().trim();
    final createdAt = _formatReviewDate(review['created_at']?.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...List.generate(
              5,
              (index) => Icon(
                index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: const Color(0xFFF59E0B),
                size: 15,
              ),
            ),
            const Spacer(),
            if (createdAt != null)
              Text(
                createdAt,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.34),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        if (body != null && body.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            body,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.66),
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (targetName != null && targetName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            targetName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.36),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

class _OrgAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _OrgAvatar({
    required this.name,
    required this.avatarUrl,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kCobalt.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size >= 60 ? 20 : 16),
        border: Border.all(color: kCobalt.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _AvatarFallback(name: name),
            )
          : _AvatarFallback(name: name),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;

  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '艺' : name.substring(0, 1);
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: kCobalt,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;
  final int reviewCount;

  const _RatingPill({
    required this.rating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
          const SizedBox(width: 3),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : '新',
            style: const TextStyle(
              color: Color(0xFF92400E),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (reviewCount > 0) ...[
            const SizedBox(width: 3),
            Text(
              '$reviewCount',
              style: TextStyle(
                color: const Color(0xFF92400E).withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ServiceTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ServiceTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.artC.ink.withValues(alpha: 0.36)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: context.artC.ink.withValues(alpha: 0.44),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _OfflineContactSheet extends StatelessWidget {
  final Map<String, dynamic> org;

  const _OfflineContactSheet({required this.org});

  @override
  Widget build(BuildContext context) {
    final name = org['name']?.toString() ?? '官方组织';
    final address = _organizationAddress(org);
    final phone = _metadataText(org, ['phone', 'telephone', 'mobile']);
    final qr = _metadataText(org, ['wechat_qr_url', 'wechatQrUrl']);
    final canOpenMap = _organizationMapQuery(org).isNotEmpty ||
        (_numberValue(org['latitude']) != null &&
            _numberValue(org['longitude']) != null);
    return _SheetShell(
      title: '线下见面',
      subtitle: name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContactRow(
            icon: Icons.place_outlined,
            label: '组织地址',
            value: address.isNotEmpty ? address : '官方组织尚未填写地址',
          ),
          if (canOpenMap) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: kCobalt,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                onPressed: () async {
                  final opened = await _openOrganizationMap(org);
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('暂时无法打开地图')),
                    );
                  }
                },
                icon: const Icon(Icons.map_outlined, size: 17),
                label: const Text('在地图中打开'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.call_outlined,
            label: '联系电话',
            value: phone.isNotEmpty ? phone : '官方组织尚未填写电话',
          ),
          if (qr.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                qr,
                height: 180,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '线下沟通由用户与官方组织自行确认。平台仅提供组织信息与必要记录入口。',
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.42),
              fontSize: 11,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => ContractArchiveScreen(
                      initialOrganizationId: org['id']?.toString(),
                      initialOrganizationName: name,
                      openCreateOnLoad: true,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('上传合同存档'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.artC.silver.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: kCobalt, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.artC.ink.withValues(alpha: 0.36),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class _MembershipUpgradeSheet extends StatefulWidget {
  final bool loading;
  final Future<void> Function(String plan) onUpgrade;

  const _MembershipUpgradeSheet({
    required this.loading,
    required this.onUpgrade,
  });

  @override
  State<_MembershipUpgradeSheet> createState() =>
      _MembershipUpgradeSheetState();
}

class _MembershipUpgradeSheetState extends State<_MembershipUpgradeSheet> {
  String _plan = 'yearly';
  String? _submittingPlan;

  Future<void> _submit() async {
    if (widget.loading || _submittingPlan != null) return;
    setState(() => _submittingPlan = _plan);
    try {
      await widget.onUpgrade(_plan);
    } finally {
      if (mounted) setState(() => _submittingPlan = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.loading || _submittingPlan != null;
    return _SheetShell(
      title: '升级会员',
      subtitle: '解锁官方组织咨询权限',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BenefitRow(
              icon: Icons.chat_bubble_outline_rounded, label: '向官方组织发起线上会话'),
          const SizedBox(height: 10),
          const _BenefitRow(
              icon: Icons.storefront_outlined, label: '查看线下地址、电话和联系二维码'),
          const SizedBox(height: 10),
          const _BenefitRow(
              icon: Icons.description_outlined, label: '保留必要沟通与资料记录'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MembershipPlanTile(
                  title: '月度会员',
                  subtitle: '先体验咨询权限',
                  selected: _plan == 'monthly',
                  enabled: !busy,
                  onTap: () => setState(() => _plan = 'monthly'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MembershipPlanTile(
                  title: '年度会员',
                  subtitle: '长期申请周期',
                  selected: _plan == 'yearly',
                  enabled: !busy,
                  onTap: () => setState(() => _plan = 'yearly'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : _submit,
              icon: _submittingPlan == null
                  ? const Icon(Icons.verified_user_outlined, size: 18)
                  : const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
              label: Text(
                busy
                    ? '创建订单中...'
                    : _plan == 'monthly'
                        ? '开通月度会员'
                        : '开通年度会员',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kCobalt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '平台只做信息连接与记录，不代替官方组织作出录取、认证或服务承诺。',
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.42),
              fontSize: 11,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipPlanTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _MembershipPlanTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? kCobalt : context.artC.silver.withValues(alpha: 0.28);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? kCobalt.withValues(alpha: 0.08)
                : context.artC.porcelain,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 17,
                    color: selected
                        ? kCobalt
                        : context.artC.ink.withValues(alpha: 0.32),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? kCobalt : context.artC.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.48),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kCobalt.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: kCobalt, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SheetShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: context.artC.cardIconBg,
          borderRadius: BorderRadius.circular(28),
          border:
              Border.all(color: context.artC.silver.withValues(alpha: 0.24)),
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
                    color: context.artC.silver.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  color: context.artC.ink,
                  fontFamily: 'Noto Serif SC',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.44),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(icon, size: 42, color: context.artC.ink.withValues(alpha: 0.22)),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: context.artC.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.artC.ink.withValues(alpha: 0.42),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onTap,
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

String? _extractCity(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  const knownCities = ['北京', '上海', '广州', '深圳', '杭州', '伦敦', '纽约'];
  for (final city in knownCities) {
    if (text.contains(city)) return city;
  }
  return text.split(RegExp(r'[\s,，/]+')).first.trim();
}

List<({String? value, String label})> _cityFilterItems(String? currentCity) {
  final items = <({String? value, String label})>[
    (value: null, label: '全部'),
    (value: '北京', label: '北京'),
    (value: '上海', label: '上海'),
    (value: '广州', label: '广州'),
    (value: '深圳', label: '深圳'),
    (value: '杭州', label: '杭州'),
    (value: '伦敦', label: '伦敦'),
    (value: '纽约', label: '纽约'),
  ];
  final city = currentCity?.trim();
  if (city != null &&
      city.isNotEmpty &&
      !items.any((item) => item.value == city)) {
    items.insert(1, (value: city, label: city));
  }
  return items;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> _objectMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

double? _numberValue(Object? value) {
  if (value is num) return value.toDouble();
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return double.tryParse(text);
}

String _metadataText(
  Map<String, dynamic> org,
  List<String> keys, {
  String fallback = '',
}) {
  final metadata = _objectMap(org['metadata']);
  for (final key in keys) {
    final raw = metadata[key] ?? org[key];
    final text = raw?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return fallback;
}

String _organizationAddress(Map<String, dynamic> org) {
  final address = _metadataText(
    org,
    ['address', 'offline_address', 'offlineAddress', 'location'],
  );
  if (address.isNotEmpty) return address;
  final province = org['province']?.toString().trim() ?? '';
  final city = org['city']?.toString().trim() ?? '';
  return [
    if (province.isNotEmpty && province != city) province,
    if (city.isNotEmpty) city,
  ].join(' ');
}

String _organizationMapQuery(Map<String, dynamic> org) {
  final name = org['name']?.toString().trim() ?? '';
  final address = _organizationAddress(org);
  return [
    if (address.isNotEmpty) address,
    if (name.isNotEmpty) name,
  ].join(' ');
}

Future<bool> _openOrganizationMap(Map<String, dynamic> org) async {
  final name = org['name']?.toString().trim() ?? '官方组织';
  final lat = _numberValue(org['latitude']);
  final lon = _numberValue(org['longitude']);
  final query = _organizationMapQuery(org);
  final urls = <Uri>[];

  if (lat != null && lon != null) {
    final encodedName = Uri.encodeComponent(name);
    urls.add(Uri.parse('geo:$lat,$lon?q=$lat,$lon($encodedName)'));
    urls.add(Uri.https('maps.apple.com', '/', {
      'll': '$lat,$lon',
      'q': name,
    }));
    urls.add(Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$lat,$lon',
    }));
  }

  if (query.isNotEmpty) {
    urls.add(Uri.https('maps.apple.com', '/', {'q': query}));
    urls.add(Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    }));
  }

  for (final uri in urls) {
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return true;
    } catch (_) {}
  }
  return false;
}

List<Map<String, dynamic>> _metadataCards(
  Map<String, dynamic> org,
  List<String> keys,
) {
  final metadata = _objectMap(org['metadata']);
  for (final key in keys) {
    final raw = metadata[key] ?? org[key];
    final maps = _mapList(raw);
    if (maps.isNotEmpty) return maps;
    if (raw is List) {
      final cards = raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .map((item) => {'title': item})
          .toList();
      if (cards.isNotEmpty) return cards;
    }
  }
  return const [];
}

bool _organizationVerified(Map<String, dynamic> org) {
  final status = org['verification_status']?.toString().toLowerCase() ?? '';
  final active = org['status']?.toString().toLowerCase() == 'active';
  return active ||
      status == 'verified' ||
      status == 'approved' ||
      status == 'passed';
}

String _organizationTypeLabel(String? value) {
  const labels = {
    'official_association': '官方协会 / 行业组织',
    'industry_association': '行业协会',
    'academic_association': '学术协会',
    'school_official': '院校官方 / 招生部门',
    'official_partner': '官方合作组织',
    'public_institution': '公共机构',
    'study_abroad_agency': '留学服务（已下线）',
    'portfolio_training': '作品集服务（已下线）',
    'gallery_exhibition': '画廊 / 展览机构',
    'event_organizer': '活动主办方',
    'hotel_culture_space': '文旅空间',
    'brand_partner': '品牌合作方',
    'art_media_community': '艺术媒体 / 社群',
    'other_service': '艺术服务商',
  };
  final key = value?.trim();
  if (key == null || key.isEmpty) return '官方组织';
  return labels[key] ?? key;
}

String _organizationResponseSpeed(Map<String, dynamic> org) {
  final value = _metadataText(
    org,
    ['response_speed', 'response_time', 'reply_time'],
  );
  if (value.isNotEmpty) return value;
  if (org['supports_online'] != false) return '2小时内';
  return '24小时内';
}

List<Map<String, dynamic>> _organizationServices(Map<String, dynamic> org) {
  final fromMetadata = _metadataCards(org, ['services', 'service_items']);
  if (fromMetadata.isNotEmpty) return fromMetadata;
  final focus = _stringList(org['focus_areas']);
  final service = <Map<String, dynamic>>[
    {
      'title': '官方信息咨询',
      'description': '确认院校、活动、协会资源或申请节点的公开信息。',
      'mode': org['supports_online'] != false ? '线上咨询' : '线下沟通',
    },
    {
      'title': '项目与活动对接',
      'description': '了解公开项目、活动报名、合作资源和下一步联系路径。',
      'mode': '官方资源',
    },
  ];
  if (focus.contains('portfolio') || focus.contains('service_design')) {
    service.add({
      'title': '作品与项目展示建议',
      'description': '围绕官方项目要求，确认作品材料、展示节奏和提交注意事项。',
      'mode': '材料建议',
    });
  } else {
    service.add({
      'title': '负责人答疑',
      'description': '围绕官方信息、活动参与和资源匹配进行轻量咨询。',
      'mode': '快速咨询',
    });
  }
  return service;
}

List<Map<String, dynamic>> _organizationCases(
  Map<String, dynamic> org, {
  String? schoolName,
}) {
  final fromMetadata = _metadataCards(org, ['cases', 'case_studies']);
  if (fromMetadata.isNotEmpty) return fromMetadata;
  final school =
      schoolName?.trim().isNotEmpty == true ? schoolName!.trim() : '目标院校';
  return [
    {
      'title': '$school 官方信息整理',
      'description': '整理公开申请节点、项目资源和常见问题。',
      'result': '信息档案',
    },
    {
      'title': '活动与资源对接记录',
      'description': '沉淀活动报名、协会资源和合作沟通中的关键节点。',
      'result': '资源记录',
    },
  ];
}

List<Map<String, dynamic>> _organizationTeam(Map<String, dynamic> org) {
  final fromMetadata = _metadataCards(org, ['team', 'members', 'artists']);
  if (fromMetadata.isNotEmpty) return fromMetadata;
  final type = _organizationTypeLabel(org['type']?.toString());
  return [
    {
      'name': '项目负责人',
      'role': type,
      'bio': '负责官方信息确认、资源匹配和联系路径判断。',
    },
    {
      'name': '合作联系人',
      'role': '项目联络',
      'bio': '负责活动、项目或合作资源的沟通与跟进。',
    },
  ];
}

List<Map<String, dynamic>> _organizationActivities(Map<String, dynamic> org) {
  final fromMetadata = _metadataCards(org, ['activities', 'updates', 'posts']);
  if (fromMetadata.isNotEmpty) return fromMetadata;
  return [
    {
      'title': '官方组织主页已开放',
      'description': '服务、活动、团队和常见问题会持续更新，用户可从这里发起咨询。',
      'date': '最近更新',
    },
    {
      'title': '资源资料整理中',
      'description': '后续将补充更多官方活动、项目资源和合作艺术家信息。',
      'date': '动态',
    },
  ];
}

List<Map<String, dynamic>> _organizationQas(Map<String, dynamic> org) {
  final fromMetadata = _metadataCards(org, ['qas', 'faqs', 'questions']);
  if (fromMetadata.isNotEmpty) return fromMetadata;
  return const [
    {
      'question': '适合什么阶段的学生咨询？',
      'answer': '从刚开始了解院校、活动项目到临近申请，都可以先发起一次轻咨询确认官方信息。',
    },
    {
      'question': '咨询后会直接进入交易吗？',
      'answer': '不会。官方组织页先提供信息展示与轻沟通，后续合作由双方自行确认。',
    },
  ];
}

String _itemText(
  Map<String, dynamic> item,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = item[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return fallback;
}

String? _formatReviewDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return null;
  return '${date.month}月${date.day}日';
}

String _focusLabel(String value) {
  const labels = {
    'uk': '英国院校',
    'us': '美国院校',
    'portfolio': '作品材料',
    'rca': 'RCA',
    'service_design': '服务设计',
  };
  return labels[value] ?? value;
}

bool _isInternalCheckoutUrl(String value) {
  return value.startsWith('/orders/');
}

String _checkoutOrderId(Map<String, dynamic> checkout) {
  final direct = checkout['orderId']?.toString().trim() ?? '';
  if (direct.isNotEmpty) return direct;
  final order = checkout['order'];
  if (order is Map) return order['id']?.toString().trim() ?? '';
  return '';
}
