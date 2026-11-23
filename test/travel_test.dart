import 'package:flutter_test/flutter_test.dart';
import 'package:filacero/models/travel.dart';

void main() {
  test('Una ubicación incompleta o no finita no se dibuja como estación', () {
    expect(recordPoint({'latitud': null, 'longitud': -68}), isNull);
    expect(recordPoint({'latitud': double.nan, 'longitud': -68}), isNull);
    expect(recordPoint({'latitud': -91, 'longitud': -68}), isNull);
    expect(
      recordPoint({'latitud': -16.5, 'longitud': -68.13})?.latitude,
      -16.5,
    );
  });
  test('Un recorrido inválido no se sustituye por una línea inventada', () {
    expect(() => routePoints([]), throwsFormatException);
    expect(
      () => routePoints([
        [0, 0],
        [double.infinity, 1],
      ]),
      throwsFormatException,
    );
    final route = routePoints([
      [-16.5, -68.1],
      [-16.51, -68.12],
    ]);
    expect(route.length, 2);
    expect(route.last.longitude, -68.12);
  });
  test('Distancia y tiempo se presentan con unidades legibles', () {
    expect(roadDistance(950), '950 m');
    expect(roadDistance(1040), '1.0 km');
    expect(travelTime(101), '2 min');
    expect(travelTime(3601), '1 h 1 min');
  });
}
