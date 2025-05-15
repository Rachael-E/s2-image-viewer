import 'package:flutter/material.dart';

String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  final day = date.day;
  final month = months[date.month - 1];
  final year = date.year.toString().substring(2);

  return "$day $month $year";
}

Future<DateTimeRange?> pickDateRange({
  required BuildContext context,
  required DateTime initialStart,
  required DateTime initialEnd,
}) {
  return showDateRangePicker(
    context: context,
    initialEntryMode: DatePickerEntryMode.input,
    helpText: 'Select range within the past 14 months',
    firstDate: DateTime.now().subtract(const Duration(days: 30 * 14)),
    lastDate: DateTime.now(),
    initialDateRange: DateTimeRange(
      start: initialStart,
      end: initialEnd,
    ),
    builder: (context, child) {
      return Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
              secondary: Color.fromARGB(255, 99, 98, 85),
            ),
            dialogTheme: const DialogTheme(backgroundColor: Colors.black),
            textTheme: TextTheme(
              headlineLarge:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )),
        child: child!,
      );
    },
  );
}

Future<void> showWelcomeDialog({
  required BuildContext context,
  required VoidCallback onProceed,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.black,
      title: const Text(
        'Welcome to Laurel Ridge State Park!',
        style: TextStyle(color: Colors.yellow),
      ),
      content: const Text(
        'Browse satellite images from Sentinel-2 to see how foliage changes throughout the year. Tap below to choose a date range.',
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.yellow,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () {
            Navigator.pop(context);
            onProceed(); // external callback to trigger date picker
          },
          icon: const Icon(Icons.calendar_today, color: Colors.yellow),
          label: const Text("Choose Date Range"),
        ),
      ],
    ),
  );
}

Widget buildCloudOption({
  required double value,
  required double? selectedCloudCover,
  required void Function(double newValue) onSelected,
}) {
  final isSelected = selectedCloudCover == (value / 100);

  return GestureDetector(
    onTap: () => onSelected(value / 100),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: Colors.black,
          child: Icon(
            isSelected ? Icons.cloud_done : Icons.cloud,
            color: Colors.yellow,
          ),
        ),
        const SizedBox(height: 4),
        Text('${value.toInt()}%', style: const TextStyle(color: Colors.black)),
      ],
    ),
  );
}

Future<double?> showCloudCoverDialog({
  required BuildContext context,
  required double? selectedCloudCover,
  required String formattedStart,
  required String formattedEnd,
}) async {
  double? tempSelected = selectedCloudCover;

  final result = await showDialog<double>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text("Select Cloud Cover Threshold"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Choose a cloud cover threshold:"),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 12,
              children: [
                buildCloudOption(
                  value: 0.0,
                  selectedCloudCover: tempSelected,
                  onSelected: (val) => setDialogState(() {
                    tempSelected = val;
                  }),
                ),
                buildCloudOption(
                  value: 5.0,
                  selectedCloudCover: tempSelected,
                  onSelected: (val) => setDialogState(() {
                    tempSelected = val;
                  }),
                ),
                buildCloudOption(
                  value: 10.0,
                  selectedCloudCover: tempSelected,
                  onSelected: (val) => setDialogState(() {
                    tempSelected = val;
                  }),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tempSelected != null) {
                Navigator.pop(context, tempSelected);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    ),
  );

  return result;
}

Widget buildLoadingOverlay(String? message) => Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: Center(
        child: SafeArea(
          child: Column(
            spacing: 15,
            children: [
              const CircularProgressIndicator(
                color: Colors.amber,
              ),
              Text(
                message ?? 'Loading... please wait',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );

Widget buildBottomControls({
  required BuildContext context,
  required bool isCompleted,
  required List<Map<String, dynamic>> rasterMetadata,
  required VoidCallback onSettingsPressed,
  required VoidCallback onInfoPressed,
  required Widget slider,
}) {
  return Container(
    color: Colors.black87,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        if (isCompleted && rasterMetadata.isNotEmpty) slider,
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: onSettingsPressed,
              color: Colors.yellow,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: onInfoPressed,
              color: Colors.yellow,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildSlider({
  required BuildContext context,
  required int currentIndex,
  required List<Map<String, dynamic>> rasterMetadata,
  required void Function(int) onSliderChanged,
  required String Function(int) getDateForIndex,
}) {
  final maxIndex = rasterMetadata.length > 1 ? rasterMetadata.length - 1 : 1;
  final safeSliderIndex = currentIndex.clamp(0, maxIndex).toDouble();
  final label =
      rasterMetadata.isNotEmpty && currentIndex < rasterMetadata.length
          ? getDateForIndex(currentIndex)
          : null;

  return Column(
    children: [
      Slider(
        label: label,
        value: safeSliderIndex,
        min: 0,
        thumbColor: Colors.amber,
        max: maxIndex.toDouble(),
        divisions: rasterMetadata.length > 1 ? rasterMetadata.length - 1 : null,
        onChanged: rasterMetadata.length > 1
            ? (value) => onSliderChanged(value.round())
            : null,
      ),
      /*const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(rasterMetadata.length, (index) {
          print('index: $index');
          final label = getDateForIndex(index);
          final isSelected = index == currentIndex;
          return Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.yellow : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }),
      ),*/
    ],
  );
}

String getDateForIndex(int index, List<Map<String, dynamic>> metadata) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    metadata[index]['acquisitiondate'],
  ).toLocal();

  return formatDate(date);
}

Future<void> showInfoDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.black,
      title: const Text(
        'About this App',
        style: TextStyle(color: Colors.yellow),
      ),
      content: const Text(
        'This app shows imagery from Sentinel-2, hosted on an ArcGIS Image Service.\n\n'
        'The service displays any image available within the past 14 months.',
        style: TextStyle(color: Colors.white),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'OK',
            style: TextStyle(color: Colors.amber),
          ),
        ),
      ],
    ),
  );
}
