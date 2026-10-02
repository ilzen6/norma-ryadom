import 'dart:io';

void main(List<String> args) {
  final minimum = double.parse(args.isEmpty ? '90' : args.first);
  final records = File('coverage/lcov.info').readAsStringSync().split('end_of_record');
  var found = 0;
  var hit = 0;
  for (final record in records) {
    final source = RegExp(r'SF:(.*)').firstMatch(record)?.group(1);
    if (source == null || _generated(source)) continue;
    found += int.parse(RegExp(r'LF:(\d+)').firstMatch(record)?.group(1) ?? '0');
    hit += int.parse(RegExp(r'LH:(\d+)').firstMatch(record)?.group(1) ?? '0');
  }
  final percent = found == 0 ? 0.0 : hit * 100 / found;
  stdout.writeln('Line coverage: ${percent.toStringAsFixed(1)}% ($hit/$found), minimum $minimum%');
  if (percent < minimum) exit(1);
}

bool _generated(String path) =>
    path.endsWith('.g.dart') || path.endsWith('.freezed.dart') || path.contains('/l10n/generated/');
