import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final directory =
        Platform.environment['FILACERO_CAPTURE_DIR'] ?? 'docs/capturas_sprint2';
    final output = File('$directory/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes);
    return true;
  },
);
