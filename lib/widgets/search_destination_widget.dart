import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/places_service.dart';
import '../data/suggestions_locales.dart';

class SearchDestinationWidget extends StatefulWidget {
  final Function(String nom, double lat, double lon) onDestinationSelected;
  final bool isNight;

  const SearchDestinationWidget({
    super.key,
    required this.onDestinationSelected,
    required this.isNight,
  });

  @override
  State<SearchDestinationWidget> createState() =>
      _SearchDestinationWidgetState();
}

class _SearchDestinationWidgetState extends State<SearchDestinationWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Uuid _uuid = const Uuid();

  String _sessionToken = '';
  List<PlacePrediction> _predictions = [];
  List<SuggestionLocale> _suggestionsFiltrees = [];
  bool _isLoading = false;
  bool _showResults = false;
  Timer? _searchDebounce;
  int _searchRequestId = 0;

  // Couleurs selon thème
  Color get _bgColor =>
      widget.isNight ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
  Color get _cardColor =>
      widget.isNight ? const Color(0xFF161616) : Colors.white;
  Color get _textColor =>
      widget.isNight ? Colors.white : const Color(0xFF0A0A0A);
  Color get _subColor =>
      widget.isNight ? Colors.white38 : Colors.black38;
  Color get _dividerColor =>
      widget.isNight ? Colors.white10 : Colors.grey.shade200;

  @override
  void initState() {
    super.initState();
    _sessionToken = _uuid.v4();
    _focusNode.addListener(() {
      setState(() => _showResults = _focusNode.hasFocus);
      if (_focusNode.hasFocus && _controller.text.isEmpty) {
        _afficherSuggestions('');
      }
    });
  }

  void _afficherSuggestions(String input) {
    // Filtrer suggestions locales
    final query = input.toLowerCase();
    setState(() {
      _suggestionsFiltrees = query.isEmpty
          ? suggestionsLocales.take(6).toList()
          : suggestionsLocales
              .where((s) =>
                  s.nom.toLowerCase().contains(query) ||
                  s.categorie.toLowerCase().contains(query))
              .take(4)
              .toList();
    });
  }

  void _onChanged(String input) {
    _afficherSuggestions(input);
    _searchDebounce?.cancel();

    if (input.length < 2) {
      setState(() {
        _predictions = [];
        _isLoading = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      final requestId = ++_searchRequestId;
      if (!mounted) return;
      setState(() => _isLoading = true);

      final predictions = await PlacesService.autocomplete(
        input: input,
        sessionToken: _sessionToken,
      );

      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _predictions = predictions;
        _isLoading = false;
      });
    });
  }

  Future<void> _onPredictionSelected(PlacePrediction prediction) async {
    setState(() => _isLoading = true);
    _controller.text = prediction.mainText;
    _focusNode.unfocus();

    final detail = await PlacesService.getPlaceDetail(
      placeId: prediction.placeId,
      sessionToken: _sessionToken,
    );

    // Renouvelle le session token après sélection
    _sessionToken = _uuid.v4();

    setState(() {
      _isLoading = false;
      _predictions = [];
      _showResults = false;
    });

    if (detail != null) {
      widget.onDestinationSelected(
        detail.name,
        detail.latitude,
        detail.longitude,
      );
    }
  }

  void _onSuggestionLocaleSelected(SuggestionLocale s) {
    _controller.text = s.nom;
    _focusNode.unfocus();
    setState(() {
      _showResults = false;
      _predictions = [];
    });
    widget.onDestinationSelected(s.nom, s.latitude, s.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Barre de recherche ──
        Container(
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showResults
                  ? const Color(0xFFFF6B2B).withOpacity(0.5)
                  : Colors.white12,
              width: _showResults ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: 'Destination (ex: Sococé, Bingerville...)',
              hintStyle: TextStyle(color: _subColor, fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFFFF6B2B), size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: _subColor, size: 18),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _predictions = [];
                          _suggestionsFiltrees =
                              suggestionsLocales.take(6).toList();
                        });
                      },
                    )
                  : _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF6B2B),
                            ),
                          ),
                        )
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 16, horizontal: 4),
            ),
            onChanged: _onChanged,
          ),
        ),

        // ── Résultats ──
        if (_showResults)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  // Suggestions locales
                  if (_suggestionsFiltrees.isNotEmpty) ...[
                    _buildSectionHeader('📍 Lieux populaires'),
                    ..._suggestionsFiltrees.map((s) =>
                        _buildSuggestionLocale(s)),
                  ],

                  // Résultats Google Places
                  if (_predictions.isNotEmpty) ...[
                    if (_suggestionsFiltrees.isNotEmpty)
                      Divider(height: 1, color: _dividerColor),
                    _buildSectionHeader('🔍 Résultats Google'),
                    ..._predictions.map((p) => _buildPrediction(p)),
                  ],

                  // Aucun résultat
                  if (_predictions.isEmpty &&
                      _suggestionsFiltrees.isEmpty &&
                      _controller.text.length >= 2)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Aucun lieu trouvé',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _subColor, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String titre) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Text(
        titre,
        style: TextStyle(
          color: _subColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSuggestionLocale(SuggestionLocale s) {
    return InkWell(
      onTap: () => _onSuggestionLocaleSelected(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B2B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(s.emoji,
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.nom,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    s.categorie,
                    style: TextStyle(color: _subColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.north_west,
                color: _subColor, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildPrediction(PlacePrediction p) {
    return InkWell(
      onTap: () => _onPredictionSelected(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.place,
                  color: Color(0xFF2196F3), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.mainText,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    p.secondaryText,
                    style: TextStyle(color: _subColor, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.north_west, color: _subColor, size: 14),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
