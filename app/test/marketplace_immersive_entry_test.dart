import 'package:artsee_app/main.dart' as app;
import 'package:artsee_app/screens/forum/forum_screen.dart';
import 'package:artsee_app/theme/artsee_app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const {});
    await Supabase.initialize(
      url: app.supabaseUrl,
      anonKey: app.supabaseAnonKey,
    );
  });

  testWidgets('精选数字艺术详情提供当前页 3D 与全屏入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArtseeLightTheme(),
        home: const Scaffold(
          body: MarketplaceSurface(
            bottom: 0,
            searchKeyword: '',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('生成式数字雕塑《Mandelbulb · 二阶》'));
    await tester.pumpAndSettle();

    expect(find.text('先咨询'), findsOneWidget);
    expect(find.text('在当前页查看 3D'), findsOneWidget);
    expect(find.text('约 69 MB · 点击后加载'), findsOneWidget);
    await tester.drag(
      find.byType(ListView).last,
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    expect(find.text('全屏沉浸观看'), findsOneWidget);
    await tester.drag(
      find.byType(ListView).last,
      const Offset(0, -760),
    );
    await tester.pumpAndSettle();
    expect(find.text('作品信息'), findsOneWidget);
    expect(find.text('交付与保障'), findsOneWidget);
    await tester.drag(
      find.byType(ListView).last,
      const Offset(0, -820),
    );
    await tester.pumpAndSettle();
    expect(find.text('精选评论'), findsOneWidget);
  });

  testWidgets('固定价商品展示规格、交付信息和直接购买入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArtseeLightTheme(),
        home: const Scaffold(
          body: MarketplaceSurface(
            bottom: 0,
            searchKeyword: '',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('手工陶瓷香器'));
    await tester.pumpAndSettle();

    expect(find.text('直接购买'), findsOneWidget);
    final detailScroll = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('手工陶瓷'),
      260,
      scrollable: detailScroll,
    );
    await tester.pumpAndSettle();
    expect(find.text('手工陶瓷'), findsOneWidget);
    expect(find.text('约 9 × 9 × 12 cm'), findsOneWidget);
    expect(find.text('付款后 3–5 天内发出'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('相关作品'),
      320,
      scrollable: detailScroll,
    );
    await tester.pumpAndSettle();
    expect(find.text('相关作品'), findsOneWidget);
  });

  testWidgets('商品详情分享入口提供二维码、复制、浏览器和举报操作', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildArtseeLightTheme(),
        home: const Scaffold(
          body: MarketplaceSurface(
            bottom: 0,
            searchKeyword: '',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('手工陶瓷香器'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('分享商品'));
    await tester.pumpAndSettle();

    expect(find.text('分享这件作品'), findsOneWidget);
    expect(find.text('复制链接'), findsOneWidget);
    expect(find.text('浏览器打开'), findsOneWidget);
    expect(find.text('举报'), findsOneWidget);
  });
}
