import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n_extensions.dart';
import '../core/theme.dart';
import '../core/widgets/visuals.dart';
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? null
            : IconButton(
                tooltip: l10n.back,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _step--),
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            if (_step == 0) ...[
              Row(
                children: [
                  const BrandMark(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.appTitle, style: textTheme.titleMedium),
                        Text(
                          l10n.appTagline,
                          style: textTheme.bodySmall?.copyWith(color: context.palette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            StepProgress(current: _step, total: _steps),
            const SizedBox(height: 18),
            Eyebrow(l10n.onboardingStep(_step + 1, _steps)),
            const SizedBox(height: 6),
            Semantics(header: true, child: Text(title, style: textTheme.headlineMedium)),
            const SizedBox(height: 20),
            ...switch (_step) {
              0 => const [BodyParametersForm(), SizedBox(height: 16), NormCard()],
              1 => [
                Text(l10n.preferencesHint, style: textTheme.bodyLarge?.copyWith(color: context.palette.inkMuted)),
                const SizedBox(height: 20),
                const PreferencesPicker(),
              ],
              _ => const [LocationPicker()],
            },
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
