import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../services/settings_service.dart';
import '../app_theme.dart';

class TutorialScreen extends StatefulWidget {
  final bool fromSettings;

  const TutorialScreen({super.key, this.fromSettings = false});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _autoTheme = false;

  late AnimationController _entryController;
  late AnimationController _floatController;
  late Animation<double> _entryAnimation;
  late Animation<double> _floatAnimation;

  final List<TutorialPage> _pages = [
    const TutorialPage(
      emoji: '',
      titre: 'Bienvenue sur TransitCI',
      description:
          'L\'app qui te guide dans les transports d\'Abidjan. '
          'Woro-woro, gbaka, SOTRA — tout en un seul endroit.',
      couleur: Color(0xFFFF6B2B),
      illustration: _IllustrationAccueil(),
      astuces: [
        'Orange = Woro-Woro',
        'Vert = Gbaka',
        'Bleu = SOTRA',
      ],
    ),
    const TutorialPage(
      emoji: '',
      titre: 'Ta position en temps réel',
      description:
          'TransitCI détecte automatiquement où tu es. '
          'Active le GPS pour trouver les gares les plus proches de toi.',
      couleur: Color(0xFF00C896),
      illustration: _IllustrationGPS(),
      astuces: [
        'GPS haute précision',
        'Distance à pied calculée',
        'Temps de marche estimé',
      ],
    ),
    const TutorialPage(
      emoji: '',
      titre: 'Cherche ta destination',
      description:
          'Tape où tu veux aller. L\'algo analyse toutes les options '
          'disponibles et te propose les 3 meilleures.',
      couleur: Color(0xFF2196F3),
      illustration: _IllustrationRecherche(),
      astuces: [
        'Mode Economique',
        'Mode Rapide',
        'Mode Equilibre',
      ],
    ),
    const TutorialPage(
      emoji: '',
      titre: 'Compare et choisis',
      description:
          'Chaque option affiche le prix exact, le temps total '
          'et la distance à marcher. Tu choisis selon tes besoins.',
      couleur: Color(0xFFFF6B2B),
      illustration: _IllustrationResultats(),
      astuces: [
        'Le meilleur choix mis en avant',
        'Filtres en temps réel',
        'Tape pour naviguer',
      ],
    ),
    const TutorialPage(
      emoji: '',
      titre: 'Guidage jusqu\'à la gare',
      description:
          'Une fois ton transport choisi, suis l\'itinéraire à pied '
          'jusqu\'à la gare. Trajet tracé en temps réel sur la carte.',
      couleur: Color(0xFF00C896),
      illustration: _IllustrationNavigation(),
      astuces: [
        'Itinéraire pédestre',
        'Marqueurs de départ et arrivée',
        'Mode nuit automatique',
      ],
    ),
  ];

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

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _entryController.forward();
  }

  Future<void> _loadSettings() async {
    final auto = await SettingsService.getAutoTheme();
    setState(() => _autoTheme = auto);
  }

  bool get _isNight {
    if (!_autoTheme) return false;
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  Color get _bgColor => _isNight ? AppTheme.darkBg : const Color(0xFFF8F8F8);
  Color get _textColor => _isNight ? AppTheme.darkTextPrimary : const Color(0xFF0A0A0A);
  Color get _subTextColor => _isNight ? AppTheme.darkTextSecondary : Colors.grey.shade600;

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
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
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentPage = i);
                  _entryController.reset();
                  _entryController.forward();
                },
                itemCount: _pages.length,
                itemBuilder: (_, i) => _buildPage(_pages[i]),
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
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 16),
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
            '${_currentPage + 1} / ${_pages.length}',
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

  Widget _buildPage(TutorialPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: child,
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: page.couleur.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: page.couleur.withValues(alpha: 0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: page.illustration,
                ),
              ),
            ),
          ),

          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(page.emoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  Text(
                    page.titre,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    page.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _subTextColor,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: page.astuces.map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: page.couleur.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: page.couleur.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          a,
                          style: TextStyle(
                            color: page.couleur,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        children: [
          SmoothPageIndicator(
            controller: _pageController,
            count: _pages.length,
            effect: ExpandingDotsEffect(
              activeDotColor: page.couleur,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: _isNight ? AppTheme.darkSurfaceBright : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.arrow_back,
                        color: _textColor, size: 20),
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
                        colors: [
                          page.couleur,
                          page.couleur.withValues(alpha: 0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: page.couleur.withValues(alpha: 0.4),
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
                          const Icon(Icons.arrow_forward,
                              color: Colors.white, size: 18),
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

class TutorialPage {
  final String emoji;
  final String titre;
  final String description;
  final Color couleur;
  final Widget illustration;
  final List<String> astuces;

  const TutorialPage({
    required this.emoji,
    required this.titre,
    required this.description,
    required this.couleur,
    required this.illustration,
    required this.astuces,
  });
}

class _IllustrationAccueil extends StatelessWidget {
  const _IllustrationAccueil();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AccueilPainter(),
      child: const SizedBox(height: 220),
    );
  }
}

class _AccueilPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;

    paint.color = const Color(0xFFFF6B2B).withValues(alpha: 0.05);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.42, paint);

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      paint.color =
          const Color(0xFFFF6B2B).withValues(alpha: 0.08 * i);
      canvas.drawCircle(Offset(cx, cy), size.width * 0.15 * i, paint);
    }

    _drawMarker(canvas, Offset(cx - 70, cy - 40),
        const Color(0xFFFF6B2B), 18, paint);
    _drawMarker(canvas, Offset(cx + 50, cy - 60),
        const Color(0xFF00C896), 14, paint);
    _drawMarker(canvas, Offset(cx + 20, cy + 50),
        const Color(0xFF2196F3), 16, paint);
    _drawMarker(canvas, Offset(cx - 40, cy + 60),
        const Color(0xFFFF6B2B), 12, paint);

    paint.style = PaintingStyle.fill;
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), 12, paint);
    paint.color = const Color(0xFFFF6B2B);
    canvas.drawCircle(Offset(cx, cy), 8, paint);
  }

  void _drawMarker(Canvas canvas, Offset pos, Color color,
      double size, Paint paint) {
    paint.style = PaintingStyle.fill;
    paint.color = color;
    final path = Path()
      ..addOval(Rect.fromCircle(center: pos, radius: size / 2))
      ..moveTo(pos.dx, pos.dy + size / 2)
      ..lineTo(pos.dx - size / 3, pos.dy + size)
      ..lineTo(pos.dx + size / 3, pos.dy + size)
      ..close();
    canvas.drawPath(path, paint);
    paint.color = Colors.white;
    canvas.drawCircle(pos, size / 4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _IllustrationGPS extends StatelessWidget {
  const _IllustrationGPS();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GPSPainter(),
      child: const SizedBox(height: 220),
    );
  }
}

class _GPSPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final cx = size.width / 2;
    final cy = size.height / 2;

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    for (int i = 1; i <= 4; i++) {
      paint.color =
          const Color(0xFF00C896).withValues(alpha: 0.15 + i * 0.08);
      canvas.drawCircle(Offset(cx, cy), i * 30.0, paint);
    }

    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF00C896).withValues(alpha: 0.2);
    canvas.drawCircle(Offset(cx, cy), 28, paint);
    paint.color = const Color(0xFF00C896);
    canvas.drawCircle(Offset(cx, cy), 14, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), 6, paint);

    paint.color = const Color(0xFF00C896).withValues(alpha: 0.2);
    paint.strokeWidth = 4;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), paint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _IllustrationRecherche extends StatelessWidget {
  const _IllustrationRecherche();
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF2196F3), size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Sococé, Riviera 2...',
                      style: TextStyle(color: Color(0xFF2196F3), fontSize: 12),
                    ),
                  ),
                  Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: ['Economique', 'Rapide', 'Equilibre']
                  .asMap()
                  .entries
                  .map((e) {
                final selected = e.key == 2;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2196F3)
                          : const Color(0xFF2196F3).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF2196F3),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            ...['Woro-Woro', 'SOTRA']
                .asMap()
                .entries
                .map((e) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3)
                      .withValues(alpha: e.key == 0 ? 0.15 : 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: e.key == 0
                      ? Border.all(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.5))
                      : null,
                ),
                child: Row(
                  children: [
                    Text(e.value, style: const TextStyle(fontSize: 11)),
                    const Spacer(),
                    if (e.key == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Meilleur',
                            style: TextStyle(color: Colors.white, fontSize: 8)),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _IllustrationResultats extends StatelessWidget {
  const _IllustrationResultats();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMockCard('Woro-Woro',
              '300 FCFA', '42 min', const Color(0xFFFF6B2B), true),
          const SizedBox(height: 10),
          _buildMockCard('SOTRA',
              '200 FCFA', '55 min', const Color(0xFF2196F3), false),
          const SizedBox(height: 10),
          _buildMockCard('Gbaka',
              '250 FCFA', '50 min', const Color(0xFF00C896), false),
        ],
      ),
    );
  }

  Widget _buildMockCard(String label, String prix,
      String temps, Color color, bool best) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: color.withValues(alpha: best ? 0.6 : 0.2),
            width: best ? 1.5 : 1),
      ),
      child: Row(
        children: [
          const Spacer(),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const Spacer(),
          Text(prix,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(temps,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

class _IllustrationNavigation extends StatelessWidget {
  const _IllustrationNavigation();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NavPainter(),
      child: const SizedBox(height: 220),
    );
  }
}

class _NavPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final cx = size.width / 2;

    final path = Path()
      ..moveTo(cx - 60, size.height * 0.8)
      ..cubicTo(
        cx - 40, size.height * 0.5,
        cx + 40, size.height * 0.5,
        cx + 60, size.height * 0.2,
      );

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 12;
    paint.color = _isNight ? AppTheme.darkStroke : Colors.white.withValues(alpha: 0.3);
    paint.strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);

    paint.strokeWidth = 6;
    paint.color = const Color(0xFF00C896);
    canvas.drawPath(path, paint);

    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF2196F3);
    canvas.drawCircle(Offset(cx - 60, size.height * 0.8), 10, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(cx - 60, size.height * 0.8), 5, paint);

    paint.color = const Color(0xFF00C896);
    final markerPath = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(cx + 60, size.height * 0.2), radius: 14))
      ..moveTo(cx + 60, size.height * 0.2 + 14)
      ..lineTo(cx + 55, size.height * 0.2 + 22)
      ..lineTo(cx + 65, size.height * 0.2 + 22)
      ..close();
    canvas.drawPath(markerPath, paint);
    paint.color = Colors.white;
    canvas.drawCircle(
        Offset(cx + 60, size.height * 0.2), 6, paint);
  }

  bool get _isNight {
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
