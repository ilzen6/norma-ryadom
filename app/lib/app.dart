import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'routing/app_router.dart';
import 'ui/core/session.dart';
import 'ui/core/theme.dart';

class NormaRyadomApp extends ConsumerStatefulWidget {
  const NormaRyadomApp({super.key});

  @override
  ConsumerState<NormaRyadomApp> createState() => _NormaRyadomAppState();
}

class _NormaRyadomAppState extends ConsumerState<NormaRyadomApp> {
  late final AppLifecycleListener _lifecycle;

  void _refreshSession() {
    ref.read(currentDayProvider.notifier).refresh();
    ref.invalidate(locationProvider);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshSession);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    theme: buildTheme(),
    locale: const Locale('ru'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: ref.watch(routerProvider),
  );
}
