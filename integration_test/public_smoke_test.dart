import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:filacero/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Consulta pública real en dispositivo', (tester) async {
    await app.main();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 200),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 40),
    );
    expect(find.text('Surtidor El Alto Central'), findsOneWidget);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
    }
    await binding.takeScreenshot('pantalla1-HU-09-lista');
    await tester.scrollUntilVisible(
      find.text('Surtidor Sopocachi'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Surtidor Sopocachi'));
    await tester.pumpAndSettle();
    expect(find.text('Disponibilidad por combustible'), findsOneWidget);
    expect(find.text('Actualizar disponibilidad'), findsNothing);
    await binding.takeScreenshot('pantalla2-HU-09-detalle');
  });
}
