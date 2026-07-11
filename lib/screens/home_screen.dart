import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'home/home_bottom_panel.dart';
import 'home/home_header.dart';
import 'home/home_map_controls.dart';
import 'home/home_map_view.dart';
import 'home/home_overlays.dart';
import '../services/cluster_service.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../services/gtfs_loader.dart';
import '../widgets/signaler_arret_widget.dart';
import '../services/routing_service.dart';
import '../services/settings_service.dart';
import '../services/crowdsourcing_service.dart';
import '../services/guide_service.dart';
import '../services/tip_service.dart';
import '../data/lignes_mock.dart';
import '../models/gare.dart';
import '../models/ligne.dart';
import '../models/conditions_trafic.dart';
import '../app_theme.dart';
import '../widgets/ai_guide_overlay.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  double? _destLat;
  double? _destLon;
  String? _destNom;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _autoTheme = false;
  String? _errorMessage;
  Set<Marker> _markers = {};
  Set<Marker> _clusterMarkers = {};
  Set<Marker> _overlayMarkers = {};
  final Set<Polyline> _polylines = {};
  Timer? _vehiculeTimer;
  StreamSubscription<Position>? _positionStreamSub;
  bool _positionStreamStarted = false;
  bool _followUser = false;
  bool _isLoadingVehicles = false;
  List<ArretSignale> _arretsSignales = [];
  List<Ligne> _lignesActives = [];
  BitmapDescriptor? _iconUserPosition;
  BitmapDescriptor? _iconUserPositionPulse;
  Timer? _cameraDebounce;
  String _markerSignature = '';
  bool _panelExpanded = true;
  DateTime? _lastPositionUpdate;
  static const _positionThrottle = Duration(milliseconds: 1000);

  /// Conditions de simulation (pluie / embouteillages) appliquées au calcul
  /// des trajets, pilotées depuis le panneau du bas.
  ConditionsTrafic _conditions = const ConditionsTrafic();

  // Controllers d'animation
  late AnimationController _panelController;
  late Animation<double> _panelAnimation;
  late Animation<Offset> _slideAnimation;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(5.3600, -4.0083),
    zoom: 13,
  );

  final String _mapStyleDay = AppTheme.mapStyleDay;

  bool get _isNight {
    if (!_autoTheme) return false; // mode jour par défaut
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  String get _mapStyle => _isNight ? AppTheme.mapStyleNight : _mapStyleDay;

  bool get _canSearch =>
      _currentPosition != null &&
      _destNom != null &&
      _destLat != null &&
      _destLon != null;

  LatLng? _departurePosition;
  String? _departureLabel;
  bool _selectingDepartureMode = false;

  LatLng get _originPosition => _departurePosition ?? LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
  bool get _hasCustomDeparture => _departurePosition != null;

  void _setDeparturePosition(LatLng position, {String? label}) {
    setState(() {
      _departurePosition = position;
      _departureLabel = label ?? 'Départ personnalisé';
      _selectingDepartureMode = false;
    });
    _addDepartureMarker(position);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  void _clearDeparturePosition() {
    setState(() {
      _departurePosition = null;
      _departureLabel = null;
      _selectingDepartureMode = false;
    });
    if (_currentPosition != null) {
      _updateUserMarker();
    }
    _refreshMarkers();
  }

  void _toggleDepartureSelectionMode() {
    if (_selectingDepartureMode) {
      setState(() => _selectingDepartureMode = false);
    } else {
      setState(() => _selectingDepartureMode = true);
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appuie long sur la carte pour choisir le point de départ'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _addDepartureMarker(LatLng position) {
    final nouveaux = Set<Marker>.from(_overlayMarkers);
    nouveaux.removeWhere((m) => m.markerId.value == 'departure_custom');
    nouveaux.add(Marker(
      markerId: const MarkerId('departure_custom'),
      position: position,
      infoWindow: InfoWindow(title: 'Départ', snippet: _departureLabel),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    ));
    _overlayMarkers = nouveaux;
    _refreshMarkers();
  }

  Future<void> _loadSettings() async {
    final auto = await SettingsService.getAutoTheme();
    if (!mounted) return;
    setState(() => _autoTheme = auto);
  }

  bool _iconsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _chargerGtfsEnArrierePlan();

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(_panelAnimation);

    GuideService().start();
    GuideService().showTip(TipService.instance.getTip(
      TipEvent.appOpen,
      heure: DateTime.now().hour,
      conditions: _conditions,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iconsInitialized) {
      _iconsInitialized = true;
      _preloadIcons().then((_) => _loadPosition());
    }
  }

  Future<void> _preloadIcons() async {
    _iconUserPosition = await _createDotMarker(const Color(0xFF00C896));
    _iconUserPositionPulse =
        await _createPulsingDotMarker(const Color(0xFF00C896));

    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createDotMarker(Color color) async {
    const int size = 40;
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    final paint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size * 0.2, paint);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size * 0.2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final image = await recorder.endRecording().toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createPulsingDotMarker(Color color) async {
    const int size = 66;
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

    // Outer pale ring
    final ringPaint = Paint()..color = color.withAlpha((0.18 * 255).round());
    canvas.drawCircle(const Offset(size / 2, size / 2), size * 0.28, ringPaint);

    // Inner solid dot
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size * 0.16, dotPaint);

    // White border
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size * 0.16,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final image = await recorder.endRecording().toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _chargerLignesSupabase() async {
    List<Ligne> lignesSupabase = <Ligne>[];
    try {
      lignesSupabase = await SupabaseService.getLignes().timeout(
        const Duration(seconds: 20),
        onTimeout: () => <Ligne>[],
      );
    } catch (e) {
      debugPrint('⚠️ getLignes() a échoué: $e');
    }

    final lignesMockSansSOTRA =
        lignesMock.where((l) => l.type != TransportType.sotra).toList();

    final gtfsLignes = GtfsLoader.instance.lignes;
    final lignesGtfs = gtfsLignes.where((l) => l.type != TransportType.sotra).toList();
    final lignesGtfsSotra = gtfsLignes.where((l) => l.type == TransportType.sotra).toList();

    final candidates = <Ligne>[
      ...lignesGtfs,
      ...lignesMockSansSOTRA,
    ];

    final deja = <String>{};
    final uniques = <Ligne>[];
    for (final l in candidates) {
      if (l.id.isEmpty) continue;
      if (!deja.add(l.id)) continue;
      uniques.add(l);
    }

    final vu = <String>{...deja};
    final ajoutSupabase = <Ligne>[];
    for (final l in lignesSupabase) {
      if (l.id.isEmpty) continue;
      if (!vu.add(l.id)) continue;
      ajoutSupabase.add(l);
    }

    setState(() {
      _lignesActives = [
        ...uniques,
        ...lignesGtfsSotra,
        ...ajoutSupabase,
      ];
    });

    debugPrint('✅ GTFS=${lignesGtfs.length + lignesGtfsSotra.length} '
        'mock=${lignesMockSansSOTRA.length} '
        'supabase=${lignesSupabase.length} '
        'total=${_lignesActives.length}');
  }

  Future<void> _loadPosition() async {
    // Position OPTIONNELLE : récupérée dans une méthode dédiée (ré-appelable
    // au retour au premier plan). Si elle échoue, on continue sans centrer.
    await _fetchPosition();

    if (!mounted) return;
    setState(() => _isLoading = false);

    // GTFS d'abord pour garantir que les lignes/arrêts sont disponibles.
    await GtfsLoader.instance.initialize().timeout(
      const Duration(seconds: 20),
      onTimeout: () {},
    );
    debugPrint('📦 GTFS initialisé: ${GtfsLoader.instance.isLoaded}');

    // Supabase en parallèle (non bloquant)
    final lignesSotraFuture = SupabaseService.getLignesSotra().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <Map<String, dynamic>>[],
    );
    final supabaseTask = _chargerLignesSupabase().timeout(
      const Duration(seconds: 15),
      onTimeout: () {},
    );

    // Centre de la carte : position si dispo, sinon position par défaut
    final center = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultPosition.target;

    final lignesSotra = await lignesSotraFuture;

    // S'assure que les lignes Supabase sont chargées avant ClusterService
    await supabaseTask;

    debugPrint('🧭 lignesActives=${_lignesActives.length} '
        'mock=${lignesMock.where((l)=>l.type!=TransportType.sotra).length} '
        'sotra=${_lignesActives.where((l)=>l.type==TransportType.sotra).length}');

    final arretsSupabase = lignesSotra
        .map((l) => <String, dynamic>{
              'latitude': l['lat_depart'] ?? l['latitude'],
              'longitude': l['lon_depart'] ?? l['longitude'],
              'nom': '${l['nom']} — ${l['terminus_depart']}',
              'ligne': l['nom'],
              'prix': l['prix'] ?? 200,
            })
        .toList();

    ClusterService.initialiser(
      onMarkersUpdated: _onClusterMarkersUpdated,
      lignes: _lignesActives,
      arretsSupabase: arretsSupabase,
    );
    ClusterService.mettreAJourCamera(
      CameraPosition(target: center, zoom: 14),
    );
    ClusterService.onCameraIdle();

    await _chargerArretsSignales();

    // Charger les positions des véhicules (chauffeurs) et démarrer un timer
    _chargerVehiculesLive();
    _vehiculeTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _chargerVehiculesLive());

    // Slide up du panel après chargement
    await Future.delayed(const Duration(milliseconds: 400));
    _panelController.forward();

    // Le flux de position temps réel est démarré dans _fetchPosition()
    // (une seule fois, guardé par _positionStreamStarted).
  }

  /// Récupère la position de manière isolée et ré-appelable (1er lancement et
  /// retour au premier plan). En cas d'échec, affiche un message d'erreur avec
  /// un accès direct aux paramètres, sans bloquer le reste de l'app.
  Future<void> _fetchPosition() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      final etaitNull = _currentPosition == null;
      setState(() {
        _currentPosition = position;
        _errorMessage = null;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );
      _updateUserMarker();
      _startPositionStream();
      if (etaitNull && _clusterMarkers.isNotEmpty) {
        ClusterService.mettreAJourCamera(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Position indisponible: $e');
      if (mounted) {
        setState(() => _errorMessage =
            'Position GPS indisponible (permission/GPS). Ouvre les paramètres '
            "pour autoriser la localisation, puis reviens dans l'app.");
      }
    }
  }

  void _startPositionStream() {
    if (_positionStreamStarted || _currentPosition == null) return;
    _positionStreamStarted = true;

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 50,
      ),
    ).listen((pos) {
      if (!mounted) return;

      final now = DateTime.now();
      if (_lastPositionUpdate != null &&
          now.difference(_lastPositionUpdate!) < _positionThrottle) {
        return;
      }
      _lastPositionUpdate = now;

      _currentPosition = pos;
      _updateUserMarker();
      if (_followUser && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(pos.latitude, pos.longitude),
            16,
          ),
        );
      }
    });
  }

  void _refreshMarkers() {
    if (!mounted) return;

    final merged = <MarkerId, Marker>{};
    for (final marker in _clusterMarkers) {
      merged[marker.markerId] = marker;
    }
    for (final marker in _overlayMarkers) {
      merged[marker.markerId] = marker;
    }

    final markers = merged.values.toSet();
    final signature = _buildMarkerSignature(markers);
    if (signature == _markerSignature) return;

    _markerSignature = signature;
    setState(() => _markers = markers);
  }

  String _buildMarkerSignature(Set<Marker> markers) {
    final parts = markers.map((m) {
      final p = m.position;
      return '${m.markerId.value}:'
          '${p.latitude.toStringAsFixed(5)}:'
          '${p.longitude.toStringAsFixed(5)}';
    }).toList()
      ..sort();
    return parts.join('|');
  }

  void _onClusterMarkersUpdated(Set<Marker> markers) {
    _clusterMarkers = markers;
    _refreshMarkers();
  }

  Future<void> _chargerArretsSignales() async {
    if (_currentPosition == null) return;
    final arrets = await CrowdsourcingService.getArretsProches(
      lat: _currentPosition!.latitude,
      lon: _currentPosition!.longitude,
    );
    _arretsSignales = arrets;
    _ajouterMarqueursSignales();
  }

  void _ajouterMarqueursSignales() {
    final nouveauxMarqueurs = Set<Marker>.from(_overlayMarkers);
    for (int i = 0; i < _arretsSignales.length; i++) {
      final a = _arretsSignales[i];
      nouveauxMarqueurs.add(Marker(
        markerId: MarkerId('signale_$i'),
        position: LatLng(a.latitude, a.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          a.statut == 'valide'
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueViolet,
        ),
        infoWindow: InfoWindow(
          title: '📌 ${a.nom}',
          snippet: a.statut == 'valide'
              ? '✅ Validé par la communauté'
              : '⏳ En attente de validation',
        ),
      ));
    }
    _overlayMarkers = nouveauxMarqueurs;
    _refreshMarkers();
  }

  void _ouvrirSignalerArret({required SignalerArretMode mode}) {
    if (_currentPosition == null) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SignalerArretWidget(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        isNight: _isNight,
        onSuccess: _chargerArretsSignales,
        mode: mode,
      ),
    );
  }

  void _ouvrirSignalerProbleme() {
    _ouvrirSignalerArret(mode: SignalerArretMode.probleme);
  }

  void _ouvrirAjouterArret() {
    _ouvrirSignalerArret(mode: SignalerArretMode.ajout);
  }

  Future<void> _chargerGtfsEnArrierePlan() async {
    try {
      await GtfsLoader.instance.initialize();
      debugPrint('✅ GTFS chargé : ${GtfsLoader.instance.lignes.length} lignes');
    } catch (e) {
      debugPrint('⚠️ GTFS erreur : $e');
    }
  }

  Future<void> _onDestinationSubmitted(
      String nom, double destLat, double destLon) async {
    if (_currentPosition == null) return;

    setState(() => _isSearching = true);

    // Laisse Flutter peindre l'overlay de recherche avant le calcul
    // (qui reste synchrone) : évite le freeze visuel et l'absence d'animation.
    await Future.microtask(() {});

    final originLat = _originPosition.latitude;
    final originLon = _originPosition.longitude;

    final lignes = _lignesActives;

    final trajets = RoutingService.calculerTrajets(
      userLat: originLat,
      userLon: originLon,
      destLat: destLat,
      destLon: destLon,
      lignes: lignes,
      heure: DateTime.now().hour,
      conditions: _conditions,
    );

    setState(() => _isSearching = false);

    if (trajets.isNotEmpty && _mapController != null) {
      final bounds = _calculerBounds(
        userLat: originLat,
        userLon: originLon,
        destLat: destLat,
        destLon: destLon,
      );
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    }

    if (!mounted) return;
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, animation, __) => ResultsScreen(
        trajets: trajets,
        destination: nom,
        destLat: destLat,
        destLon: destLon,
        userLat: originLat,
        userLon: originLon,
        conditions: _conditions,
      ),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1), end: Offset.zero,
        ).animate(CurvedAnimation(
            parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  LatLngBounds _calculerBounds({
    required double userLat, required double userLon,
    required double destLat, required double destLon,
  }) {
    return LatLngBounds(
      southwest: LatLng(
        userLat < destLat ? userLat - 0.005 : destLat - 0.005,
        userLon < destLon ? userLon - 0.005 : destLon - 0.005,
      ),
      northeast: LatLng(
        userLat > destLat ? userLat + 0.005 : destLat + 0.005,
        userLon > destLon ? userLon + 0.005 : destLon + 0.005,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Carte avec hauteur réduite ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: _panelExpanded ? 280 : 80,
            child: HomeMapView(
              initialCameraPosition: _defaultPosition,
              mapStyle: _mapStyle,
              polylines: _polylines,
              markers: _markers,
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onCameraMove: (position) {
                _cameraDebounce?.cancel();
                ClusterService.mettreAJourCamera(position);
              },
              onCameraIdle: () {
                _cameraDebounce?.cancel();
                _cameraDebounce = Timer(const Duration(milliseconds: 300), () {
                  ClusterService.onCameraIdle();
                });
              },
              onMapTap: _selectingDepartureMode
                  ? (position) {
                      if (_selectingDepartureMode) {
                        _setDeparturePosition(position);
                      }
                    }
                  : null,
            ),
          ),

          Positioned(
            top: 140,
            right: 16,
            child: HomeMapControls(
              followUser: _followUser,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onToggleFollow: _toggleFollow,
              hasCustomDeparture: _hasCustomDeparture,
              selectingDepartureMode: _selectingDepartureMode,
              onToggleDepartureMode: _toggleDepartureSelectionMode,
              onResetDeparture: _hasCustomDeparture ? _clearDeparturePosition : null,
            ),
          ),

          // ── Overlay gradient haut ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
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

          // ── Header ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            child: HomeHeader(
              autoTheme: _autoTheme,
              isNight: _isNight,
              isLoading: _isLoading,
              onAutoThemeChanged: (value) {
                if (!mounted) return;
                setState(() => _autoTheme = value);
              },
            ),
          ),

          // ── Loader Lottie ──
          if (_isLoading) const HomeLoadingOverlay(),

          // ── Overlay recherche en cours ──
          if (_isSearching) const HomeSearchingOverlay(),

          // ── Sélection du point de départ ──
          if (_selectingDepartureMode) const HomeDepartureSelectionOverlay(isNight: true),

          // ── Bannière départ personnalisé ──
          if (_hasCustomDeparture && _departureLabel != null)
            HomeDepartureBanner(
              departureLabel: _departureLabel!,
              onReset: _clearDeparturePosition,
              isNight: _isNight,
            ),

          // ── Erreur ──
          if (_errorMessage != null)
            Positioned(
              bottom: 220,
              left: 20,
              right: 20,
              child: HomeErrorBanner(
                message: _errorMessage!,
                onSettings: () => LocationService.openAppSettings(),
              ),
            ),

          // ── Panel bas animé ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta == null) return;
                if (details.primaryDelta! < -15 && !_panelExpanded) {
                  setState(() => _panelExpanded = true);
                } else if (details.primaryDelta! > 15 && _panelExpanded) {
                  setState(() => _panelExpanded = false);
                }
              },
              child: AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: SlideTransition(
                  position: _slideAnimation,
              child: HomeBottomPanel(
                isNight: _isNight,
                canSearch: _canSearch,
                hasCurrentPosition: _currentPosition != null,
                hasCustomDeparture: _hasCustomDeparture,
                departureLabel: _departureLabel,
                collapsed: !_panelExpanded,
                conditions: _conditions,
                onConditionsChanged: (c) {
                  final old = _conditions;
                  setState(() => _conditions = c);
                  if (c.pluie != old.pluie) {
                    GuideService().showTip(TipService.instance.getTip(
                      TipEvent.rainToggled,
                      heure: DateTime.now().hour,
                      conditions: c,
                    ));
                  }
                  if (c.embouteillage != old.embouteillage) {
                    GuideService().showTip(TipService.instance.getTip(
                      TipEvent.trafficToggled,
                      heure: DateTime.now().hour,
                      conditions: c,
                    ));
                  }
                },
                onReportProblem: _ouvrirSignalerProbleme,
                onAddStop: _ouvrirAjouterArret,
                onDestinationSelected: (nom, lat, lon) {
                  setState(() {
                    _destNom = nom;
                    _destLat = lat;
                    _destLon = lon;
                  });
                  GuideService().triggerStep(GuideStep.destinationSelected, destination: nom);
                  _onDestinationSubmitted(nom, lat, lon);
                },
                onGo: _canSearch
                    ? () => _onDestinationSubmitted(
                          _destNom!,
                          _destLat!,
                          _destLon!,
                        )
                    : null,
                onToggleDepartureMode: _toggleDepartureSelectionMode,
                onResetDeparture: _clearDeparturePosition,
                onToggleCollapsed: () =>
                    setState(() => _panelExpanded = !_panelExpanded),
              ),
                ),
              ),
            ),
          ),
          // ── Guide IA animé ──
          // if (GuideService().isActive && GuideService().stream != null)
            // const AiGuideOverlay(),

        ],
      ),
    );
  }

  Future<void> _chargerVehiculesLive() async {
    if (_isLoadingVehicles) return;
    _isLoadingVehicles = true;
    try {
      final vehicles = await SupabaseService.getVehiculesLive();
      if (!mounted) return;

      final nouveaux = Set<Marker>.from(_overlayMarkers);
      for (final v in vehicles) {
        final lat = double.tryParse(v['latitude']?.toString() ?? '') ?? 0.0;
        final lon = double.tryParse(v['longitude']?.toString() ?? '') ?? 0.0;
        final id =
            v['id']?.toString() ?? v['chauffeur_id']?.toString() ?? '$lat:$lon';
        final titre = v['ligne_id']?.toString() ?? 'Véhicule';

        nouveaux.removeWhere((m) => m.markerId.value == id);
        nouveaux.add(Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lon),
          infoWindow: InfoWindow(
            title: titre,
            snippet: 'Dernière mise à jour: ${v['updated_at'] ?? 'inconnue'}',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ));
      }

      _overlayMarkers = nouveaux;
      _refreshMarkers();
    } catch (e) {
      // ignore: avoid_print
      // print('Erreur chargement vehicules live: $e');
    } finally {
      _isLoadingVehicles = false;
    }
  }

  Future<void> _zoomIn() async {
    if (_mapController == null) return;
    final currentZoom = await _mapController!.getZoomLevel();
    await _mapController!.animateCamera(CameraUpdate.zoomTo(currentZoom + 1));
  }

  Future<void> _zoomOut() async {
    if (_mapController == null) return;
    final currentZoom = await _mapController!.getZoomLevel();
    await _mapController!.animateCamera(CameraUpdate.zoomTo(currentZoom - 1));
  }

  void _toggleFollow() {
    HapticFeedback.lightImpact();
    setState(() {
      _followUser = !_followUser;
    });
    if (_followUser && _currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          16,
        ),
      );
    }
  }

  void _updateUserMarker() {
    if (_currentPosition == null) return;
    const userId = 'user_position';
    final nouveaux = Set<Marker>.from(_overlayMarkers);
    nouveaux.removeWhere((m) => m.markerId.value == userId);
    final iconToUse = _iconUserPositionPulse ??
        _iconUserPosition ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    nouveaux.add(Marker(
      markerId: const MarkerId(userId),
      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      infoWindow: const InfoWindow(title: 'Moi'),
      anchor: const Offset(0.5, 0.5),
      icon: iconToUse,
    ));
    _overlayMarkers = nouveaux;
    _refreshMarkers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Au retour au premier plan (ex : permission changée dans les réglages),
    // on revérifie la localisation si elle n'était pas disponible.
    if (state == AppLifecycleState.resumed && _currentPosition == null && mounted) {
      _fetchPosition();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraDebounce?.cancel();
    _vehiculeTimer?.cancel();
    _positionStreamSub?.cancel();
    _panelController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
