import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_flutter_app/screens/history_page.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'helpers.dart';

void main() {
  setUpAll(() async { await initializeDateFormatting('id'); });

  testWidgets('history uses server month, paginates, and clears records when month changes', (tester) async {
    final calls = <Uri>[];
    final api = ApiClient(tokens: MemoryTokenStore('token'),
      client: MockClient((request) async {
        calls.add(request.url);
        if (request.url.path.endsWith('/today')) {
          return http.Response('{"date":"2026-09-14"}', 200);
        }
        final month = request.url.queryParameters['month'];
        final page = request.url.queryParameters['page'];
        return http.Response(jsonEncode({
          'attendances': [
            {'date': month == '2026-08' ? '2026-08-31' : page == '1' ? '2026-09-14' : '2026-09-13',
             'check_in_time': '08:00:00', 'check_out_time': '17:00:00', 'distance': 20},
          ],
          'meta': {'current_page': int.parse(page!), 'last_page': 2, 'total': 2},
        }), 200);
      }));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HistoryPage(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(calls.last.queryParameters['per_page'], '20');
    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pumpAndSettle();
    expect(calls.last.queryParameters['page'], '2');
    expect(find.text('2026-09-13'), findsOneWidget);
    await tester.tap(find.byTooltip('Bulan sebelumnya'));
    await tester.pumpAndSettle();
    expect(calls.last.queryParameters['month'], '2026-08');
    expect(calls.last.queryParameters['page'], '1');
    expect(find.text('2026-09-14'), findsNothing);
    expect(find.text('2026-08-31'), findsOneWidget);
    api.close();
  });
}
