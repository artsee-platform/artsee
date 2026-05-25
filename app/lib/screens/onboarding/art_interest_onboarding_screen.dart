import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/backend_api_service.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// 注册后冷启动：采集申请身份、目标、作品集、预算等用户画像字段。
class ArtInterestOnboardingScreen extends StatefulWidget {
  const ArtInterestOnboardingScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<ArtInterestOnboardingScreen> createState() =>
      _ArtInterestOnboardingScreenState();
}

class _ArtInterestOnboardingScreenState
    extends State<ArtInterestOnboardingScreen> {
  final _currentSchoolCtrl = TextEditingController();
  final _currentMajorCtrl = TextEditingController();
  final _gpaCtrl = TextEditingController();
  final _englishScoreCtrl = TextEditingController();
  final _favoriteCtrl = TextEditingController();

  final Set<String> _targetDirections = {};
  final Set<String> _targetMajors = {};
  final Set<String> _targetCountries = {};
  final Set<String> _selectedSchoolTypes = {};
  final Set<String> _selectedPortfolioStyles = {};
  final Set<String> _priorityFactors = {};
  final Set<String> _uploading = {};

  String? _userRole;
  String? _targetDegree;
  String? _educationStage;
  String? _rankingSensitivity;
  String? _cityPreference;
  String? _portfolioStatus;
  String? _englishTestType;
  String? _budgetRange;
  String? _scholarshipNeed;
  String? _familySupport;
  String? _targetIntake;
  String? _avatarUrl;
  String? _error;
  bool _saving = false;
  bool _started = false;
  int _currentStep = 0;

  static const _userRoles = [
    _ProfileOption('student', '申请学生', Icons.school_outlined),
    _ProfileOption('parent', '家长', Icons.family_restroom_outlined),
    _ProfileOption('working_professional', '转行申请者', Icons.work_outline_rounded),
    _ProfileOption('artist', '独立艺术家', Icons.palette_outlined),
  ];

  static const _targetDegrees = [
    _ProfileOption('foundation', 'Foundation/预科', Icons.auto_stories_outlined,
        description: '艺术基础课程'),
    _ProfileOption('bachelor', '本科 BA/BFA', Icons.workspace_premium_outlined,
        description: '学士学位'),
    _ProfileOption('master', '研究生 MA/MFA', Icons.local_library_outlined,
        description: '硕士学位'),
    _ProfileOption('phd', '博士', Icons.science_outlined, description: '研究型学位'),
    _ProfileOption('non_degree', '非学位课程', Icons.badge_outlined,
        description: '短期课程/证书'),
  ];

  static const _educationStages = [
    _ProfileOption('high_school', '高中在读', Icons.menu_book_outlined),
    _ProfileOption('university_undergrad', '大学在读', Icons.school_outlined),
    _ProfileOption('graduated', '已毕业', Icons.verified_outlined),
    _ProfileOption('working', '在职', Icons.work_outline),
  ];

  static const _directions = [
    _ProfileOption('fine_arts', '纯艺术', Icons.brush_outlined,
        description: '绘画、雕塑、装置'),
    _ProfileOption('design', '设计', Icons.design_services_outlined,
        description: '视觉、产品、时装'),
    _ProfileOption('media_arts', '媒体艺术', Icons.devices_outlined,
        description: '数字媒体、交互、游戏'),
    _ProfileOption('architecture', '建筑', Icons.architecture_outlined,
        description: '建筑设计、城市规划'),
    _ProfileOption('performance', '表演艺术', Icons.theater_comedy_outlined,
        description: '戏剧、舞蹈'),
    _ProfileOption('music', '音乐', Icons.music_note_outlined,
        description: '作曲、演奏、制作'),
    _ProfileOption('film', '电影/摄影', Icons.movie_creation_outlined,
        description: '导演、摄影、剪辑'),
  ];

  static const _majors = [
    _MajorOption('fashion_design', '时装设计', 'design'),
    _MajorOption('textile_design', '纺织品设计', 'design'),
    _MajorOption('graphic_design', '平面设计', 'design'),
    _MajorOption('product_design', '产品设计', 'design'),
    _MajorOption('interior_design', '室内设计', 'design'),
    _MajorOption('jewelry_design', '珠宝设计', 'design'),
    _MajorOption('industrial_design', '工业设计', 'design'),
    _MajorOption('interaction_design', '交互设计', 'media_arts'),
    _MajorOption('game_design', '游戏设计', 'media_arts'),
    _MajorOption('animation', '动画', 'media_arts'),
    _MajorOption('digital_media', '数字媒体', 'media_arts'),
    _MajorOption('painting', '绘画', 'fine_arts'),
    _MajorOption('sculpture', '雕塑', 'fine_arts'),
    _MajorOption('printmaking', '版画', 'fine_arts'),
    _MajorOption('installation', '装置艺术', 'fine_arts'),
    _MajorOption('illustration', '插画', 'design'),
    _MajorOption('photography', '摄影', 'film'),
    _MajorOption('film_production', '电影制作', 'film'),
    _MajorOption('architecture', '建筑设计', 'architecture'),
  ];

  static const _countries = [
    _ProfileOption('US', '美国', Icons.location_city_outlined),
    _ProfileOption('GB', '英国', Icons.location_city_outlined),
    _ProfileOption('FR', '法国', Icons.location_city_outlined),
    _ProfileOption('IT', '意大利', Icons.location_city_outlined),
    _ProfileOption('DE', '德国', Icons.location_city_outlined),
    _ProfileOption('NL', '荷兰', Icons.location_city_outlined),
    _ProfileOption('JP', '日本', Icons.location_city_outlined),
    _ProfileOption('KR', '韩国', Icons.location_city_outlined),
    _ProfileOption('AU', '澳大利亚', Icons.location_city_outlined),
    _ProfileOption('CA', '加拿大', Icons.location_city_outlined),
    _ProfileOption('CN', '中国', Icons.location_city_outlined),
    _ProfileOption('other', '其他', Icons.more_horiz_outlined),
  ];

  static const _schoolTypes = [
    _ProfileOption('comprehensive_university', '综合大学', Icons.account_balance,
        description: '如 Yale, UCLA'),
    _ProfileOption('art_academy', '独立艺术学院', Icons.palette_outlined,
        description: '如 RISD, CSM'),
    _ProfileOption('design_school', '设计学院', Icons.design_services_outlined,
        description: '如 Parsons, Pratt'),
    _ProfileOption('conservatory', '音乐/表演学院', Icons.music_note_outlined,
        description: '如 Juilliard'),
  ];

  static const _rankingSensitivityOptions = [
    _ProfileOption('very_important', '非常重要', Icons.trending_up_outlined,
        description: '优先考虑排名靠前'),
    _ProfileOption('moderately', '适度关注', Icons.tune_outlined,
        description: '排名是参考因素'),
    _ProfileOption('not_important', '不太在意', Icons.explore_outlined,
        description: '更关注教学和氛围'),
  ];

  static const _portfolioStatuses = [
    _ProfileOption('not_started', '还没开始', Icons.lightbulb_outline,
        description: '正在收集灵感'),
    _ProfileOption('brainstorming', '构思阶段', Icons.psychology_outlined,
        description: '确定主题和方向'),
    _ProfileOption('in_progress', '制作中', Icons.construction_outlined,
        description: '已开始创作项目'),
    _ProfileOption('mostly_done', '接近完成', Icons.task_alt_outlined,
        description: '大部分项目已完成'),
    _ProfileOption('refining', '精修阶段', Icons.auto_fix_high_outlined,
        description: '优化排版和细节'),
  ];

  static const _budgetRanges = [
    _ProfileOption('under_30', '30万以下/年', Icons.savings_outlined,
        description: '适合欧洲部分国家'),
    _ProfileOption('30_50', '30-50万/年', Icons.account_balance_wallet_outlined,
        description: '英美公立学校'),
    _ProfileOption('50_80', '50-80万/年', Icons.credit_card_outlined,
        description: '英美私立学校'),
    _ProfileOption('80_plus', '80万以上/年', Icons.diamond_outlined,
        description: '顶尖私立学校'),
  ];

  static const _targetIntakes = [
    _ProfileOption('2025_fall', '2025 秋季', Icons.event_outlined),
    _ProfileOption('2026_spring', '2026 春季', Icons.event_outlined),
    _ProfileOption('2026_fall', '2026 秋季', Icons.event_outlined),
    _ProfileOption('2027_spring', '2027 春季', Icons.event_outlined),
    _ProfileOption('2027_fall', '2027 秋季', Icons.event_outlined),
    _ProfileOption('flexible', '时间灵活', Icons.all_inclusive_outlined),
  ];

  static const _priorityOptions = [
    _ProfileOption('reputation', '学校声誉', Icons.workspace_premium_outlined),
    _ProfileOption('teaching', '教学质量', Icons.local_library_outlined),
    _ProfileOption('career', '就业前景', Icons.work_outline),
    _ProfileOption('culture', '校园氛围', Icons.palette_outlined),
    _ProfileOption('cost', '费用', Icons.payments_outlined),
    _ProfileOption('location', '地理位置', Icons.place_outlined),
    _ProfileOption('faculty', '教授资源', Icons.person_search_outlined),
    _ProfileOption('alumni', '校友网络', Icons.diversity_3_outlined),
  ];

  @override
  void dispose() {
    _currentSchoolCtrl.dispose();
    _currentMajorCtrl.dispose();
    _gpaCtrl.dispose();
    _englishScoreCtrl.dispose();
    _favoriteCtrl.dispose();
    super.dispose();
  }

  List<_MajorOption> get _visibleMajors {
    if (_targetDirections.isEmpty) return _majors;
    return _majors
        .where((major) => _targetDirections.contains(major.category))
        .toList();
  }

  int get _completionScore {
    var score = 0;
    var total = 0;

    void add(bool filled, int weight) {
      total += weight;
      if (filled) score += weight;
    }

    add(_userRole != null, 10);
    add(_targetDegree != null, 10);
    add(_educationStage != null, 10);
    add(_targetMajors.isNotEmpty, 10);
    add(_targetCountries.isNotEmpty, 10);
    add(_portfolioStatus != null, 10);
    add(_targetIntake != null, 10);

    add(_englishTestType != null, 8);
    add(_budgetRange != null, 8);
    add(_currentSchoolCtrl.text.trim().isNotEmpty, 8);
    add(_currentMajorCtrl.text.trim().isNotEmpty, 8);

    add(_selectedSchoolTypes.isNotEmpty, 5);
    add(_rankingSensitivity != null, 5);
    add(_selectedPortfolioStyles.isNotEmpty, 5);
    add(_englishScoreCtrl.text.trim().isNotEmpty, 5);
    add(_scholarshipNeed != null, 5);
    add(_gpaCtrl.text.trim().isNotEmpty, 5);

    add(_favoriteCtrl.text.trim().isNotEmpty, 3);
    add(_priorityFactors.isNotEmpty, 3);
    add(_cityPreference != null, 3);
    add(_familySupport != null, 3);

    return total == 0 ? 0 : ((score / total) * 100).round();
  }

  void _setSingle(String value, String? current, ValueChanged<String?> set) {
    setState(() => set(current == value ? null : value));
  }

  void _toggle(Set<String> values, String value, {int? max}) {
    setState(() {
      if (values.contains(value)) {
        values.remove(value);
      } else if (max == null || values.length < max) {
        values.add(value);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('最多选择 $max 项')),
        );
      }
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() {
      _uploading.add('avatar');
      _error = null;
    });
    try {
      final url = await StorageService.uploadAvatarFile(x);
      await SupabaseService.updateAvatarUrl(url);
      if (mounted) {
        setState(() => _avatarUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像已更新')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading.remove('avatar'));
    }
  }

  List<String> _missingRequiredLabels() {
    final missing = <String>[];
    if (_userRole == null) missing.add('身份角色');
    if (_targetDegree == null) missing.add('目标学位');
    if (_educationStage == null) missing.add('当前阶段');
    if (_targetMajors.isEmpty) missing.add('目标专业');
    if (_targetCountries.isEmpty) missing.add('目标国家');
    if (_portfolioStatus == null) missing.add('作品集状态');
    if (_targetIntake == null) missing.add('申请时间');
    return missing;
  }

  bool get _stepCanContinue {
    return switch (_currentStep) {
      0 =>
        _userRole != null && _targetDegree != null && _educationStage != null,
      1 => _targetMajors.isNotEmpty && _targetCountries.isNotEmpty,
      2 => _portfolioStatus != null && _targetIntake != null,
      _ => true,
    };
  }

  double get _stepProgress => (_currentStep + 1) / 4;

  String get _primaryActionLabel {
    if (_currentStep == 3) return '生成我的艺术画像';
    return _stepCanContinue ? '下一步' : '完成当前步骤';
  }

  void _goNext() {
    if (!_stepCanContinue || _saving) return;
    if (_currentStep < 3) {
      setState(() => _currentStep += 1);
      return;
    }
    _submit();
  }

  void _goBack() {
    if (_saving) return;
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      setState(() => _started = false);
    }
  }

  Future<void> _submit() async {
    final missing = _missingRequiredLabels();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请先补充：${missing.take(3).join('、')}')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final englishScore = _englishScoreCtrl.text.trim();
    final payload = <String, dynamic>{
      'user_role': _userRole,
      'target_degree': _targetDegree,
      'current_education_stage': _educationStage,
      'current_school': _currentSchoolCtrl.text.trim(),
      'current_major': _currentMajorCtrl.text.trim(),
      'gpa_or_grade': _gpaCtrl.text.trim(),
      'target_directions': _targetDirections.toList(),
      'target_majors': _targetMajors.toList(),
      'target_countries': _targetCountries.toList(),
      'school_type_preference': _selectedSchoolTypes.toList(),
      'ranking_sensitivity': _rankingSensitivity,
      'city_preference': _cityPreference,
      'portfolio_status': _portfolioStatus,
      'portfolio_style_tendency': _selectedPortfolioStyles.toList(),
      'english_test_type': _englishTestType,
      'english_test_score': englishScore.isEmpty ? null : englishScore,
      'total_budget_range': _budgetRange,
      'scholarship_need': _scholarshipNeed,
      'family_support_level': _familySupport,
      'target_intake': _targetIntake,
      'favorite_artists_or_styles': _favoriteCtrl.text.trim(),
      'priority_factors': _priorityFactors.toList(),
      'profile_completion_score': _completionScore,
      'application_stage': _educationStage,
      'target_major': _targetMajors.isEmpty ? null : _targetMajors.first,
      'budget_range': _budgetRange,
      'language_level': englishScore.isEmpty ? _englishTestType : englishScore,
      'portfolio_progress': _portfolioStatus,
      'application_timeline': _targetIntake,
      'need_scholarship': _scholarshipNeed == 'must_have',
      'has_completed_onboarding': true,
      'onboarding_completed_at': DateTime.now().toIso8601String(),
    };

    payload.removeWhere((_, value) {
      if (value == null) return true;
      if (value is String && value.trim().isEmpty) return true;
      return false;
    });

    try {
      await BackendApiService.updateUserProfile(payload);
      widget.onCompleted();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      bottomNavigationBar: _started ? _buildStepNavigation() : null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _started
              ? _buildStepBody(key: ValueKey<int>(_currentStep))
              : _buildIntro(key: const ValueKey('intro')),
        ),
      ),
    );
  }

  Widget _buildIntro({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
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
                      '完善你的艺术画像',
                      style: TextStyle(
                        fontSize: 31,
                        fontWeight: FontWeight.w900,
                        color: context.artC.ink,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '让 Artiqore 根据你的身份、目标和现实条件推荐更合适的院校与内容。',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.artC.ink.withValues(alpha: 0.56),
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _AvatarPicker(
                avatarUrl: _avatarUrl,
                uploading: _uploading.contains('avatar'),
                onTap:
                    _uploading.contains('avatar') ? null : _pickAndUploadAvatar,
              ),
            ],
          ),
          const SizedBox(height: 34),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: context.artC.silver.withValues(alpha: 0.34),
              ),
              boxShadow: [
                BoxShadow(
                  color: context.artC.ink.withValues(alpha: 0.045),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IntroRow(
                  icon: Icons.layers_outlined,
                  title: '4 个轻量步骤',
                  subtitle: '每次只做一个小选择，不再面对长表单。',
                ),
                SizedBox(height: 18),
                _IntroRow(
                  icon: Icons.schedule_rounded,
                  title: '约 3 分钟完成',
                  subtitle: '先收集核心必填项，其他细节以后再补。',
                ),
                SizedBox(height: 18),
                _IntroRow(
                  icon: Icons.auto_awesome_rounded,
                  title: '生成初始推荐画像',
                  subtitle: '用于选校、专业、案例和 AI 咨询的基础判断。',
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
          const SizedBox(height: 34),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _started = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: kCobalt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                '开始定制 · 约 3 分钟',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            step: _currentStep + 1,
            title: switch (_currentStep) {
              0 => '你是谁？',
              1 => '你想去哪？',
              2 => '现实条件如何？',
              _ => '你的艺术偏好？',
            },
            subtitle: switch (_currentStep) {
              0 => '先确认身份、目标学位和当前阶段。',
              1 => '选择申请方向、目标专业和国家偏好。',
              2 => '告诉我们作品集进度、申请时间和预算。',
              _ => '这些是可选信息，会让推荐更像你。',
            },
            onBack: _goBack,
            onSkip: _currentStep == 3 ? _submit : null,
            saving: _saving,
          ),
          const SizedBox(height: 18),
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
            const SizedBox(height: 14),
          ],
          _StepCard(child: _buildCurrentStep()),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_currentStep) {
      0 => _buildIdentityStep(),
      1 => _buildTargetStep(),
      2 => _buildRealityStep(),
      _ => _buildPreferenceStep(),
    };
  }

  Widget _buildIdentityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuestionBlock(
          title: '身份角色',
          required: true,
          child: _ChoiceGrid(
            options: _userRoles,
            selectedValue: _userRole,
            onSelected: (v) =>
                _setSingle(v, _userRole, (next) => _userRole = next),
          ),
        ),
        _QuestionBlock(
          title: '目标学位',
          required: true,
          child: _ChoiceGrid(
            options: _targetDegrees,
            selectedValue: _targetDegree,
            onSelected: (v) =>
                _setSingle(v, _targetDegree, (next) => _targetDegree = next),
          ),
        ),
        _QuestionBlock(
          title: '当前阶段',
          required: true,
          child: _ChoiceGrid(
            options: _educationStages,
            selectedValue: _educationStage,
            compact: true,
            onSelected: (v) => _setSingle(
              v,
              _educationStage,
              (next) => _educationStage = next,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuestionBlock(
          title: '目标方向',
          child: _ChoiceGrid(
            options: _directions,
            selectedValues: _targetDirections,
            onSelected: (v) {
              setState(() {
                if (_targetDirections.contains(v)) {
                  _targetDirections.remove(v);
                } else {
                  _targetDirections.add(v);
                }
                _targetMajors.removeWhere((major) {
                  final item = _majors.firstWhere((m) => m.value == major);
                  return _targetDirections.isNotEmpty &&
                      !_targetDirections.contains(item.category);
                });
              });
            },
          ),
        ),
        _QuestionBlock(
          title: '目标专业',
          required: true,
          trailing: '${_targetMajors.length}/6',
          child: _ChipWrap(
            options: _visibleMajors
                .map((m) =>
                    _ProfileOption(m.value, m.label, Icons.sell_outlined))
                .toList(),
            selectedValues: _targetMajors,
            max: 6,
            onSelected: (v) => _toggle(_targetMajors, v, max: 6),
          ),
        ),
        _QuestionBlock(
          title: '目标国家',
          required: true,
          trailing: '${_targetCountries.length}/5',
          child: _ChipWrap(
            options: _countries,
            selectedValues: _targetCountries,
            max: 5,
            onSelected: (v) => _toggle(_targetCountries, v, max: 5),
          ),
        ),
      ],
    );
  }

  Widget _buildRealityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _QuestionBlock(
          title: '作品集状态',
          required: true,
          child: _ChoiceGrid(
            options: _portfolioStatuses,
            selectedValue: _portfolioStatus,
            onSelected: (v) => _setSingle(
              v,
              _portfolioStatus,
              (next) => _portfolioStatus = next,
            ),
          ),
        ),
        _QuestionBlock(
          title: '申请时间',
          required: true,
          child: _ChoiceGrid(
            options: _targetIntakes,
            selectedValue: _targetIntake,
            compact: true,
            onSelected: (v) =>
                _setSingle(v, _targetIntake, (next) => _targetIntake = next),
          ),
        ),
        _QuestionBlock(
          title: '预算范围',
          child: _ChoiceGrid(
            options: _budgetRanges,
            selectedValue: _budgetRange,
            onSelected: (v) =>
                _setSingle(v, _budgetRange, (next) => _budgetRange = next),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileTextField(
          controller: _favoriteCtrl,
          label: '喜欢的艺术家、品牌或风格',
          hint: '例如：川久保玲、包豪斯、影像装置、手工材料',
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _QuestionBlock(
          title: '优先考虑因素',
          trailing: '${_priorityFactors.length}/5',
          child: _ChipWrap(
            options: _priorityOptions,
            selectedValues: _priorityFactors,
            max: 5,
            onSelected: (v) => _toggle(_priorityFactors, v, max: 5),
          ),
        ),
        _QuestionBlock(
          title: '学校类型偏好',
          child: _ChoiceGrid(
            options: _schoolTypes,
            selectedValues: _selectedSchoolTypes,
            onSelected: (v) => _toggle(_selectedSchoolTypes, v),
          ),
        ),
        _QuestionBlock(
          title: '排名敏感度',
          child: _ChoiceGrid(
            options: _rankingSensitivityOptions,
            selectedValue: _rankingSensitivity,
            onSelected: (v) => _setSingle(
              v,
              _rankingSensitivity,
              (next) => _rankingSensitivity = next,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepNavigation() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: context.artC.porcelain.withValues(alpha: 0.97),
          border: Border(
            top: BorderSide(color: context.artC.silver.withValues(alpha: 0.5)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: _stepProgress,
                      backgroundColor:
                          context.artC.silver.withValues(alpha: 0.7),
                      color: kCobalt,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${((_stepProgress) * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.artC.ink.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _stepCanContinue && !_saving ? _goNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _stepCanContinue ? kCobalt : kCobaltMuted,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: kCobaltMuted,
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusMedium),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _primaryActionLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.avatarUrl,
    required this.uploading,
    required this.onTap,
  });

  final String? avatarUrl;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: context.artC.silver, width: 2),
          boxShadow: [kShadowCard],
        ),
        child: uploading
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kCobalt,
                ),
              )
            : avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      avatarUrl!,
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.add_a_photo_outlined,
                          color: kCobalt,
                          size: 24),
                    ),
                  )
                : const Icon(
                    Icons.add_a_photo_outlined,
                    color: kCobalt,
                    size: 24,
                  ),
      ),
    );
  }
}

class _IntroRow extends StatelessWidget {
  const _IntroRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: kCobalt.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, size: 21, color: kCobalt),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.38,
                  fontWeight: FontWeight.w600,
                  color: context.artC.ink.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.saving,
    this.onSkip,
  });

  final int step;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onSkip;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.artC.silver.withValues(alpha: 0.58),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: context.artC.ink,
                ),
              ),
            ),
            const Spacer(),
            if (onSkip != null)
              TextButton(
                onPressed: saving ? null : onSkip,
                child: Text(
                  '跳过，直接进入系统',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink.withValues(alpha: 0.48),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'STEP $step / 4',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
            color: kCobalt,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 30,
            height: 1.08,
            fontWeight: FontWeight.w900,
            color: context.artC.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: context.artC.ink.withValues(alpha: 0.52),
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: context.artC.ink.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _QuestionBlock extends StatelessWidget {
  const _QuestionBlock({
    required this.title,
    required this.child,
    this.required = false,
    this.trailing,
  });

  final String title;
  final Widget child;
  final bool required;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.artC.ink.withValues(alpha: 0.38),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({
    required this.options,
    required this.onSelected,
    this.selectedValue,
    this.selectedValues,
    this.compact = false,
  });

  final List<_ProfileOption> options;
  final String? selectedValue;
  final Set<String>? selectedValues;
  final ValueChanged<String> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = compact ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: options.map((option) {
            final selected = selectedValues?.contains(option.value) ??
                selectedValue == option.value;
            return SizedBox(
              width: itemWidth,
              child: _ChoiceTile(
                option: option,
                selected: selected,
                compact: compact,
                onTap: () => onSelected(option.value),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final _ProfileOption option;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: BoxConstraints(minHeight: compact ? 74 : 96),
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: selected ? kCobalt.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(kRadiusMedium),
          border: Border.all(
            color:
                selected ? kCobalt : context.artC.silver.withValues(alpha: 0.9),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? [kShadowCard] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              option.icon,
              size: compact ? 21 : 24,
              color:
                  selected ? kCobalt : context.artC.ink.withValues(alpha: 0.42),
            ),
            const SizedBox(height: 8),
            Text(
              option.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? kCobalt
                    : context.artC.ink.withValues(alpha: 0.78),
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            if (!compact && option.description != null) ...[
              const SizedBox(height: 4),
              Text(
                option.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.artC.ink.withValues(alpha: 0.42),
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.options,
    required this.selectedValues,
    required this.onSelected,
    this.max,
  });

  final List<_ProfileOption> options;
  final Set<String> selectedValues;
  final ValueChanged<String> onSelected;
  final int? max;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final selected = selectedValues.contains(option.value);
        final disabled =
            max != null && selectedValues.length >= max! && !selected;
        return GestureDetector(
          onTap: disabled ? null : () => onSelected(option.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? kCobalt
                  : disabled
                      ? context.artC.silver.withValues(alpha: 0.22)
                      : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? kCobalt
                    : context.artC.silver
                        .withValues(alpha: disabled ? 0.32 : 1),
              ),
            ),
            child: Text(
              option.label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : context.artC.ink
                        .withValues(alpha: disabled ? 0.28 : 0.66),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusMedium),
          borderSide: BorderSide(color: context.artC.silver),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusMedium),
          borderSide: BorderSide(color: context.artC.silver),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusMedium),
          borderSide: const BorderSide(color: kCobalt, width: 1.5),
        ),
      ),
    );
  }
}

class _ProfileOption {
  final String value;
  final String label;
  final IconData icon;
  final String? description;

  const _ProfileOption(
    this.value,
    this.label,
    this.icon, {
    this.description,
  });
}

class _MajorOption {
  final String value;
  final String label;
  final String category;

  const _MajorOption(this.value, this.label, this.category);
}
