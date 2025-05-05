//   Copyright 2024 Esri
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
import 'package:flutter/material.dart';

import 'package:arcgis_maps/arcgis_maps.dart';

void main() {

  const apiKey = ''; // Your access token here.

  ArcGISEnvironment.apiKey = apiKey;

  // Check that the access token has been set.
  //
  // A known issue in Flutter's core HTTP stack means that if an API key access
  // token is required but has not been set or is invalid, any REST requests
  // made by the ArcGIS Maps SDK for Flutter may fail with the nondescript error 
  // message "Failed to parse header value".
  if (apiKey.isEmpty) {
    throw Exception('apiKey undefined');
  }

  runApp(

    const MaterialApp(
      home: MainApp(),
    ),

  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {

  final _mapViewController = ArcGISMapView.createController();

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ArcGISMapView(
              controllerProvider: () => _mapViewController,
              onMapViewReady: onMapViewReady,
            ),
          ),
        ],
      ),
    );

  }

  void onMapViewReady() {

    final map = ArcGISMap.withBasemapStyle(BasemapStyle.arcGISTopographic);

    _mapViewController.arcGISMap = map;
    _mapViewController.setViewpoint(
      Viewpoint.withLatLongScale(
        latitude: 34.02700,
        longitude: -118.80500,
        scale: 72000,
      ),
    );

  }

}


