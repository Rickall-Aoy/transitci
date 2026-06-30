import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:shimmer/shimmer.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import '../widgets/search_destination_widget.dart';
import '../widgets/signaler_arret_widget.dart';
import '../services/routing_service.dart';
import '../services/settings_service.dart';
import '../services/crowdsourcing_service.dart';
import '../data/lignes_mock.dart';
import '../models/gare.dart';
import 'results_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
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
  Timer? _vehiculeTimer;
  StreamSubscription<Position>? _positionStreamSub;
  List<ArretSignale> _arretsSignales = [];
  BitmapDescriptor? _iconWoroWoro;
  BitmapDescriptor? _iconGbaka;
  BitmapDescriptor? _iconSotra;
  BitmapDescriptor? _iconYango;
  BitmapDescriptor? _iconStop;

  // Controllers d'animation
  late AnimationController _panelController;
  late Animation<double> _panelAnimation;
  late Animation<Offset> _slideAnimation;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(5.3600, -4.0083),
    zoom: 13,
  );

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
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#e9bc62"}]},
  {"featureType": "water", "elementType": "geometry.fill", "stylers": [{"color": "#aadaff"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#c5dea8"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#ede7d8"}]}
]
''';

  bool get _isNight {
    if (!_autoTheme) return false; // mode jour par défaut
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  String get _mapStyle => _isNight ? _mapStyleNight : _mapStyleDay;

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
    final double dpr = MediaQuery.of(context).devicePixelRatio;

    final config = ImageConfiguration(
      size: const Size(36, 36),
      devicePixelRatio: dpr,
    );

    final configSmall = ImageConfiguration(
      size: const Size(24, 24),
      devicePixelRatio: dpr,
    );

    _iconWoroWoro = await BitmapDescriptor.fromAssetImage(
      config,
      'assets/icons/woroworo.jpg',
    );
    _iconGbaka = await BitmapDescriptor.fromAssetImage(
      config,
      'assets/icons/gbaka.jpg',
    );
    _iconSotra = await BitmapDescriptor.fromAssetImage(
      config,
      'assets/icons/sotra.jpg',
    );
    _iconYango = await BitmapDescriptor.fromAssetImage(
      config,
      'assets/icons/yango.jpg',
    );
    _iconStop = await BitmapDescriptor.fromAssetImage(
      configSmall,
      'assets/icons/stop.jpg',
    );

    if (mounted) setState(() {});
  }

  Future<void> _loadPosition() async {
    try {
      final position = await LocationService.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );

      // Ajouter immédiatement le marqueur utilisateur
      _updateUserMarker();

      _chargerMarqueurs();
      await _chargerArretsSignales();

      // Charger les positions des véhicules (chauffeurs) et démarrer un timer
      _chargerVehiculesLive();
      _vehiculeTimer = Timer.periodic(const Duration(seconds: 15), (_) => _chargerVehiculesLive());

      // Slide up du panel après chargement
      await Future.delayed(const Duration(milliseconds: 400));
      _panelController.forward();

      // Démarrer l'écoute de la position en temps réel et mettre à jour le marqueur utilisateur
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() => _currentPosition = pos);
        _updateUserMarker();
      });

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _chargerMarqueurs() {
    final Set<Marker> markers = {};

    for (final ligne in lignesMock) {
      final iconTerminus = _iconParType(ligne.type);
      final iconArret = _iconStop ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);

      // ── Terminus départ ──
      markers.add(Marker(
        markerId: MarkerId('dep_${ligne.id}'),
        position: LatLng(
          ligne.terminusDepart.latitude,
          ligne.terminusDepart.longitude,
        ),
        icon: iconTerminus,
        infoWindow: InfoWindow(
          title: '${_emojiParType(ligne.type)} ${ligne.terminusDepart.nom}',
          snippet: '${ligne.nom} · ${ligne.prix} FCFA',
        ),
      ));

      // ── Terminus arrivée ──
      markers.add(Marker(
        markerId: MarkerId('arr_${ligne.id}'),
        position: LatLng(
          ligne.terminusArrivee.latitude,
          ligne.terminusArrivee.longitude,
        ),
        icon: iconTerminus,
        infoWindow: InfoWindow(
          title: '${_emojiParType(ligne.type)} ${ligne.terminusArrivee.nom}',
          snippet: '${ligne.nom} · ${ligne.prix} FCFA',
        ),
      ));

      // ── Arrêts possibles ──
      for (int i = 0; i < ligne.arretsPossibles.length; i++) {
        final arret = ligne.arretsPossibles[i];
        markers.add(Marker(
          markerId: MarkerId('arret_${ligne.id}_$i'),
          position: LatLng(arret.latitude, arret.longitude),
          icon: iconArret,
          infoWindow: InfoWindow(
            title: '📌 ${arret.nom}',
            snippet: 'Arrêt possible · ${ligne.nom}',
          ),
          alpha: 0.75,
        ));
      }
    }

    setState(() => _markers = markers);
  }

  Future<void> _chargerArretsSignales() async {
    if (_currentPosition == null) return;
    final arrets = await CrowdsourcingService.getArretsProches(
      lat: _currentPosition!.latitude,
      lon: _currentPosition!.longitude,
    );
    setState(() => _arretsSignales = arrets);
    _ajouterMarqueursSignales();
  }

  void _ajouterMarqueursSignales() {
    final nouveauxMarqueurs = Set<Marker>.from(_markers);
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
    setState(() => _markers = nouveauxMarqueurs);
  }

  void _ouvrirSignalerArret() {
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
      ),
    );
  }

  // ── Helper icône par type ──
  BitmapDescriptor _iconParType(TransportType type) {
    switch (type) {
      case TransportType.woroWoro:
        return _iconWoroWoro ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case TransportType.gbaka:
        return _iconGbaka ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case TransportType.sotra:
        return _iconSotra ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case TransportType.yango:
        return _iconYango ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    }
  }

  String _emojiParType(TransportType type) {
    switch (type) {
      case TransportType.woroWoro: return '🚕';
      case TransportType.gbaka:    return '🚐';
      case TransportType.sotra:    return '🚌';
      case TransportType.yango:    return '🚗';
    }
  }

  Future<void> _onDestinationSubmitted(
      String nom, double destLat, double destLon) async {
    if (_currentPosition == null) return;

    setState(() => _isSearching = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final trajets = RoutingService.calculerTrajets(
      userLat: _currentPosition!.latitude,
      userLon: _currentPosition!.longitude,
      destLat: destLat,
      destLon: destLon,
      lignes: lignesMock,
      heure: DateTime.now().hour,
    );

    setState(() => _isSearching = false);
    if (!mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ResultsScreen(
          trajets: trajets,
          destination: nom,
          destLat: destLat,
          destLon: destLon,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
              parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Carte réduite ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 340,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: GoogleMap(
                key: const ValueKey('home_google_map'),
                initialCameraPosition: _defaultPosition,
                style: _mapStyle,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapType: MapType.normal,
              ),
            ),
          ),

          Positioned(
            top: 140,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapControlButton(
                  icon: Icons.add,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 12),
                _buildMapControlButton(
                  icon: Icons.remove,
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),

          // ── Overlay gradient haut ──
          Positioned(
            top: 0, left: 0, right: 0,
            height: 180,
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

          // ── Header ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            child: _buildHeader(),
          ),

          // ── Loader Lottie ──
          if (_isLoading)
            Container(
              color: const Color(0xFF0A0A0A),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: LottieBuilder.asset(
                        'assets/lottie/road_trip.json',
                        fit: BoxFit.contain,
                        repeat: true,
                        errorBuilder: (context, error, stack) {
                          return const CircularProgressIndicator(
                            color: Color(0xFFFF6B2B),
                            strokeWidth: 2,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ShimmerText(),
                    const SizedBox(height: 8),
                    const Text(
                      'Chargement de la carte...',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Overlay recherche en cours ──
          if (_isSearching)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF6B2B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: LottieBuilder.asset(
                          'assets/lottie/car_search.json',
                          fit: BoxFit.contain,
                          repeat: true,
                          errorBuilder: (context, error, stack) {
                            return const CircularProgressIndicator(
                              color: Color(0xFFFF6B2B),
                              strokeWidth: 2,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Analyse en cours...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Recherche des meilleures options',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 180,
            right: 16,
            child: GestureDetector(
              onTap: _ouvrirSignalerArret,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B2B), Color(0xFFFF8C55)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B2B).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_location_alt,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // ── Panel bas animé ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildBottomPanel(),
            ),
          ),

          // ── Erreur ──
          if (_errorMessage != null)
            Positioned(
              bottom: 220,
              left: 20, right: 20,
              child: _buildErrorBanner(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B2B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Transit',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const Text(
              'CI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final newVal = !_autoTheme;
                        await SettingsService.setAutoTheme(newVal);
                        if (!mounted) return;
                        setState(() => _autoTheme = newVal);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _autoTheme
                              ? const Color(0xFFFF6B2B).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _autoTheme
                                ? const Color(0xFFFF6B2B)
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _autoTheme ? Icons.brightness_auto : Icons.wb_sunny,
                              size: 12,
                              color: _autoTheme
                                  ? const Color(0xFFFF6B2B)
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _autoTheme ? 'Auto' : 'Jour',
                              style: TextStyle(
                                color: _autoTheme
                                    ? const Color(0xFFFF6B2B)
                                    : Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ), // ← fin GestureDetector toggle

                    const SizedBox(width: 8),

                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(context, '/chauffeur/login');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.drive_eta,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(context, '/passager/search');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ), // ← fin GestureDetector settings

                    const SizedBox(width: 8),

                    _buildGpsIndicator(),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (!_isLoading)
          const Text(
            'Où veux-tu aller ?',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildGpsIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00C896).withValues(alpha: 0.6),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF00C896)),
          SizedBox(width: 6),
          Text(
            'GPS actif',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _isNight ? const Color(0xFF111111) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -8),
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
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _isNight ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Légende transports
          _buildLegende(),

          const SizedBox(height: 16),

          // Actions rapides
          _buildActionButtons(),

          const SizedBox(height: 16),

          // Barre de recherche
          _buildSearchBar(),

          const SizedBox(height: 12),

          // Bouton principal
          _buildGoButton(),
        ],
      ),
    );
  }

  Widget _buildLegende() {
    final types = [
      {'emoji': '🚕', 'label': 'Woro-Woro', 'color': const Color(0xFFFF6B2B)},
      {'emoji': '🚐', 'label': 'Gbaka',     'color': const Color(0xFF00C896)},
      {'emoji': '🚌', 'label': 'SOTRA',     'color': const Color(0xFF2196F3)},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: types.map((t) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t['emoji'] as String,
                style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              t['label'] as String,
              style: TextStyle(
                color: t['color'] as Color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _ouvrirSignalerArret,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.report, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Alerter un arrêt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _ouvrirSignalerArret,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B2B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_location_alt, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Ajouter un arrêt',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SearchDestinationWidget(
      isNight: _isNight,
      onDestinationSelected: (nom, lat, lon) {
        setState(() {
          _destNom = nom;
          _destLat = lat;
          _destLon = lon;
        });
        _onDestinationSubmitted(nom, lat, lon);
      },
    );
  }

  Widget _buildGoButton() {
    final canSearch = _currentPosition != null &&
        _destNom != null &&
        _destLat != null &&
        _destLon != null;

    return GestureDetector(
      onTap: canSearch
          ? () => _onDestinationSubmitted(_destNom!, _destLat!, _destLon!)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canSearch
                ? [const Color(0xFFFF6B2B), const Color(0xFFFF8C55)]
                : [Colors.grey.shade800, Colors.grey.shade700],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: canSearch
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF6B2B).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              _currentPosition != null
                  ? 'Trouver le meilleur transport'
                  : 'Localisation en cours...',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade700),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chargerVehiculesLive() async {
    try {
      final vehicles = await SupabaseService.getVehiculesLive();
      if (!mounted) return;

      final nouveaux = Set<Marker>.from(_markers);
      for (final v in vehicles) {
        final lat = double.tryParse(v['latitude']?.toString() ?? '') ?? 0.0;
        final lon = double.tryParse(v['longitude']?.toString() ?? '') ?? 0.0;
        final id = v['id']?.toString() ?? v['chauffeur_id']?.toString() ?? '$lat:$lon';
        final titre = v['ligne_id']?.toString() ?? 'Véhicule';

        nouveaux.removeWhere((m) => m.markerId.value == id);
        nouveaux.add(Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lon),
          infoWindow: InfoWindow(
            title: titre,
            snippet: 'Dernière mise à jour: ${v['updated_at'] ?? 'inconnue'}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ));
      }

      if (mounted) setState(() => _markers = nouveaux);
    } catch (e) {
      // ignore: avoid_print
      // print('Erreur chargement vehicules live: $e');
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

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF333333), size: 24),
      ),
    );
  }

  void _updateUserMarker() {
    if (_currentPosition == null) return;
    const userId = 'user_position';
    final nouveaux = Set<Marker>.from(_markers);
    nouveaux.removeWhere((m) => m.markerId.value == userId);
    nouveaux.add(Marker(
      markerId: const MarkerId(userId),
      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      infoWindow: const InfoWindow(title: 'Moi'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    ));
    if (mounted) setState(() => _markers = nouveaux);
  }

  @override
  void dispose() {
    _vehiculeTimer?.cancel();
    _positionStreamSub?.cancel();
    _panelController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

// Widget shimmer pour le loading
class ShimmerText extends StatelessWidget {
  const ShimmerText({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: const Color(0xFFFF6B2B),
      child: const Text(
        'TransitCI',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
      ),
    );
  }
}