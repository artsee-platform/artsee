import 'package:flutter/material.dart';
import '../../widgets/artsee_ui.dart';
import '../../widgets/common.dart';
import '../../theme/artsee_ui_colors.dart';

class ArtCalculatorScreen extends StatefulWidget {
  const ArtCalculatorScreen({super.key});

  @override
  State<ArtCalculatorScreen> createState() => _ArtCalculatorScreenState();
}

class _ArtCalculatorScreenState extends State<ArtCalculatorScreen> {
  final TextEditingController _gpaController = TextEditingController();
  final TextEditingController _toeflController = TextEditingController();
  final TextEditingController _ieltsController = TextEditingController();
  String _selectedDegree = '硕士';
  String _selectedCountry = '英国';

  @override
  void dispose() {
    _gpaController.dispose();
    _toeflController.dispose();
    _ieltsController.dispose();
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
          '艺术计算器',
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
                '申请成功率评估',
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
                '基于你的背景，评估申请顶尖艺术院校的成功率',
                style: TextStyle(
                  fontSize: 14,
                  color: context.artC.ink.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              _buildSection(
                '目标学位',
                Wrap(
                  spacing: 8,
                  children: ['本科', '硕士', '博士'].map((degree) {
                    final isSelected = _selectedDegree == degree;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDegree = degree),
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
                          degree,
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
              ),
              const SizedBox(height: 20),
              _buildSection(
                '目标国家',
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['英国', '美国', '欧洲', '其他'].map((country) {
                    final isSelected = _selectedCountry == country;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCountry = country),
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
                          country,
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
              ),
              const SizedBox(height: 20),
              _buildInputField('GPA', _gpaController, '例如：3.5'),
              const SizedBox(height: 16),
              _buildInputField('TOEFL', _toeflController, '例如：100'),
              const SizedBox(height: 16),
              _buildInputField('IELTS', _ieltsController, '例如：7.0'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // TODO: 调用计算器 API
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('成功率计算功能开发中...')),
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
                  '计算成功率',
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

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.artC.ink,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.artC.ink,
          ),
        ),
        const SizedBox(height: 8),
        ArtseeSurface(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: hint,
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
      ],
    );
  }
}
