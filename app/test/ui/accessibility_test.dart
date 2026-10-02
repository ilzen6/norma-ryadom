import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  Future<void> expectAccessible(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('онбординг доступен: размер целей, подписи, контраст', (tester) async {
    final handle = tester.ensureSemantics();
    await TestHarness().pump(tester);

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('главный экран с результатами доступен', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget,
          options: [
            TestData.option([TestData.dish(1, 'Куриная грудка гриль', 374)]),
          ],
        ),
      );
    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('экран набора доступен', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget,
          options: [
            TestData.option([TestData.dish(1, 'Куриная грудка гриль', 374)]),
          ],
        ),
      );
    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Куриная грудка гриль'));

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('дневник и профиль доступны', (tester) async {
    final handle = tester.ensureSemantics();
    await TestHarness(profile: TestData.profile).pump(tester);

    for (final tab in ['Дневник', 'Профиль']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
      await expectAccessible(tester);
    }
    handle.dispose();
  });
}
