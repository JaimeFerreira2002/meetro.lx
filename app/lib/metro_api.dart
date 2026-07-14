/// Client for the interpolation service. Shared by the 2D map now and the AR
/// view later — the app never talks to the Metro API directly.
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';

class MetroApi {
  /// Override at build time: --dart-define=API_BASE=http://<host>:8000
  /// Android emulator reaches the host via 10.0.2.2; iOS simulator via localhost.
  static const base = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8000');

  Future<List<Station>> stations() async {
    final resp = await http.get(Uri.parse('$base/stations'));
    final list = jsonDecode(resp.body) as List;
    return list.map((e) => Station.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Live train snapshots via Server-Sent Events (`GET /stream`).
  Stream<List<TrainPosition>> trainStream() async* {
    final req = http.Request('GET', Uri.parse('$base/stream'));
    final resp = await http.Client().send(req);
    final lines = resp.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (line.startsWith('data:')) {
        final data = jsonDecode(line.substring(5).trim()) as List;
        yield data.map((e) => TrainPosition.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
  }
}
