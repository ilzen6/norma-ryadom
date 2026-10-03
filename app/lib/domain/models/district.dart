enum DistrictRegion { moscow, oblast, spb }

enum District {
  moscowCity(DistrictRegion.moscow, 55.7495, 37.5374),
  tverskaya(DistrictRegion.moscow, 55.7652, 37.6050),
  arbat(DistrictRegion.moscow, 55.7516, 37.5930),
  chistyePrudy(DistrictRegion.moscow, 55.7616, 37.6420),
  kurskaya(DistrictRegion.moscow, 55.7585, 37.6590),
  belorusskaya(DistrictRegion.moscow, 55.7766, 37.5840),
  zelenograd(DistrictRegion.moscow, 55.9825, 37.1814),
  balashikha(DistrictRegion.oblast, 55.7963, 37.9382),
  dmitrov(DistrictRegion.oblast, 56.3434, 37.5203),
  dolgoprudny(DistrictRegion.oblast, 55.9386, 37.5011),
  domodedovo(DistrictRegion.oblast, 55.4363, 37.7666),
  zhukovsky(DistrictRegion.oblast, 55.5953, 38.1203),
  istra(DistrictRegion.oblast, 55.9146, 36.8593),
  kolomna(DistrictRegion.oblast, 55.1030, 38.7531),
  korolev(DistrictRegion.oblast, 55.9142, 37.8256),
  krasnogorsk(DistrictRegion.oblast, 55.8204, 37.3302),
  lyubertsy(DistrictRegion.oblast, 55.6783, 37.8936),
  mytishchi(DistrictRegion.oblast, 55.9105, 37.7320),
  noginsk(DistrictRegion.oblast, 55.8545, 38.4417),
  odintsovo(DistrictRegion.oblast, 55.6789, 37.2639),
  podolsk(DistrictRegion.oblast, 55.4312, 37.5455),
  pushkino(DistrictRegion.oblast, 56.0104, 37.8471),
  reutov(DistrictRegion.oblast, 55.7586, 37.8617),
  sergievPosad(DistrictRegion.oblast, 56.3153, 38.1358),
  serpukhov(DistrictRegion.oblast, 54.9158, 37.4111),
  khimki(DistrictRegion.oblast, 55.8889, 37.4450),
  shchyolkovo(DistrictRegion.oblast, 55.9233, 37.9724),
  elektrostal(DistrictRegion.oblast, 55.7847, 38.4447),
  spbNevsky(DistrictRegion.spb, 59.9343, 30.3351),
  spbPetrogradka(DistrictRegion.spb, 59.9663, 30.3115),
  spbVasileostrovsky(DistrictRegion.spb, 59.9426, 30.2785),
  spbMoskovsky(DistrictRegion.spb, 59.8519, 30.3215),
  spbPushkin(DistrictRegion.spb, 59.7225, 30.4157);

  const District(this.region, this.lat, this.lon);

  final DistrictRegion region;
  final double lat;
  final double lon;
}
