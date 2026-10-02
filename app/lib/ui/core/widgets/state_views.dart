import 'package:flutter/material.dart';

import '../../../utils/result.dart';
import '../l10n_extensions.dart';
import '../theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
  );
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.message, this.icon = Icons.info_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: context.palette.brandSoft, shape: BoxShape.circle),
          child: Icon(icon, size: 30, color: context.palette.brand),
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.palette.inkMuted),
        ),
      ],
    ),
  );
}

class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: context.palette.warnSoft, shape: BoxShape.circle),
          child: Icon(
            failure == AppFailure.offline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
            size: 30,
            color: context.palette.warn,
          ),
        ),
        const SizedBox(height: 12),
        Text(context.l10n.failure(failure), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.retry)),
      ],
    ),
  );
}
