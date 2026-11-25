import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Норма рядом',
      packageName: 'ru.normaryadom.norma_ryadom',
      version: '1.0.0',
      buildNumber: '10',
      buildSignature: '',
    ),
  );

  Future<void> openAbout(WidgetTester tester, TestHarness harness) async {
    await harness.pump(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Профиль')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('open-about')));
  }

  testWidgets('из профиля открывает «О приложении» с версией и будущей синхронизацией', (tester) async {
    await openAbout(tester, TestHarness(profile: TestData.profile));

    expect(find.text('Версия 1.0.0 (10)'), findsOneWidget);
    expect(find.text('Откуда данные: 25 сетей и OpenStreetMap'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('about-sync-soon')), matching: find.text('Скоро')), findsOneWidget);
    expect(find.text('Карта © участники OpenStreetMap'), findsOneWidget);
  });

  testWidgets('объясняет, как считается норма', (tester) async {
    await openAbout(tester, TestHarness(profile: TestData.profile));

    await tester.tap(find.byKey(const Key('about-norm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Миффлина — Сан Жеора'), findsOneWidget);
    await tester.tap(find.text('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Миффлина — Сан Жеора'), findsNothing);
  });

  testWidgets('открывает лицензии открытых библиотек', (tester) async {
    await openAbout(tester, TestHarness(profile: TestData.profile));

    await tester.tap(find.byKey(const Key('about-licenses')));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('открывает политику конфиденциальности и из профиля, и из «О приложении»', (tester) async {
    await openAbout(tester, TestHarness(profile: TestData.profile));

    await tester.tap(find.byKey(const Key('about-privacy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy-sheet')), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const Key('open-privacy')));
    expect(find.text('Что уходит на сервер при подборе'), findsOneWidget);
  });

  testWidgets('без адреса разработчиков строку «Написать» не показывает', (tester) async {
    await openAbout(tester, TestHarness(profile: TestData.profile));

    expect(find.byKey(const Key('about-write')), findsNothing);
  });

  testWidgets('копирует адрес разработчиков и сообщает об этом', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map<Object?, Object?>)['text']! as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await openAbout(tester, TestHarness(profile: TestData.profile)..supportEmail = 'team@norma.example');

    await tester.tap(find.byKey(const Key('about-write')));
    await tester.pumpAndSettle();

    expect(copied, ['team@norma.example']);
    expect(find.text('Адрес скопирован: team@norma.example'), findsOneWidget);
  });
}
