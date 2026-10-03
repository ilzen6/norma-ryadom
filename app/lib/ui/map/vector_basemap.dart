import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/map/basemap.dart';
import '../../data/map/map_atlas.dart';
import '../../data/providers.dart';
import '../core/theme.dart';
import 'basemap_layers.dart';

class VectorBasemap extends ConsumerStatefulWidget {
  const VectorBasemap({super.key});

  static const regionZoom = 9.0;
  static const suburbZoom = 12.0;
  static const cityZoom = 14.0;

  static String? tilesetFor(double zoom) => switch (zoom) {
    < regionZoom => null,
    < suburbZoom => 'overview',
    _ => 'suburb',
  };

  @override
  ConsumerState<VectorBasemap> createState() => _VectorBasemapState();
}

class _VectorBasemapState extends ConsumerState<VectorBasemap> {
  final _requested = <String>{};

  void _request(AssetStore<BasemapPack> store, String path) {
    if (!_requested.add(path)) return;
    store.get(path).then((_) {
      _requested.remove(path);
      if (mounted) setState(() {});
    });
  }

  List<Basemap>? _tiles(AssetStore<BasemapPack> store, MapTileset? tileset, GeoBounds view) {
    if (tileset == null) return const [];
    final tiles = <Basemap>[];
    var complete = true;
    for (final key in tileset.tilesIn(view)) {
      final path = tileset.packOf(key);
      final pack = store.peek(path);
      if (pack != null) {
        if (pack[key] case final tile?) tiles.add(tile);
      } else if (!store.isReady(path)) {
        complete = false;
        _request(store, path);
      }
    }
    return complete ? tiles : null;
  }

  @override
  Widget build(BuildContext context) {
    final atlas = ref.watch(mapAtlasProvider).value;
    if (atlas == null) return const SizedBox.shrink();
    final country = ref.watch(mapCountryProvider).value;
    final store = ref.watch(packStoreProvider);
    final palette = context.palette;
    final camera = MapCamera.of(context);
    final bounds = camera.visibleBounds;
    final view = GeoBounds(bounds.south, bounds.west, bounds.north, bounds.east);
    final zoom = camera.zoom;
    final regions = zoom >= VectorBasemap.regionZoom ? atlas.regionsIn(view) : const <MapRegion>[];
    final maps = <Basemap>[
      if (country != null && !regions.any((region) => region.bounds.encloses(view))) country,
    ];
    if (regions.isNotEmpty) {
      final base = _tiles(store, atlas.tilesets[VectorBasemap.tilesetFor(zoom)], view);
      final fallback = base == null
          ? _tiles(store, atlas.tilesets['overview'], view) ?? const <Basemap>[]
          : const <Basemap>[];
      maps
        ..addAll(fallback)
        ..addAll(base ?? const []);
      if (zoom >= VectorBasemap.cityZoom) maps.addAll(_tiles(store, atlas.tilesets['city'], view) ?? const []);
    }
    return Stack(
      children: [
        for (final map in maps)
          for (final layer in BasemapLayers.of(map, palette)) Positioned.fill(child: layer),
      ],
    );
  }
}
