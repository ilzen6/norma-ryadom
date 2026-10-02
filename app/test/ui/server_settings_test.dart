import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/config/app_config.dart';
import 'package:norma_ryadom/data/providers.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  Future<void> openServerDialog(WidgetTester tester, TestHarness harness) async {
    await harness.pump(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Профиль')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('server-settings')));
  }

  Future<void> submit(WidgetTester tester, String address) async {
    await tester.enterText(find.byKey(const Key('server-address')), address);
    await tester.tap(find.byKey(const Key('server-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('проверяет связь с новым сервером и запоминает его адрес', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await openServerDialog(tester, harness);
    expect(find.widgetWithText(TextField, 'http://test'), findsOneWidget);

    await submit(tester, ' https://norma.example.ru/ ');

    expect(harness.probe.checked, ['https://norma.example.ru']);
    expect(harness.settings.address, 'https://norma.example.ru');
    expect(find.text('Сервер подключён'), findsOneWidget);
    expect(find.text('https://norma.example.ru'), findsOneWidget);
  });

  testWidgets('не сохраняет адрес, если сервер не отвечает', (tester) async {
    final harness = TestHarness(profile: TestData.profile)..probe.result = const Err(AppFailure.offline);
    await openServerDialog(tester, harness);

    await submit(tester, 'https://down.example.ru');

    expect(harness.settings.address, isNull);
    expect(find.text('Нет связи с сервером. Проверьте интернет и адрес сервера в профиле.'), findsOneWidget);
  });

  testWidgets('объясняет, что адрес не похож на адрес сервера', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await openServerDialog(tester, harness);

    await submit(tester, 'norma.example.ru');

    expect(harness.probe.checked, isEmpty);
    expect(find.text('Введите адрес сервера целиком, например https://norma.example.ru'), findsOneWidget);
  });

  testWidgets('в обычной сборке требует https для адреса в сети', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await openServerDialog(tester, harness);

    await submit(tester, 'http://192.168.1.5:8080');

    expect(harness.probe.checked, isEmpty);
    expect(find.text('Нужен защищённый адрес, начинающийся с https://'), findsOneWidget);
  });

  testWidgets('в демо-сборке подключается к компьютеру в локальной сети по HTTP', (tester) async {
    final harness = TestHarness(profile: TestData.profile)..allowCleartextServer = true;
    await openServerDialog(tester, harness);

    await submit(tester, 'http://192.168.1.5:8080');

    expect(harness.settings.address, 'http://192.168.1.5:8080');
  });

  test('после смены адреса создаёт клиент API заново', () async {
    final settings = InMemorySettingsRepository();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'http://10.0.2.2:8080', tileUrlTemplate: '', searchRadiusMeters: 1500),
        ),
        settingsRepositoryProvider.overrideWithValue(settings),
        initialServerAddressProvider.overrideWithValue('https://saved.example.ru'),
      ],
    );
    addTearDown(container.dispose);
    final before = container.read(normaApiProvider);
    expect(container.read(serverAddressProvider), 'https://saved.example.ru');

    await container.read(serverAddressProvider.notifier).save('https://norma.example.ru');

    expect(container.read(serverAddressProvider), 'https://norma.example.ru');
    expect(identical(container.read(normaApiProvider), before), isFalse);
  });
}
