import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/trajet.dart';
import '../services/settings_service.dart';
import '../services/yango_estimate_service.dart';
import 'navigation_screen.dart';

enum Priorite { economique, rapide, equilibre }

class ResultsScreen extends StatefulWidget {
  final List<Trajet> trajets;
  final String destination;
  final double? destLat;
  final double? destLon;
  final double? userLat;
  final double? userLon;

  const ResultsScreen({
    super.key,
    required this.trajets,
    required this.destination,
    this.destLat,
    this.destLon,
    this.userLat,
    this.userLon,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  Priorite _priorite = Priorite.equilibre;
  bool _autoTheme = false;
  late List<Trajet> _options;
  YangoEstimate? _yangoEstimate;

  late AnimationController _listController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _options = widget.trajets;
    _loadSettings();

    if (widget.destLat != null &&
        widget.destLon != null &&
        widget.userLat != null &&
        widget.userLon != null) {
      _yangoEstimate = YangoEstimateService.estimer(
        userLat: widget.userLat!,
        userLon: widget.userLon!,
        destLat: widget.destLat!,
        destLon: widget.destLon!,
        heure: DateTime.now().hour,
      );
    }

    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardAnimations = List.generate(3, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _listController,
          curve: Interval(i * 0.2, 0.6 + i * 0.2,
              curve: Curves.easeOutCubic),
        ),
      );
    });

    _listController.forward();
  }

  Future<void> _loadSettings() async {
    final auto = await SettingsService.getAutoTheme();
    if (!mounted) return;
    setState(() => _autoTheme = auto);
  }

  bool get _isNight {
    if (!_autoTheme) return false;
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  Color get _bgColor =>
      _isNight ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
  Color get _cardColor =>
      _isNight ? const Color(0xFF161616) : Colors.white;
  Color get _textColor =>
      _isNight ? Colors.white : const Color(0xFF0A0A0A);
  Color get _subTextColor =>
      _isNight ? Colors.white54 : Colors.grey.shade500;

  void _changerPriorite(Priorite p) {
    HapticFeedback.lightImpact();
    setState(() {
      _priorite = p;
      _options = List.from(_options)
        ..sort((a, b) => _scoreAvecPriorite(a, p)
            .compareTo(_scoreAvecPriorite(b, p)));
    });
    _listController.reset();
    _listController.forward();
  }

  double _scoreAvecPriorite(Trajet trajet, Priorite p) {
    switch (p) {
      case Priorite.economique:
        return (trajet.prixTotal * 3 + trajet.dureeTotal).toDouble();
      case Priorite.rapide:
        return (trajet.dureeTotal * 3 + trajet.prixTotal / 100).toDouble();
      case Priorite.equilibre:
        return (trajet.prixTotal * 1.5 + trajet.dureeTotal * 1.5).toDouble();
    }
  }

  Color _couleurResume(String resume) {
    if (resume.contains('Woro')) return const Color(0xFFFF6B2B);
    if (resume.contains('Gbaka')) return const Color(0xFF00C896);
    if (resume.contains('SOTRA')) return const Color(0xFF2196F3);
    return const Color(0xFFFF6B2B);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildHeader(),
          _buildPrioriteFilter(),
          Expanded(
            child: _options.isEmpty
                ? Center(
                    child: Text(
                      'Aucun trajet trouvé',
                      style: TextStyle(color: _subTextColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _options.length + (_yangoEstimate != null ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_yangoEstimate != null && i == 0) {
                        final estim = _yangoEstimate!;
                        return AnimatedBuilder(
                          animation: _cardAnimations.first,
                          builder: (_, child) => Opacity(
                            opacity: _cardAnimations.first.value,
                            child: Transform.translate(
                              offset: Offset(0, 40 * (1 - _cardAnimations.first.value)),
                              child: child,
                            ),
                          ),
                          child: _buildYangoCard(estim),
                        );
                      }

                      final index = _yangoEstimate != null ? i - 1 : i;
                      final anim = index < _cardAnimations.length
                          ? _cardAnimations[index]
                          : _cardAnimations.last;
                      return AnimatedBuilder(
                        animation: anim,
                        builder: (_, child) => Opacity(
                          opacity: anim.value,
                          child: Transform.translate(
                            offset: Offset(0, 40 * (1 - anim.value)),
                            child: child,
                          ),
                        ),
                        child: _buildTrajetCard(_options[index], index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 16, 16, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isNight ? 0.4 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isNight ? Colors.white10 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back, color: _textColor, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meilleurs trajets',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Color(0xFFFF6B2B), size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '→ ${widget.destination}',
                        style: const TextStyle(
                          color: Color(0xFFFF6B2B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B2B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF6B2B).withOpacity(0.3),
              ),
            ),
            child: Text(
              '${_options.length + (_yangoEstimate != null ? 1 : 0)} option${_options.length + (_yangoEstimate != null ? 1 : 0) > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Color(0xFFFF6B2B),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioriteFilter() {
    final filters = [
      {'label': '💰 Économique', 'value': Priorite.economique},
      {'label': '⚡ Rapide', 'value': Priorite.rapide},
      {'label': '⚖️ Équilibré', 'value': Priorite.equilibre},
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isNight ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: filters.map((f) {
          final isSelected = _priorite == f['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () => _changerPriorite(f['value'] as Priorite),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [
                          Color(0xFFFF6B2B),
                          Color(0xFFFF8C55),
                        ])
                      : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  f['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : _subTextColor,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildYangoCard(YangoEstimate estimate) {
    const couleur = Color(0xFFFFCC00);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: couleur.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: couleur.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(Icons.local_taxi, color: couleur, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Yango (VTC)',
                    style: TextStyle(
                      color: couleur,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '${estimate.prixMin} - ${estimate.prixMax} FCFA',
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _buildStat('💰', '${estimate.prixMin}', 'FCFA', couleur),
                _buildDivider(),
                _buildStat('⏱️', '${estimate.dureeMinutes}', 'min', couleur),
                _buildDivider(),
                const Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.speed, color: Color(0xFFFFCC00), size: 18),
                      SizedBox(height: 4),
                      Text(
                        '~25 km/h',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrajetCard(Trajet trajet, int index) {
    final isMeilleur = index == 0;
    final couleur = _couleurResume(trajet.resume);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => NavigationScreen(
              trajet: trajet,
              destLat: widget.destLat ?? 0,
              destLon: widget.destLon ?? 0,
            ),
            transitionsBuilder: (_, animation, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isMeilleur
              ? Border.all(color: couleur, width: 1.5)
              : Border.all(
                  color: _isNight
                      ? Colors.white10
                      : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: isMeilleur
                  ? couleur.withOpacity(0.15)
                  : Colors.black.withOpacity(_isNight ? 0.3 : 0.06),
              blurRadius: isMeilleur ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: couleur.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                trajet.resume,
                                style: TextStyle(
                                  color: couleur,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMeilleur) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: couleur,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '⭐ Meilleur',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (trajet.correspondances > 0)
                          Text(
                            '${trajet.correspondances} correspondance(s)',
                            style: TextStyle(
                                color: _subTextColor, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: couleur, size: 14),
                ],
              ),
            ),

            // ── Stats ──
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _buildStat('💰', '${trajet.prixTotal}', 'FCFA', couleur),
                  _buildDivider(),
                  _buildStat('⏱️', '${trajet.dureeTotal}', 'min', couleur),
                  _buildDivider(),
                  _buildStat(
                      '🔄', '${trajet.correspondances}', 'corresp.', couleur),
                ],
              ),
            ),

            // ── Segments ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: trajet.segments
                    .where((s) => s.type != TypeSegment.piedVersDest)
                    .map((s) => _buildSegmentRow(s))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentRow(Segment s) {
    final isTransport = s.type == TypeSegment.transport;
    final color =
        isTransport ? const Color(0xFFFF6B2B) : const Color(0xFF00C896);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isTransport ? Icons.directions_bus : Icons.directions_walk,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.description,
              style: TextStyle(color: _subTextColor, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${s.dureeMinutes} min',
            style: TextStyle(
              color: _textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
      String emoji, String valeur, String label, Color couleur) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            valeur,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: _subTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: _isNight ? Colors.white10 : Colors.grey.shade200,
    );
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }
}