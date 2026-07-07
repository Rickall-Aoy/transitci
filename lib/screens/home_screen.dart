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
import '../data/lignes_mock.dart';
import '../models/gare.dart';
import '../models/ligne.dart';
import '../app_theme.dart';
import 'results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
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
  bool _followUser = false;
  bool _isLoadingVehicles = false;
  List<ArretSignale> _arretsSignales = [];
  List<Ligne> _lignesActives = lignesMock;
  BitmapDescriptor? _iconUserPosition;
  BitmapDescriptor? _iconUserPositionPulse;
  Timer? _cameraDebounce;
  String _markerSignature = '';

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

  Future<void> _loadSettings() async {
    final auto = await SettingsService.getAutoTheme();
    if (!mounted) return;
    setState(() => _autoTheme = auto);
  }

  bool _iconsInitialized = false;

  @override
  void initState() {
    super.initState();
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
    final lignesSupabase = await SupabaseService.getLignes();

    final lignesMockSansSOTRA =
        lignesMock.where((l) => l.type != TransportType.sotra).toList();

    if (lignesSupabase.isEmpty) {
      debugPrint('⚠️ Supabase vide — utilisation des données mock (GTFS inclus)');
      setState(() {
        _lignesActives = [...lignesMockSansSOTRA, ...lignesSotra];
      });
      return;
    }

    setState(() {
      _lignesActives = [...lignesMockSansSOTRA, ...lignesSupabase];
    });

    debugPrint('✅ ${lignesSupabase.length} lignes depuis Supabase');
    debugPrint('✅ Total: ${_lignesActives.length} lignes actives');
  }

  Future<void> _loadPosition() async {
    try {
      // Lance GPS et Supabase en parallèle
      final positionFuture = LocationService.getCurrentPosition()
          .timeout(const Duration(seconds: 8));
      final lignesSotraFuture = SupabaseService.getLignesSotra();
      final supabaseTask = _chargerLignesSupabase();

      final position = await positionFuture;

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );

      _updateUserMarker();

      final lignesSotra = await lignesSotraFuture;

      // S'assure que les lignes Supabase sont chargées avant ClusterService
      await supabaseTask;

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
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14,
        ),
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

      // Démarrer l'écoute de la position en temps réel et mettre à jour le marqueur utilisateur
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() => _currentPosition = pos);
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
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
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

    final lignes = _lignesActives;

    final trajets = RoutingService.calculerTrajets(
      userLat: _currentPosition!.latitude,
      userLon: _currentPosition!.longitude,
      destLat: destLat,
      destLon: destLon,
      lignes: lignes,
      heure: DateTime.now().hour,
    );

    setState(() => _isSearching = false);

    if (trajets.isNotEmpty && _mapController != null) {
      final bounds = _calculerBounds(
        userLat: _currentPosition!.latitude,
        userLon: _currentPosition!.longitude,
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
        userLat: _currentPosition?.latitude,
        userLon: _currentPosition?.longitude,
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
            bottom: 280,
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

          Positioned(
            bottom: 180,
            right: 16,
            child: HomeAddStopButton(
              onTap: _ouvrirAjouterArret,
            ),
          ),

          // ── Panel bas animé ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: HomeBottomPanel(
                isNight: _isNight,
                canSearch: _canSearch,
                hasCurrentPosition: _currentPosition != null,
                onReportProblem: _ouvrirSignalerProbleme,
                onAddStop: _ouvrirAjouterArret,
                onDestinationSelected: (nom, lat, lon) {
                  setState(() {
                    _destNom = nom;
                    _destLat = lat;
                    _destLon = lon;
                  });
                  _onDestinationSubmitted(nom, lat, lon);
                },
                onGo: _canSearch
                    ? () => _onDestinationSubmitted(
                          _destNom!,
                          _destLat!,
                          _destLon!,
                        )
                    : null,
              ),
            ),
          ),

          // ── Erreur ──
          if (_errorMessage != null)
            Positioned(
              bottom: 220,
              left: 20,
              right: 20,
              child: HomeErrorBanner(message: _errorMessage!),
            ),
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
  void dispose() {
    _cameraDebounce?.cancel();
    _vehiculeTimer?.cancel();
    _positionStreamSub?.cancel();
    _panelController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
