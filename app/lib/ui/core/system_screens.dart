import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../routing/routes.dart';
import 'l10n_extensions.dart';
import 'session.dart';
import 'widgets/state_views.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MessageView(message: l10n.errorNotFound, icon: Icons.search_off),
            FilledButton(onPressed: () => context.go(Routes.home), child: Text(l10n.goHome)),
          ],
        ),
      ),
    );
  }
}

class DataErrorScreen extends ConsumerWidget {
  const DataErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MessageView(message: l10n.dataErrorText, icon: Icons.storage),
                FilledButton.tonal(onPressed: () => ref.invalidate(profileProvider), child: Text(l10n.retry)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('data-reset'),
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  icon: const Icon(Icons.delete_forever),
                  label: Text(l10n.dataErrorReset),
                  onPressed: () async {
                    await ref.read(profileRepositoryProvider).deleteAllData();
                    ref.invalidate(profileProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
