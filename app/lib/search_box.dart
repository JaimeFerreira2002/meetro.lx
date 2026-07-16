/// Cozy search box: filters stations live, and geocodes free text via Nominatim
/// on submit. Picking a result flies the map there.
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'metro_api.dart';
import 'models.dart';
import 'panel.dart';

class SearchBox extends StatefulWidget {
  final MetroApi api;
  final List<Station> stations;
  final void Function(LatLng target, Station? station) onPick;

  const SearchBox({super.key, required this.api, required this.stations, required this.onPick});

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final _controller = TextEditingController();
  List<Place> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    // Local station matches first (instant).
    final matches = widget.stations
        .where((s) => s.name.toLowerCase().contains(query))
        .map((s) => Place(name: s.name, pos: s.pos, station: s))
        .toList();
    setState(() => _results = matches);
  }

  Future<void> _onSubmit(String q) async {
    setState(() => _loading = true);
    final places = await widget.api.geocode(q);
    if (!mounted) return;
    // Keep station matches on top, then geocoded places.
    final stationMatches = _results.where((p) => p.station != null).toList();
    setState(() {
      _results = [...stationMatches, ...places];
      _loading = false;
    });
  }

  void _pick(Place p) {
    _controller.clear();
    FocusScope.of(context).unfocus();
    setState(() => _results = []);
    widget.onPick(p.pos, p.station);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Colors.black45, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  onSubmitted: _onSubmit,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Search stations or places',
                    hintStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.w400),
                  ),
                ),
              ),
              if (_loading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    setState(() => _results = []);
                    FocusScope.of(context).unfocus();
                  },
                  child: const Icon(Icons.close_rounded, color: Colors.black45, size: 18),
                ),
            ],
          ),
        ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
              child: Panel(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        p.station != null ? Icons.directions_subway_rounded : Icons.place_rounded,
                        color: Colors.black45,
                        size: 20,
                      ),
                      title: Text(p.name,
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                      onTap: () => _pick(p),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
