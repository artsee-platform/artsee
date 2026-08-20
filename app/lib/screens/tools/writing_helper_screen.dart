import 'package:flutter/material.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import '../../theme/artsee_ui_colors.dart';

class WritingHelperScreen extends StatefulWidget {
  const WritingHelperScreen({super.key});

  @override
  State<WritingHelperScreen> createState() => _WritingHelperScreenState();
}

class _WritingHelperScreenState extends State<WritingHelperScreen> {
  final TextEditingController _controller = TextEditingController();
  String _selectedType = '个人陈述';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.artC.porcelain,
      appBar: AppBar(
        backgroundColor: context.artC.porcelain,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.artC.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '文书助手',
          style: TextStyle(
            color: context.artC.ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'AI 文书辅助工具',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: context.artC.ink,
                  fontFamily: kAppFontFamily,
                  fontFamilyFallback: kAppFontFallback,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '帮助你撰写申请文书、个人陈述和推荐信',
                style: TextStyle(
                  fontSize: 14,
                  color: context.artC.ink.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '选择文书类型',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['个人陈述', '推荐信', '学习计划', '研究计划'].map((type) {
                  final isSelected = _selectedType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? kCobalt.withOpacity(0.08)
                            : context.artC.cardIconBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected
                              ? kCobalt.withOpacity(0.28)
                              : context.artC.silver.withOpacity(0.48),
                        ),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? kCobalt
                              : context.artC.ink.withOpacity(0.6),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                '输入你的想法',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.artC.ink,
                ),
              ),
              const SizedBox(height: 12),
              ArtseeSurface(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: '例如：我对可持续设计很感兴趣，希望通过学习探索环保材料...',
                    hintStyle: TextStyle(
                      color: context.artC.ink.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                    color: context.artC.ink,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // TODO: 调用 AI 生成文书
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AI 文书生成功能开发中...')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCobalt,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '生成文书',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
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
