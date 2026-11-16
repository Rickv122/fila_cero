import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final output = File('docs/capturas_sprint2/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes);
    return true;
  },
);
