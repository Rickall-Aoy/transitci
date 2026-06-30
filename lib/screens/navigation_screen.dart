import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/location_service.dart';
import '../models/trajet.dart';
import '../services/settings_service.dart';

class NavigationScreen extends StatefulWidget {
  final Trajet trajet;
  final double destLat;
  final double destLon;

  const NavigationScreen({
    super.key,
    required this.trajet,
    required this.destLat,
    required this.destLon,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  List<LatLng> _routePoints = [];
  bool _isLoading = true;
  String? _erreur;
  double? _userLat;
  double? _userLon;
  bool _autoTheme = false;
  bool _panelExpanded = false;

  // Segment actif (navigation étape par étape)
  int _segmentActif = 0;

  late AnimationController _panelController;
  late AnimationController _pulseController;
  late Animation<double> _panelAnimation;
  late Animation<double> _pulseAnimation;

  static const String _mapStyleNight = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#1a1a2e"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#16213e"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#0f3460"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0f3460"}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#16213e"}]}
  ]
  ''';

  static const String _mapStyleDay = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#f5f0e8"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#523735"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#FF6B2B"}]},
    {"featureType": "water", "elementType": "geometry.fill", "stylers": [{"color": "#aadaff"}]},
    {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#c5dea8"}]}
  ]
  ''';

  bool get _isNight {
    if (!_autoTheme) return false;
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  Color get _bgColor => _isNight ? const Color(0xFF0A0A0A) : Colors.white;
  Color get _textColor => _isNight ? Colors.white : const Color(0xFF0A0A0A);
  Color get _subTextColor => _isNight ? Colors.white54 : Colors.grey.shade500;
  Color get _surfaceColor =>
      _isNight ? const Color(0xFF161616) : const Color(0xFFF5F5F5);

  // Couleur selon le résumé du trajet
  Color get _couleurPrincipale {
    final resume = widget.trajet.resume;
    if (resume.contains('Woro')) return const Color(0xFFFF6B2B);
    if (resume.contains('Gbaka')) return const Color(0xFF00C896);
    if (resume.contains('SOTRA')) return const Color(0xFF2196F3);
    return const Color(0xFFFF6B2B);
  }

  // Segments de transport uniquement
  List<Segment> get _segmentsTransport => widget.trajet.segments
      .where((s) => s.type == TypeSegment.transport)
      .toList();

  // Segment actuel
  Segment get _segmentCourant => widget.trajet.segments[
      _segmentActif.clamp(0, widget.trajet.segments.length - 1)];

  @override
  void initState() {
    super.initState();

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadSettings();
    _initialiserNavigation();
  }

  Future<void> _loadSettings() async {
    final auto = await SettingsService.getAutoTheme();
    if (!mounted) return;
    setState(() => _autoTheme = auto);
  }

  Future<void> _initialiserNavigation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      _userLat = position.latitude;
      _userLon = position.longitude;

      await _tracerTousLesSegments();
      _placerMarqueurs();

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _panelController.forward();
    } catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _tracerTousLesSegments() async {
    final allPoints = <LatLng>[];
    final allPolylines = <Polyline>{};

    // Tracer chaque segment du trajet
    final segments = widget.trajet.segments;

    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (s.type == TypeSegment.piedVersDest && i == segments.length - 1) {
        continue; // Skip dernier segment pied si trop court
      }

      final deLat = i == 0 ? (_userLat ?? s.deLatitude) : s.deLatitude;
      final deLon = i == 0 ? (_userLon ?? s.deLongitude) : s.deLongitude;
      final versLat = s.type == TypeSegment.piedVersDest
          ? widget.destLat
          : s.versLatitude;
      final versLon = s.type == TypeSegment.piedVersDest
          ? widget.destLon
          : s.versLongitude;

      final points = await _getRoutePoints(deLat, deLon, versLat, versLon,
          walking: s.type != TypeSegment.transport);

      if (points.isNotEmpty) {
        allPoints.addAll(points);

        // Couleur selon type de segment
        final color = s.type == TypeSegment.transport
            ? _couleurPrincipale
            : const Color(0xFF00C896);

        allPolylines.add(Polyline(
          polylineId: PolylineId('segment_$i'),
          points: points,
          color: color,
          width: s.type == TypeSegment.transport ? 6 : 4,
          patterns: s.type == TypeSegment.piedVersGare
              ? [PatternItem.dash(20), PatternItem.gap(10)]
              : [],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ));

        // Contour blanc
        allPolylines.add(Polyline(
          polylineId: PolylineId('border_$i'),
          points: points,
          color: Colors.white.withOpacity(0.3),
          width: 10,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _routePoints = allPoints;
        _polylines = allPolylines;
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));
    _ajusterCamera();
  }

  Future<List<LatLng>> _getRoutePoints(
      double fromLat, double fromLon, double toLat, double toLon,
      {bool walking = true}) async {
    try {
      final mode = walking ? 'foot' : 'driving';
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$mode/'
        '$fromLon,$fromLat;$toLon,$toLat'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final routes = data['routes'] as List;
      if (routes.isEmpty) return [];

      final coords = routes[0]['geometry']['coordinates'] as List;
      return coords
          .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  void _placerMarqueurs() {
    final markers = <Marker>{};

    // Position utilisateur
    if (_userLat != null && _userLon != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(_userLat!, _userLon!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '📍 Ma position'),
      ));
    }

    // Marqueurs de gares (points de correspondance)
    final segmentsTransport = _segmentsTransport;
    for (int i = 0; i < segmentsTransport.length; i++) {
      final s = segmentsTransport[i];
      if (s.gare != null) {
        markers.add(Marker(
          markerId: MarkerId('gare_$i'),
          position: LatLng(s.deLatitude, s.deLongitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            s.gare!.type.name == 'woroWoro'
                ? BitmapDescriptor.hueOrange
                : s.gare!.type.name == 'gbaka'
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueBlue,
          ),
          infoWindow: InfoWindow(
            title: '${s.gare!.emoji} ${s.gare!.nom}',
            snippet: '${s.gare!.prixMoyen} FCFA',
          ),
        ));
      }
    }

    // Destination finale
    markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: LatLng(widget.destLat, widget.destLon),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: '🎯 Destination'),
    ));

    if (mounted) setState(() => _markers = markers);
  }

  void _ajusterCamera() {
    if (_routePoints.isEmpty || _mapController == null) return;

    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLon = _routePoints.first.longitude;
    double maxLon = _routePoints.first.longitude;

    for (final p in _routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.003, minLon - 0.003),
          northeast: LatLng(maxLat + 0.003, maxLon + 0.003),
        ),
        100,
      ),
    );
  }

  void _segmentSuivant() {
    if (_segmentActif < widget.trajet.segments.length - 1) {
      HapticFeedback.mediumImpact();
      setState(() => _segmentActif++);
      // Centrer sur le prochain point
      final s = _segmentCourant;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(s.deLatitude, s.deLongitude), 15,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Carte ──
          GoogleMap(
            key: const ValueKey('navigation_google_map'),
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _userLat ?? widget.destLat,
                _userLon ?? widget.destLon,
              ),
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              controller.setMapStyle(
                  _isNight ? _mapStyleNight : _mapStyleDay);
              if (_routePoints.isNotEmpty) _ajusterCamera();
            },
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // ── Gradient haut ──
          Positioned(
            top: 0, left: 0, right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _isNight
                        ? const Color(0xDD0A0A0A)
                        : const Color(0xCCFFFFFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Barre du haut ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16, right: 16,
            child: Row(
              children: [
                // Retour
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _bgColor.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(Icons.arrow_back,
                        color: _textColor, size: 20),
                  ),
                ),
                const SizedBox(width: 10),

                // Titre trajet
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _bgColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      widget.trajet.resume,
                      style: TextStyle(
                        color: _couleurPrincipale,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Recentrer
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _ajusterCamera();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _bgColor.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(Icons.zoom_out_map,
                        color: _couleurPrincipale, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // ── Loader ──
          if (_isLoading)
            Container(
              color: _bgColor.withOpacity(0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: _couleurPrincipale.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _couleurPrincipale, width: 2),
                        ),
                        child: Icon(Icons.directions,
                            color: _couleurPrincipale, size: 30),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Calcul du trajet...',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Erreur ──
          if (_erreur != null && !_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_erreur!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),

          // ── Panel bas ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_panelAnimation),
              child: _buildBottomPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return GestureDetector(
      onTap: () {
        setState(() => _panelExpanded = !_panelExpanded);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          20, 16, 20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isNight ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Étape actuelle ──
            _buildEtapeCourante(),

            const SizedBox(height: 14),

            // ── Stats globales ──
            Row(
              children: [
                _buildInfoChip(
                  Icons.payments_outlined,
                  '${widget.trajet.prixTotal} FCFA',
                  'Total',
                  _couleurPrincipale,
                ),
                const SizedBox(width: 10),
                _buildInfoChip(
                  Icons.timer_outlined,
                  '${widget.trajet.dureeTotal} min',
                  'Durée',
                  const Color(0xFF2196F3),
                ),
                const SizedBox(width: 10),
                _buildInfoChip(
                  Icons.swap_horiz,
                  '${widget.trajet.correspondances}',
                  'Corresp.',
                  const Color(0xFF00C896),
                ),
              ],
            ),

            // ── Détails expandables ──
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _panelExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const SizedBox(height: 14),
                  // Tous les segments
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Étapes du trajet',
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...widget.trajet.segments.asMap().entries.map((e) {
                          final i = e.key;
                          final s = e.value;
                          final isActive = i == _segmentActif;
                          return _buildEtapeRow(s, i, isActive);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Bouton segment suivant
                  if (_segmentActif < widget.trajet.segments.length - 1)
                    GestureDetector(
                      onTap: _segmentSuivant,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _couleurPrincipale,
                              _couleurPrincipale.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _couleurPrincipale.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.skip_next,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Étape suivante',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEtapeCourante() {
    final s = _segmentCourant;
    final isTransport = s.type == TypeSegment.transport;
    final color = isTransport ? _couleurPrincipale : const Color(0xFF00C896);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTransport ? Icons.directions_bus : Icons.directions_walk,
              color: color, size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.description,
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${s.dureeMinutes} min · ${s.prix > 0 ? "${s.prix} FCFA" : "À pied"}',
                  style: TextStyle(color: _subTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
          // Indicateur étape
          Text(
            '${_segmentActif + 1}/${widget.trajet.segments.length}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtapeRow(Segment s, int index, bool isActive) {
    final isTransport = s.type == TypeSegment.transport;
    final color = isActive
        ? _couleurPrincipale
        : (isTransport
            ? _couleurPrincipale.withOpacity(0.5)
            : const Color(0xFF00C896).withOpacity(0.5));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: isActive
                  ? Border.all(color: color, width: 1.5)
                  : null,
            ),
            child: Icon(
              isTransport ? Icons.directions_bus : Icons.directions_walk,
              color: color, size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.description,
              style: TextStyle(
                color: isActive ? _textColor : _subTextColor,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${s.dureeMinutes} min',
            style: TextStyle(
              color: isActive ? _textColor : _subTextColor,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      IconData icon, String valeur, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              valeur,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: _textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: _subTextColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _panelController.dispose();
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}