import 'package:flutter/material.dart';
import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:s2_image_viewer/raster_viewer.dart';

void main() {
  // Supply your apiKey using the --dart-define-from-file command line argument
  const apiKey = String.fromEnvironment('API_KEY');
  // Alternatively, replace the above line with the following and hard-code your apiKey here:
  // const apiKey = 'your_api_key_here';
  if (apiKey.isEmpty) {
    throw Exception('apiKey undefined');
  } else {
    ArcGISEnvironment.apiKey = apiKey;
  }

  runApp(
    MaterialApp(
      title: 'S2 Image Viewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
        sliderTheme: SliderThemeData(
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
          activeTickMarkColor: Colors.white,
          inactiveTickMarkColor: Colors.white,
          activeTrackColor: Colors.grey.shade700,
          inactiveTrackColor: Colors.grey.shade700,
          valueIndicatorColor: Colors.amber,
          valueIndicatorTextStyle: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const RasterViewer(),
    ),
  );
}
