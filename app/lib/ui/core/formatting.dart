import 'package:intl/intl.dart';

abstract final class Formatting {
  static final _integer = NumberFormat.decimalPattern('ru');
  static final _rubles = NumberFormat('#,##0.##', 'ru');
  static final _date = DateFormat('dd.MM.yyyy', 'ru');

  static String integer(num value) => _integer.format(value.round());

  static String rubles(int priceMinor) => _rubles.format(priceMinor / 100);

  static String date(DateTime value) => _date.format(value.toLocal());
}
