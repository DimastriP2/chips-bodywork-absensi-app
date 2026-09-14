import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime? month;
  DateTime? latestMonth;
  bool loading = false;
  bool failedReset = false;
  String? error;
  List<Map<String, dynamic>> records = [];
  int page = 0;
  int lastPage = 1;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final today = await widget.api.get('attendance/today');
      final serverDate = DateTime.parse(today['date'] as String);
      if (!mounted) return;
      setState(() {
        month = DateTime(serverDate.year, serverDate.month);
        latestMonth = month;
      });
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : 'Tanggal server belum tersedia.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
    if (mounted && month != null) await fetch(reset: true);
  }

  Future<void> fetch({bool reset = false}) async {
    if (loading || month == null) return;
    final nextPage = reset ? 1 : page + 1;
    failedReset = reset;
    setState(() { loading = true; error = null; });
    try {
      final key = DateFormat('yyyy-MM').format(month!);
      final data = await widget.api.get('history?month=$key&page=$nextPage&per_page=20');
      final incoming = (data['attendances'] as List).cast<Map<String, dynamic>>();
      final meta = data['meta'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        records = reset ? incoming : [...records, ...incoming];
        page = nextPage;
        lastPage = (meta['last_page'] as num).toInt();
      });
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : 'Riwayat belum dapat dimuat.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void changeMonth(int delta) {
    if (loading || month == null) return;
    setState(() {
      month = DateTime(month!.year, month!.month + delta);
      records = [];
      page = 0;
      lastPage = 1;
    });
    fetch(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: loading || month == null ? null : () => changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(child: Text(month == null ? 'Memuat periode…'
              : DateFormat('MMMM yyyy', 'id').format(month!),
            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
          IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: loading || month == null || !month!.isBefore(latestMonth!)
                ? null : () => changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
      ),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          TextButton(onPressed: loading ? null : () {
            if (month == null) { initialize(); } else { fetch(reset: failedReset || page == 0); }
          }, child: const Text('Coba lagi')),
        ]),
      ),
      Expanded(child: RefreshIndicator(
        onRefresh: () => month == null ? initialize() : fetch(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (records.isEmpty && !loading && error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Text('Belum ada absensi pada bulan ini.', textAlign: TextAlign.center),
              ),
            for (final record in records) Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(record['date'].toString(),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('Masuk: ${record['check_in_time'] ?? '—'}'),
                const SizedBox(height: 6),
                Text('Pulang: ${record['check_out_time'] ?? 'Belum tercatat'}'),
                const SizedBox(height: 6),
                Text('Jarak masuk: ${record['distance'] ?? '—'} m'),
                const SizedBox(height: 8),
                Chip(
                  avatar: Icon(record['check_out_time'] == null
                      ? Icons.schedule : Icons.check_circle_outline, size: 18),
                  label: Text(record['check_out_time'] == null ? 'Belum check out' : 'Lengkap'),
                ),
              ]),
            )),
            if (page < lastPage && records.isNotEmpty) OutlinedButton(
              onPressed: loading ? null : () => fetch(),
              child: const Text('Muat lebih banyak'),
            ),
          ],
        ),
      )),
    ]);
  }
}
