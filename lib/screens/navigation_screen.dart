import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../services/location_service.dart';
import '../services/navigation_service.dart';
import '../services/guide_service.dart';
import '../models/trajet.dart';
import '../services/settings_service.dart';
import '../app_theme.dart';
import '../widgets/ai_guide_overlay.dart';

class NavigationScreen extends StatefulWidget {
  final Trajet trajet;
  final double destLat;
  final double destLon;
  final double? userLat;
  final double? userLon;

  const NavigationScreen({
    super.key,
    required this.trajet,
    required this.destLat,
    required this.destLon,
    this.userLat,
    this.userLon,
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

  int _segmentActif = 0;

  late AnimationController _panelController;
  late AnimationController _pulseController;
  late Animation<double> _panelAnimation;
  late Animation<double> _pulseAnimation;

  final NavigationService _navService = NavigationService();
  StreamSubscription<NavigationSnapshot>? _navSubscription;
  LatLng? _liveUserPosition;
  bool _isNavigating = false;
  bool _autoRecenter = true;
  String _nextInstruction = 'Tape sur play pour démarrer le guidage';
  int _remainingMinutes = 0;
  double _remainingMeters = 0;
  bool _hasArrived = false;

  bool get _isNight {
    if (!_autoTheme) return false;
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  Color get _bgColor => _isNight ? AppTheme.darkBg : Colors.white;
  Color get _textColor => _isNight ? AppTheme.darkTextPrimary : const Color(0xFF0A0A0A);
  Color get _subTextColor => _isNight ? AppTheme.darkTextSecondary : Colors.grey.shade600;
  Color get _surfaceColor =>
      _isNight ? AppTheme.darkSurfaceBright : const Color(0xFFF5F5F5);

  Color get _couleurPrincipale {
    final resume = widget.trajet.resume;
    if (resume.contains('Woro')) return const Color(0xFFFF6B2B);
    if (resume.contains('Gbaka')) return const Color(0xFF00C896);
    if (resume.contains('SOTRA')) return const Color(0xFF2196F3);
    return const Color(0xFFFF6B2B);
  }

  List<Segment> get _segmentsTransport => widget.trajet.segments
      .where((s) => s.type == TypeSegment.transport)
      .toList();

  Segment get _segmentCourant => widget.trajet.segments[
      _segmentActif.clamp(0, widget.trajet.segments.length - 1)];

  Segment? _findActiveSegment() {
    if (_routePoints.isEmpty || widget.trajet.segments.isEmpty) return null;

    var best = widget.trajet.segments.first;
    var bestDist = double.infinity;
    for (final s in widget.trajet.segments) {
      final midLat = (s.deLatitude + s.versLatitude) / 2;
      final midLon = (s.deLongitude + s.versLongitude) / 2;
      final d = LocationService.distanceEnMetres(
        lat1: _userLat ?? widget.destLat,
        lon1: _userLon ?? widget.destLon,
        lat2: midLat,
        lon2: midLon,
      );
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

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
    GuideService().start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GuideService().triggerStep(GuideStep.navigating);
    });
  }

  Future<void> _loadSettings() async {
    final auto = await SettingsService.getAutoTheme();
    if (!mounted) return;
    setState(() => _autoTheme = auto);
  }

  Future<void> _initialiserNavigation() async {
    try {
      double? positionLat = widget.userLat;
      double? positionLon = widget.userLon;

      if (positionLat == null || positionLon == null) {
        final position = await LocationService.getCurrentPosition();
        positionLat = position.latitude;
        positionLon = position.longitude;
      }

      _userLat = positionLat;
      _userLon = positionLon;

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
    final segments = widget.trajet.segments;

    for (int i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (s.type == TypeSegment.piedVersDest && i == segments.length - 1) {
        continue;
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

        allPolylines.add(Polyline(
          polylineId: PolylineId('border_$i'),
          points: points,
          color: _isNight ? AppTheme.darkTextTertiary : Colors.white.withOpacity(0.3),
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

    final activeSegment = _findActiveSegment();
    _navService.configure(
      destination: LatLng(widget.destLat, widget.destLon),
      routePoints: allPoints,
      activeSegment: activeSegment,
    );

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

      final response = await http.get(url).timeout(
        const Duration(seconds: 6),
        onTimeout: () => http.Response('', 408),
      );
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

    if (_userLat != null && _userLon != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(_userLat!, _userLon!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Ma position'),
      ));
    }

    if (_liveUserPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('live_user'),
        position: _liveUserPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'Position actuelle'),
      ));
    }

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

    markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: LatLng(widget.destLat, widget.destLon),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: 'Destination'),
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
      final s = _segmentCourant;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(s.deLatitude, s.deLongitude), 15,
        ),
      );
    }
  }

  Future<void> _startNavigation() async {
    if (_routePoints.isEmpty) return;
    final active = _findActiveSegment();
    _navService.configure(
      destination: LatLng(widget.destLat, widget.destLon),
      routePoints: _routePoints,
      activeSegment: active,
    );

    setState(() {
      _isNavigating = true;
      _hasArrived = false;
    });

    _navSubscription = _navService.startNavigation().listen(
      _onNavigationSnapshot,
      onError: (e) {
        debugPrint('Navigation error: $e');
      },
    );
  }

  Future<void> _stopNavigation() async {
    await _navSubscription?.cancel();
    _navSubscription = null;
    _navService.stopNavigation();
    setState(() {
      _isNavigating = false;
      _hasArrived = false;
      _nextInstruction = 'Guidage arrêté';
      _remainingMinutes = 0;
      _remainingMeters = 0;
      _liveUserPosition = null;
    });
  }

  void _onNavigationSnapshot(NavigationSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _liveUserPosition = snapshot.snappedPosition ?? snapshot.position;
      _nextInstruction = snapshot.nextInstruction;
      _remainingMinutes = snapshot.remainingMinutes;
      _remainingMeters = snapshot.remainingMeters;
      _hasArrived = snapshot.hasArrived;
    });

    if (snapshot.hasArrived) {
      _onArrived();
    }

    if (_autoRecenter && _mapController != null && snapshot.snappedPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(snapshot.snappedPosition!, 17.5),
      );
    }
  }

  void _onArrived() {
    _stopNavigation();
    GuideService().triggerStep(GuideStep.arrived);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF00C896), size: 28),
            SizedBox(width: 10),
            Text('Tu es arrivé'),
          ],
        ),
        content: Text(
          'Tu as atteint ${widget.trajet.segments.last.description}.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toggleRecenter() {
    setState(() => _autoRecenter = !_autoRecenter);
    _navService.toggleRecenter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
                  _isNight ? AppTheme.mapStyleNight : AppTheme.mapStyleDay);
              if (_routePoints.isNotEmpty) _ajusterCamera();
            },
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

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
                        ? AppTheme.darkOverlay
                        : const Color(0xCCFFFFFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16, right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _bgColor.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _isNight
                              ? AppTheme.darkStroke
                              : Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(Icons.arrow_back,
                        color: _textColor, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _bgColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _isNight
                              ? AppTheme.darkStroke
                              : Colors.black.withValues(alpha: 0.15),
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
                 GestureDetector(
                   onTap: () {
                     HapticFeedback.lightImpact();
                     _ajusterCamera();
                   },
                   child: Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                       color: _bgColor.withValues(alpha: 0.9),
                       shape: BoxShape.circle,
                       boxShadow: [
                         BoxShadow(
                           color: _isNight
                               ? AppTheme.darkStroke
                               : Colors.black.withValues(alpha: 0.2),
                           blurRadius: 8,
                         ),
                       ],
                     ),
                     child: Icon(Icons.zoom_out_map,
                         color: _couleurPrincipale, size: 20),
                   ),
                 ),
                 if (_mapController != null) ...[
                   const SizedBox(width: 8),
                   GestureDetector(
                     onTap: _isNavigating ? _stopNavigation : _startNavigation,
                     child: Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(
                         color: _isNavigating
                             ? Colors.red.shade600
                             : AppTheme.primary,
                         shape: BoxShape.circle,
                         boxShadow: [
                           BoxShadow(
                             color: (_isNavigating ? Colors.red : AppTheme.primary)
                                 .withValues(alpha: 0.4),
                             blurRadius: 12,
                             offset: const Offset(0, 3),
                           ),
                         ],
                       ),
                       child: Icon(
                         _isNavigating ? Icons.stop_rounded : Icons.navigation_rounded,
                         color: Colors.white,
                         size: 20,
                       ),
                     ),
                   ),
                   if (_isNavigating)
                     GestureDetector(
                       onTap: _toggleRecenter,
                       child: Container(
                         padding: const EdgeInsets.all(10),
                         decoration: BoxDecoration(
                           color: _bgColor.withValues(alpha: 0.9),
                           shape: BoxShape.circle,
                           border: Border.all(
                             color: _autoRecenter ? AppTheme.primary : Colors.transparent,
                             width: 1.5,
                           ),
                           boxShadow: [
                             BoxShadow(
                               color: _isNight
                                   ? AppTheme.darkStroke
                                   : Colors.black.withValues(alpha: 0.2),
                               blurRadius: 8,
                             ),
                           ],
                         ),
                         child: Icon(
                           _autoRecenter ? Icons.gps_fixed : Icons.gps_off,
                           color: _autoRecenter ? AppTheme.primary : _textColor,
                           size: 20,
                         ),
                       ),
                     ),
                 ],
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: _bgColor.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: _couleurPrincipale.withValues(alpha: 0.15),
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

          if (_erreur != null && !_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.9),
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
              color: _isNight
                  ? AppTheme.darkStroke
                  : Colors.black.withValues(alpha: 0.25),
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
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isNight ? AppTheme.darkStroke : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            if (_isNavigating) _buildNavigationGuidance(),

            _buildEtapeCourante(),

            const SizedBox(height: 14),

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

            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _panelExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const SizedBox(height: 14),
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

                  if (_segmentActif < widget.trajet.segments.length - 1)
                    GestureDetector(
                      onTap: _segmentSuivant,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _couleurPrincipale,
                              _couleurPrincipale.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _couleurPrincipale.withValues(alpha: 0.35),
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
            // ── Guide IA animé ──
            if (GuideService().isActive)
              Positioned.fill(child: const AiGuideOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationGuidance() {
    final guidanceColor = _hasArrived ? const Color(0xFF00C896) : _couleurPrincipale;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: guidanceColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: guidanceColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: guidanceColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasArrived ? Icons.check_circle : Icons.navigation,
              color: guidanceColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _hasArrived ? 'Arrivé' : 'Prochaine manœuvre',
                  style: TextStyle(
                    color: guidanceColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _nextInstruction,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_remainingMinutes} min',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(_remainingMeters / 1000).toStringAsFixed(1)} km',
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
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
                if (s.conseil != null && s.conseil!.isNotEmpty)
                  Text(
                    s.conseil!,
                    style: TextStyle(color: _subTextColor, fontSize: 11),
                  ),
                Text(
                  '${s.dureeMinutes} min · ${s.prix > 0 ? "${s.prix} FCFA" : "A pied"}',
                  style: TextStyle(color: _subTextColor, fontSize: 11),
                ),
              ],
            ),
          ),
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
            ? _couleurPrincipale.withValues(alpha: 0.5)
            : const Color(0xFF00C896).withValues(alpha: 0.5));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.description,
                  style: TextStyle(
                    color: isActive ? _textColor : _subTextColor,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (s.conseil != null && s.conseil!.isNotEmpty)
                  Text(
                    s.conseil!,
                    style: TextStyle(
                      color: isActive ? _subTextColor : _subTextColor.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
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
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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
    _navSubscription?.cancel();
    _navService.stopNavigation();
    _panelController.dispose();
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
