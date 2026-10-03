import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/data/demo/demo_engine.dart';
import 'package:norma_ryadom/data/demo/demo_server.dart';

import '../../../tool/demo_catalog_builder.dart';

void main() {
  final catalog = DemoCatalog.fromJson(File('assets/demo/catalog.json').readAsStringSync());
  final contract = jsonDecode(File('../contract/combo-cases.json').readAsStringSync()) as Map<String, dynamic>;
  final cases = (contract['cases'] as List<dynamic>).cast<Map<String, dynamic>>();

  DemoTarget targetOf(Map<String, dynamic> json) => DemoTarget(
    kcal: (json['kcal'] as num).toDouble(),
    kcalTolerance: (json['kcalTolerance'] as num).toDouble(),
    minProtein: (json['minProtein'] as num).toDouble(),
    maxFat: (json['maxFat'] as num).toDouble(),
    maxCarbs: (json['maxCarbs'] as num).toDouble(),
    excludedTags: {...(json['excludeTags'] as List<dynamic>).cast<String>()},
  );

  List<Map<String, Object>> combosOf(List<DemoCombo> combos) => [
    for (final combo in combos)
      {
        'dishes': [for (final dish in combo.dishes) dish.name],
        'score': (combo.score * 1000000).round() / 1000000,
      },
  ];

  test('демо-каталог собран из тех же CSV, что загружает сервер', () {
    expect(
      File('assets/demo/catalog.json').readAsStringSync(),
      buildDemoCatalog(Directory('../server/src/main/resources')),
    );
  });

  test('эталон покрывает все сети и несколько целей', () {
    expect(cases.length, greaterThanOrEqualTo(5));
    expect(catalog.chains.where((chain) => chain.menu.isNotEmpty).map((chain) => chain.name), [
      for (final chain in (cases.first['chains'] as List<dynamic>).cast<Map<String, dynamic>>()) chain['chain'],
    ]);
  });

  for (final contractCase in cases) {
    test('подбор в браузере совпадает с сервером: ${contractCase['name']}', () {
      final exact = targetOf(contractCase['target'] as Map<String, dynamic>);
      final rounded = exact.rounded();
      final scorer = DemoScorer(preferCheaper: contractCase['preferCheaper'] == true);
      final optimizer = DemoOptimizer(scorer);
      expect(_targetJson(rounded), contractCase['roundedTarget']);

      for (final (index, expected) in (contractCase['chains'] as List<dynamic>).cast<Map<String, dynamic>>().indexed) {
        final menu = catalog.chains[index].menu;
        final nearby = optimizer.bestCombos(menu, rounded, 5);
        final fit = nearby.isNotEmpty
            ? 'GOOD'
            : optimizer.bestCombos(menu, rounded.relaxed(), 5).isNotEmpty
            ? 'COMPROMISE'
            : 'NONE';
        final replaced = nearby.isEmpty
            ? <DemoCombo>[]
            : optimizer.replacements(menu, rounded, nearby.first.dishes, 0, 3);
        final chain = expected['chain'];

        expect(fit, expected['fit'], reason: '$chain: цвет точки');
        expect(combosOf(nearby), expected['nearby'], reason: '$chain: подбор рядом');
        expect(
          combosOf(optimizer.bestCombos(menu, exact, 5)),
          expected['atVenue'],
          reason: '$chain: подбор в заведении',
        );
        expect(combosOf(replaced), expected['replaceFirst'], reason: '$chain: замена');
        expect(
          [
            for (final assessment in DemoAssessor(scorer).assessMenu(menu, exact))
              {
                'dish': assessment.dish.name,
                'verdict': switch (assessment.verdict) {
                  DemoVerdict.fits => 'FITS',
                  DemoVerdict.partial => 'PARTIAL',
                  DemoVerdict.notFits => 'NOT_FITS',
                },
                'reasons': [for (final reason in assessment.reasons) reason.code],
              },
          ],
          expected['assessment'],
          reason: '$chain: пометки меню',
        );
      }
    });
  }
}

Map<String, Object> _targetJson(DemoTarget target) => {
  'kcal': target.kcal,
  'kcalTolerance': target.kcalTolerance,
  'minProtein': target.minProtein,
  'maxFat': target.maxFat,
  'maxCarbs': target.maxCarbs,
  'excludeTags': target.excludedTags.toList()..sort(),
};
