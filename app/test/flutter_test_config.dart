import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _fonts = {
  'Onest': ['Onest_400Regular', 'Onest_500Medium', 'Onest_600SemiBold', 'Onest_700Bold'],
  'Unbounded': ['Unbounded_500Medium', 'Unbounded_600SemiBold', 'Unbounded_700Bold'],
};

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final MapEntry(key: family, value: files) in _fonts.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(rootBundle.load('assets/fonts/$file.ttf'));
    }
    await loader.load();
  }
  await testMain();
}
