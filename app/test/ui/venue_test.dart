import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:norma_ryadom/data/services/norma_api.dart';
import 'package:norma_ryadom/data/services/photo_picker_service.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  final menu = VenueMenu(
    venue: TestData.venue,
    items: [
      MenuItem(
        id: 11,
        name: 'Куриная грудка гриль',
        category: DishCategory.main,
        nutrients: const Nutrients(kcal: 374, protein: 38, fat: 6, carbs: 2),
        priceMinor: 29900,
        source: DataSource(kind: SourceKind.verified, verifiedAt: DateTime.utc(2026, 9, 30)),
        assessment: const Assessment(verdict: Verdict.fits),
      ),
      const MenuItem(
        id: 12,
        name: 'Рис с овощами',
        category: DishCategory.side,
        nutrients: Nutrients(kcal: 207, protein: 4, fat: 3, carbs: 41),
        source: DataSource(kind: SourceKind.fromMenu),
        assessment: Assessment(
          verdict: Verdict.partial,
          reasons: [AssessmentReason(code: ReasonCode.lowProtein, amount: 5)],
        ),
      ),
      const MenuItem(
        id: 13,
        name: 'Свиные рёбрышки',
        category: DishCategory.main,
        nutrients: Nutrients(kcal: 624, protein: 39, fat: 48, carbs: 9),
        priceMinor: 48900,
        source: DataSource(kind: SourceKind.estimate, kcalLow: 437, kcalHigh: 811),
        assessment: Assessment(
          verdict: Verdict.notFits,
          reasons: [
            AssessmentReason(code: ReasonCode.excludedTag, tag: 'pork'),
            AssessmentReason(code: ReasonCode.fatAbove, amount: 24.5),
          ],
        ),
      ),
    ],
  );

  Future<TestHarness> openVenue(WidgetTester tester, {Result<VenueMenu>? result}) async {
    final harness = TestHarness(profile: TestData.profile)..venues.menuResult = result ?? Ok(menu);
    await harness.pump(tester);
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/venue/7'));
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('показывает меню с пометками, причинами и уровнем доверия', (tester) async {
    await openVenue(tester);

    expect(find.text('Гриль Хаус, Москва-Сити'), findsOneWidget);
    expect(find.text('подходит'), findsOneWidget);
    await scrollTo(tester, find.text('не подходит'));
    expect(find.text('можно, но…'), findsOneWidget);
    expect(find.text('мало белка'), findsOneWidget);
    expect(find.text('есть свинина, жиры больше цели на 25 г'), findsOneWidget);
    expect(find.text('данные сети · проверено 30.09.2026'), findsOneWidget);
    expect(find.text('из меню заведения'), findsOneWidget);
    expect(find.text('оценка · ≈ 437–811 ккал'), findsOneWidget);
    expect(find.text('цена не указана'), findsOneWidget);
  });

  testWidgets('собирает обед в этом заведении', (tester) async {
    final harness = await openVenue(tester);
    harness.combos.venueResult = Ok(
      ComboSearchResult(
        appliedTarget: TestData.lunchTarget,
        options: [
          TestData.option([TestData.dish(11, 'Куриная грудка гриль', 374), TestData.dish(12, 'Рис с овощами', 207)]),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('build-here')));
    await tester.pumpAndSettle();

    expect(find.text('Собрать обед здесь'), findsOneWidget);
    expect(find.text('Куриная грудка гриль + Рис с овощами'), findsOneWidget);
    await tester.tap(find.text('Куриная грудка гриль + Рис с овощами'));
    await tester.pumpAndSettle();
    expect(find.text('Попадание в цель'), findsOneWidget);
  });

  testWidgets('отправляет жалобу «цифры не совпадают» только с причиной', (tester) async {
    final harness = await openVenue(tester);

    await tester.tap(find.byKey(const Key('report-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-send')));
    await tester.pumpAndSettle();
    expect(find.text('Опишите, что не совпадает'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('report-reason')), 'На стенде 420 ккал');
    await tester.tap(find.byKey(const Key('report-send')));
    await tester.pumpAndSettle();

    expect(harness.feedback.reports.single, (11, 'На стенде 420 ккал'));
    expect(find.text('Спасибо! Блюдо проверим'), findsOneWidget);
  });

  testWidgets('загружает фото меню из галереи и сообщает об ошибке формата', (tester) async {
    final harness = await openVenue(tester);

    await tester.tap(find.byKey(const Key('upload-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upload-from-gallery')));
    await tester.pumpAndSettle();
    expect(harness.picker.sources.single, PhotoSource.gallery);
    expect(harness.feedback.photos.single.$1, 7);
    expect(find.text('Спасибо! Фото отправлено на проверку'), findsOneWidget);

    harness.feedback.photoResult = const Err(AppFailure.unsupportedPhoto);
    await tester.tap(find.byKey(const Key('upload-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upload-from-gallery')));
    await tester.pumpAndSettle();
    expect(find.text('Подходят только фото JPEG и PNG.'), findsOneWidget);
  });

  testWidgets('ничего не отправляет, если пользователь не выбрал фото', (tester) async {
    final harness = await openVenue(tester);
    harness.picker.result = const Ok(null);

    await tester.tap(find.byKey(const Key('upload-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upload-from-gallery')));
    await tester.pumpAndSettle();

    expect(harness.feedback.photos, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('показывает понятную ошибку, если заведение не найдено', (tester) async {
    await openVenue(tester, result: const Err(AppFailure.notFound));

    expect(find.text('Заведение не найдено — возможно, оно закрылось.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('объясняет, что нет доступа к камере или галерее', (tester) async {
    final harness = await openVenue(tester);
    harness.picker.result = const Err(AppFailure.photoAccessDenied);

    await tester.tap(find.byKey(const Key('upload-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upload-from-gallery')));
    await tester.pumpAndSettle();

    expect(harness.feedback.photos, isEmpty);
    expect(find.text('Нет доступа к камере или галерее. Разрешите доступ в настройках телефона.'), findsOneWidget);
  });

  testWidgets('не отправляет фото второй раз, пока идёт загрузка', (tester) async {
    final harness = await openVenue(tester);
    final gate = Completer<void>();
    harness.feedback.gate = gate;

    await tester.tap(find.byKey(const Key('upload-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upload-from-gallery')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.widget<IconButton>(find.byKey(const Key('upload-photo'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('upload-photo')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('upload-from-gallery')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(harness.feedback.photos, hasLength(1));
    expect(tester.widget<IconButton>(find.byKey(const Key('upload-photo'))).onPressed, isNotNull);
  });

  testWidgets('подбирает в заведении по текущей цели и выбранной цене', (tester) async {
    final harness = await openVenue(tester);

    await tester.tap(find.byKey(const Key('build-here')));
    await tester.pumpAndSettle();

    expect(harness.combos.requestedVenues.single, 7);
    expect(harness.combos.requestedTargets.single.kcal, 630);
    expect(harness.combos.requestedPrices.single, PricePreference.any);
  });
}
