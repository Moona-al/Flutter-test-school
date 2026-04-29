import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ================= API =================

Future<List<Map<String, dynamic>>> fetchSchedule(String kode) async {
  final res = await http.get(
    Uri.parse('https://api.comuline.com/v1/schedule/${kode.toUpperCase()}'),
  );
  if (res.statusCode != 200) throw Exception('Stasiun tidak ditemukan');
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return ((body['data'] as List?) ?? []).cast<Map<String, dynamic>>();
}

Future<Map<String, dynamic>> fetchStationDetail(String id) async {
  final res = await http.get(
    Uri.parse('https://api.comuline.com/v1/station/$id'),
  );
  if (res.statusCode != 200) {
    throw Exception('Gagal ambil detail stasiun');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return body['data'] as Map<String, dynamic>;
}

String jamBerangkat(String? t) =>
    (t != null && t.length >= 16) ? t.substring(11, 16) : '-';

// ================= APP =================

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jadwal KRL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const HalamanJadwal(),
    );
  }
}

class HalamanJadwal extends StatefulWidget {
  const HalamanJadwal({super.key});

  @override
  State<HalamanJadwal> createState() => _HalamanJadwalState();
}

class _HalamanJadwalState extends State<HalamanJadwal> {
  final _controller = TextEditingController();

  List<Map<String, dynamic>> _jadwal = [];
  String? _pesan;
  bool _loading = false;

  final List<Map<String, dynamic>> _stations = [
    {'code': 'BOO', 'name': 'Bogor'},
    {'code': 'MRI', 'name': 'Manggarai'},
    {'code': 'JNG', 'name': 'Jatinegara'},
    {'code': 'DPK', 'name': 'Depok'},
    {'code': 'THB', 'name': 'Tanah Abang'},
  ];

  List<Map<String, dynamic>> _filteredStations = [];

  @override
  void initState() {
    super.initState();
    _filteredStations = _stations;
  }

  void _filterStations(String query) {
    final hasil = _stations.where((s) {
      return s['name']
          .toLowerCase()
          .contains(query.toLowerCase());
    }).toList();

    setState(() => _filteredStations = hasil);
  }

  Future<void> _cariJadwal() async {
    final kode = _controller.text.trim();
    if (kode.isEmpty) return;

    setState(() {
      _loading = true;
      _pesan = null;
      _jadwal = [];
    });

    try {
      final data = await fetchSchedule(kode);
      setState(() {
        _jadwal = data;
        _pesan = data.isEmpty ? 'Tidak ada jadwal.' : null;
      });
    } catch (e) {
      setState(() {
        _pesan = 'Stasiun "$kode" tidak ditemukan.';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚆 Jadwal KRL'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔍 SEARCH STATION
            TextField(
              onChanged: _filterStations,
              decoration: InputDecoration(
                hintText: 'Cari nama stasiun...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // LIST STATION
            SizedBox(
              height: 120,
              child: _filteredStations.isEmpty
                  ? const Center(child: Text('Stasiun tidak ditemukan'))
                  : ListView.builder(
                      itemCount: _filteredStations.length,
                      itemBuilder: (context, i) {
                        final s = _filteredStations[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.train),
                            title: Text(s['name']),
                            subtitle: Text(s['code']),
                            onTap: () {
                              _controller.text = s['code'];

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      HalamanDetailStasiun(id: s['code']),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            // INPUT KODE
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Kode Stasiun',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // BUTTON
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _cariJadwal,
                icon: const Icon(Icons.search),
                label: const Text('Cari Jadwal'),
              ),
            ),

            const SizedBox(height: 16),

            if (_loading) const CircularProgressIndicator(),

            if (_pesan != null) Text(_pesan!),

            if (_jadwal.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ditemukan ${_jadwal.length} jadwal',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(height: 8),

            // LIST JADWAL
            Expanded(
              child: ListView.builder(
                itemCount: _jadwal.length,
                itemBuilder: (context, i) {
                  final j = _jadwal[i];
                  final jam = jamBerangkat(j['departs_at'] as String?);
                  final tujuan = j['station_destination_id'] ?? '-';

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(jam),
                      ),
                      title: Text('Tujuan: $tujuan'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= DETAIL PAGE =================

class HalamanDetailStasiun extends StatelessWidget {
  final String id;

  const HalamanDetailStasiun({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Stasiun')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchStationDetail(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? '-',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text('Kode: ${data['code']}'),
                    Text('ID: ${data['id']}'),
                    Text('Kota: ${data['city'] ?? '-'}'),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Kembali'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}