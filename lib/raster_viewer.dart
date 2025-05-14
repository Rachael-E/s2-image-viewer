import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:s2_image_viewer/utils/raster_helpers.dart';

class RasterViewer extends StatefulWidget {
  const RasterViewer({super.key});

  @override
  State<RasterViewer> createState() => _RasterViewerState();
}

class _RasterViewerState extends State<RasterViewer> {
  final _mapViewController = ArcGISMapView.createController();
  final Set<String> _drawnRasterLayerNames = {};
  int currentSliderIndex = 0;
  int expectedRasterLayerCount = 0;
  List<Map<String, dynamic>> rasterMetadata = [];
  late ArcGISMap _map;
  late Envelope _envelope;
  late ImageServiceRaster _imageServiceRaster;
  bool _isCompleted = false;
  bool _isLoading = false;
  String? _loadingMessage;

  late DateTime acquisitionStartDate;
  late DateTime acquisitionEndDate;

  double xMin = -79.12974311525639;
  double xMax = -79.01888017117213;
  double yMin = 40.18019604030931;
  double yMax = 40.34526092401982;

  double? _selectedCloudCover = 0.0;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final year = now.month < 12
        ? now.year - 1
        : now.year; // use the latest Autumn season
    acquisitionStartDate = DateTime(year, 9, 1); // 1st Sept
    acquisitionEndDate = DateTime(year, 11, 1); // 1st Nove

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDialogAfterBuild();
    });
  }

  void _showDialogAfterBuild() async {
    await showWelcomeDialog(
      context: context,
      onProceed: _promptUserForImageryDates,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ArcGISMapView(
                  controllerProvider: () => _mapViewController,
                  onMapViewReady: onMapViewReady,
                ),
                if (_isLoading) buildLoadingOverlay(_loadingMessage),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: buildBottomControls(
                    context: context,
                    isCompleted: _isCompleted,
                    rasterMetadata: rasterMetadata,
                    onSettingsPressed: _promptUserForImageryDates,
                    onInfoPressed: () => showInfoDialog(context),
                    slider: buildSlider(
                      context: context,
                      currentIndex: currentSliderIndex,
                      rasterMetadata: rasterMetadata,
                      onSliderChanged: _onSliderChanged,
                      getDateForIndex: (index) =>
                          getDateForIndex(index, rasterMetadata),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSliderChanged(int newIndex) async {
    final objectId = rasterMetadata[newIndex]['objectid'] as int;
    final targetLayerName = objectId.toString();

    RasterLayer? selectedLayer = _getRasterLayerByName(targetLayerName);

    for (final layer in _map.operationalLayers.whereType<RasterLayer>()) {
      layer.isVisible = false;
    }

    if (selectedLayer != null) {
      selectedLayer.isVisible = true;
      print("✅ Displayed raster layer $targetLayerName from index $newIndex");
    } else {
      print("⚠️ Raster layer $targetLayerName not found in map.");
    }

    await Future.delayed(const Duration(milliseconds: 50));

    setState(() => currentSliderIndex = newIndex);
  }

  Future<void> onMapViewReady() async {
    _mapViewController.onDrawStatusChanged.listen((status) {
      setState(() {
        _isCompleted = status == DrawStatus.completed;
      });
    });

    _map = ArcGISMap.withBasemapStyle(BasemapStyle.arcGISDarkGrayBase);
    _mapViewController.arcGISMap = _map;

    _envelope = Envelope.fromXY(
      xMin: xMin,
      yMin: yMin,
      xMax: xMax,
      yMax: yMax,
      spatialReference: SpatialReference.wgs84,
    );

    _map.maxExtent = _envelope;
    _mapViewController.interactionOptions.panEnabled = false;
    _mapViewController.interactionOptions.enabled = false;
    _mapViewController
        .setViewpoint(Viewpoint.fromTargetExtent(_envelope.extent));

    _imageServiceRaster = ImageServiceRaster(
      uri: Uri.parse(
          'https://sentinel.arcgis.com/arcgis/rest/services/Sentinel2/ImageServer'),
    );
    await _imageServiceRaster.load();
  }

  Future<void> _promptUserForImageryDates() async {
    final result = await pickDateRange(
      context: context,
      initialStart: acquisitionStartDate,
      initialEnd: acquisitionEndDate,
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        acquisitionStartDate = result.start;
        acquisitionEndDate = result.end;
      });

      final formattedStart = formatDate(acquisitionStartDate);
      final formattedEnd = formatDate(acquisitionEndDate);

      await showCloudCoverDialog(
        context: context,
        selectedCloudCover: _selectedCloudCover,
        formattedStart: formattedStart,
        formattedEnd: formattedEnd,
        onThresholdChosen: (value) async {
          if (!mounted) return;

          setState(() {
            _selectedCloudCover = value;
            _isLoading = true;
            _loadingMessage = "Fetching and caching rasters...";
          });

          await _handleAutumnImagery();
        },
      );
    }
  }

  Future<void> _handleAutumnImagery() async {
    setState(() {
      _isCompleted = false;
      _isLoading = true;
      _loadingMessage = 'Fetching and caching rasters...';
      _drawnRasterLayerNames.clear();
      expectedRasterLayerCount = 0;
      rasterMetadata.clear();
    });
    final fetched = await fetchRasterMetadata();
    if (!mounted) return;

    // Show message if no imagery is available
    if (fetched.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Imagery Found'),
          content: const Text(
              'We found 0 satellite images with your chosen processing needs.\n\nPlease try different settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      setState(() {
        _isLoading = false;
        _loadingMessage = null;
      });
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Imagery Available'),
        content: Text(
            'We found ${fetched.length} satellite images with your chosen processing needs. Do you want to load and browse them?'),
        actions: [
          TextButton(
              onPressed: (() => Navigator.of(context).pop(false)),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes')),
        ],
      ),
    );

    if (confirm != true) {
      setState(() => _isLoading = false);
      return;
    }

    _drawnRasterLayerNames.clear();
    expectedRasterLayerCount = fetched.length;
    List<Map<String, dynamic>> cached = [];

    for (int i = 0; i < fetched.length; i++) {
      final fetchedRasterMetadataAttribute = fetched[i];

      await showAndCacheRaster(
        index: i,
        fetchedRasterMetadata: fetched,
        envelope: _envelope,
        map: _map,
      );

      cached.add(fetchedRasterMetadataAttribute);
    }

    setState(() {
      rasterMetadata = cached;
      currentSliderIndex = cached.length;
    });
  }

  Future<List<Map<String, dynamic>>> fetchRasterMetadata() async {
    final start = acquisitionStartDate.toIso8601String().split('T')[0];
    final end = acquisitionEndDate.toIso8601String().split('T')[0];
    final whereClause =
        "acquisitiondate >= DATE '$start' AND acquisitiondate < DATE '$end' AND cloudcover <= $_selectedCloudCover";

    final encodedWhere = Uri.encodeComponent(whereClause);

    final uri = Uri.parse(
      'https://sentinel.arcgis.com/arcgis/rest/services/Sentinel2/ImageServer/query'
      '?where=$encodedWhere'
      '&geometry=$xMin, $yMin, $xMax, $yMax'
      '&geometryType=esriGeometryEnvelope'
      '&inSR=4326'
      '&spatialRel=esriSpatialRelIntersects'
      '&outFields=acquisitiondate,objectid,cloudcover'
      '&returnGeometry=false'
      '&f=json',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List<dynamic>;

      final rasterMetadata = features
          .map((f) => f['attributes'] as Map<String, dynamic>)
          .where((attrs) => attrs.containsKey('acquisitiondate'))
          .toList()
        ..sort((a, b) => a['acquisitiondate'].compareTo(b['acquisitiondate']));

      for (var r in rasterMetadata) {
        final date = DateTime.fromMillisecondsSinceEpoch(r['acquisitiondate']);
        final cloud = (r['cloudcover'] * 100).toStringAsFixed(1);
        final id = r['objectid'];
        print('📅 $date — ☁️ $cloud% cloud cover — 🆔 $id');
      }

      return rasterMetadata;
    } else {
      print('❌ Error: ${response.statusCode}');
      print('Body: ${response.body}');
      return [];
    }
  }

  Future<void> showAndCacheRaster({
    required int index,
    required List<Map<String, dynamic>> fetchedRasterMetadata,
    required Envelope envelope,
    required ArcGISMap map,
  }) async {
    final objectId = fetchedRasterMetadata[index]['objectid'] as int;
    final layerName = objectId.toString();

    final existingLayer = _getRasterLayerByName(layerName);
    if (existingLayer != null) {
      print("✅ Raster layer $layerName already added to map.");
      return;
    }

    final raster = ImageServiceRaster(
      uri: Uri.parse(
        'https://sentinel.arcgis.com/arcgis/rest/services/Sentinel2/ImageServer',
      ),
    );

    raster.mosaicRule = MosaicRule()
      ..mosaicMethod = MosaicMethod.attribute
      ..sortField = 'OBJECTID'
      ..whereClause = 'OBJECTID = $objectId';

    final rasterLayer = RasterLayer.withRaster(raster)..name = layerName;

    await rasterLayer
        .load()
        .whenComplete(() => map.operationalLayers.add(rasterLayer));

    _mapViewController.onDrawStatusChanged.listen((event) {
      if (event == DrawStatus.completed &&
          !_drawnRasterLayerNames.contains(layerName)) {
        _drawnRasterLayerNames.add(layerName);
        print("✅ Draw completed for $layerName");

        if (_drawnRasterLayerNames.length >= expectedRasterLayerCount) {
          print("✅ All raster layers drawn — showing slider");
          if (mounted) {
            setState(() {
              _isCompleted = event == DrawStatus.completed;
              _isLoading = false;
              _loadingMessage = null;
            });
          }
        }
      }
    });
  }

  RasterLayer? _getRasterLayerByName(String name) {
    try {
      return _map.operationalLayers
          .whereType<RasterLayer>()
          .firstWhere((layer) => layer.name == name);
    } catch (_) {
      return null;
    }
  }
}
