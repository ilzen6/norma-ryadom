import 'dart:convert';
import 'dart:io';

const demoVerifiedAt = '2026-09-30T00:00:00Z';

const _meatKinds = {'pork', 'beef', 'chicken'};

String buildDemoCatalog(Directory serverResources) {
  final config = File('${serverResources.path}/application-demo.yml').readAsLinesSync();
  final chains = <Map<String, Object?>>[];
  var places = <Map<String, Object?>>[];
  String? name;
  String? sourceUrl;
  String? menu;
  String? sourceDate;
  for (final line in config.map((line) => line.trim())) {
    if (line.startsWith('- name:')) name = _value(line);
    if (line.startsWith('source-url:')) sourceUrl = _value(line);
    if (line.startsWith('menu:')) menu = _value(line).replaceFirst('classpath:', '');
    if (line.startsWith('source-date:')) sourceDate = _value(line);
    if (line.startsWith('places:')) {
      places = _rows(File('${serverResources.path}/${_value(line).replaceFirst('classpath:', '')}'))
          .map(_venue)
          .toList();
    }
    if (line.startsWith('venues:') && name != null && sourceUrl != null) {
      final venues = _value(line).replaceFirst('classpath:', '');
      chains.add({
        'name': name,
        'sourceUrl': sourceUrl,
        'verifiedAt': ?(sourceDate == null ? null : '${sourceDate}T00:00:00Z'),
        'items': menu == null ? const <Object>[] : _rows(File('${serverResources.path}/$menu')).map(_item).toList(),
        'venues': _rows(File('${serverResources.path}/$venues')).map(_venue).toList(),
      });
      name = sourceUrl = menu = sourceDate = null;
    }
  }
  return '${const JsonEncoder.withIndent('  ').convert({'verifiedAt': demoVerifiedAt, 'chains': chains, 'places': places})}\n';
}

String _value(String line) {
  final value = line.substring(line.indexOf(':') + 1).trim();
  return value.startsWith('"') ? jsonDecode(value) as String : value;
}

List<Map<String, String>> _rows(File file) {
  final lines = file.readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();
  final header = lines.first.split(';').map((column) => column.trim()).toList();
  return [
    for (final line in lines.skip(1))
      {for (final (index, value) in line.split(';').indexed) header[index]: value.trim()},
  ];
}

Map<String, Object?> _item(Map<String, String> row) {
  final tags = {
    for (final tag in row['tags']!.split(','))
      if (tag.trim().isNotEmpty) tag.trim().toLowerCase(),
  };
  if (tags.any(_meatKinds.contains)) tags.add('meat');
  final price = row['price_rub']!;
  return {
    'name': row['name'],
    'category': row['category'],
    'portionGrams': row['portion_g']!.isEmpty ? null : double.parse(row['portion_g']!),
    'kcal': double.parse(row['kcal']!),
    'protein': double.parse(row['protein_g']!),
    'fat': double.parse(row['fat_g']!),
    'carbs': double.parse(row['carbs_g']!),
    'priceMinor': price.isEmpty ? null : (double.parse(price) * 100).round(),
    'tags': tags.toList()..sort(),
  };
}

Map<String, Object?> _venue(Map<String, String> row) => {
  'name': row['name'],
  'address': row['address'],
  'lat': double.parse(row['lat']!),
  'lon': double.parse(row['lon']!),
  if (row['confirmed_on'] case final confirmed? when confirmed.isNotEmpty) 'confirmedOn': confirmed,
};
