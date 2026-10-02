import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n_extensions.dart';
import 'body_parameters_form.dart';
import 'location_picker.dart';
import 'norm_card.dart';
import 'onboarding_view_model.dart';
import 'preferences_picker.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 3;
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final title = switch (_step) {
      0 => l10n.onboardingBodyTitle,
      1 => l10n.onboardingPreferencesTitle,
      _ => l10n.onboardingLocationTitle,
    };
    final canContinue = _step != 0 || state.bodyValid;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: _step == 0
            ? null
            : IconButton(
                tooltip: l10n.back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.onboardingStep(_step + 1, _steps), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 16),
            ...switch (_step) {
              0 => const [BodyParametersForm(), SizedBox(height: 16), NormCard()],
              1 => [Text(l10n.preferencesHint), const SizedBox(height: 16), const PreferencesPicker()],
              _ => const [LocationPicker()],
            },
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('onboarding-next'),
            onPressed: !canContinue || state.saving ? null : _next,
            child: Text(_step == _steps - 1 ? l10n.start : l10n.next),
          ),
        ),
      ),
    );
  }

  Future<void> _next() async {
    if (_step < _steps - 1) {
      setState(() => _step++);
      return;
    }
    await ref.read(onboardingProvider.notifier).complete();
  }
}
