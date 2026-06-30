import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/lignes_mock.dart';
import '../../services/location_service.dart';
import '../../services/places_service.dart';
import '../../services/routing_service.dart';
import '../results_screen.dart';

/// Écran de recherche passager avec autocomplétion Places API.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  final _uuid = const Uuid();
  late final String _sessionToken;

  bool _loading = false;
  String? _error;
  List<PlacePrediction> _predictions = [];

  @override
  void initState() {
    super.initState();
    _sessionToken = _uuid.v4();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value);
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await PlacesService.autocomplete(
        input: query,
        sessionToken: _sessionToken,
      );

      setState(() {
        _predictions = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur recherche: $e';
        _loading = false;
      });
    }
  }

  Future<void> _selectPrediction(PlacePrediction p) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final detail = await PlacesService.getPlaceDetail(
        placeId: p.placeId,
        sessionToken: _sessionToken,
      );

      if (!mounted) return;
      if (detail == null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Détails du lieu indisponibles')),
        );
        return;
      }

      final position = await LocationService.getCurrentPosition();
      final trajets = RoutingService.calculerTrajets(
        userLat: position.latitude,
        userLon: position.longitude,
        destLat: detail.latitude,
        destLon: detail.longitude,
        lignes: lignesMock,
        heure: DateTime.now().hour,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (trajets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun trajet n’a pu être calculé')),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            trajets: trajets,
            destination: detail.name.isNotEmpty ? detail.name : detail.address,
            destLat: detail.latitude,
            destLon: detail.longitude,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de navigation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Où veux-tu aller ?'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _controller,
              onChanged: _onTextChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Ex: Cocody, Plateau, Adjamé',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _predictions.isEmpty && !_loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Rechercher une destination pour découvrir les meilleurs trajets.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _predictions.length,
                    itemBuilder: (context, i) {
                      final p = _predictions[i];
                      return ListTile(
                        title: Text(p.mainText),
                        subtitle: Text(p.secondaryText),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectPrediction(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
