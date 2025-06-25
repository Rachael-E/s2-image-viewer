# Sentinel 2 Image Viewer

A cross platform mobile app for iOS and Android that displays raster data (imagery) obtained from the Sentinel-2 satellite, sourced from Esri's [Sentinel2 Image Server REST service](https://sentinel.arcgis.com/arcgis/rest/services/Sentinel2/ImageServer). The image service is sourced from the Sentinel-2 on AWS collections, and consists of imagery collected within the past 14 months. This app was built with the [ArcGIS Maps SDK for Flutter](https://developers.arcgis.com/flutter/).

You can read more about this app and how it was built in the blog post [How to integrate satellite imagery in mobile app development with Flutter Maps SDK](https://www.esri.com/arcgis-blog/products/sdk-flutter/developers/map-vehicle-meeting-points-flutter/) on Esri's ArcGIS Blog.

![Mobile app screen showing satellite imagery mosaic](https://github.com/user-attachments/assets/33893bbe-759f-416b-9f01-3a1132dd6dbb)

Imagery data source: Esri, European Commission, European Space Agency, Amazon Web Services.
Contains Copernicus Sentinel data for the current and previous year.

## Running the app

The app can be run on an iOS or Android simulator or device. 

- Clone or download this repository
- Navigate to the `s2-image-viewer` directory and run `flutter pub upgrade` from the terminal to configure the dependencies.
- Install arcgis_maps_core from the terminal with `dart run arcgis_maps install`
- You will also need an API Key access token to run this app.
    - Follow the [Create an API Key tutorial](https://developers.arcgis.com/documentation/security-and-authentication/api-key-authentication/tutorials/create-an-api-key/) and copy your generated API Key.
    - Add the new API key directly to `main.dart` (not recommended for production use) or create an environment JSON file that can be loaded with `flutter run --dart-define-from-file=path/to/json/file.json`
    - The JSON file should be of format: `{ "API_KEY": "your_api_key_here"}`
- Ensure a simulator is running or a device is connected to your development machine
- Run or debug the app to launch it


