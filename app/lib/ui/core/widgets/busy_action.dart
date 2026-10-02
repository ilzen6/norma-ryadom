import 'package:flutter/material.dart';

typedef BusyActionBuilder = Widget Function(BuildContext context, VoidCallback? onPressed, bool busy);

class BusyAction<T> extends StatefulWidget {
  const BusyAction({super.key, this.prepare, required this.run, required this.builder});

  final Future<T?> Function()? prepare;
  final Future<void> Function(T? prepared) run;
  final BusyActionBuilder builder;

  static Widget icon(IconData icon, {required bool busy}) =>
      busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon);

  @override
  State<BusyAction<T>> createState() => _BusyActionState<T>();
}

class _BusyActionState<T> extends State<BusyAction<T>> {
  bool _locked = false;
  bool _busy = false;

  Future<void> _press() async {
    if (_locked) return;
    _locked = true;
    try {
      final prepare = widget.prepare;
      final prepared = prepare == null ? null : await prepare();
      if (!mounted || (prepare != null && prepared == null)) return;
      setState(() => _busy = true);
      await widget.run(prepared);
    } finally {
      _locked = false;
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _busy ? null : _press, _busy);
}
