import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/server_address.dart';
import '../core/l10n_extensions.dart';
import '../core/widgets/busy_action.dart';
import 'server_settings_view_model.dart';

class ServerDialog extends ConsumerStatefulWidget {
  const ServerDialog({super.key});

  @override
  ConsumerState<ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends ConsumerState<ServerDialog> {
  late final TextEditingController _controller = TextEditingController(text: ref.read(serverAddressProvider));
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final l10n = context.l10n;
    final update = await ref.read(serverSettingsProvider).apply(_controller.text);
    if (!mounted) return;
    switch (update) {
      case ServerSaved(:final address):
        Navigator.of(context).pop(address);
      case ServerRejected(problem: ServerAddressProblem.invalid):
        setState(() => _error = l10n.serverInvalid);
      case ServerRejected(problem: ServerAddressProblem.insecure):
        setState(() => _error = l10n.serverInsecure);
      case ServerUnreachable(:final failure):
        setState(() => _error = l10n.failure(failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.serverTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.serverHint),
          const SizedBox(height: 12),
          TextField(
            key: const Key('server-address'),
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(labelText: l10n.serverAddressLabel, errorText: _error, errorMaxLines: 3),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        BusyAction<void>(
          run: (_) => _apply(),
          builder: (context, onPressed, busy) => FilledButton(
            key: const Key('server-save'),
            onPressed: onPressed,
            child: busy
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.serverCheckAndSave),
          ),
        ),
      ],
    );
  }
}
