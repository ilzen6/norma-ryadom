class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.tileUrlTemplate,
    required this.searchRadiusMeters,
    this.mapRadiusMeters = 3000,
    this.allowCleartextServer = false,
    this.demoServer = false,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080'),
    tileUrlTemplate: String.fromEnvironment(
      'TILE_URL_TEMPLATE',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    searchRadiusMeters: int.fromEnvironment('SEARCH_RADIUS_METERS', defaultValue: 1500),
    mapRadiusMeters: int.fromEnvironment('MAP_RADIUS_METERS', defaultValue: 3000),
    allowCleartextServer: String.fromEnvironment('FLUTTER_APP_FLAVOR') == demoFlavor,
    demoServer: bool.fromEnvironment('DEMO_SERVER'),
  );

  static const demoFlavor = 'demo';

  final String apiBaseUrl;
  final String tileUrlTemplate;
  final int searchRadiusMeters;
  final int mapRadiusMeters;
  final bool allowCleartextServer;
  final bool demoServer;
}
