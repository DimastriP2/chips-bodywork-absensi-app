import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_flutter_app/main.dart';
import 'package:my_flutter_app/screens/login_page.dart';
import 'package:my_flutter_app/screens/dashboard_page.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/location_service.dart';
import 'package:geolocator/geolocator.dart';

import 'helpers.dart';

class UnavailableLocation extends LocationService {
  @override
  Future<Position> current() async {
    throw const LocationFailure('Izin lokasi ditolak.');
  }
}

void main() {
  testWidgets('logged out app displays the real login form', (tester) async {
    final api = ApiClient(tokens: MemoryTokenStore(),
      client: MockClient((_) async => http.Response('{}', 200)));
    await tester.pumpWidget(ChipsApp(client: api));
    await tester.pumpAndSettle();
    expect(find.text('Chips Bodywork'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump();
    expect(find.text('Password wajib diisi.'), findsOneWidget);
    api.close();
  });

  testWidgets('login preserves password whitespace and prevents duplicate submits', (tester) async {
    var calls = 0;
    final response = Completer<http.Response>();
    final tokens = MemoryTokenStore();
    final api = ApiClient(tokens: tokens, client: MockClient((request) {
      calls++;
      expect(jsonDecode(request.body)['password'], ' password ');
      return response.future;
    }));
    var loggedIn = false;
    await tester.pumpWidget(MaterialApp(home: LoginPage(
      api: api, onLogin: () => loggedIn = true,
    )));
    await tester.enterText(find.byType(TextFormField).at(0), 'staff@example.test');
    await tester.enterText(find.byType(TextFormField).at(1), ' password ');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    response.complete(http.Response('{"token":"issued"}', 200));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tokens.token, 'issued');
    expect(loggedIn, isTrue);
    api.close();
  });

  testWidgets('dashboard disables checkout before checkin and explains a GPS failure', (tester) async {
    final api = ApiClient(tokens: MemoryTokenStore('token'), client: MockClient((request) async {
      final data = switch (request.url.path.split('/').last) {
        'today' => {'date': '2026-09-14', 'timezone': 'Asia/Jakarta',
          'state': 'not_checked_in', 'attendance': null},
        'summary' => {'summary': {'present_days': 0, 'completed_days': 0,
          'incomplete_days': 0, 'recorded_minutes': 0}},
        'office' => {'office': {'office_name': 'Demo', 'latitude': -6.2,
          'longitude': 106.8, 'radius': 100}},
        _ => {'user': {'name': 'Dimas'}, 'employee': {}},
      };
      return http.Response(jsonEncode(data), 200);
    }));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardPage(
      api: api, location: UnavailableLocation(),
    ))));
    await tester.pumpAndSettle();
    final checkout = find.widgetWithText(OutlinedButton, 'Absen pulang');
    expect(tester.widget<OutlinedButton>(checkout).onPressed, isNull);
    await tester.scrollUntilVisible(find.text('Izin lokasi ditolak.'), 200);
    expect(find.text('Izin lokasi ditolak.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets('failed status fetch keeps both attendance actions disabled', (tester) async {
    final api = ApiClient(tokens: MemoryTokenStore('token'),
      client: MockClient((_) async => http.Response('{"message":"Server unavailable"}', 503)));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardPage(
      api: api, location: UnavailableLocation(),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Server unavailable'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Absen masuk')).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Absen pulang')).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
