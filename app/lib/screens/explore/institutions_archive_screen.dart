import 'package:flutter/material.dart';
import '../../data/institution_archive_data.dart';
import '../../widgets/common.dart';
import 'package:artsee_app/theme/artsee_ui_colors.dart';

/// 对齐稿件 `InstitutionsView`：大标题、搜索、地区胶囊、卡片栅格
class InstitutionsArchiveScreen extends StatefulWidget {
  const InstitutionsArchiveScreen({super.key});

  @override
  State<InstitutionsArchiveScreen> createState() =>
      _InstitutionsArchiveScreenState();
}

class _InstitutionsArchiveScreenState extends State<InstitutionsArchiveScreen> {
  late String _region;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _region = kInstitutionArchiveByRegion.keys.first;
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InstitutionArchive> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final list = kInstitutionArchiveByRegion[_region] ?? [];
    if (q.isEmpty) return list;
    return list
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              (e.originalName?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = mainTabBottomInset(context);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, -0.2),
                  radius: 1.2,
                  colors: [
                    kCobalt.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 1,
                          color: kCobalt,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Artiqore Global Archive',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 2.4,
                            color: kCobalt.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '全球顶尖\n艺术院校',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        height: 1.05,
                        fontStyle: FontStyle.italic,
                        color: context.artC.ink,
                        fontFamily: 'Noto Serif SC',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '汇聚全球最具影响力的创意硅谷，探索通往艺术殿堂的学术路径。',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        height: 1.5,
                        color: context.artC.ink.withValues(alpha: 0.42),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Archive · $kInstitutionArchiveTotalCount+ Institutions · 7 Regions',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: context.artC.ink.withValues(alpha: 0.28),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: '搜索院校名称...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: context.artC.ink.withValues(alpha: 0.22),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: context.artC.ink.withValues(alpha: 0.22),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.55),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kRadiusMedium),
                          borderSide: BorderSide(
                              color:
                                  context.artC.silver.withValues(alpha: 0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kRadiusMedium),
                          borderSide: BorderSide(
                              color:
                                  context.artC.silver.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(kRadiusMedium),
                          borderSide: BorderSide(
                              color: kCobalt.withValues(alpha: 0.35)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: kInstitutionArchiveByRegion.keys.map((r) {
                          final sel = r == _region;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () => setState(() => _region = r),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? Colors.white
                                      : context.artC.silver
                                          .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(kRadiusMedium),
                                  boxShadow: sel
                                      ? [
                                          BoxShadow(
                                            color:
                                                kCobalt.withValues(alpha: 0.08),
                                            blurRadius: 18,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: sel
                                        ? kCobalt
                                        : context.artC.ink
                                            .withValues(alpha: 0.38),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (_filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 48, 24, bottom),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: context.artC.silver.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search,
                          size: 36,
                          color: context.artC.silver.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '未能找到相关院校',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: context.artC.ink.withValues(alpha: 0.35),
                          fontFamily: 'Noto Serif SC',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final inst = _filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _InstitutionCard(
                          index: index,
                          inst: inst,
                          onOpen: () => _openDetail(context, inst),
                        ),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, InstitutionArchive inst) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _InstitutionArchiveDetailPage(inst: inst),
      ),
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  final int index;
  final InstitutionArchive inst;
  final VoidCallback onOpen;

  const _InstitutionCard({
    required this.index,
    required this.inst,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final no = (index + 1).toString().padLeft(2, '0');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(48),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(48),
            border:
                Border.all(color: context.artC.silver.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: AspectRatio(
                  aspectRatio: 21 / 10,
                  child: Image.network(
                    inst.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: context.artC.silver.withValues(alpha: 0.35)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.artC.porcelain,
                      borderRadius: BorderRadius.circular(kRadiusMedium),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      color: context.artC.ink.withValues(alpha: 0.25),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'No. $no',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: context.artC.ink.withValues(alpha: 0.22),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onOpen,
                    icon: Icon(
                      Icons.open_in_new,
                      size: 18,
                      color: context.artC.ink.withValues(alpha: 0.22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                inst.name,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                  height: 1.2,
                  color: context.artC.ink,
                  fontFamily: 'Noto Serif SC',
                ),
              ),
              if (inst.originalName != null) ...[
                const SizedBox(height: 6),
                Text(
                  inst.originalName!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: context.artC.ink.withValues(alpha: 0.28),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                inst.description,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  height: 1.55,
                  color: context.artC.ink.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 15,
                      color: context.artC.ink.withValues(alpha: 0.32)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      inst.location.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: context.artC.ink.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onOpen,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '查看详情',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: context.artC.ink.withValues(alpha: 0.75),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: context.artC.ink.withValues(alpha: 0.45),
                        ),
                      ],
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

class _InstitutionArchiveDetailPage extends StatelessWidget {
  final InstitutionArchive inst;

  const _InstitutionArchiveDetailPage({required this.inst});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: context.artC.porcelain.withValues(alpha: 0.94),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new,
                  size: 18, color: context.artC.ink),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              inst.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.artC.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(kRadiusLarge),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.network(
                        inst.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: context.artC.silver.withValues(alpha: 0.35)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (inst.originalName != null)
                    Text(
                      inst.originalName!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                        color: context.artC.ink.withValues(alpha: 0.35),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    inst.name,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      fontFamily: 'Noto Serif SC',
                      color: context.artC.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 16, color: kCobalt),
                      const SizedBox(width: 6),
                      Text(
                        inst.location,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.artC.ink.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    inst.description,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.65,
                      color: context.artC.ink.withValues(alpha: 0.72),
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
