import 'package:flutter/material.dart';
import '../widgets/common.dart';
import 'create/create_post_screen.dart';
import 'home/home_screen.dart';
import 'news/news_scaffold.dart';
import 'explore/explore_screen.dart';
import 'forum/forum_screen.dart';
import 'profile/profile_screen.dart';
import 'tools/dot_chat_screen.dart';
import 'publish/publish_exhibition_screen.dart';
import 'publish/publish_opportunity_screen.dart';
import 'publish/publish_artist_screen.dart';
import 'workspace/gallery_workspace_screen.dart';
import 'workspace/general_business_workspace_screen.dart';
import 'workspace/institution_workspace_screen.dart';
import '../services/supabase_service.dart';
import '../services/backend_api_service.dart';
import '../utils/auth_gate.dart';
import '../utils/submission_review_feedback.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';
import '../widgets/deep_sea_ui.dart';

/// ═══════════════════════════════════════════════════════════════
/// artiqore 艺见心 — App 总入口
/// 当前主界面由院校频道 header 与各页面内入口承载导航。
/// ═══════════════════════════════════════════════════════════════

const _workspaceBusinessRoles = {
  'official_association',
  'official_partner',
  'school_official',
  'gallery_exhibition',
  'event_organizer',
  'hotel_culture_space',
  'brand_partner',
  'art_media_community',
  'other_service',
  'institution',
  'institution_user',
  'advisor',
};

const _institutionWorkspaceRoles = {
  'institution',
  'institution_user',
  'advisor',
};

const _retiredAgencyRoles = {
  'study_abroad_agency',
  'portfolio_training',
};

String _profileString(Map<String, dynamic>? profile, String key) {
  return profile?[key]?.toString() ?? '';
}

bool usesWorkspaceTabForProfile(
  Map<String, dynamic>? profile, {
  bool hasOrganizationMembership = false,
}) {
  final userType = _profileString(profile, 'user_type');
  final userRole = _profileString(profile, 'user_role');
  final systemRole = _profileString(profile, 'role');
  if (_retiredAgencyRoles.contains(userRole) && !hasOrganizationMembership) {
    return false;
  }
  final hasCurrentWorkspaceRole = _workspaceBusinessRoles.contains(userRole) ||
      systemRole == 'institution_user' ||
      systemRole == 'advisor';
  return userType == 'institution' ||
      hasOrganizationMembership ||
      hasCurrentWorkspaceRole;
}

String workspaceRoleForProfile(Map<String, dynamic>? profile) {
  final userRole = _profileString(profile, 'user_role');
  if (userRole.isNotEmpty) return userRole;
  final systemRole = _profileString(profile, 'role');
  if (systemRole.isNotEmpty) return systemRole;
  return _profileString(profile, 'user_type');
}

String workspaceSurfaceForProfile(
  Map<String, dynamic>? profile, {
  bool hasOrganizationMembership = false,
}) {
  if (!usesWorkspaceTabForProfile(
    profile,
    hasOrganizationMembership: hasOrganizationMembership,
  )) {
    return 'school';
  }
  final role = workspaceRoleForProfile(profile);
  if (role == 'gallery_exhibition') return 'gallery_workspace';
  if (_institutionWorkspaceRoles.contains(role)) {
    return 'institution_workspace';
  }
  return 'general_business_workspace';
}

List<String> mainNavigationLabelsForProfile(
  Map<String, dynamic>? profile, {
  bool hasOrganizationMembership = false,
}) {
  if (usesWorkspaceTabForProfile(
    profile,
    hasOrganizationMembership: hasOrganizationMembership,
  )) {
    return const ['工作台', '发现', '消息', '我的'];
  }
  return const ['院校', '发现', '消息', '我的'];
}

class MainScaffold extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;

  const MainScaffold({super.key, this.initialProfile});

  static final GlobalKey<_MainScaffoldState> globalKey =
      GlobalKey<_MainScaffoldState>();

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  static const double _headerHeight = 64;
  int _currentIndex = 1;
  bool _homeNavHidden = false;
  bool _profileDrawerOpen = false;
  bool _hasOrganizationMembership = false;
  Map<String, dynamic>? _profile;
  final GlobalKey<NewsScaffoldState> _newsKey = GlobalKey<NewsScaffoldState>();
  final GlobalKey<ExploreScreenState> _exploreKey =
      GlobalKey<ExploreScreenState>();
  final GlobalKey<ForumScreenState> _forumKey = GlobalKey<ForumScreenState>();

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProfile != oldWidget.initialProfile) {
      _profile = widget.initialProfile;
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    if (!SupabaseService.isLoggedIn) {
      if (mounted && (_profile != null || _hasOrganizationMembership)) {
        setState(() {
          _profile = null;
          _hasOrganizationMembership = false;
        });
      }
      return;
    }
    try {
      final profile = await SupabaseService.fetchProfile();
      var hasOrganizationMembership = false;
      try {
        final organizations =
            await BackendApiService.fetchMyOrganizations(limit: 1);
        hasOrganizationMembership =
            (organizations.count ?? organizations.data.length) > 0;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _hasOrganizationMembership = hasOrganizationMembership;
      });
    } catch (_) {
      // Navigation should not block the app if profile fetch is temporarily unavailable.
    }
  }

  void switchToTab(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
        if (index != 0) _homeNavHidden = false;
        if (index != 4) _profileDrawerOpen = false;
      });
    }
  }

  void openSchoolApplicationPlanTab() {
    if (!mounted) return;
    setState(() {
      _currentIndex = 1;
      _homeNavHidden = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newsKey.currentState?.openApplicationPlanTab();
    });
  }

  void setHomeNavHidden(bool hidden) {
    if (!mounted || _homeNavHidden == hidden) return;
    setState(() => _homeNavHidden = hidden);
  }

  void _setProfileDrawerOpen(bool open) {
    if (!mounted || _profileDrawerOpen == open) return;
    setState(() => _profileDrawerOpen = open);
  }

  List<_NavItem> get _navItems => _usesWorkspaceTab
      ? const [
          _NavItem(
            tabIndex: 1,
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: '工作台',
          ),
          _NavItem(
            tabIndex: 2,
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore_rounded,
            label: '发现',
          ),
          _NavItem(
            tabIndex: 3,
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble_rounded,
            label: '消息',
          ),
          _NavItem(
            tabIndex: 4,
            icon: Icons.person_outline,
            activeIcon: Icons.person_rounded,
            label: '我的',
          ),
        ]
      : const [
          _NavItem(
            tabIndex: 1,
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: '院校',
          ),
          _NavItem(
            tabIndex: 2,
            icon: Icons.explore_outlined,
            activeIcon: Icons.explore_rounded,
            label: '发现',
          ),
          _NavItem(
            tabIndex: 3,
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: '消息',
          ),
          _NavItem(
            tabIndex: 4,
            icon: Icons.person_outline,
            activeIcon: Icons.person_rounded,
            label: '我的',
          ),
        ];

  bool get _usesWorkspaceTab {
    return usesWorkspaceTabForProfile(
      _profile,
      hasOrganizationMembership: _hasOrganizationMembership,
    );
  }

  bool get _shouldShowTopHeader => false;

  String get _workspaceRole {
    return workspaceRoleForProfile(_profile);
  }

  bool get _usesInstitutionWorkspace {
    return _institutionWorkspaceRoles.contains(_workspaceRole);
  }

  Widget _buildWorkspaceScreen() {
    final role = _workspaceRole;
    if (role == 'gallery_exhibition') {
      return GalleryWorkspaceScreen(profile: _profile);
    }
    if (_usesInstitutionWorkspace) {
      return InstitutionWorkspaceScreen(profile: _profile);
    }
    return GeneralBusinessWorkspaceScreen(profile: _profile);
  }

  String get _workspaceSearchHint {
    if (_workspaceRole == 'gallery_exhibition') {
      return '搜索展览、艺术家、合作机会';
    }
    if (_usesInstitutionWorkspace) {
      return '搜索线索、预约、订单';
    }
    return '搜索合作机会、活动、品牌项目';
  }

  Future<void> _openCreatePost() async {
    if (!await ensureLoggedIn(context, message: '请先登录后发布图文')) return;
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (!mounted || created != true) return;
    if (_currentIndex == 2) {
      _exploreKey.currentState?.refreshActiveTab();
    }
    if (_currentIndex == 3) {
      _forumKey.currentState?.refreshActiveTab();
    }
  }

  Future<void> _openCommunityDialog(_CommunityCreateKind kind) async {
    if (!await ensureLoggedIn(context, message: '请先登录后发布社区内容')) return;
    if (kind == _CommunityCreateKind.circle) {
      await _openCreateCircleSheet();
      return;
    }
    if (kind == _CommunityCreateKind.salon) {
      await _openCreateSalonSheet();
      return;
    }
    final titleCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    final labels = switch (kind) {
      _CommunityCreateKind.market => (
          '发布市集商品',
          '商品标题',
          '商品分类',
          '城市/地区',
          '商品说明',
          '价格/条件'
        ),
      _CommunityCreateKind.circle => (
          '创建圈子',
          '圈子名称',
          '圈子分类',
          '城市/地区',
          '圈子简介',
          '预算'
        ),
      _CommunityCreateKind.salon => (
          '创建沙龙',
          '沙龙标题',
          '沙龙类型',
          '城市',
          '地点/活动说明',
          '费用'
        ),
    };
    if (kind == _CommunityCreateKind.market) {
      typeCtrl.text = '艺术';
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (!formKey.currentState!.validate() || submitting) return;
            setDialogState(() => submitting = true);
            try {
              if (kind == _CommunityCreateKind.market) {
                final category = typeCtrl.text.trim();
                await BackendApiService.createPlazaPost(
                  title: titleCtrl.text.trim(),
                  body: noteCtrl.text.trim(),
                  kind: 'market',
                  group: category.isEmpty ? '艺术' : category,
                  tags: [
                    if (category.isNotEmpty) category,
                    if (cityCtrl.text.trim().isNotEmpty) cityCtrl.text.trim(),
                  ],
                  metadata: {
                    'kind': 'market',
                    'category': category.isEmpty ? '艺术' : category,
                    'source': 'market_resource',
                    'city': cityCtrl.text.trim(),
                    'price': amountCtrl.text.trim(),
                  },
                );
              } else if (kind == _CommunityCreateKind.circle) {
                await BackendApiService.createCommunityCircle({
                  'title': titleCtrl.text.trim(),
                  'subtitle': noteCtrl.text.trim(),
                  'category': typeCtrl.text.trim().isEmpty
                      ? 'art'
                      : typeCtrl.text.trim(),
                  'city': cityCtrl.text.trim(),
                });
              } else {
                await BackendApiService.createEvent({
                  'title': titleCtrl.text.trim(),
                  'type': 'salon',
                  'city': cityCtrl.text.trim(),
                  'venue': noteCtrl.text.trim(),
                  'summary': typeCtrl.text.trim(),
                  if (int.tryParse(amountCtrl.text.trim()) != null)
                    'fee_amount': int.parse(amountCtrl.text.trim()),
                });
              }
              if (!mounted) return;
              Navigator.of(dialogContext).pop();
              if (_currentIndex == 2) {
                _exploreKey.currentState?.refreshActiveTab();
              }
              if (_currentIndex == 3) {
                _forumKey.currentState?.refreshActiveTab();
              }
              final successText = kind == _CommunityCreateKind.market
                  ? '商品已提交审核，通过后会展示到市集'
                  : '${labels.$1}成功';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(successText)),
              );
            } catch (e) {
              if (!mounted) return;
              setDialogState(() => submitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('提交失败：$e')),
              );
            }
          }

          return AlertDialog(
            title: Text(labels.$1),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ResourceTextField(
                      controller: titleCtrl,
                      label: labels.$2,
                      required: true,
                    ),
                    _ResourceTextField(controller: typeCtrl, label: labels.$3),
                    _ResourceTextField(controller: cityCtrl, label: labels.$4),
                    _ResourceTextField(
                      controller: noteCtrl,
                      label: labels.$5,
                      maxLines: 3,
                    ),
                    if (kind == _CommunityCreateKind.market ||
                        kind == _CommunityCreateKind.salon)
                      _ResourceTextField(
                        controller: amountCtrl,
                        label: labels.$6,
                        keyboardType: kind == _CommunityCreateKind.salon
                            ? TextInputType.number
                            : TextInputType.text,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    submitting ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submitting ? null : submit,
                child: Text(submitting ? '提交中' : '发布'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      titleCtrl.dispose();
      typeCtrl.dispose();
      cityCtrl.dispose();
      noteCtrl.dispose();
      amountCtrl.dispose();
    });
  }

  Future<void> _openCreateCircleSheet() async {
    if (!await ensureLoggedIn(context, message: '请先登录后创建圈子')) return;
    final nameCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    final introCtrl = TextEditingController();
    final directions = <String>{};
    const directionOptions = ['留学', '作品集', '同城', '就业', '市场'];
    var joinType = 'open';
    var submitting = false;
    var nameError = '';
    var directionError = '';
    var placeError = '';
    var introError = '';

    bool validate(void Function(void Function()) setSheetState) {
      final name = nameCtrl.text.trim();
      final intro = introCtrl.text.trim();
      final place = placeCtrl.text.trim();
      setSheetState(() {
        nameError = '';
        directionError = '';
        placeError = '';
        introError = '';
        if (name.isEmpty) {
          nameError = '请输入圈子名称';
        } else if (name.length < 4 || name.length > 24) {
          nameError = '圈子名称需为 4-24 个字';
        } else if (['艺术交流群', '交流群', '艺术圈'].contains(name)) {
          nameError = '名称再具体一点，会更容易吸引同方向用户';
        }
        if (directions.isEmpty) {
          directionError = '请选择至少一个方向';
        }
        if (directions.contains('同城') && place.isEmpty) {
          placeError = '同城圈子需要填写城市或地区';
        }
        if (intro.length < 10) {
          introError = '简介再具体一点，至少 10 个字';
        }
      });
      return nameError.isEmpty &&
          directionError.isEmpty &&
          placeError.isEmpty &&
          introError.isEmpty;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit() async {
            if (submitting || !validate(setSheetState)) return;
            setSheetState(() => submitting = true);
            final name = nameCtrl.text.trim();
            final intro = introCtrl.text.trim();
            final place = placeCtrl.text.trim();
            final primaryDirection = directions.first;
            try {
              await BackendApiService.createCommunityCircle({
                'title': name,
                'subtitle': intro,
                'category': primaryDirection,
                'city': place.isEmpty ? null : place,
                'metadata': {
                  'directions': directions.toList(),
                  'join_type': joinType,
                  'tags': [
                    ...directions.map((item) => '#$item'),
                    if (place.isNotEmpty) '#$place',
                  ],
                  'hot_topic': '发布第一条讨论，开启圈子交流',
                  'announcement':
                      '欢迎来到$name。这里适合交流${directions.join('、')}相关经验、资源和机会。请保持专业、尊重原创。',
                },
              });
              if (!mounted || !sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('圈子已创建，你可以发布第一条动态或邀请同方向用户加入'),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              setSheetState(() => submitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('创建失败：$e')),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: context.artC.porcelain,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.artC.silver.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        Text(
                          '创建圈子',
                          style: TextStyle(
                            color: context.artC.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Noto Serif SC',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '建立一个面向专业方向、学校或城市的艺术社群。',
                          style: TextStyle(
                            color: context.artC.ink.withOpacity(0.48),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _CircleCreateTextField(
                          controller: nameCtrl,
                          label: '圈子名称',
                          hint: '例如：RCA 作品集互助圈',
                          maxLength: 24,
                          error: nameError,
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateSection(
                          title: '方向',
                          error: directionError,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: directionOptions
                                .map(
                                  (item) => _CircleCreateChip(
                                    label: item,
                                    selected: directions.contains(item),
                                    onTap: () {
                                      setSheetState(() {
                                        if (directions.contains(item)) {
                                          directions.remove(item);
                                        } else if (directions.length < 2) {
                                          directions.add(item);
                                        } else {
                                          directions
                                            ..clear()
                                            ..add(item);
                                        }
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateSection(
                          title: '加入方式',
                          child: Row(
                            children: [
                              Expanded(
                                child: _CircleJoinModeCard(
                                  title: '开放加入',
                                  subtitle: '任何人都可以直接加入',
                                  selected: joinType == 'open',
                                  onTap: () =>
                                      setSheetState(() => joinType = 'open'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _CircleJoinModeCard(
                                  title: '申请加入',
                                  subtitle: '需要圈主审核',
                                  selected: joinType == 'approval',
                                  onTap: () => setSheetState(
                                    () => joinType = 'approval',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateTextField(
                          controller: placeCtrl,
                          label: '城市 / 学校 / 地区（可选）',
                          hint: '例如：伦敦、RCA、UAL',
                          error: placeError,
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateTextField(
                          controller: introCtrl,
                          label: '圈子简介',
                          hint: '这个圈子适合谁？大家可以在这里交流什么？',
                          maxLines: 4,
                          maxLength: 120,
                          error: introError,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: submitting
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: submitting ? null : submit,
                          child: Text(submitting ? '创建中' : '创建圈子'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      nameCtrl.dispose();
      placeCtrl.dispose();
      introCtrl.dispose();
    });
  }

  Future<void> _openCreateSalonSheet() async {
    if (!await ensureLoggedIn(context, message: '请先登录后创建沙龙')) return;
    if (!mounted) return;
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    final guestCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final seatsCtrl = TextEditingController(text: '8');
    const salonTypes = ['留学答疑', '作品集诊断', '校友分享', '行业就业', '艺术市场'];
    var salonType = '作品集诊断';
    var mode = '线下';
    var feeMode = 'free';
    var submitting = false;
    var titleError = '';
    var timeError = '';
    var venueError = '';
    var guestError = '';
    var descError = '';
    var amountError = '';
    var seatsError = '';

    bool validate(void Function(void Function()) setSheetState) {
      final title = titleCtrl.text.trim();
      final start = _parseSalonDateTime(timeCtrl.text.trim());
      final venue = venueCtrl.text.trim();
      final guest = guestCtrl.text.trim();
      final desc = descCtrl.text.trim();
      final amount = int.tryParse(amountCtrl.text.trim());
      final seats = int.tryParse(seatsCtrl.text.trim());
      setSheetState(() {
        titleError = '';
        timeError = '';
        venueError = '';
        guestError = '';
        descError = '';
        amountError = '';
        seatsError = '';
        if (title.length < 6 || title.length > 40) {
          titleError = '标题需为 6-40 个字';
        }
        if (start == null) {
          timeError = '请按 2026-06-22 19:00 格式填写时间';
        }
        if (venue.isEmpty) {
          venueError = mode == '线上' ? '请填写会议链接或待定' : '请填写地点';
        }
        if (guest.length < 3) {
          guestError = '请填写嘉宾或主讲人';
        }
        if (desc.length < 12) {
          descError = '活动说明再具体一点，至少 12 个字';
        }
        if (feeMode == 'paid' && (amount == null || amount <= 0)) {
          amountError = '请填写有效金额';
        }
        if (seats == null || seats <= 0) {
          seatsError = '请填写有效席位数';
        }
      });
      return titleError.isEmpty &&
          timeError.isEmpty &&
          venueError.isEmpty &&
          guestError.isEmpty &&
          descError.isEmpty &&
          amountError.isEmpty &&
          seatsError.isEmpty;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit() async {
            if (submitting || !validate(setSheetState)) return;
            setSheetState(() => submitting = true);
            final start = _parseSalonDateTime(timeCtrl.text.trim())!;
            final seats = int.parse(seatsCtrl.text.trim());
            final amount =
                feeMode == 'paid' ? int.parse(amountCtrl.text.trim()) : 0;
            final title = titleCtrl.text.trim();
            final desc = descCtrl.text.trim();
            final guest = guestCtrl.text.trim();
            final venue = venueCtrl.text.trim();
            try {
              final created = await BackendApiService.createEvent({
                'title': title,
                'type': 'salon',
                'city':
                    cityCtrl.text.trim().isEmpty ? mode : cityCtrl.text.trim(),
                'venue': venue,
                'summary': desc,
                'description': desc,
                'start_time': start.toIso8601String(),
                'quota': seats,
                'fee_amount': amount,
                'currency': 'cny',
                'metadata': {
                  'salon_type': salonType,
                  'mode': mode,
                  'guest': guest,
                  'fee_mode': feeMode,
                  'seats_left': seats,
                  'benefit': _salonCreateBenefit(salonType, feeMode),
                },
              });
              if (!mounted || !sheetContext.mounted) return;
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(sheetContext).pop();
              if (created['status']?.toString() == 'published') {
                _exploreKey.currentState?.refreshActiveTab();
                messenger.showSnackBar(
                  const SnackBar(content: Text('沙龙已创建，可以在发现页“活动”中查看')),
                );
              } else {
                showSubmissionReviewSnackBar(
                  messenger: messenger,
                  navigator: navigator,
                  message: '沙龙已提交审核，审核通过后展示',
                );
              }
            } catch (e) {
              if (!mounted) return;
              setSheetState(() => submitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('创建失败：$e')),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: context.artC.porcelain,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.artC.silver.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        Text(
                          '创建沙龙',
                          style: TextStyle(
                            color: context.artC.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Noto Serif SC',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '创建一场面向艺术申请、作品集或行业交流的活动。',
                          style: TextStyle(
                            color: context.artC.ink.withOpacity(0.48),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _CircleCreateTextField(
                          controller: titleCtrl,
                          label: '沙龙标题',
                          hint: '例如：RISD 校友作品集分享会',
                          maxLength: 40,
                          error: titleError,
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateSection(
                          title: '活动类型',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: salonTypes
                                .map(
                                  (item) => _CircleCreateChip(
                                    label: item,
                                    selected: salonType == item,
                                    onTap: () =>
                                        setSheetState(() => salonType = item),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateTextField(
                          controller: timeCtrl,
                          label: '活动时间',
                          hint: '例如：2026-06-22 19:00',
                          error: timeError,
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateSection(
                          title: '举办方式',
                          child: Row(
                            children: ['线下', '线上', '混合']
                                .map(
                                  (item) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _CircleCreateChip(
                                        label: item,
                                        selected: mode == item,
                                        onTap: () =>
                                            setSheetState(() => mode = item),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateTextField(
                          controller: cityCtrl,
                          label: '城市',
                          hint: '例如：纽约、伦敦（线上活动可留空）',
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateTextField(
                          controller: venueCtrl,
                          label: '地点 / 链接',
                          hint: '例如：Brooklyn Art Space / Zoom 链接待定',
                          error: venueError,
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateTextField(
                          controller: guestCtrl,
                          label: '嘉宾 / 主讲人',
                          hint: '例如：RISD 工业设计校友',
                          error: guestError,
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateTextField(
                          controller: descCtrl,
                          label: '活动说明',
                          hint: '适合谁？分享什么？参与者能获得什么？',
                          maxLines: 4,
                          maxLength: 160,
                          error: descError,
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateSection(
                          title: '费用',
                          error: amountError,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ('free', '免费'),
                                  ('invite', '邀请制'),
                                  ('paid', '付费'),
                                ]
                                    .map(
                                      (item) => Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: _CircleCreateChip(
                                            label: item.$2,
                                            selected: feeMode == item.$1,
                                            onTap: () => setSheetState(
                                              () => feeMode = item.$1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              if (feeMode == 'paid') ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: amountCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '金额，例如：2500',
                                    filled: true,
                                    fillColor: context.artC.cardIconBg
                                        .withOpacity(0.72),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: context.artC.silver
                                            .withOpacity(0.36),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: context.artC.silver
                                            .withOpacity(0.32),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: kCobalt,
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CircleCreateTextField(
                          controller: seatsCtrl,
                          label: '席位',
                          hint: '例如：8',
                          error: seatsError,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: submitting
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: submitting ? null : submit,
                          child: Text(submitting ? '创建中' : '创建沙龙'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      titleCtrl.dispose();
      timeCtrl.dispose();
      cityCtrl.dispose();
      venueCtrl.dispose();
      guestCtrl.dispose();
      descCtrl.dispose();
      amountCtrl.dispose();
      seatsCtrl.dispose();
    });
  }

  Future<void> _showCreateSheet() async {
    if (!await ensureLoggedIn(context, message: '请先登录后发布资源')) return;
    if (!mounted) return;
    final primarySection = _primaryCreateSection;
    final sections = _orderedCreateSections();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭发布菜单',
      barrierColor: Colors.black.withValues(alpha: 0.58),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final bottomInset = MediaQuery.paddingOf(dialogContext).bottom;
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: bottomInset + 22,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCreateFloatingOptions(
                      dialogContext,
                      sections: sections,
                      primarySection: primarySection,
                    ),
                    const SizedBox(height: 18),
                    _buildCreateCloseButton(dialogContext),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  _CreateSectionKind get _primaryCreateSection {
    if (_currentIndex != 2) return _CreateSectionKind.cooperation;
    return switch (_exploreKey.currentState?.activeTabIndex ?? 0) {
      1 => _CreateSectionKind.activity,
      2 || 3 => _CreateSectionKind.circle,
      _ => _CreateSectionKind.cooperation,
    };
  }

  List<_CreateSheetSection> _orderedCreateSections() {
    const sections = [
      _CreateSheetSection(
        kind: _CreateSectionKind.cooperation,
        actions: [
          _CreateSheetAction(
            kind: _CreateActionKind.opportunity,
            icon: Icons.business_center_outlined,
            label: '发布合作',
            subtitle: '招募 / 征集 / 驻留 / 委托',
          ),
        ],
      ),
      _CreateSheetSection(
        kind: _CreateSectionKind.activity,
        actions: [
          _CreateSheetAction(
            kind: _CreateActionKind.exhibition,
            icon: Icons.grid_view_rounded,
            label: '发布活动',
            subtitle: '展览 / 沙龙 / 工作坊 / 开放日',
          ),
        ],
      ),
      _CreateSheetSection(
        kind: _CreateSectionKind.circle,
        actions: [
          _CreateSheetAction(
            kind: _CreateActionKind.post,
            icon: Icons.add_photo_alternate_outlined,
            label: '发布动态',
            subtitle: '作品 / 现场 / 灵感记录',
          ),
          _CreateSheetAction(
            kind: _CreateActionKind.question,
            icon: Icons.storefront_outlined,
            label: '发布商品',
            subtitle: '艺术 / 工艺 / 出版 / 定制',
          ),
        ],
      ),
    ];

    return sections;
  }

  Widget _buildCreateFloatingOptions(
    BuildContext dialogContext, {
    required List<_CreateSheetSection> sections,
    required _CreateSectionKind primarySection,
  }) {
    final availableWidth =
        (MediaQuery.sizeOf(dialogContext).width - 40).clamp(280.0, 620.0);
    final tileWidth = (availableWidth - 12) / 2;

    return Center(
      child: SizedBox(
        width: availableWidth,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final section in sections)
              for (final action in section.actions)
                SizedBox(
                  width: tileWidth,
                  height: 82,
                  child: _buildSheetOption(
                    icon: action.icon,
                    label: action.label,
                    subtitle: action.subtitle,
                    emphasized: section.kind == primarySection,
                    onTap: () => _handleCreateAction(
                      dialogContext,
                      action.kind,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCloseButton(BuildContext dialogContext) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(dialogContext).pop(),
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(
            Icons.close_rounded,
            size: 29,
            color: context.artC.ink.withValues(alpha: 0.82),
          ),
        ),
      ),
    );
  }

  void _handleCreateAction(
    BuildContext sheetContext,
    _CreateActionKind action,
  ) {
    Navigator.of(sheetContext).pop();
    switch (action) {
      case _CreateActionKind.opportunity:
        _openResourceDialog(_ResourceKind.opportunity);
        break;
      case _CreateActionKind.exhibition:
        _openResourceDialog(_ResourceKind.event);
        break;
      case _CreateActionKind.question:
        if (_currentIndex == 2 &&
            _exploreKey.currentState?.activeTabIndex == 3) {
          _openCommunityDialog(_CommunityCreateKind.market);
          break;
        }
        _openCreatePost();
        break;
      case _CreateActionKind.post:
        _openCreatePost();
        break;
    }
  }

  Future<void> _openResourceDialog(_ResourceKind kind) async {
    if (!await ensureLoggedIn(context, message: '请先登录后发布资源')) return;
    if (!mounted) return;
    if (kind == _ResourceKind.event) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const PublishExhibitionScreen(),
          fullscreenDialog: true,
        ),
      );
      if (result == true && _currentIndex == 2) {
        _exploreKey.currentState?.refreshActiveTab();
      }
      return;
    }

    if (kind == _ResourceKind.opportunity) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const PublishOpportunityScreen(),
          fullscreenDialog: true,
        ),
      );
      if (result == true && _currentIndex == 2) {
        _exploreKey.currentState?.refreshActiveTab();
      }
      return;
    }

    if (kind == _ResourceKind.artist) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const PublishArtistScreen(),
          fullscreenDialog: true,
        ),
      );
      if (result == true && _currentIndex == 2) {
        _exploreKey.currentState?.refreshActiveTab();
      }
      return;
    }

    final titleCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    final labels = switch (kind) {
      _ResourceKind.opportunity => ('发布合作', '机会标题', '类型', '城市', '需求说明', '预算上限'),
      _ResourceKind.event => ('发布活动', '活动标题', '类型', '城市', '地点/场馆', '费用'),
      _ResourceKind.artist => (
          '艺术家入驻',
          '显示名称',
          '艺术方向',
          '城市',
          '履历/合作意向',
          '合作预算'
        ),
    };

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (!formKey.currentState!.validate() || submitting) return;
            setDialogState(() => submitting = true);
            try {
              if (kind == _ResourceKind.opportunity) {
                await BackendApiService.createOpportunity({
                  'title': titleCtrl.text.trim(),
                  'type': typeCtrl.text.trim().isEmpty
                      ? 'collaboration'
                      : typeCtrl.text.trim(),
                  'city': cityCtrl.text.trim(),
                  'requirements': noteCtrl.text.trim(),
                  if (int.tryParse(amountCtrl.text.trim()) != null)
                    'budget_max': int.parse(amountCtrl.text.trim()),
                });
              } else if (kind == _ResourceKind.event) {
                await BackendApiService.createEvent({
                  'title': titleCtrl.text.trim(),
                  'type': typeCtrl.text.trim().isEmpty
                      ? 'exhibition'
                      : typeCtrl.text.trim(),
                  'city': cityCtrl.text.trim(),
                  'venue': noteCtrl.text.trim(),
                  if (int.tryParse(amountCtrl.text.trim()) != null)
                    'fee_amount': int.parse(amountCtrl.text.trim()),
                });
              } else {
                await BackendApiService.upsertArtistProfile({
                  'display_name': titleCtrl.text.trim(),
                  'art_fields': typeCtrl.text
                      .split(RegExp(r'[,，/、]'))
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  'experience': noteCtrl.text.trim(),
                  'cooperation_intent': cityCtrl.text.trim(),
                  'status': 'reviewing',
                });
              }
              if (!mounted || !dialogContext.mounted) return;
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(dialogContext).pop();
              if (_currentIndex == 2) {
                _exploreKey.currentState?.refreshActiveTab();
              }
              showSubmissionReviewSnackBar(
                messenger: messenger,
                navigator: navigator,
                message: '${labels.$1}已提交审核',
              );
            } catch (e) {
              if (!mounted) return;
              setDialogState(() => submitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('提交失败：$e')),
              );
            }
          }

          return AlertDialog(
            title: Text(labels.$1),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ResourceTextField(
                        controller: titleCtrl,
                        label: labels.$2,
                        required: true),
                    _ResourceTextField(controller: typeCtrl, label: labels.$3),
                    _ResourceTextField(controller: cityCtrl, label: labels.$4),
                    _ResourceTextField(
                        controller: noteCtrl, label: labels.$5, maxLines: 3),
                    if (kind != _ResourceKind.artist)
                      _ResourceTextField(
                        controller: amountCtrl,
                        label: labels.$6,
                        keyboardType: TextInputType.number,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    submitting ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submitting ? null : submit,
                child: Text(submitting ? '提交中' : '发布'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      titleCtrl.dispose();
      typeCtrl.dispose();
      cityCtrl.dispose();
      noteCtrl.dispose();
      amountCtrl.dispose();
    });
  }

  Widget _buildSheetOption({
    required IconData icon,
    required String label,
    String? subtitle,
    bool emphasized = false,
    required VoidCallback onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: context.artC.ink,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: emphasized ? const Color(0xFFEAF1FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: emphasized
                ? kCobalt.withValues(alpha: 0.46)
                : Colors.white.withValues(alpha: 0.92),
            width: emphasized ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: emphasized ? 0.16 : 0.11),
              blurRadius: emphasized ? 22 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: emphasized ? kCobalt : kCobalt.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: emphasized ? Colors.white : kCobalt,
                size: 19,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: context.artC.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: context.artC.ink.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDotChatRoute() {
    return _pushDotChatRoute();
  }

  Future<void> _pushDotChatRoute({String? initialQuery}) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (routeContext, animation, secondaryAnimation) =>
            DotChatScreen(initialQuery: initialQuery),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isSchoolSurface = _currentIndex == 1 && !_usesWorkspaceTab;
    final isDiscoverSurface = _currentIndex == 2;
    final isMessageSurface = _currentIndex == 3;
    final isProfileSurface = _currentIndex == 4;
    final showTopHeader = _shouldShowTopHeader;
    final contentTop = _currentIndex == 0 ||
            isSchoolSurface ||
            isDiscoverSurface ||
            isMessageSurface ||
            isProfileSurface
        ? 0.0
        : statusBarHeight + (showTopHeader ? _headerHeight : 0);
    final hideFloatingNav = _homeNavHidden || _profileDrawerOpen;

    return Scaffold(
      backgroundColor: context.artC.porcelain,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: contentTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: IndexedStack(
              index: _currentIndex,
              children: [
                HomeScreen(showWorkbenchShortcut: _usesWorkspaceTab),
                _usesWorkspaceTab
                    ? _buildWorkspaceScreen()
                    : NewsScaffold(
                        key: _newsKey,
                      ),
                ExploreScreen(
                  key: _exploreKey,
                  onCreateTap: _showCreateSheet,
                  onTabChanged: () {
                    if (mounted) setState(() {});
                  },
                ),
                ForumScreen(
                  key: _forumKey,
                  onTabChanged: () {
                    if (mounted) setState(() {});
                  },
                ),
                ProfileScreen(
                  onOpenMainTab: switchToTab,
                  onDrawerChanged: _setProfileDrawerOpen,
                ),
              ],
            ),
          ),
          if (showTopHeader)
            Positioned(
              top: statusBarHeight,
              left: 0,
              right: 0,
              child: _TopHeader(
                showCreateIcon: _currentIndex == 2 || _currentIndex == 3,
                searchHint: _headerSearchHint,
                searchValue: _headerSearchValue,
                actionIcon: _headerActionIcon,
                actionLabel: _headerActionLabel,
                onSearchSubmit: _handleHeaderSearch,
                onActionTap: _handleHeaderAction,
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: hideFloatingNav ? -88 : 0,
            child: IgnorePointer(
              ignoring: hideFloatingNav,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: hideFloatingNav ? 0 : 1,
                child: Material(
                  color: Colors.transparent,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Center(child: _buildFloatingNav()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNav() {
    final leadingItems = _navItems.take(2);
    final trailingItems = _navItems.skip(2);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: DeepSeaGlassPanel(
        padding: const EdgeInsets.all(5),
        radius: 32,
        opacity: 0.48,
        airy: true,
        child: Row(
          children: [
            ...leadingItems.map(_buildNavButtonSlot),
            Expanded(child: _AiNavButton(onTap: _openDotChatRoute)),
            ...trailingItems.map(_buildNavButtonSlot),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButtonSlot(_NavItem item) {
    return Expanded(
      child: _NavButton(
        item: item,
        isSelected: _currentIndex == item.tabIndex,
        onTap: () {
          setState(() {
            _currentIndex = item.tabIndex;
            _homeNavHidden = false;
            if (item.tabIndex != 4) _profileDrawerOpen = false;
          });
          if (item.tabIndex == 1 || item.tabIndex == 4) _loadProfile();
        },
      ),
    );
  }

  void _handleHeaderSearch(String keyword) {
    if (_currentIndex == 1 && !_usesWorkspaceTab) {
      _newsKey.currentState?.setSchoolSearchKeyword(keyword);
    } else if (_currentIndex == 2) {
      _exploreKey.currentState?.applySearch(keyword);
    } else if (_currentIndex == 3) {
      _forumKey.currentState?.applySearch(keyword);
    }
    if (mounted) setState(() {});
  }

  void _handleHeaderAction() {
    if (_currentIndex == 2) {
      _showCreateSheet();
    } else if (_currentIndex == 3) {
      _handleCommunityHeaderAction();
    }
  }

  String get _headerSearchHint {
    if (_currentIndex == 1) {
      return _usesWorkspaceTab ? _workspaceSearchHint : '搜索 RCA、插画、伦敦';
    }
    if (_currentIndex == 2) {
      return _exploreKey.currentState?.searchHint ?? '搜索合作、活动、圈子';
    }
    if (_currentIndex == 3) {
      return _forumKey.currentState?.searchHint ?? '搜索消息、联系人、通知';
    }
    return '搜索院校、灵感、作品集问题';
  }

  String get _headerSearchValue {
    if (_currentIndex == 1 && !_usesWorkspaceTab) {
      return _newsKey.currentState?.schoolSearchKeyword ?? '';
    }
    if (_currentIndex == 2) {
      return _exploreKey.currentState?.searchKeyword ?? '';
    }
    if (_currentIndex == 3) {
      return _forumKey.currentState?.searchKeyword ?? '';
    }
    return '';
  }

  IconData? get _headerActionIcon {
    if (_currentIndex == 1) {
      return null;
    }
    if (_currentIndex == 3) {
      return _forumKey.currentState?.actionIcon ?? Icons.add_rounded;
    }
    return Icons.add_rounded;
  }

  void _handleCommunityHeaderAction() {
    _forumKey.currentState?.refreshActiveTab();
  }

  String? get _headerActionLabel {
    return null;
  }
}

class _TopHeader extends StatefulWidget {
  final bool showCreateIcon;
  final String searchHint;
  final String searchValue;
  final IconData? actionIcon;
  final String? actionLabel;
  final ValueChanged<String> onSearchSubmit;
  final VoidCallback? onActionTap;

  const _TopHeader({
    required this.showCreateIcon,
    required this.searchHint,
    required this.searchValue,
    required this.actionIcon,
    this.actionLabel,
    required this.onSearchSubmit,
    required this.onActionTap,
  });

  @override
  State<_TopHeader> createState() => _TopHeaderState();
}

class _TopHeaderState extends State<_TopHeader> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchValue;
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _TopHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchValue != oldWidget.searchValue &&
        _searchController.text != widget.searchValue) {
      _searchController.text = widget.searchValue;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _handleSubmit(String value) {
    final keyword = value.trim();
    widget.onSearchSubmit(keyword);
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onSearchSubmit('');
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    final activeColor = Theme.of(context).brightness == Brightness.dark
        ? kCobaltMuted
        : kCobalt;

    return Container(
      height: _MainScaffoldState._headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.artC.porcelain.withValues(alpha: 0.96),
        border: Border(
          bottom:
              BorderSide(color: context.artC.silver.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OpticalGlassSurface(
              padding: const EdgeInsets.only(left: 14, right: 6),
              radius: 18,
              surfaceOpacity: isFocused ? 0.22 : 0.17,
              blurSigma: 14,
              emphasized: isFocused,
              child: SizedBox(
                height: 46,
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 19,
                      color: isFocused
                          ? kGlassAccent
                          : kGlassInk.withValues(alpha: 0.64),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        onSubmitted: _handleSubmit,
                        cursorColor: activeColor,
                        textInputAction: TextInputAction.search,
                        maxLines: 1,
                        textAlignVertical: TextAlignVertical.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: context.artC.ink,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.searchHint,
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: context.artC.ink.withValues(alpha: 0.36),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        if (value.text.isEmpty) {
                          return const SizedBox(width: 2);
                        }
                        return GestureDetector(
                          onTap: _clearSearch,
                          child: SizedBox(
                            width: 30,
                            height: 34,
                            child: Icon(
                              Icons.close_rounded,
                              size: 17,
                              color: context.artC.ink.withValues(alpha: 0.4),
                            ),
                          ),
                        );
                      },
                    ),
                    GestureDetector(
                      onTap: () => _handleSubmit(_searchController.text),
                      child: OpticalGlassSurface(
                        padding: EdgeInsets.zero,
                        radius: 12,
                        surfaceOpacity: isFocused ? 0.23 : 0.15,
                        blurSigma: 10,
                        elevated: false,
                        emphasized: isFocused,
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: isFocused
                                ? kGlassAccent
                                : context.artC.ink.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.actionIcon != null || widget.actionLabel != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onActionTap,
              child: OpticalGlassSurface(
                padding: EdgeInsets.zero,
                radius: 14,
                surfaceOpacity: 0.2,
                blurSigma: 12,
                child: SizedBox(
                  width: widget.actionLabel == null ? 40 : 58,
                  height: 40,
                  child: widget.actionLabel == null
                      ? Icon(
                          widget.actionIcon,
                          size: widget.showCreateIcon ? 21 : 18,
                          color: kGlassInk.withValues(alpha: 0.8),
                        )
                      : Center(
                          child: Text(
                            widget.actionLabel!,
                            style: TextStyle(
                              color: kGlassInk.withValues(alpha: 0.84),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _ResourceKind { opportunity, event, artist }

enum _CommunityCreateKind { market, circle, salon }

enum _CreateSectionKind { cooperation, activity, circle }

enum _CreateActionKind {
  opportunity,
  exhibition,
  question,
  post,
}

class _CreateSheetSection {
  final _CreateSectionKind kind;
  final List<_CreateSheetAction> actions;

  const _CreateSheetSection({
    required this.kind,
    required this.actions,
  });
}

class _CreateSheetAction {
  final _CreateActionKind kind;
  final IconData icon;
  final String label;
  final String subtitle;

  const _CreateSheetAction({
    required this.kind,
    required this.icon,
    required this.label,
    required this.subtitle,
  });
}

DateTime? _parseSalonDateTime(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized);
}

String _salonCreateBenefit(String salonType, String feeMode) {
  if (feeMode == 'free') return '免费 / 预约制 · 可回放';
  if (feeMode == 'invite') return '邀请制 · 小范围交流';
  if (salonType == '作品集诊断') return '含作品集点评 · 现场 Q&A';
  if (salonType == '校友分享') return '含校友交流 · 申请经验';
  return '含主题分享 · 现场交流';
}

class _ResourceTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;

  const _ResourceTextField({
    required this.controller,
    required this.label,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: required
            ? (value) =>
                value == null || value.trim().isEmpty ? '请填写$label' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _CircleCreateSection extends StatelessWidget {
  final String title;
  final String error;
  final Widget child;

  const _CircleCreateSection({
    required this.title,
    required this.child,
    this.error = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (error.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _CircleCreateTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String error;
  final int maxLines;
  final int? maxLength;

  const _CircleCreateTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.error = '',
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return _CircleCreateSection(
      title: label,
      error: error,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          filled: true,
          fillColor: context.artC.cardIconBg.withOpacity(0.72),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: context.artC.silver.withOpacity(0.5),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: context.artC.silver.withOpacity(0.45),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kCobalt, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _CircleCreateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CircleCreateChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? kCobalt.withOpacity(0.08)
              : context.artC.cardIconBg.withOpacity(0.78),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? kCobalt.withOpacity(0.24)
                : context.artC.silver.withOpacity(0.52),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? kCobalt : context.artC.ink.withOpacity(0.68),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CircleJoinModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _CircleJoinModeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? kCobalt.withOpacity(0.08)
              : context.artC.cardIconBg.withOpacity(0.78),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? kCobalt.withOpacity(0.26)
                : context.artC.silver.withOpacity(0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: kCobalt,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: selected ? kCobalt : context.artC.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: selected
                    ? context.artC.ink.withOpacity(0.48)
                    : context.artC.ink.withOpacity(0.42),
                fontSize: 10,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final int tabIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.tabIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final itemColor = widget.isSelected
        ? kDeepSeaMidnight
        : kGlassInk.withValues(alpha: 0.56);

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.item.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.center,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild
                ],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: widget.isSelected
                  ? OpticalGlassSurface(
                      key: ValueKey('selected-${widget.item.tabIndex}'),
                      padding: EdgeInsets.zero,
                      radius: 22,
                      surfaceOpacity: 0.18,
                      blurSigma: 13,
                      emphasized: true,
                      child: SizedBox(
                        width: 58,
                        height: 50,
                        child: Icon(
                          widget.item.activeIcon,
                          size: 21,
                          color: itemColor,
                        ),
                      ),
                    )
                  : SizedBox(
                      key: ValueKey('idle-${widget.item.tabIndex}'),
                      width: 54,
                      height: 50,
                      child: Icon(
                        widget.item.icon,
                        size: 21,
                        color: itemColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiNavButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AiNavButton({required this.onTap});

  @override
  State<_AiNavButton> createState() => _AiNavButtonState();
}

class _AiNavButtonState extends State<_AiNavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'AI 助手',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: const SizedBox(
              width: 54,
              height: 50,
              child: Center(
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: kGlassInk,
                    fontFamily: 'Didot',
                    fontFamilyFallback: [
                      'Bodoni 72',
                      'Times New Roman',
                      'serif',
                    ],
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: Colors.white54,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
