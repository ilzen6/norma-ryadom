import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n_extensions.dart';
import 'body_parameters_form.dart';
import 'norm_card.dart';
import 'onboarding_view_model.dart';
import 'preferences_picker.dart';

class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileEdit)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const BodyParametersForm(),
            const SizedBox(height: 16),
            const NormCard(),
            const SizedBox(height: 16),
            Text(l10n.onboardingPreferencesTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            const PreferencesPicker(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('profile-save'),
            onPressed: !state.bodyValid || state.saving
                ? null
                : () async {
                    final router = GoRouter.of(context);
                    if (await ref.read(onboardingProvider.notifier).complete()) router.pop();
                  },
            child: Text(l10n.save),
          ),
        ),
      ),
    );
  }
}
