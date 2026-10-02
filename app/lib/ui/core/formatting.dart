import 'package:intl/intl.dart';

abstract final class Formatting {
  static final _integer = NumberFormat.decimalPattern('ru');
  static final _decimal = NumberFormat('#,##0.#', 'ru');
  static final _rubles = NumberFormat('#,##0.##', 'ru');
  static final _date = DateFormat('dd.MM.yyyy', 'ru');
  static final _longDate = DateFormat('EEEE, d MMMM', 'ru');

  static String integer(num value) => _integer.format(value.round());

  static String decimal(num value) => _decimal.format(value);

  static String rubles(int priceMinor) => _rubles.format(priceMinor / 100);

  static String date(DateTime value) => _date.format(value.toLocal());

  static String longDate(DateTime value) {
    final text = _longDate.format(value.toLocal());
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }
}
