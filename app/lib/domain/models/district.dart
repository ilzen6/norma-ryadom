enum District {
  moscowCity(55.7495, 37.5374),
  tverskaya(55.7652, 37.6050),
  arbat(55.7516, 37.5930),
  chistyePrudy(55.7616, 37.6420),
  kurskaya(55.7585, 37.6590),
  belorusskaya(55.7766, 37.5840);

  const District(this.lat, this.lon);

  final double lat;
  final double lon;
}
