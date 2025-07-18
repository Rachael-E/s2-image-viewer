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
  List<Map<String, dynamic>> rasterDataAttributes = [];
  late ArcGISMap _map;
  late Envelope _envelope;
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
      body: Stack(
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
              rasterAttributes: rasterDataAttributes,
              onSettingsPressed: _promptUserForImageryDates,
              onInfoPressed: () => showInfoDialog(context),
              slider: buildSlider(
                context: context,
                currentIndex: currentSliderIndex,
                rasterAttributes: rasterDataAttributes,
                onSliderChanged: _onSliderChanged,
                getDateForIndex: (index) =>
                    getDateForIndex(index, rasterDataAttributes),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> onMapViewReady() async {
    _map = ArcGISMap.withBasemapStyle(BasemapStyle.arcGISDarkGrayBase);
    _mapViewController.arcGISMap = _map;

    _envelope = Envelope.fromXY(
      xMin: xMin,
      yMin: yMin,
      xMax: xMax,
      yMax: yMax,
      spatialReference: SpatialReference.wgs84,
    );

    _mapViewController.interactionOptions.enabled = false;
    _mapViewController
        .setViewpoint(Viewpoint.fromTargetExtent(_envelope.extent));
  }

  Future<void> _promptUserForImageryDates() async {
    final result = await pickDateRange(
      context: context,
      initialStart: acquisitionStartDate,
      initialEnd: acquisitionEndDate,
    );

    if (!mounted || result == null) return;

    setState(() {
      acquisitionStartDate = result.start;
      acquisitionEndDate = result.end;
    });

    final formattedStart = formatDate(acquisitionStartDate);
    final formattedEnd = formatDate(acquisitionEndDate);

    final selected = await showCloudCoverDialog(
      context: context,
      selectedCloudCover: _selectedCloudCover,
      formattedStart: formattedStart,
      formattedEnd: formattedEnd,
    );

    if (!mounted || selected == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Selection"),
        content: Text(
          "You've chosen images from $formattedStart to $formattedEnd with up to ${(selected * 100).toInt()}% cloud cover. Proceed?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, continue"),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) return;

    setState(() {
      _selectedCloudCover = selected;
      // _isLoading = false;
      // _loadingMessage = "Waiting for user input...";
    });

    await _handleSatelliteImagery();
  }

  Future<void> _handleSatelliteImagery() async {
    setState(() {
      _isCompleted = false;
      _drawnRasterLayerNames.clear();
      expectedRasterLayerCount = 0;
      rasterDataAttributes.clear();
    });

    final fetchedRasterAttributes =
        await queryImageServiceForRasterAttributes();
    if (!mounted) return;

    // Show message if no imagery is available
    if (fetchedRasterAttributes.isEmpty) {
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
            'We found ${fetchedRasterAttributes.length} satellite images with your chosen settings. Do you want to load and browse them?'),
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
      setState(() {
        _isLoading = false;
        _loadingMessage = null;
      });
      return;
    }

    expectedRasterLayerCount = fetchedRasterAttributes.length;
    List<Map<String, dynamic>> currentDisplayedRasters = [];

    for (int i = 0; i < expectedRasterLayerCount; i++) {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _loadingMessage =
            'Fetching ${i + 1}/$expectedRasterLayerCount rasters...';
      });

      await displayRasterOnMap(
        index: i,
        fetchedRasterAttributes: fetchedRasterAttributes,
        envelope: _envelope,
        map: _map,
      );

      currentDisplayedRasters.add(fetchedRasterAttributes[i]);
    }

    setState(() {
      _loadingMessage = 'Finalizing...';
      rasterDataAttributes = currentDisplayedRasters;
      currentSliderIndex = currentDisplayedRasters.length - 1;
    });

    _onSliderChanged(currentSliderIndex);
  }

  Future<List<Map<String, dynamic>>>
      queryImageServiceForRasterAttributes() async {
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

      final attributesSortedByDate = features
          .map((f) => f['attributes'] as Map<String, dynamic>)
          .where((attrs) => attrs.containsKey('acquisitiondate'))
          .toList()
        ..sort((a, b) => a['acquisitiondate'].compareTo(b['acquisitiondate']));

      return attributesSortedByDate;
    } else {
      debugPrint('❌ Error: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      return [];
    }
  }

  Future<void> displayRasterOnMap({
    required int index,
    required List<Map<String, dynamic>> fetchedRasterAttributes,
    required Envelope envelope,
    required ArcGISMap map,
  }) async {
    final objectId = fetchedRasterAttributes[index]['objectid'] as int;
    final layerName = objectId.toString();

    // if a layer has already been drawn don't request it again from the server
    final existingLayer = _getRasterLayerByName(layerName);
    if (existingLayer != null) {
      markLayerDrawnIfComplete(layerName);
      return;
    }

    final imageServiceRaster = ImageServiceRaster(
      uri: Uri.parse(
        'https://sentinel.arcgis.com/arcgis/rest/services/Sentinel2/ImageServer',
      ),
    );

    imageServiceRaster.mosaicRule = MosaicRule()
      ..whereClause = 'OBJECTID = $objectId';

    final rasterLayer = RasterLayer.withRaster(imageServiceRaster)
      ..name = layerName;

    await rasterLayer
        .load()
        .whenComplete(() => map.operationalLayers.add(rasterLayer));

    _mapViewController.onDrawStatusChanged.listen((event) {
      if (event == DrawStatus.completed) {
        markLayerDrawnIfComplete(layerName);
      }
    });
  }

  Future<void> _onSliderChanged(int newIndex) async {
    final objectId = rasterDataAttributes[newIndex]['objectid'] as int;
    final targetLayerName = objectId.toString();

    RasterLayer? selectedLayer = _getRasterLayerByName(targetLayerName);

    for (final layer in _map.operationalLayers.whereType<RasterLayer>()) {
      layer.isVisible = false;
    }

    if (selectedLayer != null) {
      selectedLayer.isVisible = true;
    }

    await Future.delayed(const Duration(milliseconds: 50));

    setState(() => currentSliderIndex = newIndex);
  }

  void markLayerDrawnIfComplete(String layerName) {
    if (!_drawnRasterLayerNames.contains(layerName)) {
      _drawnRasterLayerNames.add(layerName);

      if (_drawnRasterLayerNames.length >= expectedRasterLayerCount) {
        if (mounted) {
          setState(() {
            _isCompleted = true;
            _isLoading = false;
            _loadingMessage = null;
          });
        }
      }
    }
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
