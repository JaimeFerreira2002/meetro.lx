/// Client for the interpolation service. Shared by the 2D map now and the AR
/// view later — the app never talks to the Metro API directly.
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';

class MetroApi {
  /// Override at build time: --dart-define=API_BASE=http://<host>:8000
  /// Android emulator reaches the host via 10.0.2.2; iOS simulator via localhost.
  static const base = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8000');

  /// Retries until the server answers, so app/server launch order doesn't matter.
  Future<List<Station>> stations() async {
    while (true) {
      try {
        final resp = await http.get(Uri.parse('$base/stations'));
        final list = jsonDecode(resp.body) as List;
        return list.map((e) => Station.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Baked track polylines (one per line+direction). Retries until reachable.
  Future<List<TrackLine>> track() async {
    while (true) {
      try {
        final resp = await http.get(Uri.parse('$base/track'));
        final gj = jsonDecode(resp.body) as Map<String, dynamic>;
        final feats = (gj['features'] as List?) ?? [];
        return feats.map((f) => TrackLine.fromFeature(f as Map<String, dynamic>)).toList();
      } catch (_) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Per-line operational status. Retries until reachable.
  Future<List<LineStatus>> lines() async {
    while (true) {
      try {
        final resp = await http.get(Uri.parse('$base/lines'));
        final list = jsonDecode(resp.body) as List;
        return list.map((e) => LineStatus.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Live train snapshots via Server-Sent Events (`GET /stream`).
  /// Reconnects automatically if the server is down or the connection drops.
  Stream<List<TrainPosition>> trainStream() async* {
    while (true) {
      try {
        final req = http.Request('GET', Uri.parse('$base/stream'));
        final resp = await http.Client().send(req);
        final lines = resp.stream.transform(utf8.decoder).transform(const LineSplitter());
        await for (final line in lines) {
          if (line.startsWith('data:')) {
            final data = jsonDecode(line.substring(5).trim()) as List;
            yield data.map((e) => TrainPosition.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      } catch (_) {
        // server unreachable or stream dropped — fall through and retry
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}
