import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../data/mock_compare_schools.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// 懂车帝式：全屏沉浸、深色顶栏、对话 + 「对比选校」数据面板（雷达 + 参数表）
class AiConsultScreen extends StatefulWidget {
  const AiConsultScreen({super.key});

  @override
  State<AiConsultScreen> createState() => _AiConsultScreenState();
}

class _AiConsultScreenState extends State<AiConsultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'text': '你好！我是 Artiqore AI 助手。可以问我选校、作品集与职业路径；也可切换到「对比选校」添加院校查看多维数据面板。',
    },
  ];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;

  final TextEditingController _compareSearch = TextEditingController();
  final Set<String> _selectedIds = {};

  static const _suggestions = [
    'RCA 和 RISD 哪个更适合交互方向？',
    '一年制硕士总预算 40 万可以选哪些院校？',
    '作品集里需要几个完整项目？',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _input.dispose();
    _scrollCtrl.dispose();
    _compareSearch.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _sending = true;
    });
    _input.clear();
    _scrollBottom();

    String reply;
    try {
      final result = await BackendApiService.aiSchoolSearch(text);
      reply = _formatAiReply(result);
    } catch (e) {
      reply = _buildFallbackReply(text, e);
    }
    if (!mounted) return;
    setState(() {
      _messages.add({
        'role': 'assistant',
        'text': reply,
      });
      _sending = false;
    });
    _scrollBottom();
  }

  String _formatAiReply(Map<String, dynamic> response) {
    final result = response['result'];
    if (result is! Map<String, dynamic>) {
      return result?.toString() ?? '我已经收到你的问题，但暂时没有生成可展示的结构化建议。';
    }

    final lines = <String>[];
    final summary = result['summary']?.toString().trim();
    if (summary != null && summary.isNotEmpty) {
      lines.add(summary);
    }

    final recommendations = result['recommendations'];
    if (recommendations is List && recommendations.isNotEmpty) {
      lines.add('推荐方向：');
      for (final item in recommendations.take(4)) {
        if (item is Map) {
          final school = item['school']?.toString() ?? '目标院校';
          final reason = item['reason']?.toString() ?? '';
          lines.add('· $school：$reason');
        }
      }
    }

    final tips = result['tips'];
    if (tips is List && tips.isNotEmpty) {
      lines.add('下一步建议：');
      for (final tip in tips.take(3)) {
        lines.add('· ${tip.toString()}');
      }
    }

    return lines.isEmpty ? '我已经收到你的问题，但暂时没有生成可展示的结构化建议。' : lines.join('\n\n');
  }

  String _buildFallbackReply(String question, Object error) {
    final schools = _filterMockSchools(question).take(3).toList();
    final schoolLines = schools
        .map(
          (s) =>
              '· ${s.name}：${s.cityCountry}，${s.language}，参考学费 ${s.tuition}，适合作为${s.difficulty}档位继续核对。',
        )
        .join('\n');
    return [
      '当前 AI 或后端环境还没完全配置好，我先基于本地院校样例给你一个可执行判断。',
      if (schoolLines.isNotEmpty) schoolLines,
      '建议你下一步补充目标国家、专业方向、预算、语言成绩和作品集进度；等 OPENAI_API_KEY/MOONSHOT_API_KEY 与 Supabase Service Role 配好后，这里会自动切换成数据库 + AI 的真实回答。',
    ].join('\n\n');
  }

  List<CompareSchool> _filterMockSchools(String question) {
    final q = question.toLowerCase();
    final matched = kMockCompareSchools.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.enName.toLowerCase().contains(q) ||
          s.tags.any((tag) => q.contains(tag.toLowerCase())) ||
          q.contains(s.name.toLowerCase()) ||
          q.contains(s.enName.toLowerCase());
    }).toList();
    return matched.isEmpty ? kMockCompareSchools : matched;
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<CompareSchool> get _filteredSchools {
    final q = _compareSearch.text.trim().toLowerCase();
    if (q.isEmpty) return kMockCompareSchools;
    return kMockCompareSchools
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.enName.toLowerCase().contains(q),
        )
        .toList();
  }

  List<CompareSchool> get _selected =>
      kMockCompareSchools.where((s) => _selectedIds.contains(s.id)).toList();

  void _toggleSchool(CompareSchool s) {
    setState(() {
      if (_selectedIds.contains(s.id)) {
        _selectedIds.remove(s.id);
      } else if (_selectedIds.length < 5) {
        _selectedIds.add(s.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: Column(
        children: [
          _buildTopBar(context),
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: kCobalt,
              indicatorWeight: 3,
              labelColor: context.artC.ink,
              unselectedLabelColor: context.artC.ink.withValues(alpha: 0.38),
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: '智能问答'),
                Tab(text: '对比选校'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildChatTab(),
                _buildCompareTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 6, 12, 14),
      decoration: BoxDecoration(
        color: context.artC.ink,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kCobalt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Artiqore AI',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Intelligent Concierge · 选校参谋',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: _messages.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestions.map((s) {
                      return ActionChip(
                        label: Text(
                          s,
                          style:
                              TextStyle(fontSize: 11, color: context.artC.ink),
                        ),
                        backgroundColor:
                            context.artC.silver.withValues(alpha: 0.35),
                        side: BorderSide(
                            color: context.artC.silver.withValues(alpha: 0.6)),
                        onPressed: _sending ? null : () => _send(s),
                      );
                    }).toList(),
                  ),
                );
              }
              final msg = _messages[i - 1];
              final user = msg['role'] == 'user';
              return Align(
                alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: user ? context.artC.ink : Colors.white,
                    borderRadius: BorderRadius.circular(20).copyWith(
                      bottomRight: user ? const Radius.circular(4) : null,
                      bottomLeft: !user ? const Radius.circular(4) : null,
                    ),
                    border: user
                        ? null
                        : Border.all(
                            color: context.artC.silver.withValues(alpha: 0.45)),
                    boxShadow: [
                      BoxShadow(
                        color: context.artC.ink.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    msg['text']!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: user
                          ? context.artC.porcelain
                          : context.artC.ink.withValues(alpha: 0.88),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_sending)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _typingDot(0),
                _typingDot(1),
                _typingDot(2),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
                top: BorderSide(
                    color: context.artC.silver.withValues(alpha: 0.5))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: '询问艺术留学、院校或作品集…',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: context.artC.ink.withValues(alpha: 0.28),
                          ),
                          filled: true,
                          fillColor: context.artC.porcelain,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color:
                                    context.artC.silver.withValues(alpha: 0.6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color:
                                    context.artC.silver.withValues(alpha: 0.6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: kCobalt.withValues(alpha: 0.55)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _send(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _input.text.trim().isEmpty && !_sending
                              ? context.artC.ink.withValues(alpha: 0.12)
                              : kCobalt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '演示数据 · 正式算法匹配与院校库接入后续开放',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: context.artC.ink.withValues(alpha: 0.22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _typingDot(int i) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: kCobalt.withValues(alpha: 0.35 + i * 0.2),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCompareTab() {
    final selected = _selected;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _compareSearch,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search,
                        color: context.artC.ink.withValues(alpha: 0.25)),
                    hintText: '搜索伦敦艺术大学、罗德岛设计学院…',
                    hintStyle: TextStyle(
                        fontSize: 12,
                        color: context.artC.ink.withValues(alpha: 0.28)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: context.artC.silver.withValues(alpha: 0.55)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: context.artC.silver.withValues(alpha: 0.55)),
                ),
                child: Icon(Icons.tune, color: kCobalt.withValues(alpha: 0.85)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '点击封面右上角「+」加入对比（最多 5 所） · 已选 ${selected.length} 所',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.artC.ink.withValues(alpha: 0.38),
            ),
          ),
          const SizedBox(height: 14),
          ..._filteredSchools.map((s) => _CompareSchoolRow(
                school: s,
                selected: _selectedIds.contains(s.id),
                onToggle: () => _toggleSchool(s),
              )),
          const SizedBox(height: 24),
          if (selected.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: context.artC.silver.withValues(alpha: 0.45)),
              ),
              child: Column(
                children: [
                  Icon(Icons.compare_arrows,
                      size: 40,
                      color: context.artC.ink.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  Text(
                    '对比中心暂无数据',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: context.artC.ink.withValues(alpha: 0.45),
                      fontFamily: 'Noto Serif SC',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '在上方列表中点击「+」加入院校，即可查看雷达图与参数表。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: context.artC.ink.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: context.artC.silver.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '能力多维对比',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: context.artC.ink,
                    ),
                  ),
                  Text(
                    'Comparative Data Visualization',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.2,
                      color: context.artC.ink.withValues(alpha: 0.28),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: CustomPaint(
                      painter: _RadarPainter(schools: selected),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: selected.asMap().entries.map((e) {
                      final colors = [
                        kCobalt,
                        kCobaltMuted,
                        const Color(0xFF64748B)
                      ];
                      final c = colors[e.key % colors.length];
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration:
                                BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            e.value.name,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _CompareTable(schools: selected),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareSchoolRow extends StatelessWidget {
  final CompareSchool school;
  final bool selected;
  final VoidCallback onToggle;

  const _CompareSchoolRow({
    required this.school,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.artC.silver.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    school.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: context.artC.silver.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Wrap(
                  spacing: 6,
                  children: school.tags.take(2).map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: context.artC.ink,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color:
                      selected ? kCobalt : Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        selected ? Icons.check : Icons.add,
                        color: selected
                            ? Colors.white
                            : context.artC.ink.withValues(alpha: 0.55),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                            school.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.artC.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            school.enName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: context.artC.ink.withValues(alpha: 0.32),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.artC.silver.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${school.id}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: kCobalt,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          school.cityCountry,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: context.artC.ink.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      school.tuition,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.artC.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<CompareSchool> schools;

  _RadarPainter({required this.schools});

  static const _labels = ['排名', '就业', '费用', '设施', '声誉'];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 6);
    final r = math.min(size.width, size.height) * 0.36;
    final paintGrid = Paint()
      ..color = kSilver.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      final rr = r * ring / 4;
      for (var i = 0; i < 5; i++) {
        final ang = -math.pi / 2 + i * 2 * math.pi / 5;
        final x = c.dx + rr * math.cos(ang);
        final y = c.dy + rr * math.sin(ang);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paintGrid);
    }

    for (var i = 0; i < 5; i++) {
      final ang = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawLine(
        c,
        Offset(c.dx + r * math.cos(ang), c.dy + r * math.sin(ang)),
        paintGrid,
      );
      final lx = c.dx + (r + 18) * math.cos(ang);
      final ly = c.dy + (r + 18) * math.sin(ang);
      final tp = TextPainter(
        text: TextSpan(
          text: _labels[i],
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: kInk.withValues(alpha: 0.45),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }

    final colors = [kCobalt, kCobaltMuted, const Color(0xFF64748B)];
    for (var s = 0; s < schools.length; s++) {
      final school = schools[s];
      final path = Path();
      final scores = school.radarScores;
      for (var i = 0; i < 5; i++) {
        final ang = -math.pi / 2 + i * 2 * math.pi / 5;
        final v = scores[i] / 100.0;
        final rr = r * v;
        final x = c.dx + rr * math.cos(ang);
        final y = c.dy + rr * math.sin(ang);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      final fill = Paint()
        ..color = colors[s % colors.length].withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = colors[s % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.schools != schools;
}

class _CompareTable extends StatelessWidget {
  final List<CompareSchool> schools;

  const _CompareTable({required this.schools});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('预计学费/年', (CompareSchool s) => s.tuition, false),
      ('语言成绩要求', (CompareSchool s) => s.language, false),
      ('硕士就业率', (CompareSchool s) => s.employmentRate, true),
      ('GPA 录取建议', (CompareSchool s) => s.gpa, true),
      ('毕业平均起薪', (CompareSchool s) => s.avgSalary, true),
    ];
    return DataTable(
      headingRowColor: WidgetStateProperty.all(context.artC.porcelain),
      dataRowMinHeight: 44,
      horizontalMargin: 12,
      columns: [
        DataColumn(
          label: Text(
            '指标',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: context.artC.ink,
            ),
          ),
        ),
        ...schools.map(
          (s) => DataColumn(
            label: SizedBox(
              width: 120,
              child: Text(
                s.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ),
      ],
      rows: rows.map((row) {
        return DataRow(
          cells: [
            DataCell(
              Text(
                row.$1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: context.artC.ink.withValues(alpha: 0.38),
                ),
              ),
            ),
            ...schools.map((s) {
              return DataCell(
                Text(
                  row.$2(s),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }
}
