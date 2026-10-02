import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/profile.dart';
import '../ui/combo/combo_screen.dart';
import '../ui/core/l10n_extensions.dart';
import '../ui/core/session.dart';
import '../ui/core/system_screens.dart';
import '../ui/diary/diary_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/map/map_screen.dart';
import '../ui/onboarding/onboarding_screen.dart';
import '../ui/onboarding/profile_edit_screen.dart';
import '../ui/profile/profile_screen.dart';
import '../ui/venue/venue_screen.dart';
import 'routes.dart';

enum ProfileGate { loading, failed, missing, present }

ProfileGate _gateOf(AsyncValue<UserProfile?> profile) => switch (profile) {
  AsyncValue(hasValue: false, hasError: true) => ProfileGate.failed,
  AsyncValue(hasValue: false) => ProfileGate.loading,
  AsyncValue(value: null) => ProfileGate.missing,
  _ => ProfileGate.present,
};

final routerProvider = Provider<GoRouter>((ref) {
  final gate = ValueNotifier<ProfileGate>(_gateOf(ref.read(profileProvider)));
  ref.listen(profileProvider, (_, next) => gate.value = _gateOf(next));
  ref.onDispose(gate.dispose);
  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: gate,
    redirect: (context, state) {
      final onboarding = state.matchedLocation == Routes.onboarding;
      final dataError = state.matchedLocation == Routes.dataError;
      return switch (gate.value) {
        ProfileGate.loading => null,
        ProfileGate.failed => dataError ? null : Routes.dataError,
        ProfileGate.missing => onboarding ? null : Routes.onboarding,
        ProfileGate.present => onboarding || dataError ? Routes.home : null,
      };
    },
    errorBuilder: (_, _) => const NotFoundScreen(),
    routes: [
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.dataError, builder: (_, _) => const DataErrorScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.map, builder: (_, _) => const MapScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.diary, builder: (_, _) => const DiaryScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileScreen(),
                routes: [GoRoute(path: 'edit', builder: (_, _) => const ProfileEditScreen())],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/venue/:id',
        builder: (_, state) => switch (int.tryParse(state.pathParameters['id'] ?? '')) {
          final venueId? when venueId > 0 => VenueScreen(venueId: venueId),
          _ => const NotFoundScreen(),
        },
      ),
      GoRoute(path: Routes.combo, builder: (_, _) => const ComboScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _MainShell extends StatelessWidget {
  const _MainShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.restaurant), label: l10n.navHome),
          NavigationDestination(icon: const Icon(Icons.map_outlined), label: l10n.navMap),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), label: l10n.navDiary),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: l10n.navProfile),
        ],
      ),
    );
  }
}
