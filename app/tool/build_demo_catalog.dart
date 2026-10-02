import 'dart:io';

import 'demo_catalog_builder.dart';

void main() {
  File('assets/demo/catalog.json').writeAsStringSync(buildDemoCatalog(Directory('../server/src/main/resources')));
}
