class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.tileUrlTemplate, required this.searchRadiusMeters});

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080'),
    tileUrlTemplate: String.fromEnvironment(
      'TILE_URL_TEMPLATE',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    searchRadiusMeters: int.fromEnvironment('SEARCH_RADIUS_METERS', defaultValue: 1500),
  );

  final String apiBaseUrl;
  final String tileUrlTemplate;
  final int searchRadiusMeters;
}
