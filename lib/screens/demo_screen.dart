import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../app_theme.dart';
import '../models/ligne.dart';
import '../models/trajet.dart';
import '../models/gare.dart';
import '../models/conditions_trafic.dart';
import '../services/settings_service.dart';
import '../services/tip_service.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final GlobalKey<_DemoInteractivePageState> _interactiveKey = GlobalKey();

  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  int _selectedTrajet = 0;
  late final List<Trajet> _trajetsDemo = _buildTrajetsDemo();

  bool _autoTheme = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entryController.forward();
  }

  Future<void> _loadSettings() async {
    final auto = await SettingsService.getAutoTheme();
    if (mounted) setState(() => _autoTheme = auto);
  }

  bool get _isNight {
    if (!_autoTheme) return false;
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  Color get _bgColor => _isNight ? AppTheme.darkBg : const Color(0xFFF8F8F8);
  Color get _textColor => _isNight ? AppTheme.darkTextPrimary : const Color(0xFF0A0A0A);
  Color get _subTextColor => _isNight ? AppTheme.darkTextSecondary : Colors.grey.shade600;

  static List<Trajet> _buildTrajetsDemo() {
    return [
      Trajet(
        segments: [
          Segment(
            type: TypeSegment.piedVersGare,
            deLatitude: 5.3560,
            deLongitude: -4.0100,
            versLatitude: 5.3520,
            versLongitude: -4.0130,
            dureeMinutes: 8,
            prix: 0,
            description: 'Marche vers l\'arrêt Woro-Woro (~8 min)',
          ),
          Segment(
            type: TypeSegment.transport,
            deLatitude: 5.3520,
            deLongitude: -4.0130,
            versLatitude: 5.3220,
            versLongitude: -4.0220,
            dureeMinutes: 22,
            prix: 300,
            description: 'Prends Woro-Woro direction Plateau — descends à Plateau Gare',
            arretMontee: 'Riviera',
            arretDescente: 'Plateau',
            couleurVehicule: '#FF6B2B',
          ),
          Segment(
            type: TypeSegment.piedVersDest,
            deLatitude: 5.3220,
            deLongitude: -4.0220,
            versLatitude: 5.3190,
            versLongitude: -4.0230,
            dureeMinutes: 4,
            prix: 0,
            description: 'Marche vers ta destination (~4 min)',
          ),
        ],
        dureeTotal: 34,
        prixTotal: 300,
        score: 34 + 300 * 2.0 + 0 * 5,
        resume: 'Woro-Woro vers Plateau (~34 min)',
      ),
      Trajet(
        segments: [
          Segment(
            type: TypeSegment.piedVersGare,
            deLatitude: 5.3560,
            deLongitude: -4.0100,
            versLatitude: 5.3520,
            versLongitude: -4.0130,
            dureeMinutes: 10,
            prix: 0,
            description: 'Marche vers l\'arrêt Gbaka (~10 min)',
          ),
          Segment(
            type: TypeSegment.transport,
            deLatitude: 5.3520,
            deLongitude: -4.0130,
            versLatitude: 5.3220,
            versLongitude: -4.0220,
            dureeMinutes: 28,
            prix: 250,
            description: 'Prends Gbaka direction Plateau — descends à Plateau Gare',
            arretMontee: 'Adjamé',
            arretDescente: 'Plateau',
            couleurVehicule: '#00C896',
          ),
          Segment(
            type: TypeSegment.piedVersDest,
            deLatitude: 5.3220,
            deLongitude: -4.0220,
            versLatitude: 5.3190,
            versLongitude: -4.0230,
            dureeMinutes: 4,
            prix: 0,
            description: 'Marche vers ta destination (~4 min)',
          ),
        ],
        dureeTotal: 42,
        prixTotal: 250,
        score: 42 + 250 * 2.0 + 0 * 5,
        resume: 'Gbaka vers Plateau (~42 min)',
      ),
      Trajet(
        segments: [
          Segment(
            type: TypeSegment.piedVersGare,
            deLatitude: 5.3560,
            deLongitude: -4.0100,
            versLatitude: 5.3480,
            versLongitude: -3.9950,
            dureeMinutes: 12,
            prix: 0,
            description: 'Marche vers l\'arrêt SOTRA (~12 min)',
          ),
          Segment(
            type: TypeSegment.transport,
            deLatitude: 5.3480,
            deLongitude: -3.9950,
            versLatitude: 5.3200,
            versLongitude: -4.0240,
            dureeMinutes: 35,
            prix: 200,
            description: 'Prends SOTRA 81 direction Plateau Sud — descends à Plateau Sud',
            arretMontee: 'Cocody',
            arretDescente: 'Plateau Sud',
            couleurVehicule: '#2196F3',
          ),
          Segment(
            type: TypeSegment.piedVersDest,
            deLatitude: 5.3200,
            deLongitude: -4.0240,
            versLatitude: 5.3190,
            versLongitude: -4.0230,
            dureeMinutes: 2,
            prix: 0,
            description: 'Marche vers ta destination (~2 min)',
          ),
        ],
        dureeTotal: 49,
        prixTotal: 200,
        score: 49 + 200 * 2.0 + 0 * 5,
        resume: 'SOTRA 81 vers Plateau Sud (~49 min)',
      ),
    ];
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _terminer();
    }
  }

  void _terminer() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _resetDemo() {
    setState(() {
      _selectedTrajet = 0;
      _currentPage = 0;
    });
    _interactiveKey.currentState?.resetDemo();
    _pageController.animateToPage(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: FadeTransition(
        opacity: _entryAnimation,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentPage = i);
                  _entryController.reset();
                  _entryController.forward();
                },
                children: [
                  _buildProblemPage(),
                  _buildSolutionPage(),
                  _buildDemoPage(),
                  _buildFeaturesPage(),
                  _buildCtaPage(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _terminer,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isNight ? AppTheme.darkStroke : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, color: _textColor, size: 18),
            ),
          ),
          const Spacer(),
          Text(
            'Démo',
            style: TextStyle(
              color: _subTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.traffic_rounded, size: 40, color: Colors.red),
          ),
          const SizedBox(height: 24),
          Text(
            'Le problème',
            style: TextStyle(
              color: _textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'À Abidjan, un trajet simple peut prendre 3h...',
            textAlign: TextAlign.center,
            style: TextStyle(color: _subTextColor, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          _buildStatCard('44 000 FCFA/mois', 'Transport sur un SMIG de 75 000', Colors.red),
          const SizedBox(height: 10),
          _buildStatCard('30+ minutes', "Temps d'attente moyen aux arrêts", Colors.orange),
          const SizedBox(height: 10),
          _buildStatCard('3 heures', "Perte maximale par trajet aux heures de pointe", Colors.deepPurple),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: _subTextColor, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.alt_route_rounded, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Transit CI',
            style: TextStyle(
              color: _textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Tout l'écosystème de transport d'Abidjan, dans une seule app.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _subTextColor, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildModeChip('🚕', 'Woro-Woro', const Color(0xFFFF6B2B)),
              _buildModeChip('🚐', 'Gbaka', const Color(0xFF00C896)),
              _buildModeChip('🚌', 'SOTRA', const Color(0xFF2196F3)),
              _buildModeChip('🚙', 'Yango', const Color(0xFFFFB800)),
              _buildModeChip('🚶', 'Marche', const Color(0xFF6366F1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String emoji, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDemoPage() {
    return _DemoInteractivePage(
      key: _interactiveKey,
      trajets: _trajetsDemo,
      selectedTrajet: _selectedTrajet,
      onSelectedTrajetChanged: (i) => setState(() => _selectedTrajet = i),
      onReset: _resetDemo,
      isNight: _isNight,
      textColor: _textColor,
      subTextColor: _subTextColor,
      currentPage: _currentPage,
    );
  }

  Widget _buildFeaturesPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Fonctionnalités clés',
            style: TextStyle(color: _textColor, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.navigation_rounded, 'Navigation temps réel', 'Suivi GPS, snap-to-route, ETA dynamique', AppTheme.primary),
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.smart_toy_rounded, 'Guide IA contextuel', 'Overlay animé, adapté à ta situation', const Color(0xFF6366F1)),
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.chat_bubble_outline_rounded, 'TransitBot', 'Assistant conversationnel 24/7', const Color(0xFF00C896)),
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.directions_car_rounded, 'Mode chauffeur', 'Session live, stats, gains', const Color(0xFFFF6B2B)),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: _textColor, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: _subTextColor, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.emoji_transportation_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            "On ne devine plus. On sait.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Transit CI — l'app qui rend le transport à Abidjan lisible, prévisible, et accessible à tous.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _subTextColor, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _terminer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Essayer Transit CI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _terminer,
            child: Text('Retour', style: TextStyle(color: _subTextColor, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final isLast = _currentPage == 4;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        children: [
          SmoothPageIndicator(
            controller: _pageController,
            count: 5,
            effect: ExpandingDotsEffect(
              activeDotColor: AppTheme.primary,
              dotColor: _isNight ? AppTheme.darkStroke : Colors.grey.shade300,
              dotHeight: 8,
              dotWidth: 8,
              expansionFactor: 3,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_currentPage > 0)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: _isNight ? AppTheme.darkSurfaceBright : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.arrow_back, color: _textColor, size: 20),
                  ),
                ),
              if (_currentPage > 0) const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _nextPage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLast ? 'C\'est parti !' : 'Suivant',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoInteractivePage extends StatefulWidget {
  final List<Trajet> trajets;
  final int selectedTrajet;
  final ValueChanged<int> onSelectedTrajetChanged;
  final VoidCallback onReset;
  final bool isNight;
  final Color textColor;
  final Color subTextColor;
  final int currentPage;

  const _DemoInteractivePage({
    super.key,
    required this.trajets,
    required this.selectedTrajet,
    required this.onSelectedTrajetChanged,
    required this.onReset,
    required this.isNight,
    required this.textColor,
    required this.subTextColor,
    required this.currentPage,
  });

  @override
  State<_DemoInteractivePage> createState() => _DemoInteractivePageState();
}

class _DemoInteractivePageState extends State<_DemoInteractivePage> {
  bool _searchFocused = false;
  bool _resultsRevealed = false;
  bool _navigationStarted = false;
  bool _guideShown = false;

  static const double _minLat = 5.3220;
  static const double _maxLat = 5.3500;
  static const double _minLng = -4.0220;
  static const double _maxLng = -4.0100;

  void resetDemo() {
    setState(() {
      _searchFocused = false;
      _resultsRevealed = false;
      _navigationStarted = false;
      _guideShown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = widget.currentPage == 2;
    final showResults = _searchFocused && _resultsRevealed;
    final showNav = _navigationStarted;
    final showGuide = _guideShown;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            showNav ? 'Navigation temps réel' : showResults ? 'Résultats & choix' : 'Recherche',
            style: TextStyle(color: widget.textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Stack(
              children: [
                // Carte mock
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: widget.isNight ? const Color(0xFF1A1A2E) : const Color(0xFFE5E3DF),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Fond carte
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DemoMapPainter(isNight: widget.isNight),
                            ),
                          ),
                          // Marqueurs (positionnés selon les dimensions réelles)
                          if (showResults || showNav)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final w = constraints.maxWidth;
                                final h = constraints.maxHeight;
                                return Stack(
                                  children: [
                                    _buildDemoMarker(w, h, 5.3320, -4.0150, 'Riviera', const Color(0xFFFF6B2B)),
                                    _buildDemoMarker(w, h, 5.3220, -4.0220, 'Plateau', const Color(0xFF2196F3)),
                                    if (showNav) _buildDemoUserMarker(w, h, 5.3500, -4.0100),
                                  ],
                                );
                              },
                            ),
                          // Polyligne
                          if (showNav)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _DemoRoutePainter(isNight: widget.isNight),
                              ),
                            ),
                          // Overlay guide
                          if (showGuide)
                            Positioned(
                              top: 12,
                              left: 12,
                              right: 12,
                              child: _DemoGuideBubble(isNight: widget.isNight),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // UI overlay
                if (showSearch || showResults)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchFocused = true;
                          _resultsRevealed = false;
                          _navigationStarted = false;
                          _guideShown = false;
                        });
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            setState(() {
                              _resultsRevealed = true;
                            });
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: widget.isNight ? AppTheme.darkSurfaceBright : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Plateau, Abidjan',
                                style: TextStyle(
                                  color: widget.textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.close, color: widget.subTextColor, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Contrôles
                if (showResults && !showNav)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _navigationStarted = true;
                                _guideShown = false;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Naviguer', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _guideShown = !_guideShown;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isNight ? AppTheme.darkSurfaceBright : Colors.white,
                            foregroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Guide IA'),
                        ),
                      ],
                    ),
                  ),
                // CTA reset démo
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: TextButton(
                    onPressed: widget.onReset,
                    style: TextButton.styleFrom(
                      backgroundColor: widget.isNight ? AppTheme.darkSurfaceBright : Colors.white,
                      foregroundColor: AppTheme.primary,
                    ),
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (showResults && !showNav)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(widget.trajets.length, (i) {
                  final t = widget.trajets[i];
                  final selected = i == widget.selectedTrajet;
                  return GestureDetector(
                    onTap: () => widget.onSelectedTrajetChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 160,
                      margin: EdgeInsets.only(right: i < widget.trajets.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary.withValues(alpha: 0.1) : (widget.isNight ? AppTheme.darkSurfaceBright : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppTheme.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.resume,
                            style: TextStyle(
                              color: widget.textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 12, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text('${t.dureeTotal} min', style: TextStyle(color: widget.subTextColor, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined, size: 12, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text('${t.prixTotal} FCFA', style: TextStyle(color: widget.subTextColor, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  double _markerX(double lng, double width) {
    final t = ((lng - _minLng) / (_maxLng - _minLng)).clamp(0.0, 1.0);
    const padX = 64.0;
    return padX + t * (width - 2 * padX);
  }

  double _markerY(double lat, double height) {
    final t = ((_maxLat - lat) / (_maxLat - _minLat)).clamp(0.0, 1.0);
    const padY = 32.0;
    return padY + t * (height - 2 * padY);
  }

  Widget _buildDemoMarker(double width, double height, double lat, double lng, String label, Color color) {
    return Positioned(
      top: _markerY(lat, height),
      left: _markerX(lng, width),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDemoUserMarker(double width, double height, double lat, double lng) {
    return Positioned(
      top: _markerY(lat, height),
      left: _markerX(lng, width),
      child: Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppTheme.primary, blurRadius: 8)],
        ),
      ),
    );
  }
}

class _DemoMapPainter extends CustomPainter {
  final bool isNight;
  _DemoMapPainter({required this.isNight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final fill = isNight ? const Color(0xFF1A1A2E) : const Color(0xFFE5E3DF);
    paint.color = fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    paint.color = isNight ? const Color(0xFF2A2A3E) : const Color(0xFFD5D3CF);
    for (int i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i.toDouble(), 0), Offset(i.toDouble(), size.height), paint);
    }
    for (int i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DemoRoutePainter extends CustomPainter {
  final bool isNight;
  _DemoRoutePainter({required this.isNight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.primary;

    final path = Path()
      ..moveTo(size.width * 0.55, size.height * 0.25)
      ..lineTo(size.width * 0.45, size.height * 0.45)
      ..lineTo(size.width * 0.55, size.height * 0.75);

    canvas.drawPath(path, paint);

    paint.color = Colors.white;
    paint.strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DemoGuideBubble extends StatelessWidget {
  final bool isNight;
  const _DemoGuideBubble({required this.isNight});

  String get _guideText {
    final tip = TipService.instance.getTip(
      TipEvent.resultsShown,
      heure: DateTime.now().hour,
      conditions: const ConditionsTrafic(),
      destination: 'Plateau',
    );
    return tip.isNotEmpty
        ? tip
        : '🚦 Trafic dense sur la ligne 81. Je te propose un Woro-Woro direct.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _guideText,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
