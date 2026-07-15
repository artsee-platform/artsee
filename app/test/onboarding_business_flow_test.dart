import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artsee_app/screens/onboarding/art_interest_onboarding_screen.dart';

void main() {
  testWidgets('机构 onboarding uses a two-step draft flow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArtInterestOnboardingScreen(onCompleted: () {}),
      ),
    );

    expect(find.text('1 / 3'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('机构'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('提交入驻申请'), findsOneWidget);

    await tester.tap(find.text('提交入驻申请'));
    await tester.pump();

    expect(find.text('先选择机构类型'), findsOneWidget);
  });
}
